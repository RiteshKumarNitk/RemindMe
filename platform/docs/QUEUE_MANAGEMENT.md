# Queue Management

The in-clinic consultation queue. One `QueueEntry` per checked-in appointment.
Strictly tenant-scoped: a Clinic A queue and a Clinic B queue never interact
(spec §12) — enforced by `organizationId` on every row and the tenant-scoped
client.

## Queue states

`WAITING` · `CALLED` · `IN_CONSULTATION` · `COMPLETED` · `SKIPPED`

```
WAITING ──► CALLED ──► IN_CONSULTATION ──► COMPLETED
   ▲          │
   │          └──► SKIPPED         (no-show at the door)
   └── recall ◄─────────┘          (SKIPPED/CALLED back to WAITING, recallCount++)
```

## Scope of a queue

A queue is identified by `(organizationId, doctorId, queueDate)` — one logical
line per doctor per clinic-local day, optionally partitioned by `locationId`.
`queueDate` is the clinic-local calendar day (`@db.Date`), derived from the
appointment's `timezone`.

## Token generation

On `POST /appointments/:id/check-in`:

1. Transition the appointment `CONFIRMED → CHECKED_IN`.
2. In the same transaction, allocate the next `tokenNumber` for
   `(organizationId, doctorId, queueDate)` — `MAX(tokenNumber)+1`, starting at
   1 each day. The `@@unique([organizationId, doctorId, queueDate, tokenNumber])`
   constraint + `SERIALIZABLE` (or `SELECT ... FOR UPDATE` on a per-day counter
   row) prevents two receptionists issuing the same token.
3. Create the `QueueEntry` with `state = WAITING`, `position = tokenNumber`
   (position is mutable; token is not), `checkedInAt = now`.
4. Transition the appointment `CHECKED_IN → WAITING`.
5. `AuditLog` (`PATIENT_CHECKED_IN`) + `Notification` (`CHECK_IN_CONFIRMED`)
   with token number and people-ahead count.

## Operations (`/api/orgs/:orgId/queue/...`)

| Action | Transition | Effect |
|---|---|---|
| **call** | `WAITING → CALLED` | `calledAt = now`; notify patient (`QUEUE_UPDATE`, "your turn") |
| **recall** | `CALLED/SKIPPED → WAITING` (re-queued, kept near front) | `recallCount++`; re-notify |
| **skip** | `WAITING/CALLED → SKIPPED` | `skippedAt = now`; patient dropped from active order; can be recalled |
| **start** | `CALLED → IN_CONSULTATION` | `consultationStartedAt`; appointment → `IN_CONSULTATION`; only the assigned DOCTOR |
| **complete** | `IN_CONSULTATION → COMPLETED` | `completedAt`; appointment → `COMPLETED` |

"Call next" = pick the lowest-`position` `WAITING` entry for the doctor/day and
`call` it. A `recall`ed entry is re-inserted at `position = (current min
WAITING position) - 1` (or a dedicated `recallPriority` ordering key) so it is
served next without renumbering everyone.

## Ordering

Live board query:
`WHERE organizationId=? AND doctorId=? AND queueDate=? AND state IN ('WAITING','CALLED','IN_CONSULTATION') ORDER BY (state='IN_CONSULTATION') DESC, position ASC`
served by `@@index([organizationId, doctorId, queueDate, state, position])`.

Patient-facing view returns: `tokenNumber`, `state`, `nowServing` (current
`CALLED`/`IN_CONSULTATION` token), `ahead` (count of `WAITING` with lower
position). Example: *Token #24 · Now serving #21 · 3 ahead*.

## Concurrency & correctness

- Token allocation and state transitions run in a transaction; the unique
  constraint is the backstop.
- Every transition is validated against the table above → invalid ⇒
  **409 `INVALID_QUEUE_TRANSITION`**.
- Completing / cancelling the underlying appointment cascades to the queue
  entry (`COMPLETED` / removed).
- Queue entries are not deleted for history; end-of-day they simply age out of
  the active board by `queueDate`.

## Realtime delivery (MVP)

Polling: the web board and patient app poll `GET /queue` every ~10 s. A
push `Notification` (`QUEUE_UPDATE`) is sent on `call`/`recall`. Server-Sent
Events / WebSockets are a post-MVP enhancement — not needed to be correct.
