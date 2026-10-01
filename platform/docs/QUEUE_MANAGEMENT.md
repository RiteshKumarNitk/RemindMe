# Queue Management

The in-clinic consultation queue. One `QueueEntry` per checked-in appointment.
Strictly tenant-scoped: a Clinic A queue and a Clinic B queue never interact
(spec §12) — enforced by `organizationId` on every row and the tenant-scoped
client.

## Queue states

`WAITING` · `CALLED` · `IN_CONSULTATION` · `COMPLETED` · `SKIPPED` · `HOLD` · `NO_SHOW`

```
WAITING ──call──► CALLED ──start──► IN_CONSULTATION ──complete──► COMPLETED
  │  ▲              │ │ │
  │  └──recall──────┘ │ └──skip──► SKIPPED ──recall──► WAITING (served next)
  │                   └──hold──► HOLD ──recall──► CALLED
  ├──hold──► HOLD           HOLD ──release──► WAITING
  ├──skip──► SKIPPED
  └──no-show (also from CALLED / SKIPPED / HOLD) ──► NO_SHOW  (terminal)
```

Source of truth: `src/modules/queue/state-machine.ts`. HOLD = here-ish but out
of the running order (recallable); SKIPPED = missed the call (recallable);
NO_SHOW = clinic decided they did not attend (terminal; the appointment
becomes NO_SHOW too).

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
| **call** | `WAITING → CALLED` | `calledAt` |
| **recall** | `CALLED/SKIPPED → WAITING`, `HOLD → CALLED` | `recallCount++`, `position = -1`, `calledAt` |
| **skip** | `WAITING/CALLED → SKIPPED` | `skippedAt` |
| **hold** | `WAITING/CALLED → HOLD` | `heldAt` |
| **release** | `HOLD → WAITING` | `heldAt = null` (keeps its old position) |
| **no-show** | `WAITING/CALLED/SKIPPED/HOLD → NO_SHOW` | appointment → `NO_SHOW` |
| **start** | `CALLED → IN_CONSULTATION` | assigned DOCTOR only; appointment → `IN_CONSULTATION` |
| **complete** | `IN_CONSULTATION → COMPLETED` | assigned DOCTOR only; appointment → `COMPLETED` |
| **next** (`POST /queue/next`) | earliest `WAITING` → `CALLED` | refuses while anyone is CALLED/IN_CONSULTATION |

Every action writes `AuditLog` `QUEUE_<ACTION>` and (except release/complete)
a `QUEUE_UPDATE` notification to the patient's owner. Front-desk actions are
RECEPTIONIST / CLINIC_ADMIN, or the assigned doctor on their own queue.

**Appointment is the source of truth.** Queue actions are refused when the
appointment is CANCELLED / RESCHEDULED / NO_SHOW. Starting, completing or
no-showing the *appointment* directly (consultation page, appointment routes)
moves the queue entry in the same transaction.

## Ordering

`ORDER BY position ASC, tokenNumber ASC`. `position` starts equal to the
token and only RECALL changes it (to -1). The board returns every entry for
the day (all states) with a per-entry `actions` list computed server-side.

Patient-facing view (`GET /api/patient/token-status`) returns `tokenNumber`,
`state`, `appointmentStatus`, `nowServingToken` (IN_CONSULTATION, else CALLED),
`ahead` (WAITING entries ordered before this one) and a server-written
`advice`. No ETA.

## Concurrency & correctness

- Token allocation and state transitions run in a transaction; the unique
  constraint is the backstop.
- Every transition is validated against the table above → invalid ⇒
  **409 `INVALID_QUEUE_TRANSITION`**.
- Cancelling the underlying appointment parks a WAITING / CALLED / HOLD entry
  as `SKIPPED` (history kept, no further queue actions). Starting / completing
  / no-showing the appointment moves the entry to match.
- Queue entries are not deleted for history; end-of-day they simply age out of
  the active board by `queueDate`.

## Realtime delivery (MVP)

Polling: the web board refreshes every 10 s and the web token panel every
15 s while live; the Flutter token card polls `/patient/token-status` every
20 s while the token is live and stops when it is finished or cancelled. A
`QUEUE_UPDATE` notification is sent on every queue action except release /
complete. Server-Sent
Events / WebSockets are a post-MVP enhancement — not needed to be correct.

## Same-day tokens, HOLD and NO_SHOW

Token bookings (`Appointment.bookingKind = SAME_DAY_TOKEN`) enter this queue directly as
`WAITING` and share the per-(organization, doctor, clinic-local day) token counter
(`QueueTokenCounter`) with scheduled check-ins — one sequence per doctor per day, across that
doctor's locations. Added states: `HOLD` (from WAITING or CALLED; `RECALL` → CALLED,
`RELEASE` → WAITING) and `NO_SHOW` (terminal, also marks the appointment NO_SHOW). "Call next"
is server-side and picks the earliest `WAITING` by `(position, tokenNumber)`; HOLD/SKIPPED are
never auto-picked. Details: [TOKEN_BOOKING_ASSESSMENT.md](TOKEN_BOOKING_ASSESSMENT.md).
