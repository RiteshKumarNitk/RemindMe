# DoseWise Healthcare Platform — `platform/`

Multi-tenant healthcare **appointment + patient management** platform built
around the existing **DoseWise** Flutter app. This directory holds the new
backend and (later) the Next.js web application. The Flutter app at the repo
root is **not** modified.

> **Status: Phase 1 complete (2026-09-10).** Next.js 15 + Prisma 6 + Neon
> Postgres backend foundation: auth (argon2id + JWT access/refresh + sessions),
> application-layer tenant isolation, RBAC + capabilities, 6 modules, 20 API
> routes, 2 migrations (incl. the double-booking EXCLUDE constraint), demo
> seed. `tsc` clean, `next build` green, **51 tests passing** (`npm test`).
> See [ROADMAP.md](ROADMAP.md) → "Phase 1".

## Quickstart (dev)

> Package manager: **pnpm** (`packageManager` field pins the exact version —
> see `package.json`). Install it with `corepack enable` (ships with Node
> 20+) so the pinned version is used automatically, or `npm i -g pnpm`.

```bash
cd platform
cp .env.example .env            # fill DATABASE_URL + DIRECT_URL + secrets
pnpm install
pnpm exec prisma migrate deploy # or: pnpm migrate:dev
pnpm db:seed                    # demo clinic (synthetic data)
pnpm dev                        # http://localhost:3000/api/health
pnpm test                       # needs ALLOW_DB_TESTS=1 + a dev DB
```

`pnpm test` TRUNCATEs the target DB's app tables — never point it at anything
real; re-run `pnpm db:seed` afterward.

## Why `platform/` and not `docs/`

The repo root already contains the Flutter app, its own `docs/` (DoseWise
family-sync / notification notes), and a Flutter-web build in `web/`. The new
system is a separate concern with a separate toolchain (Node/Next.js/Prisma),
so it lives entirely under `platform/`. The Flutter `docs/` at the repo root is
on the "must not modify" list.

## Documentation map

| File | What it covers |
|---|---|
| [STATUS.md](STATUS.md) | Plain-English, always-current progress summary — the one to show non-engineers |
| [DECISIONS.md](DECISIONS.md) | Dated ADR log — why each non-obvious technical choice was made |
| [CHANGELOG.md](CHANGELOG.md) | Dated log of what actually shipped, newest first |
| [PRODUCT_REQUIREMENTS.md](PRODUCT_REQUIREMENTS.md) | Problem, users, roles, workflows, MVP vs post-MVP, non-goals |
| [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) | Modular monolith, request lifecycle, module list, shared domain layer |
| [MULTI_TENANCY.md](MULTI_TENANCY.md) | Tenant model, isolation enforcement, cross-tenant test contract |
| [DATABASE_DESIGN.md](DATABASE_DESIGN.md) | Every table, key indexes, the double-booking constraint, time handling |
| [RBAC.md](RBAC.md) | Roles, the capability matrix, role≠clinical-access, where checks happen |
| [AUTHENTICATION.md](AUTHENTICATION.md) | Normative requirements: argon2id, sessions, access/refresh rotation + reuse-detection, Google OAuth + linking, Flutter/Web compatibility, DoseWise migration |
| [GUEST_ACCESS.md](GUEST_ACCESS.md) | Platform guest = demo/preview only; the separate DoseWise offline "guest"; mapping deferred |
| [API.md](API.md) | Endpoint catalogue, conventions, error envelope, OpenAPI plan |
| [APPOINTMENT_WORKFLOW.md](APPOINTMENT_WORKFLOW.md) | Lifecycle state machine, valid transitions, availability & slot calculation |
| [QUEUE_MANAGEMENT.md](QUEUE_MANAGEMENT.md) | Token generation, call/recall/skip/complete, ordering, tenant scoping |
| [MEDICAL_DATA_SECURITY.md](MEDICAL_DATA_SECURITY.md) | PHI handling, family access grants, receptionist limits, audit, retention |
| [DOSEWISE_EXISTING_FUNCTIONALITY.md](DOSEWISE_EXISTING_FUNCTIONALITY.md) | Feature-by-feature inventory of the current app + reuse decisions |
| [MEDICINE_DATA_MIGRATION.md](MEDICINE_DATA_MIGRATION.md) | Field-by-field DoseWise SQLite/Firestore → Postgres mapping |
| [FIREBASE_MIGRATION_PLAN.md](FIREBASE_MIGRATION_PLAN.md) | Per-service KEEP / MIGRATE / TEMPORARY / REMOVE-LATER plan |
| [NOTIFICATION_ARCHITECTURE.md](NOTIFICATION_ARCHITECTURE.md) | Event catalogue, channel abstraction, why the core is not alarm-dependent |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Hosting, Neon, migrations, env, HTTPS, logging — manual, nothing automatic |
| [ENVIRONMENT.md](ENVIRONMENT.md) | Every environment variable explained |
| [TESTING.md](TESTING.md) | Test layers and the required security/domain coverage |
| [SECURITY.md](SECURITY.md) | Threat model, headers, CORS/CSRF, rate limiting, error hygiene |
| [ROADMAP.md](ROADMAP.md) | Phase 0 → Flutter integration, sequenced |

## Planned stack

Next.js (App Router, route handlers) · TypeScript · Prisma · PostgreSQL (Neon) ·
Zod validation · custom auth (argon2id + JWT access/refresh + DB sessions) ·
RBAC + application-layer tenant isolation · modular monolith (no microservices,
no Redis/Kafka/ES/K8s).

## Phase 0 deliverables

- [x] `prisma/schema.prisma` — **`prisma@6 validate` passes**, `prisma@6 format`
      clean (2026-09-10). Targets Prisma 6.x.
- [x] `prisma/sql/0001_appointment_no_overlap.sql` — EXCLUDE constraint scoped
      by `(organizationId, doctorId, time range)`.
- [x] `prisma/schema.prisma`: `MembershipCapability` enum + `Membership.capabilities`
      (empty by default — no role implies clinical access).
- [x] `tests/double-booking.constraint.test.ts` — DB-contract test
      (cross-org allowed / same-org rejected). Runs once `platform/` is scaffolded.
- [x] `.env.example`, `.gitignore`
- [x] All docs listed above (incl. `GUEST_ACCESS.md`)
- [ ] **Paused for Phase 0 sign-off** — Next.js scaffold, auth, domain services,
      seed, and the full test suite come next, only after explicit approval.

## Corrections applied after the first review (2026-09-10)

1. Double-booking constraint now includes `organizationId` — same doctor may
   overlap across clinics, never within one.
2. `tests/double-booking.constraint.test.ts` added (cross-org allow + same-org
   deny + adjacent-slot allow + cancel-frees-range).
3. `AUTHENTICATION.md` gained a normative **Requirements (R1–R11)** table and a
   **Client compatibility** section (Flutter bearer / Web cookie).
4. `RBAC.md` + `MEDICAL_DATA_SECURITY.md`: **role ≠ clinical-data access**;
   `CLINIC_ADMIN` has **no** clinical-body access unless `CLINICAL_RECORD_READ`
   is explicitly granted (audited); `RECEPTIONIST` can never get it;
   `SUPER_ADMIN` no routine clinical access. Per-role can/cannot lists added.
5. `GUEST_ACCESS.md` created — platform guest = sandboxed demo org only; the
   DoseWise offline "guest" documented separately; mapping deferred.
6. `DOSEWISE_EXISTING_FUNCTIONALITY.md` gained a **Reuse register** confirming
   every listed capability is kept and unmodified in Phase 0.

## Corrections applied after the second review (2026-09-10)

7. **No self-grant of clinical capabilities.** `CLINICAL_RECORD_READ/WRITE` can
   only be granted by a *different* authorized `CLINIC_ADMIN`; self-target →
   `403 CANNOT_SELF_GRANT_CAPABILITY`. Consistent across `API.md`, `RBAC.md`,
   `MEDICAL_DATA_SECURITY.md`, `TESTING.md`.
8. **Tenant selector is `:orgId` path only.** `X-Org-Id` removed entirely;
   `organizationId` in body/query/header never trusted (`422` on mismatch).
   `SYSTEM_ARCHITECTURE.md`, `MULTI_TENANCY.md`, `API.md` aligned.
9. **`demo-viewer` capability removed.** The guest walkthrough is now an
   explicit demo-only **policy branch** (`allowDemoWalkthrough`) evaluated
   after all standard checks — read-only, demo-org-only, guest-only, no bypass
   of auth / tenant / RBAC / ownership. `MembershipCapability` enum unchanged.
10. **Notification scheduler defined.** Cron-invoked
    `POST /api/internal/notifications/dispatch` (every 60s, `X-Cron-Key`
    secret) with `FOR UPDATE SKIP LOCKED` claiming, `dedupeKey` idempotency,
    backoff retry + `maxAttempts`, stale-`SENDING` reaper for crash recovery.
    In-process timer is dev-only, never the sole prod mechanism. No Redis /
    queue / paid provider; FCM stays push-transport-only. Schema: `Notification`
    gains `dedupeKey`/`attempts`/`maxAttempts`/`claimedAt`/`nextAttemptAt` and
    `NotificationStatus.SENDING`. Documented in `NOTIFICATION_ARCHITECTURE.md`,
    `DEPLOYMENT.md`, `ENVIRONMENT.md`, `.env.example`, `DATABASE_DESIGN.md`,
    `SECURITY.md`, `API.md`, `TESTING.md`.
