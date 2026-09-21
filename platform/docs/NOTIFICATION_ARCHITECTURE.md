# Notification Architecture

Notifications are **supplementary** (spec §19). The correctness of appointments,
queue, and clinical records must never depend on a notification being
delivered, and never on an Android background alarm. The DoseWise on-device
reminder engine stays exactly as it is; this is a separate, additive layer.

## Principles

- The database is authoritative; notifications are a projection of state
  changes.
- The core system works with notifications fully disabled.
- Channel-agnostic: one event → zero or more channel deliveries.
- MVP ships **PUSH (FCM)** and **IN_APP** only. Email / SMS / WhatsApp are
  designed-for but not wired (no paid providers in MVP).

## Event catalogue

| Event | Trigger | Default recipients | Default channels |
|---|---|---|---|
| `APPOINTMENT_BOOKED` | appointment created | patient (+ guardian w/ `MANAGE_APPOINTMENTS`) | PUSH, IN_APP |
| `APPOINTMENT_CONFIRMED` | → `CONFIRMED` | patient | PUSH, IN_APP |
| `APPOINTMENT_CANCELLED` | → `CANCELLED` | patient; assigned doctor | PUSH, IN_APP |
| `APPOINTMENT_RESCHEDULED` | reschedule action | patient; assigned doctor | PUSH, IN_APP |
| `APPOINTMENT_REMINDER` | scheduled job, T-24h / T-2h | patient | PUSH |
| `CHECK_IN_CONFIRMED` | check-in → `QueueEntry` created | patient (token #, people ahead) | PUSH, IN_APP |
| `QUEUE_UPDATE` | queue `call` / `recall` | patient (your turn / almost) | PUSH |
| `CONSULTATION_COMPLETED` | → `COMPLETED` | patient | IN_APP (PUSH optional) |
| `FOLLOW_UP_INFO` | `Consultation.followUpDate` set / approaching | patient | PUSH, IN_APP |
| `INVITATION_ISSUED` | staff/patient/family invite created | invitee (email later; link now) | (EMAIL later) |
| `MEDICATION_MISSED_ALERT` | dose sync marks a shared dose `MISSED` | authorized guardians w/ alert pref | PUSH |

## Model

```
Notification {
  organizationId?  userId?  channel  event  payload Json
  status  (PENDING | SENDING | SENT | FAILED | SUPPRESSED)
  scheduledFor?    // when it becomes due (null = immediately)
  dedupeKey?       // @unique — see idempotency below
  attempts  Int    // 0..maxAttempts
  maxAttempts Int
  claimedAt?       // set when a dispatch run takes the row
  nextAttemptAt?   // backoff target after a failure
  sentAt?  error?
}
@@index([status, scheduledFor])
@@unique([dedupeKey])
```

- A state-change service calls `notify(event, { recipients, data, scheduledFor?, dedupeKey? })`.
- `notify` expands recipients → per-`(user, channel)` `Notification` rows in
  `PENDING`. If a `dedupeKey` collides, the insert is a no-op (idempotent
  creation — see below).
- The **dispatcher** (below) claims due rows, sends via the channel adapter,
  and moves them to `SENT` / `FAILED` / back to `PENDING` for retry, or
  `SUPPRESSED` when the recipient opted out.

## Scheduling & delivery mechanism (MVP, production-grade)

Reliability does **not** depend on an in-process timer. The production trigger
is an **external cron calling a protected dispatch endpoint**; the in-process
interval is a dev-only convenience and is never the sole prod mechanism.

### Invocation

- **Endpoint:** `POST /api/internal/notifications/dispatch`, authenticated by a
  shared secret header `X-Cron-Key: $NOTIFICATIONS_CRON_SECRET` (constant-time
  compare). Not tenant-scoped; returns a small JSON summary
  `{ claimed, sent, failed, requeued, reaped }`.
- **Frequency:** every **60 seconds**. Good enough for T-24h / T-2h reminders
  (minute-granularity). One invocation processes up to `DISPATCH_BATCH`
  (default 100) due rows, then returns; the next tick continues. Long backlogs
  drain over successive ticks — no single request runs unbounded.
- **Who calls it** (any one; all free / no extra infra):
  - the host's built-in scheduler (e.g. Vercel Cron, Render Cron Job, Fly
    Machines `schedule`), **or**
  - a system `cron` entry: `* * * * * curl -fsS -H "X-Cron-Key: …" $APP_BASE_URL/api/internal/notifications/dispatch`, **or**
  - a scheduled **GitHub Actions** workflow (`on: schedule: - cron: '*/1 * * * *'`) that curls the endpoint.
- **Dev fallback:** a `setInterval` in the app process hitting the same
  internal function every 60 s, enabled only when `NODE_ENV !== "production"`
  **or** `NOTIFICATIONS_INPROCESS_DISPATCH=true`. It is explicitly *not* relied
  on in production and is documented as best-effort.

### Claiming (safe with plain Postgres — no Redis)

Each dispatch run claims a batch atomically:

```sql
WITH due AS (
  SELECT id FROM "Notification"
  WHERE status = 'PENDING'
    AND (scheduledFor IS NULL OR scheduledFor <= now())
    AND (nextAttemptAt IS NULL OR nextAttemptAt <= now())
  ORDER BY scheduledFor NULLS FIRST
  LIMIT $DISPATCH_BATCH
  FOR UPDATE SKIP LOCKED          -- concurrent runs never collide
)
UPDATE "Notification" n
SET status = 'SENDING', claimedAt = now(), attempts = attempts + 1
FROM due WHERE n.id = due.id
RETURNING n.*;
```

`FOR UPDATE SKIP LOCKED` lets two overlapping cron invocations run without
double-claiming a row — the second simply skips locked rows. No external lock
service.

### Idempotency / duplicate prevention

- **Creation:** `dedupeKey` is `@unique`. For scheduled reminders it is
  deterministic, e.g. `APPOINTMENT_REMINDER:{appointmentId}:T-24H` /
  `:T-2H`, and `FOLLOW_UP_INFO:{consultationId}`. Re-running the code path that
  schedules a reminder (a ret/reschedule, a replayed job) just conflicts on
  the key and inserts nothing.
- **Delivery:** the `PENDING → SENDING` claim transition means a given row is
  handed to exactly one run. On success → `SENT` (terminal). The PUSH adapter
  additionally passes an FCM idempotency/message key derived from
  `Notification.id`, so an at-least-once retry after an ambiguous failure does
  not double-notify the device.

### Retry behaviour

- On a transient failure: `status = 'PENDING'`, `error = <message>`,
  `nextAttemptAt = now() + backoff(attempts)` where `backoff` is exponential
  with jitter (≈ 1m, 5m, 15m, 1h, 3h), capped.
- After `attempts >= maxAttempts` (default 5): `status = 'FAILED'` (terminal),
  `error` retained. A `FAILED` row is never retried automatically.
- A permanent error (invalid recipient, unknown device token) short-circuits
  straight to `FAILED` without exhausting attempts.

### Restart / crash behaviour

- No in-memory queue or timer state — everything lives in the table.
- A process that dies mid-send leaves a row in `SENDING` with an old
  `claimedAt`. Every dispatch run first **reaps** stragglers:
  `UPDATE "Notification" SET status='PENDING', claimedAt=NULL
   WHERE status='SENDING' AND claimedAt < now() - interval '$CLAIM_TIMEOUT'`
  (`CLAIM_TIMEOUT` default 10 min). Delivery is therefore **at-least-once**;
  `dedupeKey` + the FCM message key keep duplicates rare and harmless.
- A redeploy is just a normal process restart: the next cron tick resumes from
  the table.

### Failure handling & visibility

- Per-row `error` + `attempts`; a failing channel adapter never aborts the
  batch (each row is isolated, mirroring the app's resilient sync).
- Alerts (see [DEPLOYMENT.md](DEPLOYMENT.md)): dispatch endpoint returning
  non-2xx, `PENDING` backlog above a threshold, `FAILED` rate spike, cron not
  observed for > 5 min (heartbeat row).

### Cost

One extra table, one authenticated HTTP hit per minute, zero additional
infrastructure. No Redis, no queue service, no worker dyno, no paid provider.
This mirrors the deliberate `cdf1ddf` decision to stay off Firebase Blaze.

## Channel adapters

```
interface ChannelAdapter { send(n: Notification): Promise<Result> }
```

| Channel | MVP status | Adapter |
|---|---|---|
| `IN_APP` | ✅ | writes are the feed; `GET /api/me/notifications` |
| `PUSH` | ✅ | FCM via server credentials (`FCM_*` env). Device tokens from `POST /api/me/devices`. |
| `EMAIL` | stub | interface only; provider TBD, not in MVP |
| `SMS` | stub | interface only |
| `WHATSAPP` | stub | interface only |

Adapters are resolved from a registry; adding a channel is a new adapter + an
entry, no changes to `notify` callers.

## Recipient preferences

- `User.locale` selects the message catalogue (`en` / `hi`, mirroring
  DoseWise's ARB strings).
- Per-event, per-channel opt-out (post-MVP UI; schema hook: a
  `NotificationPreference` table or a JSON column on `User` — deferred).
- `SUPPRESSED` status records that a send was intentionally skipped.

## Scheduled notifications

`APPOINTMENT_REMINDER` (T-24h, T-2h) and `FOLLOW_UP_INFO` create `Notification`
rows with a future `scheduledFor` and a deterministic `dedupeKey` at the moment
the appointment is confirmed / the follow-up is set. The cron-driven dispatcher
above delivers them when due; a reschedule creates new rows with new keys and
the stale ones are cancelled (`SUPPRESSED`) by the reschedule handler. See
[DEPLOYMENT.md](DEPLOYMENT.md) for the concrete cron wiring per host.

## What stays on the device (unchanged)

The DoseWise medication reminder stack — exact alarms, `fullScreenIntent`,
insistent WAV, boot re-arm, TAKEN/SNOOZE/SKIP handling, missed-dose escalation,
home-screen widget — is **not** replaced and **not** driven by the server.
Server-side `MEDICATION_MISSED_ALERT` is only the *caregiver* fan-out that the
Cloud Function used to do.

## Logging

Notification payloads may contain names and appointment times but **must not**
contain clinical free-text, credentials, or raw device tokens. Dispatcher logs
reference `Notification.id` + `requestId`, not payload contents.
