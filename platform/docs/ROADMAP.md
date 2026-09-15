# Roadmap

Sequenced. Each phase ends at a reviewable checkpoint. "Understand → Document →
Design → Backend → Web → Flutter integration" (spec §41).

## Phase 0 — Discovery & design  ← current

- [x] Inspect the existing DoseWise app.
- [x] `DOSEWISE_EXISTING_FUNCTIONALITY.md` — full feature inventory + reuse
      verdicts + a Reuse register (everything kept, nothing modified in Phase 0).
- [x] `prisma/schema.prisma` — `prisma@6 validate` passes, `prisma@6 format`
      clean. `MembershipCapability` enum + `Membership.capabilities` (empty by
      default; no role implies clinical access).
- [x] `prisma/sql/0001_appointment_no_overlap.sql` — EXCLUDE scoped by
      `(organizationId, doctorId, time range)`.
- [x] `tests/double-booking.constraint.test.ts` — DB-contract test.
- [x] `.env.example`, `.gitignore`.
- [x] All architecture / security / migration docs, incl. `GUEST_ACCESS.md`.
- [x] First-review corrections applied (see README "Corrections applied").
- [ ] **Sign-off checkpoint — you are here.** No code is scaffolded until the
      schema and docs are explicitly approved.

## Phase 1 — Backend foundation  ✅ DONE (2026-09-10)

- [x] Next.js 15 project scaffolded under `platform/` (App Router, TS, API-only).
      `next build` green (20 route handlers), `tsc --noEmit` clean.
- [x] `src/lib`: `env`, `db`, `crypto`, `errors`, `rate-limit`, `validation`,
      `audit`, `rbac`, `context`, `tenant` (Prisma `$extends` scoped client),
      `http` (pipeline), `auth/{password,tokens,session,authenticate,respond,oauth-google}`,
      `notifications/dispatch`.
- [x] Migrations applied to Neon: `20260910123448_init` (31 tables + the
      `Appointment_org_doctor_no_overlap` EXCLUDE constraint + `btree_gist`),
      `20260910124044_user_auth_fields` (`User.tokenVersion`, `User.isGuest`).
- [x] `prisma/seed.ts` — one **DEMO clinic**, synthetic data only: CLINIC_ADMIN
      + DOCTOR (Mon–Fri availability) + RECEPTIONIST + 3 patients + 2 appts +
      an appointment type.
- [x] Modules: `auth`, `tenancy`, `users`, `clinics`, `doctors`, `staff`.
- [x] Endpoints: `/api/health`, `/api/auth/{register,login,refresh,logout,logout-all,guest(501),google/*}`,
      `/api/me`, `/api/orgs` (+ `[orgId]`, `/settings`, `/locations`,
      `/members` (+ `[membershipId]` (+ `/capabilities`)), `/doctors`
      (+ `[doctorId]`), `/staff`), `/api/internal/notifications/dispatch`.
- [x] **Tests: 51 passing** (`npm test`) — unit (rbac, password/argon2id,
      tokens, rate-limit, errors) + integration against Neon:
      `auth` (R1–R11: argon2id, generic login failure, rotation + reuse
      detection + family burn, `tokenVersion` invalidation, cookie flags),
      `tenant-isolation` (cross-tenant → 404, no leak, no `X-Org-Id`,
      body `organizationId` rejected), `rbac` (role gates, **no self-grant of
      `CLINICAL_RECORD_*`**, audited grant to another member, audit rows carry
      no secrets), `double-booking.constraint` (same-clinic overlap rejected,
      cross-clinic same doctor allowed, adjacent OK, cancel frees range),
      `notifications-dispatch` (§13: cron-key 404, exactly-once, concurrency,
      future `scheduledFor`, PUSH→SUPPRESSED, stale-`SENDING` reaper).
- [x] **Checkpoint reached:** auth + tenancy + RBAC enforced and proven by
      the test suite; every subsequent phase keeps these green.

### Phase 1 — known follow-ups (not blockers)
- Google OAuth `start`/`callback` are implemented but only unit-reachable
  (`NOT_IMPLEMENTED` until `GOOGLE_CLIENT_ID/SECRET` are set); real end-to-end
  exercise lands in Phase 4.
- `/api/auth/guest` returns `501` until the demo-org policy + `allowDemoWalkthrough`
  are built (GUEST_ACCESS.md).
- `MembershipCapability` grant currently allows an admin to grant clinical
  caps to a *second* admin who then self-manages — the SoD rule blocks
  self-grant only; document/train around single-admin clinics.
- `npm test` TRUNCATEs the shared dev DB; re-run `npm run db:seed` afterward.
- ESLint not configured (`eslint.ignoreDuringBuilds`); `tsc` is the type gate.

## Phase 2 — Scheduling core  ✅ DONE (2026-09-11)

- [x] `src/lib/time.ts` — zero-dep timezone conversion (local wall-clock ↔ UTC
      instant via `Intl`, DST-corrected), ISO weekday, range overlap.
- [x] `src/lib/serializable.ts` — `runSerializable()` (SERIALIZABLE txn + write-
      conflict retry; overlap-constraint violation → `409 APPOINTMENT_SLOT_TAKEN`).
- [x] `src/lib/notifications/notify.ts` — enqueue helper (idempotent via
      `dedupeKey`, best-effort).
- [x] Central Prisma-error mapping in the pipeline (`P2025`→404, `P2002`→409,
      `P2003`→422, `P2034`→409) — cross-tenant record lookups now 404, not 500.
- [x] **`availability`** module — recurring `AvailabilityRule`s (weekday +
      minutes-from-local-midnight + slotMinutes), `AvailabilityException`
      (`DAY_OFF`/`HOLIDAY`/`LEAVE`/`BREAK` subtract, `EXTRA_HOURS` add),
      `computeFreeWindows` + `computeSlots` (tz-correct, minus existing
      appointments, minus lead-time), `assertWithinAvailability` for booking.
- [x] **`appointments`** module — state machine (`state-machine.ts`, the
      APPOINTMENT_WORKFLOW.md table; illegal move → `409
      INVALID_STATUS_TRANSITION`), `bookAppointment` (SERIALIZABLE, lead/advance
      checks, patient-self-book gate, availability check, EXCLUDE-backed),
      `confirm` / `cancel` (patient cancellation-window, staff override) /
      `reschedule` (linked new appt, old → `RESCHEDULED`, reminders re-scheduled)
      / `check-in` (→ CHECKED_IN → QueueEntry → WAITING) / `no-show` (guarded) /
      `start` / `complete` (assigned-doctor only). Every transition writes an
      `AppointmentEvent` + `AuditLog` + a `Notification`. Reminder rows
      (T-24H/T-2H, `dedupeKey`) created on confirm, suppressed on
      cancel/reschedule/check-in.
- [x] **`queue`** module — `state-machine.ts` (`WAITING/CALLED/IN_CONSULTATION/
      COMPLETED/SKIPPED`; illegal → `409 INVALID_QUEUE_TRANSITION`), token
      allocation per `(org, doctor, queueDate)` inside the check-in txn (unique
      constraint backstop), live board with people-ahead, `call`/`recall`
      (served next)/`skip`/`start`/`complete` (start/complete cascade to the
      appointment; assigned-doctor-only for those two).
- [x] **20 new routes**: `/doctors/:id/availability` (+`/exceptions` +
      `/exceptions/:id`), `/doctors/:id/slots`, `/appointment-types`,
      `/appointments` (+`/:id` + `confirm|cancel|reschedule|check-in|no-show|
      start|complete`), `/queue`, `/queue/:entryId/:action`.
- [x] **Tests: 72 passing total** (+21 in Phase 2) — `availability` (5),
      `appointments` (9: staff→CONFIRMED, outside-availability→409, **race →
      one 201 / one 409 `APPOINTMENT_SLOT_TAKEN`**, full flow, invalid
      transition→409, assigned-doctor-only, no-show guard, reschedule lineage,
      cancellation-window), `queue` (7: sequential tokens, board order,
      happy path, invalid→409, skip→recall served next, doctor-only start,
      cross-tenant→404). `tsc` clean, `next build` green.
- [x] **Checkpoint reached:** full book → confirm → check-in (token) → queue
      call → start → complete flow works end-to-end via the API and is tested.

### Phase 2 — known follow-ups (not blockers)
- Slot **step** is `rule.slotMinutes`; slot **duration** is the appointment
  type's (or `defaultAppointmentDurationMin`). Intentional, but a clinic that
  wants step == duration must set them equal.
- Location-level timezone override is read but there is no locations-with-tz
  test yet.
- `no-show` grace is 0 (allowed at/after `scheduledStart`); make it a
  `ClinicSettings` value when needed.
- Recall ordering uses `position = -1` ("next"); a multi-recall tie-breaker
  (`recallPriority`) is deferred.

## Phase 3 — Clinical & patient data  ◐ PARTIAL (patients, consultations, prescriptions, audit, family access done 2026-09-14)

- [x] **`patients`** — minimal (list/search/create; added ahead of schedule in
      Phase 4 because booking needed it). No family linkage beyond the single
      `ownerUserId` field yet.
- [x] **`consultations`** — SOAP notes (`getConsultation`/`saveConsultation`/
      `signConsultation`), 1:1 with `Appointment`, auto-created on first save.
      Signing locks further edits (`409` on a post-sign write).
      **RBAC corrected from the original draft**: a `DOCTOR` gets read/write
      on their own assigned appointment with **no separate capability**
      needed — `CLINICAL_RECORD_READ` is now documented as an optional
      clinic-wide *override* for doctors (e.g. covering a colleague), not a
      base requirement. `CLINIC_ADMIN` still needs the capability, granted by
      a different admin (unchanged). RBAC.md / MEDICAL_DATA_SECURITY.md
      updated to match; see `tests/integration/consultations.test.ts`.
- [x] **`prescriptions`** — items added one at a time to "the" prescription
      for a consultation (auto-created on first item); removable until signed.
- [x] **`audit`** read API + a web page (`CLINIC_ADMIN`, own org, last 100).
- [x] Reschedule UI (the API existed since Phase 2; no screen until now).
- [x] **`family`** — `PatientAccessGrant` (+ `FamilyRelationship` for the
      human-readable relation) now has real CRUD:
      `POST/GET /orgs/:orgId/patients/:patientId/access-grants`,
      `DELETE .../:grantId`, `GET /orgs/:orgId/my-access` ("patients I can
      access as family"). Created only by the patient (self-owned) or
      `CLINIC_ADMIN`; grantee must already have a platform account
      (email-lookup, same as `patients.ownerEmail`); re-granting the same
      grantee upserts instead of duplicating. Wired into reads:
      `patients.getPatient` checks `VIEW_PROFILE`,
      `consultations.getConsultation` checks `VIEW_MEDICATIONS` (no separate
      "view consultation" permission exists in the schema). **Not** wired:
      `MANAGE_APPOINTMENTS`/`VIEW_APPOINTMENTS` into the `appointments`
      module — a guardian can't yet book/view a dependent's appointments via
      a grant, left out deliberately to avoid touching the SERIALIZABLE
      booking path without dedicated coverage. Web: patient detail page
      (`/patients/:id`) for admins/owners to manage grants; `/family` page
      for a PATIENT-role user to see what's been shared with them.
- [x] Tests: `consultations` (7 — assigned-doctor write, unassigned-doctor
      403, RECEPTIONIST 403, admin capability-gated read, patient-owner
      read-only, prescription item add/remove + audit, sign-locks-edits),
      `family` (8 — no-grant 403, unknown-email 422, self-grant 422,
      RECEPTIONIST 403, VIEW_PROFILE-only still blocks clinical read,
      re-grant upserts + extends to VIEW_MEDICATIONS, my-access listing,
      revoke removes access immediately). **87/87 tests passing overall**,
      `tsc` clean, `next build` green.
- [ ] Not done: `documents` (metadata table exists, no upload endpoint),
      `medications` /`/api/sync/medications` (the DoseWise sync target),
      reports/export, the `notifications` module beyond the dispatcher (no
      `/api/me/notifications` read endpoint yet), `openapi.yaml` generation,
      field-level projection tests for RECEPTIONIST beyond consultations (see
      MEDICAL_DATA_SECURITY.md), family-grant invites for emails without an
      existing account, family access wired into appointments.

## Phase 4 — Web application  ✅ MVP DONE (2026-09-14)

- [x] Next.js web UI directly under `app/` (login, register, dashboard shell)
      — auth via Server Actions + web sessions, tenant context via
      `requireOrgContext(orgId)`, role-based nav (PATIENT / DOCTOR /
      RECEPTIONIST / CLINIC_ADMIN). No new business logic — pages and Server
      Actions call the **same module services** as the API routes.
- [x] `src/lib/org-context.ts` + `src/lib/web-context.ts` — the web app gets
      the identical tenant-isolation guarantee as `withApi` (shared
      implementation, not duplicated).
- [x] Minimal **`patients`** module added (list/search/create) — Phase 2 had
      no way to create/find a patient, so booking from the UI was impossible
      without it. Full family/consultations/prescriptions/documents remain
      Phase 3.
- [x] Screens: org picker + create clinic; CLINIC_ADMIN (doctors, staff,
      team incl. capability grants with no-self-grant enforced, settings,
      locations, appointment types); doctor weekly availability editor +
      exceptions; patients search/register; appointments (live slot-picker
      booking form + confirm/check-in/no-show/start/complete/cancel);
      queue board (auto-refresh, call/recall/skip/start/complete).
- [x] Verified: `tsc` clean, `next build` green (61 routes), full 72-test
      backend suite still passes, **and a real end-to-end run against a
      local production build** through the actual Server Action wire
      protocol — register → login → create clinic → every role page loads,
      including a cross-tenant 404 check at the web layer.
- [x] **SUPER_ADMIN console** added 2026-09-15 — `src/modules/superadmin/`
      (`listOrganizations`, `getOrganizationDetail`, `setOrganizationActive`,
      `listPlatformAuditLog`, `platformStats`), all using the **unscoped**
      `db` client (the one deliberate exception to `tenantDb()`, per
      SYSTEM_ARCHITECTURE.md) and re-asserting `ctx.isPlatformAdmin`
      themselves regardless of route-level gating. API: `GET/PUT
      /api/admin/organizations[/:targetOrgId[/status]]`, `GET
      /api/admin/audit`, `GET /api/admin/stats` — the dynamic segment is
      named `targetOrgId`, not `orgId`, specifically so `withApi()`'s
      auto tenant-resolution (keyed on a literal `params.orgId`) doesn't
      try and fail to find the admin's own membership in the org being
      inspected. Web: `/admin` (stats), `/admin/organizations`
      (list/search/status filter), `/admin/organizations/:orgId` (detail +
      suspend/reactivate), `/admin/audit` (cross-tenant audit feed); an
      "Admin panel" link appears on `/dashboard` for a platform admin.
      **No self-service way to become a platform admin exists** (by
      design — `User.isPlatformAdmin` is a manual DB flag, set directly in
      Neon; there is deliberately no API or UI path that grants it). 5 new
      tests (non-admin 403 on every route, cross-tenant listing,
      search/status filters, org detail + membership roster, suspend →
      audited → reactivate → audited, platform-wide audit + stats). **92
      tests passing overall**, `tsc` clean, `next build` green.
- [ ] Not done: restyle pass to the full DoseWise mockup language (currently
      a clean but original light UI using the indigo/coral tokens, not a
      pixel match to the Flutter app), responsive/mobile-browser pass,
      reschedule UI (API exists, no screen yet), a `SUPPORT_ACCESS` flow for
      genuine clinical-data support (MEDICAL_DATA_SECURITY.md already
      specs this as SUPER_ADMIN's only sanctioned path to PHI — not built).

## Phase 5 — Flutter integration (mirrors FIREBASE_MIGRATION_PLAN.md)

- **5a** parallel run: optional platform sign-in; medication data dual-writes
  (Firestore + `/api/sync/medications`) behind a flag.
- **5b** platform primary: `HttpBackend` default; run the DoseWise data
  importer; family invites → platform `Invitation` tokens; Firestore
  read-only.
- **5c** auth cutover: platform auth only; link Firebase Google users by
  `sub`; prompt anonymous-only users once.
- **5d** retire Firebase: delete `functions/`, `firestore.rules`; drop
  `cloud_firestore` / `firebase_auth`; keep `firebase_messaging` only if FCM
  stays the push transport.

## Backlog / later (not scheduled)

- Postgres RLS as defense-in-depth over the app-layer isolation.
- Shared-store rate limiting for horizontal scaling.
- Email / SMS / WhatsApp notification channels.
- Object-storage document upload + previews.
- SSE/WebSocket live queue board.
- MFA / passkeys.
- Per-event notification preference UI + schema.
- Right-to-erasure workflow.
- Multi-location resource/room scheduling; billing.

## Explicit non-goals (spec §39, §40)

No AI diagnosis / disease prediction / automated prescription / treatment
recommendation / drug-interaction engine. No microservices, Redis, Kafka,
Elasticsearch, or Kubernetes without a concrete forcing requirement. No
big-bang Flutter rewrite.
