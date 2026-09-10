# Testing

Written before the code so the code is built to satisfy it. The security and
domain suites below are **required** and gate every release (spec §29).

## Layers

| Layer | Tooling | Runs against |
|---|---|---|
| Unit | Vitest / Jest | pure functions: slot math, RBAC `can()`, state-transition tables, adherence stats, token hashing |
| Integration | Vitest + a real Postgres (Neon dev branch or local container) + Prisma | module services through the tenant-scoped client |
| API / contract | supertest against the Next.js handler, real DB | full request pipeline: auth → tenant → RBAC → service → audit |
| Migration | `prisma migrate deploy` on a scratch DB in CI | schema applies cleanly from zero, incl. the EXCLUDE constraint |

No mocking of the database for integration/API tests — tenant isolation bugs
hide behind mocks. Each test file runs in its own schema/transaction and rolls
back.

## Required suites

### 1. Tenant isolation (`tenant-isolation.test.ts`)
Seed Clinic A + Clinic B. For **every** tenant-owned resource:
- A-user reading a B-owned id → `404`, body leaks nothing.
- A-user `PATCH`/`DELETE` on a B-owned id → `404`.
- A-user creating a child row that references a B-owned parent → `404`/`422`.
- List endpoints never include B rows.
- Body-supplied `organizationId: B` while authed as A → ignored/rejected.
- A cannot read a B `AuditLog` entry.

### 2. RBAC / role permissions (`rbac.test.ts`)
Drive the [RBAC.md](RBAC.md) matrix: for each (role, capability) cell, assert
allow/deny. Explicitly:
- `RECEPTIONIST` cannot read `Consultation`/`Prescription`/`Medication`/
  `Document` bodies (403 or fields stripped) — and there is **no** capability
  that can grant it.
- **`CLINIC_ADMIN` with `capabilities: []` cannot read clinical record bodies**
  (403 / stripped). After a **second** admin grants `CLINICAL_RECORD_READ` on
  that membership, the same request succeeds **and** writes a
  `CLINICAL_RECORD_VIEWED` audit row; `MEMBER_CAPABILITY_GRANTED` is audited
  with actor + target.
- **Self-grant rejected:** a `CLINIC_ADMIN` calling
  `PUT /members/:membershipId/capabilities` with `:membershipId` = their own
  membership and a `CLINICAL_RECORD_*` capability → `403
  CANNOT_SELF_GRANT_CAPABILITY`, no write, audit records the denied attempt.
  Granting `BILLING_MANAGE` / `DATA_EXPORT` to self is allowed.
- Single-admin clinic: no path exists for that admin to obtain
  `CLINICAL_RECORD_*` (needs a distinct second admin).
- `DOCTOR` with `CLINICAL_RECORD_READ` but **no** appointment/grant link to the
  patient → still `403` (capability alone is insufficient).
- `DOCTOR` without `CLINICAL_RECORD_READ` but with an appointment link → `403`
  for clinical bodies (link alone is insufficient); demographics still OK.
- `PATIENT` cannot read another patient.
- `SUPER_ADMIN` cannot read clinical bodies through normal endpoints (holds no
  clinic `Membership`).
- Guest principal (`isGuest`, demo-org `PATIENT` membership only): any
  `:orgId` ≠ demo org → `404`; cannot read real data; cannot write outside
  demo doctors/patients; issued no rotating refresh token; no path to a real
  membership.
- `allowDemoWalkthrough` policy branch: for a **guest** on the **demo org** it
  permits the allow-listed **read** endpoints for the doctor/reception
  dashboards **and nothing else** — same request as a non-guest, or on any
  non-demo org, or any write → denied. Standard tenant + ownership checks still
  run in the test (they pass only because the data is synthetic).

### 3. Authentication (`auth.test.ts`)
- Register → login → `/api/me` shape (memberships + role per org).
- Wrong password / unknown email → identical generic error, no enumeration.
- Access token expiry → `401 TOKEN_EXPIRED`; refresh rotates; old refresh
  token reuse → whole `familyId` revoked (`REFRESH_REUSE_DETECTED`).
- `logout-all` bumps `tv`, invalidating existing access tokens.
- Password reset consumes a single-use hashed token and revokes sessions.
- argon2id: hash never returned/logged; outdated params re-hashed on login.

### 4. Appointment lifecycle (`appointments.test.ts`)
- Every valid transition in [APPOINTMENT_WORKFLOW.md](APPOINTMENT_WORKFLOW.md)
  succeeds and writes one `AppointmentEvent` + one `AuditLog`.
- Every invalid transition → `409 INVALID_STATUS_TRANSITION`, no state change.
- Cancellation outside `cancellationWindowHours` → `403` for PATIENT, allowed
  for staff.
- Reschedule creates a linked new appointment, old → `RESCHEDULED`.
- Booking respects lead time / max-advance / self-booking flag.

### 5. Double-booking race (`double-booking.test.ts`)
- Two concurrent `POST /appointments` for the same doctor + overlapping range
  **in the same clinic**: exactly one `201`, the other
  `409 APPOINTMENT_SLOT_TAKEN`.
- Run with `Promise.all` and with real serialization conflicts (retry a few
  hundred iterations).
- Overlap of *different* durations is still rejected (EXCLUDE range overlap,
  not just equal start).
- A `CANCELLED`/`NO_SHOW`/`RESCHEDULED` appointment does **not** block the slot.

### 5b. Double-booking DB constraint (`double-booking.constraint.test.ts`)
Exercises the Postgres constraint directly (Prisma client + `prisma migrate
deploy` on a scratch DB — **no app layer needed**). Concrete file already
committed at `platform/tests/double-booking.constraint.test.ts`; runs in CI
once `platform/` has `package.json`.

- **Same org, same doctor, overlapping time** → the second insert throws
  (`Appointment_org_doctor_no_overlap` / `exclusion_violation`).
- **Different org, same underlying doctor (own `DoctorProfile` per org),
  identical time** → **both inserts succeed** (the reviewer's Clinic A / Clinic
  B example).
- Same org, same doctor, **adjacent non-overlapping** ranges (`10:00–10:30`,
  `10:30–11:00`) → both succeed (`'[)'` bounds).
- A row transitioned to `CANCELLED` frees the range for a new insert.

### 6. Availability / slot calculation (`availability.test.ts`)
- Rules + exceptions (`DAY_OFF`, `HOLIDAY`, `LEAVE`, `BREAK`, `EXTRA_HOURS`)
  produce the expected slot list.
- DST boundary date: local times convert to the correct instants.
- Slots before `now + leadTime` are excluded.
- A slot overlapping an existing active appointment is excluded.

### 7. Queue (`queue.test.ts`)
- Check-in issues sequential tokens per doctor/day; two concurrent check-ins
  never collide (unique constraint).
- `call` / `recall` / `skip` / `start` / `complete` transitions; invalid ones
  → `409`.
- Recalled entry is served next without renumbering.
- Clinic A queue ops never touch Clinic B rows.

### 8. Family / access grants (`family.test.ts`)
- Family link alone grants nothing.
- Guardian with `VIEW_MEDICATIONS` can read dependent meds; without it → `403`.
- Expired / revoked grant → `403` immediately.
- Only the patient-owner or `CLINIC_ADMIN` can create a grant.

### 9. Medication ownership & sync (`medications.test.ts`)
- `/api/sync/medications` batch: LWW on `updatedAt`; tombstones (`deletedAt`)
  win when newer; re-running the same batch is idempotent.
- `(sourceDeviceId, legacyLocalId)` uniqueness prevents duplicate import.
- A patient cannot sync into another patient's medication set.
- Clinic visibility of a patient's meds requires an authorization link.

### 10. Audit logging (`audit.test.ts`)
- Each mutating action writes exactly one `AuditLog` with `before`/`after`,
  actor, tenant, entity.
- `AuditLog` rows never contain a password, hash, session/refresh/reset token,
  or FCM token (assert by scanning serialized rows in the test).

### 11. Invitations (`invitations.test.ts`)
- Raw token never stored; only `sha256`.
- Single-use: second `accept` → `409 TOKEN_ALREADY_USED`.
- Expired → `409`; revoked → `409`.
- `accept` is atomic: a simulated failure after token-consume leaves no
  half-created membership/grant.

### 12. Error hygiene (`errors.test.ts`)
- No endpoint returns a raw Prisma/Postgres message.
- `500` bodies are the generic envelope; the detail is only in the log with a
  `requestId`.
- Cross-tenant lookups return `404`, not `403`.

### 13. Notification dispatcher (`notifications-dispatch.test.ts`)
- `POST /api/internal/notifications/dispatch` without / with a wrong
  `X-Cron-Key` → `404`; correct key → `200` + counters, no PHI in the body.
- A due `PENDING` row is delivered once → `SENT`; two concurrent dispatch
  calls (`Promise.all`) never double-send (claim + `SKIP LOCKED`).
- Deterministic `dedupeKey`: scheduling the same reminder twice inserts one
  row; the second is a silent no-op.
- Transient adapter failure → row back to `PENDING` with `nextAttemptAt` in the
  future and `attempts` incremented; not retried before `nextAttemptAt`.
- After `maxAttempts` → `FAILED`, never retried again; a sibling row in the
  same batch still sends.
- Crash simulation: a row left `SENDING` with an old `claimedAt` is reaped to
  `PENDING` on the next run and then delivered (at-least-once).
- `scheduledFor` in the future → not claimed until due.
- Opted-out recipient → `SUPPRESSED`, never sent.

## CI gate

`prisma validate` + `prisma format --check` + typecheck + **all** suites above
green. A failing tenant-isolation or double-booking test blocks merge and
release, no exceptions.

## DoseWise app tests

Unchanged and must stay green (`flutter test`). The existing fake
`RemoteBackend` is the model for testing the future `HttpBackend`.
