# System Architecture

## Shape: modular monolith

One Next.js project. One deployable. One Postgres database. Modules are code
boundaries (directories + a service API), **not** separate services. No message
bus, no Redis, no microservices (spec §37, §38, §40).

```
Flutter Android app ─┐
                     ├─ HTTPS/JSON ─> Next.js route handlers (app/api/**)
Next.js web app    ──┘                      │
                                            ▼
                                   ┌───────────────────┐
                                   │  request pipeline  │
                                   │  1 rate limit      │
                                   │  2 authenticate    │
                                   │  3 resolve tenant  │
                                   │  4 RBAC / policy   │
                                   │  5 module service  │
                                   │  6 audit log       │
                                   └─────────┬─────────┘
                                             ▼
                              domain services  (src/modules/**)
                                             ▼
                           tenant-scoped Prisma client extension
                                             ▼
                                  Prisma  ──>  Neon PostgreSQL
```

The **web app and the Flutter app call the same route handlers**, which call
the same module services. Business logic exists once.

## Directory layout (planned)

```
platform/
  prisma/
    schema.prisma
    sql/0001_appointment_no_overlap.sql
    migrations/**            # generated later
    seed.ts                 # later
  src/
    lib/
      db.ts                 # PrismaClient singleton
      tenant.ts             # tenant-scoped client extension + RequestContext
      auth/                 # password hashing, tokens, sessions, oauth
      rbac.ts               # can(role, action, resource, ctx)
      validation.ts         # zod helpers, request parsing
      errors.ts             # AppError + typed error envelope
      audit.ts              # writeAudit(...)
      rate-limit.ts         # in-process token bucket
      http.ts               # handler wrapper: pipeline steps 1-6
    modules/
      auth/  tenancy/  users/  clinics/  doctors/  staff/  patients/
      family/  availability/  appointments/  queue/  consultations/
      prescriptions/  medications/  documents/  notifications/  audit/
        <module>/service.ts     # pure domain logic, takes RequestContext
        <module>/schema.ts      # zod request/response schemas
        <module>/policy.ts      # module-specific authorization rules
        <module>/types.ts
  app/
    api/**/route.ts         # thin: parse -> service -> respond
    (web)/**                # web UI, added after backend sign-off
  docs/**
```

## Request pipeline (`src/lib/http.ts`)

Every route handler is wrapped by `withApi(handler, { auth, roles, rateKey })`:

1. **Rate limit** — key by IP + route class; auth routes are stricter
   (`RATE_LIMIT_AUTH_PER_MIN`). In-process token bucket for MVP.
2. **Authenticate** — web: signed session cookie → `Session` row. Flutter:
   `Authorization: Bearer <access JWT>` → verified, not revoked. Produces
   `{ userId, isPlatformAdmin }`.
3. **Resolve tenant** — the **only** tenant selector is the `:orgId` path
   segment of `/api/orgs/:orgId/...`. It is looked up **against the
   authenticated user's `Membership` rows**; no matching `ACTIVE` membership ⇒
   `404`. There is **no `X-Org-Id` header** and `organizationId` in a body,
   query string, or any header is never read as tenant context (a body value
   that disagrees with the resolved tenant ⇒ `422`, never honored). Routes with
   no `:orgId` (`/api/auth/*`, `/api/me`, `/api/invitations/:token/*`) carry no
   tenant context and touch only non-tenant or self-scoped rows.
4. **RBAC** — `can(membership.role, action, resource, ctx)`; deny ⇒ 403.
   Record-level ownership (e.g. "is this patient in this org?") is re-checked
   inside the service.
5. **Service** — module function receives `RequestContext` and validated
   input; returns typed data or throws `AppError`.
6. **Audit** — mutations write an `AuditLog` row (who/what/when/tenant/entity/
   before/after) before the response is sent.

Errors become `{ error: { code, message, details? } }` with an appropriate
status. Prisma/DB errors are caught and mapped; raw messages never leave the
server (spec §23).

## Tenant-scoped data access (`src/lib/tenant.ts`)

A Prisma Client extension bound to a `RequestContext`:

- `create` — injects `organizationId` from context.
- `findMany / findFirst / findUnique / update / updateMany / delete /
  deleteMany / count / aggregate` — merges `where: { organizationId }`.
- Models without an `organizationId` column (`User`, `Session`,
  `RefreshToken`, `IdentityAccount`) bypass the extension and are guarded
  explicitly.

Services always use the scoped client. The unscoped client is available only to
`auth`, `tenancy` (org creation), and `SUPER_ADMIN` platform operations, each
with its own guard. See [MULTI_TENANCY.md](MULTI_TENANCY.md).

## Shared domain layer with Flutter

The Flutter app does **not** re-implement appointment rules, availability math,
queue ordering, or RBAC. It calls the API. The only client-side logic that
stays in Flutter is what must work offline: local notification scheduling and
the medication reminder engine (already built, unchanged). Medication data
reaches the platform through a **sync** endpoint modelled on the app's existing
offline-first outbox, not blocking RPC.

## Data-flow notes

- **Appointments** are timezone-safe: `scheduledStart/End` are `timestamptz`;
  `timezone` (IANA) is snapshotted at booking for display and slot math.
- **Medication doses** keep DoseWise semantics: `scheduledAtLocal` is a
  wall-clock local time plus a `timezone` string — a 09:00 dose stays 09:00
  when the patient travels.
- **Documents**: Postgres stores metadata only; bytes go to object storage
  later (spec §18). Phase 0 uses `local-dev` provider.

## What is explicitly not here

No GraphQL, no gRPC, no event streaming, no separate auth server, no CQRS, no
multi-region. Add only when a concrete requirement forces it (spec §40).
