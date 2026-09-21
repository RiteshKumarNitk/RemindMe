# Appointment Workflow

## Statuses (spec §8)

`REQUESTED` · `CONFIRMED` · `CHECKED_IN` · `WAITING` · `IN_CONSULTATION` ·
`COMPLETED` · `CANCELLED` · `NO_SHOW` · `RESCHEDULED`

## State machine

```
                 ┌──────────────► CANCELLED   (from REQUESTED / CONFIRMED)
                 │
REQUESTED ──► CONFIRMED ──► CHECKED_IN ──► WAITING ──► IN_CONSULTATION ──► COMPLETED
    │            │
    │            └──────────► NO_SHOW      (CONFIRMED only, at/after start time)
    │
    └──► RESCHEDULED  (terminal on the old row; a new REQUESTED/CONFIRMED row is created and linked)

CHECKED_IN / WAITING ──► IN_CONSULTATION ──► COMPLETED
CHECKED_IN / WAITING ──► CANCELLED        (walked out — reason required)
```

### Valid transitions (enforced server-side)

| From | To | Who | Guard |
|---|---|---|---|
| `REQUESTED` | `CONFIRMED` | RECEPTIONIST+, or auto if `ClinicSettings.allowPatientSelfBooking` and slot valid | slot still free |
| `REQUESTED` | `CANCELLED` | patient (owner), RECEPTIONIST+ | within cancellation window for patients |
| `REQUESTED` | `RESCHEDULED` | patient†, RECEPTIONIST+ | new slot valid |
| `CONFIRMED` | `CHECKED_IN` | RECEPTIONIST+ | same clinic day (configurable early window) |
| `CONFIRMED` | `CANCELLED` | patient†, RECEPTIONIST+ | reason required |
| `CONFIRMED` | `RESCHEDULED` | patient†, RECEPTIONIST+ | new slot valid |
| `CONFIRMED` | `NO_SHOW` | RECEPTIONIST+, DOCTOR | now ≥ `scheduledStart` + grace |
| `CHECKED_IN` | `WAITING` | system (on `QueueEntry` create) | — |
| `CHECKED_IN`/`WAITING` | `IN_CONSULTATION` | DOCTOR (own) | queue entry `CALLED` |
| `CHECKED_IN`/`WAITING` | `CANCELLED` | RECEPTIONIST+, DOCTOR | reason required |
| `IN_CONSULTATION` | `COMPLETED` | DOCTOR (own) | — |
| any non-terminal | same | — | no-op returns 200, no event |
| anything else | — | — | **409 `INVALID_STATUS_TRANSITION`** |

Terminal: `COMPLETED`, `CANCELLED`, `NO_SHOW`, `RESCHEDULED`. No transitions
out of terminal states. Every accepted transition writes an `AppointmentEvent`
(`fromStatus`, `toStatus`, `actorId`, `reason`, `at`) **and** an `AuditLog`
row. Arbitrary `PATCH status` is not allowed — only the named action endpoints.

## Booking

Request: `{ patientId, doctorId, scheduledStart, appointmentTypeId?, reason? }`.
The server computes `scheduledEnd` from the appointment type (or
`ClinicSettings.defaultAppointmentDurationMin`) and snapshots the doctor/
location `timezone`.

**Algorithm** (inside a `SERIALIZABLE` transaction):

1. Resolve `patientId` and `doctorId` — both must belong to `ctx.organizationId`
   (else 404).
2. Check `ClinicSettings`: lead time (`scheduledStart` ≥ now + lead), max
   advance (`≤ now + maxAdvanceBookingDays`), and — for a PATIENT caller —
   `allowPatientSelfBooking`.
3. **Availability**: `scheduledStart..scheduledEnd` must fall entirely inside a
   computed free slot for that doctor on that date (see below).
4. `INSERT` the `Appointment`. The Postgres `EXCLUDE` constraint
   (`Appointment_org_doctor_no_overlap`, scoped by `organizationId` +
   `doctorId` + time range) rejects any overlap with an active appointment for
   the same doctor **in the same clinic**. The same doctor overlapping in a
   *different* clinic is allowed.
5. On constraint violation or serialization failure → roll back, return
   **409 `APPOINTMENT_SLOT_TAKEN`**. The client refetches slots.
6. Emit `AppointmentEvent(null → REQUESTED|CONFIRMED)`, `AuditLog`, and a
   `Notification` (`APPOINTMENT_BOOKED`).

"The slot was free when the page loaded" is never trusted — the DB is the
final authority (spec §11).

## Slot calculation (`GET /doctors/:id/slots?date=`)

Pure function, server-side, never trusted from the client (spec §10):

1. Resolve the doctor/location IANA timezone for `date`.
2. Gather `AvailabilityRule`s for `weekday(date)` that are effective on `date`
   → a set of `[startMinute, endMinute)` local windows with `slotMinutes`.
3. Subtract `AvailabilityException`s of kind `DAY_OFF`/`HOLIDAY`/`LEAVE`/
   `BREAK` overlapping `date`; add `EXTRA_HOURS` windows.
4. Slice each remaining window into `slotMinutes` steps → candidate local
   start times; convert to `timestamptz` using the resolved tz (DST-correct).
5. Subtract any candidate that overlaps an existing active `Appointment` for
   that doctor (`status NOT IN (CANCELLED, NO_SHOW, RESCHEDULED)`).
6. Drop candidates before `now + bookingLeadTimeMinutes`.
7. Return `[{ start, end }]` in UTC plus the `timezone` used.

## Reschedule

`POST /appointments/:id/reschedule` with `{ scheduledStart, appointmentTypeId? }`:

- Runs the full booking algorithm for the new time.
- On success: create a **new** `Appointment` (status mirrors the old one's
  stage — `CONFIRMED` if the old was confirmed, else `REQUESTED`), set
  `rescheduledFromId` on the new row, transition the old row to `RESCHEDULED`.
- Two `AppointmentEvent`s + `AuditLog` (`APPOINTMENT_RESCHEDULED`) + a
  `Notification`.
- Reschedule lineage is queryable via the self-relation.

## Cancellation

`POST /appointments/:id/cancel` with `{ reason }`:

- Allowed from `REQUESTED`, `CONFIRMED`, `CHECKED_IN`, `WAITING`.
- PATIENT callers are checked against `ClinicSettings.cancellationWindowHours`
  → **403 `OUTSIDE_CANCELLATION_WINDOW`** if too late (staff can override).
- Sets `cancelledAt`, `cancelledById`, `cancellationReason`; frees the slot
  immediately (the `EXCLUDE` predicate excludes `CANCELLED`).
- If a `QueueEntry` exists, it is removed / marked `SKIPPED`.
- `AuditLog` (`APPOINTMENT_CANCELLED`) + `Notification`.

## No-show

`CONFIRMED → NO_SHOW` only, and only at/after `scheduledStart` + grace. Sets
`noShowMarkedAt`. Audited. Does not auto-charge anything (no billing in MVP).

## Timezone correctness

- Store `scheduledStart/End` as `timestamptz`; keep `timezone` (IANA) on the
  row for display and for recomputing local slot math.
- All slot generation and "same clinic day" checks use the clinic/location
  timezone, not the server's and not the client's.
- DST transitions are handled by doing local→instant conversion through the
  IANA zone at generation time.
