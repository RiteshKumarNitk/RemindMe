# Deployment

**Nothing is deployed automatically. Nothing in this doc runs during Phase 0.**
This is the runbook for when the backend exists and is approved (spec §36).

## Targets

| Concern | Choice | Notes |
|---|---|---|
| App host | Any Node host that runs Next.js (Vercel, Fly.io, Render, a VM) | Modular monolith = one deployable. Start with the simplest. |
| Database | **Neon PostgreSQL** | pooled + direct connection strings (see ENVIRONMENT.md) |
| Object storage | deferred | `local-dev` provider until documents ship |
| Push | FCM (server credentials) | optional |
| TLS | managed by the host / a proxy | HTTPS only, HSTS on |
| Error monitoring | Sentry (optional, `SENTRY_DSN`) | |

No Redis, no container orchestration, no multi-region in MVP (spec §37).

## Environments

| Env | DB | Notes |
|---|---|---|
| `development` | local Postgres or a Neon dev branch | `prisma migrate dev`, seed data allowed |
| `preview` (optional) | Neon branch per PR | ephemeral; `migrate deploy` + seed |
| `production` | Neon primary | `migrate deploy` only; **no** seed, **no** reset |

## First-time setup

> Toolchain: the schema targets **Prisma 6.x** (`prisma@^6`, `@prisma/client@^6`).
> `url`/`directUrl` live in the datasource block. If you later adopt Prisma 7,
> move those URLs to `prisma.config.ts` (mechanical, no model changes).

```bash
cd platform
cp .env.example .env            # fill in real values (never commit)
npm install                     # includes prisma@^6, @prisma/client@^6
npx prisma generate
npx prisma migrate dev --name init          # dev only
# apply the EXCLUDE constraint (see prisma/sql/0001_appointment_no_overlap.sql):
#  - paste it into the generated migration, OR
#  - run it as its own follow-up migration
npx prisma db seed              # dev only — demo clinic, clearly marked
npm run dev
```

## Migrations (spec §27)

| Situation | Command |
|---|---|
| Develop a schema change | `npx prisma migrate dev --name <change>` |
| Create migration without applying | `npx prisma migrate dev --create-only` (then hand-edit for raw SQL like the EXCLUDE constraint) |
| Deploy to preview/production | `npx prisma migrate deploy` |
| Inspect drift | `npx prisma migrate status` |

Rules:
- **Never** hand-edit a production DB schema outside a tracked migration.
- **Never** run `prisma migrate reset` / `db push --force-reset` against
  preview or production.
- The `btree_gist` extension + `Appointment_doctor_no_overlap` constraint are
  part of migration history, not a manual post-deploy step in production.
- Run `migrate deploy` as a release step **before** the new app code starts
  serving.

## Release procedure

1. CI: `prisma validate`, `prisma format --check`, typecheck, `npm test`
   (must include the tenant-isolation + double-booking suites — see TESTING.md).
2. Tag / promote the build.
3. `prisma migrate deploy` against the target DB (using `DIRECT_URL`).
4. Deploy the app.
5. Smoke test: `GET /api/health`, a login, a booking, a cross-tenant 404 probe.
6. Watch error rate / logs for the first N minutes.

Rollback: redeploy the previous app build. Schema rollbacks are forward-only —
write a compensating migration; do not delete migration files.

## Secrets

Provided via the host's secret manager / env config, never a committed file.
Rotate `JWT_*` and `AUTH_SESSION_SECRET` on a schedule and on suspected
compromise (clients re-authenticate).

## Backups & restore

- Neon manages automated backups / point-in-time restore.
- Document and **practise** a restore into a scratch branch quarterly.
- Before a risky migration, take an explicit Neon branch as a snapshot.

## Scheduled jobs — notification dispatcher

The one recurring job in MVP. Full mechanism in
[NOTIFICATION_ARCHITECTURE.md](NOTIFICATION_ARCHITECTURE.md#scheduling--delivery-mechanism-mvp-production-grade).

- **What runs:** `POST /api/internal/notifications/dispatch`, guarded by
  `X-Cron-Key: $NOTIFICATIONS_CRON_SECRET` (constant-time compare). Claims a
  batch of due `Notification` rows (`FOR UPDATE SKIP LOCKED`), reaps stale
  `SENDING` rows, sends, updates status. Idempotent and safe to invoke
  concurrently.
- **Frequency:** every **60 s**.
- **Wire it up** (pick one; all free, no extra infra — never rely on the
  in-process fallback in production):

  | Host | Mechanism |
  |---|---|
  | Vercel | `vercel.json` → `crons: [{ "path": "/api/internal/notifications/dispatch", "schedule": "* * * * *" }]` + the key via an env-injected header proxy route, or a tiny `/api/cron/notifications` wrapper that adds the header |
  | Render | a **Cron Job** service: `curl -fsS -H "X-Cron-Key: $NOTIFICATIONS_CRON_SECRET" $APP_BASE_URL/api/internal/notifications/dispatch` every minute |
  | Fly.io | a scheduled Machine running the same `curl` |
  | Any VM | crontab: `* * * * * curl -fsS -m 50 -H "X-Cron-Key: …" https://…/api/internal/notifications/dispatch` |
  | No host cron | a **GitHub Actions** workflow `on: schedule: - cron: "*/1 * * * *"` that curls the endpoint (repo secret holds the key) |

- **Restart/redeploy:** nothing to do — state is entirely in the
  `Notification` table; the next tick resumes.
- **Retry / failure:** per-row backoff (`nextAttemptAt`), `maxAttempts`
  (default 5) then `FAILED`; a failing row never blocks the batch.
- **Free/low-cost assumption:** one authenticated HTTP hit per minute + one
  Postgres table. No Redis, no queue, no worker process, no paid provider.
  FCM is used only as the push transport.
- **Heartbeat:** the endpoint upserts a `platform.lastDispatchAt` marker;
  alert if it goes stale > 5 min.

## Logging & monitoring

- Structured JSON logs at `LOG_LEVEL`; every request carries a `requestId`
  echoed in error envelopes.
- **No PHI, credentials, tokens, or FCM tokens in logs** (spec §22, §23).
- Minimum alerts: 5xx rate, DB connection failures, migration failures,
  auth-endpoint 429 spikes, **notification `PENDING` backlog / `FAILED` spike /
  dispatcher heartbeat stale**.

## Health endpoint

`GET /api/health` → `{ status, db: "ok"|"down", time }`. Unauthenticated,
rate-limited, no tenant data.

## Flutter / client config

The Android app points at `APP_BASE_URL`. CORS does not apply to the native
app; `CORS_ALLOWED_ORIGINS` is only for the web client. Keep a staging base URL
for pilot builds.
