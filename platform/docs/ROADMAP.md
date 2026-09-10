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

## Phase 2 — Scheduling core

- Modules: `availability` (rules, exceptions, slot calculation), `appointments`
  (booking, lifecycle state machine, reschedule, cancel, no-show), `queue`
  (tokens, call/recall/skip/complete).
- EXCLUDE-constraint-backed double-booking, `SERIALIZABLE` booking txn.
- Tests: `availability`, `appointments`, `double-booking`, `queue`.
- **Checkpoint:** a full booking→check-in→queue→consultation flow via the API.

## Phase 3 — Clinical & patient data

- Modules: `patients`, `family` (relationships + access grants), `consultations`,
  `prescriptions`, `documents` (metadata; `local-dev` storage), `medications`
  (incl. `/api/sync/medications`), reports/export, `notifications`
  (IN_APP + PUSH), `audit` read API.
- Field-level projection for RECEPTIONIST; grant-based family access.
- Tests: `family`, `medications`, `audit`, `invitations`, `errors`.
- Generate `docs/openapi.yaml` from the Zod schemas.
- **Checkpoint:** the Flutter developer can build against a stable API.

## Phase 4 — Web application

- Next.js web UI in `platform/app/(web)/**` — auth shell, tenant context,
  role-based dashboards (PATIENT / DOCTOR / RECEPTION / CLINIC_ADMIN /
  SUPER_ADMIN), API integration layer.
- Responsive (desktop / tablet / mobile browser).
- Restyle to the DoseWise design language (indigo/coral) — keep every feature.
- No new business logic — same module services.

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
