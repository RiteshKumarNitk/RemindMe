# Environment Variables

Every variable from [`.env.example`](../.env.example) explained. `.env` is
git-ignored and never committed (spec §26). Secrets are provided via the host's
secret manager in deployed environments, not a file.

## Database (Neon)

| Var | Required | Purpose |
|---|---|---|
| `DATABASE_URL` | yes | **Pooled** connection string (Neon `-pooler` host, `pgbouncer=true`, bounded `connection_limit`). Used by the running app. |
| `DIRECT_URL` | yes | **Direct** (non-pooled) connection. Used by `prisma migrate` and introspection — pooled connections break DDL. Maps to `datasource.directUrl`. |

Neon specifics: always `sslmode=require`. Use a bounded `connection_limit`
(e.g. 10) on the pooled URL for serverless/edge safety. Keep the direct URL
out of the app runtime.

## Auth & tokens

| Var | Required | Purpose |
|---|---|---|
| `AUTH_SESSION_SECRET` | yes | HMAC secret for the web session cookie. 32+ bytes. |
| `JWT_ACCESS_SECRET` | yes | Signs API access JWTs. |
| `JWT_REFRESH_SECRET` | yes | Signs/verifies refresh-token material. Rotate independently. |
| `JWT_ACCESS_TTL` | no (900) | Access token lifetime, seconds. |
| `JWT_REFRESH_TTL` | no (2592000) | Refresh token lifetime, seconds. |
| `JWT_ISSUER` | no (`dosewise-platform`) | `iss` claim. |
| `ARGON2_MEMORY_KIB` / `ARGON2_TIME_COST` / `ARGON2_PARALLELISM` | no | argon2id cost params. Defaults are OWASP-baseline; only override with a benchmark. |

Generate secrets: `openssl rand -base64 48`. Rotating a signing secret
invalidates the matching tokens — expected; clients re-authenticate.

## Google OAuth

| Var | Required | Purpose |
|---|---|---|
| `GOOGLE_CLIENT_ID` | no* | OAuth client id. Omit → Google sign-in disabled, email/password still works. |
| `GOOGLE_CLIENT_SECRET` | no* | OAuth client secret. |
| `GOOGLE_OAUTH_REDIRECT_URL` | no* | Must match the console-registered redirect. |

\* required only if Google sign-in is enabled.

## App

| Var | Required | Purpose |
|---|---|---|
| `APP_BASE_URL` | yes | Absolute base URL; used in links (invites, reset) and OAuth redirects. |
| `NODE_ENV` | yes | `development` / `production` / `test`. |
| `CORS_ALLOWED_ORIGINS` | yes | Comma-separated allow-list for browser clients. The Flutter app is not a browser origin. See SECURITY.md. |
| `LOG_LEVEL` | no (`info`) | `debug`/`info`/`warn`/`error`. |

## Rate limiting

| Var | Required | Purpose |
|---|---|---|
| `RATE_LIMIT_AUTH_PER_MIN` | no (10) | Per-IP budget for `/api/auth/*`. |
| `RATE_LIMIT_DEFAULT_PER_MIN` | no (120) | Per-IP budget for everything else. |

MVP uses an in-process token bucket (no Redis). Multi-instance deployments need
a shared store later — noted in ROADMAP.

## Notifications (all optional in MVP)

| Var | Purpose |
|---|---|
| `FCM_PROJECT_ID` / `FCM_CLIENT_EMAIL` / `FCM_PRIVATE_KEY` | FCM server credentials for PUSH. Absent → push deliveries are `SUPPRESSED`, everything else works. `FCM_PRIVATE_KEY` contains literal `\n` — unescape at load. |
| `NOTIFICATIONS_CRON_SECRET` | **Required in production.** Shared secret checked (constant-time) in the `X-Cron-Key` header of `POST /api/internal/notifications/dispatch`. The cron caller sends it. |
| `NOTIFICATIONS_DISPATCH_BATCH` | Max `Notification` rows processed per dispatch invocation (default 100). |
| `NOTIFICATIONS_CLAIM_TIMEOUT_MIN` | A `SENDING` row older than this (default 10) is reaped back to `PENDING` at the start of each run (crash recovery). |
| `NOTIFICATIONS_MAX_ATTEMPTS` | Retries before a row becomes `FAILED` (default 5). |
| `NOTIFICATIONS_INPROCESS_DISPATCH` | `true` enables a dev-only `setInterval` dispatcher in the app process. **Never** the production mechanism — production uses an external cron hitting the endpoint (see [DEPLOYMENT.md](DEPLOYMENT.md)). Default `false`; forced off when `NODE_ENV=production` unless explicitly set. |

Email / SMS / WhatsApp provider vars are intentionally absent (no paid
providers in MVP). The scheduled-notification trigger is a cron-invoked
endpoint + one Postgres table — no Redis / queue service.

## Object storage (documents — not used in Phase 0)

| Var | Purpose |
|---|---|
| `STORAGE_PROVIDER` | `local-dev` (default) / `s3` / `gcs`. |
| `STORAGE_BUCKET` / `STORAGE_REGION` / `STORAGE_ACCESS_KEY_ID` / `STORAGE_SECRET_ACCESS_KEY` | provider config when not `local-dev`. |

## Observability (optional)

| Var | Purpose |
|---|---|
| `SENTRY_DSN` | error monitoring; omit to disable. |

## Never committed

Database passwords, `AUTH_SESSION_SECRET`, `JWT_*_SECRET`, `GOOGLE_CLIENT_SECRET`,
`FCM_PRIVATE_KEY`, `NOTIFICATIONS_CRON_SECRET`, `STORAGE_SECRET_ACCESS_KEY`, any
real `.env`. `.gitignore` must cover `platform/.env*` (except `.env.example`).
