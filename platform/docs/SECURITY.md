# Security

Consolidated controls (spec §23). Clinical-data specifics are in
[MEDICAL_DATA_SECURITY.md](MEDICAL_DATA_SECURITY.md); auth mechanics in
[AUTHENTICATION.md](AUTHENTICATION.md); isolation in
[MULTI_TENANCY.md](MULTI_TENANCY.md).

## Threat model (top concerns)

| Threat | Control |
|---|---|
| Cross-tenant data access | tenant-scoped Prisma client + service re-checks + `404` on cross-tenant lookup + mandatory test suite |
| Privilege escalation | role from `Membership` only; `can()` policy table; no self-promotion; RBAC tests |
| Credential theft / reuse | argon2id; short access JWT; rotating refresh with reuse-detection → family revoke; generic auth errors |
| Broken object-level authz (IDOR) | every id lookup filtered by `organizationId` + ownership/assignment/grant check |
| Injection | Prisma parameterised queries only; Zod-validated input; no string-built SQL except the reviewed EXCLUDE migration |
| Race conditions (double-book, token #) | `SERIALIZABLE` transactions + Postgres constraints (`EXCLUDE`, `@@unique`) |
| Sensitive data in logs | log allow-list; never PHI/secrets/tokens; `requestId` correlation only |
| Enumeration | `404` (not `403`) for cross-tenant ids; generic login failure |
| DoS / brute force | per-IP rate limits, stricter on `/api/auth/*` |
| Token/secret leakage in repo | `.env` git-ignored; `.env.example` only; secrets via host secret manager |

## Server-side authorization

Nothing is authorized on the client. The pipeline (`withApi`) enforces
authentication → tenant resolution → role gate; services enforce object-level
ownership. See SYSTEM_ARCHITECTURE.md.

## Input validation

Zod schema per endpoint (`src/modules/<domain>/schema.ts`). Unknown fields
rejected (`.strict()`). Failures → `422 VALIDATION_FAILED` with a `details`
array. Numeric/string bounds enforced (name lengths, page sizes, date ranges).

## Sessions & tokens

- Web: `HttpOnly` `Secure` `SameSite=Lax` cookie; hashed at rest; sliding
  renewal; server-side revocation.
- API: access JWT (15 min) + rotating refresh token (hashed, family lineage,
  reuse-detection).
- Global invalidation via the `tv` claim (`logout-all`, password reset,
  suspected compromise).

## CORS

- `CORS_ALLOWED_ORIGINS` allow-list only; no wildcard with credentials.
- Preflight handled centrally; only the listed origins get
  `Access-Control-Allow-Credentials: true`.
- The Flutter native app is not a browser origin — CORS does not apply to it;
  it authenticates with a Bearer token.

## CSRF

- Cookie-auth state-changing requests require a double-submit CSRF token
  (`dw_csrf` cookie + `X-CSRF-Token` header) **or** are restricted to
  `SameSite=Lax` + a custom header check.
- Bearer-token (app) requests are not CSRF-exposed (no ambient credentials).
- `GET` endpoints never mutate.

## Security headers

Set on every response:

| Header | Value |
|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `no-referrer` |
| `Content-Security-Policy` | strict default-src `'self'`; tightened for the web app when it ships |
| `Permissions-Policy` | disable camera/mic/geolocation unless a feature needs it |
| `Cache-Control` | `no-store` on authenticated JSON responses |

## Rate limiting

In-process token bucket per IP + route class (`RATE_LIMIT_AUTH_PER_MIN`,
`RATE_LIMIT_DEFAULT_PER_MIN`). Over budget → `429 RATE_LIMITED` with
`Retry-After`. **Known MVP limitation:** not shared across instances — a shared
store (or the host's edge rate limiter) is required before horizontal scaling
(tracked in ROADMAP).

## Internal endpoints

`POST /api/internal/notifications/dispatch` (the notification cron worker) is
**not** user-authenticated. It requires `X-Cron-Key: $NOTIFICATIONS_CRON_SECRET`
compared in constant time; a miss → `404` (not `401`, to avoid advertising the
route). It is not tenant-scoped, takes no tenant input, and its response body
contains only counters (`{ claimed, sent, failed, requeued, reaped }`) — no
PHI, no row contents. It is safe to call repeatedly and concurrently
(`FOR UPDATE SKIP LOCKED` + the `PENDING→SENDING` claim). Rate-limited like any
route. Any future internal endpoint follows the same pattern (shared secret,
`404` on miss, no PHI in/out).

## Error handling

- One `AppError` type → typed envelope `{ error: { code, message, details? } }`.
- Prisma known errors mapped (`P2002` → `409`, `P2025` → `404`, …). Unknown →
  `500 INTERNAL`, generic message, real error logged with `requestId`.
- Stack traces / SQL / Prisma text never sent to a client (spec §23).

## Audit

Every clinical mutation and non-routine PHI read writes an `AuditLog`
(who/what/when/tenant/entity/before/after/ip/ua/requestId). Retention is
append-only; see MEDICAL_DATA_SECURITY.md for the action vocabulary and the
never-log list.

## Dependencies & supply chain

- Pin versions; `npm audit` in CI; Dependabot/renovate for updates.
- Minimal dependency surface (modular monolith, no infra sprawl).
- `argon2` native build verified in CI; `bcrypt` fallback sanctioned.

## Secrets management

No secret in git. `.gitignore` covers `platform/.env*` except `.env.example`.
Rotate signing secrets on a schedule and on incident. Neon credentials scoped
to the one database.

## Pre-launch checklist

- [ ] All TESTING.md required suites green in CI.
- [ ] `.env` not tracked; `.gitignore` verified.
- [ ] Security headers present on a sample of routes.
- [ ] Cross-tenant probe returns `404` with an empty body.
- [ ] Auth endpoints rate-limited; generic failure messages.
- [ ] No PHI/secret in a sample of production logs.
- [ ] `Appointment_org_doctor_no_overlap` EXCLUDE constraint present in the
      deployed schema (`\d "Appointment"`); scoped by `organizationId` +
      `doctorId` + time range.
- [ ] Restore drill performed from a Neon branch.
