# Multi-Tenancy

## Model

- **Tenant = `Organization`** (a clinic / healthcare org).
- A **`User`** is a single global identity (one email, one password).
- **`Membership`** joins a user to an organization with a `Role`. A user may
  hold several memberships — DOCTOR in Clinic A, PATIENT in Clinic B — each
  independent.
- Every tenant-owned row carries `organizationId`. Non-tenant rows: `User`,
  `Session`, `RefreshToken`, `IdentityAccount`.

## The rule

> `organizationId` is **never** read from the request body, query string, or a
> client-set header as trusted input. The active tenant is derived from the
> authenticated user's `Membership`. A request may *name* an org **only via the
> `:orgId` path segment** of `/api/orgs/:orgId/...`; the server resolves it
> against the user's `ACTIVE` memberships and `404`s if there is no match.
> **No `X-Org-Id` header exists.** `organizationId` in a request body, query
> string, or any header is never read as tenant context — a body value that
> disagrees with the resolved `:orgId` is a `422`, never an override.

## Enforcement — three layers

### 1. Tenant-scoped Prisma client (primary)

`tenantClient(ctx)` returns a `PrismaClient` extension that:

- sets `organizationId = ctx.organizationId` on every `create` for a
  tenant-owned model;
- merges `AND: [{ organizationId: ctx.organizationId }]` into the `where` of
  every read/update/delete/count/aggregate;
- throws if a caller tries to pass a different `organizationId` explicitly.

All module services receive `ctx` and use this client. Direct use of the raw
`PrismaClient` is confined to `auth`, org bootstrap, and platform-admin paths,
each individually reviewed.

### 2. Service-level ownership re-checks

Record lookups by id still verify the row belongs to `ctx.organizationId`
(the scoped `where` already guarantees this, but explicit `findFirstOrThrow`
with the org filter makes the intent auditable and the 404 deliberate).
Cross-entity writes (e.g. "book `patientId` with `doctorId`") verify **both**
referenced rows resolve within the tenant before proceeding.

### 3. Cross-tenant test contract (must always pass)

`src/test/tenant-isolation.test.ts` seeds Clinic A and Clinic B and asserts, for
**every** tenant-owned resource:

- A-user `GET /api/orgs/A/<resource>/<B-id>` → **404**, body reveals nothing.
- A-user `PATCH` / `DELETE` on a B-owned id → **404**.
- A-user cannot `POST` a child row referencing a B-owned parent → **404/422**.
- A-user listing endpoints never include B rows.
- A B-scoped `AuditLog` is never visible to A.
- Passing `organizationId: B` in a body while authenticated as A-user is
  ignored/rejected, never honored.

Additional required assertions (spec §29):

- Doctor A cannot read a patient not linked to Doctor A within the org, unless
  clinic policy grants it.
- Receptionist cannot read restricted clinical fields (consultation notes,
  prescription bodies) — see [MEDICAL_DATA_SECURITY.md](MEDICAL_DATA_SECURITY.md).
- Patient cannot read another patient's data; a guardian can read a dependent
  only within granted `AccessPermission`s.

## Response policy on cross-tenant access

Record-level: **404 Not Found** (no confirmation that the id exists elsewhere).
Action-level denial within the correct tenant: **403 Forbidden**. Never return
another tenant's data under any status.

## Postgres RLS — documented, not in MVP

App-layer isolation + the test contract is the MVP guarantee (spec §37/§40
discourage over-engineering). RLS is the planned next hardening step:

- add `organizationId` RLS policies to tenant tables;
- `SET LOCAL app.current_org_id = <ctx.organizationId>` at the start of each
  request transaction;
- keep the app-layer extension as well (defense in depth).

Tracked in [ROADMAP.md](ROADMAP.md). Not required for Phase 0 sign-off.

## Org lifecycle

- **Create**: `tenancy` module, unscoped client, inside a transaction that
  writes `Organization` + `ClinicSettings` + the creator's
  `Membership{role: CLINIC_ADMIN}` atomically.
- **Suspend**: `Organization.isActive = false`; all memberships still resolve
  but every non-admin request 403s.
- **Delete**: soft-delete only in MVP; hard delete is a platform-admin script
  with an explicit confirmation and an audit entry.
