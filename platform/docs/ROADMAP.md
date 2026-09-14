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

## Phase 3 — Clinical & patient data

- Modules: `patients`, `family` (relationships + access grants), `consultations`,
  `prescriptions`, `documents` (metadata; `local-dev` storage), `medications`
  (incl. `/api/sync/medications`), reports/export, `notifications`
  (IN_APP + PUSH), `audit` read API.
- Field-level projection for RECEPTIONIST; grant-based family access.
- Tests: `family`, `medications`, `audit`, `invitations`, `errors`.
- Generate `docs/openapi.yaml` from the Zod schemas.
- **Checkpoint:** the Flutter developer can build against a stable API.

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
- [ ] Not done: SUPER_ADMIN screens, restyle pass to the full DoseWise
      mockup language (currently a clean but original light UI using the
      indigo/coral tokens, not a pixel match to the Flutter app), responsive/
      mobile-browser pass, reschedule UI (API exists, no screen yet).

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
