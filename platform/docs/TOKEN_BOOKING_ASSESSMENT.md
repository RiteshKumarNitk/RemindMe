# Same-Day Token Booking — Implementation Assessment

Status: implemented. Read this first: it is the "what exists, what we reuse, what
is genuinely new" record that preceded the code, and the rationale for every
additive schema change below.

## 1. What already exists (and is reused, not replaced)

| Existing asset | Reused for |
|---|---|
| `Appointment` (`platform/prisma/schema.prisma`) | **The single source of truth.** A token booking is a normal `Appointment` row. No `TokenAppointment` table, no second booking system. |
| `AppointmentStatus` lifecycle (`REQUESTED → CONFIRMED → CHECKED_IN → WAITING → IN_CONSULTATION → COMPLETED`) | Unchanged for token bookings. Token check-in walks the *same* `CHECKED_IN → WAITING` path scheduled check-in does. |
| `QueueEntry` (`tokenNumber`, `queueDate`, `state`, `position`, `recallCount`) | **The token.** `tokenNumber` is already the daily sequence and already has `@@unique([organizationId, doctorId, queueDate, tokenNumber])`. |
| `QueueEntry` queue operations (`CALL/RECALL/SKIP/START/COMPLETE`) | Reception board actions. `HOLD` + `NO_SHOW` + `callNext` are added *to this state machine*, not as a parallel one. |
| `AppointmentEvent` | Every change of the **appointment's** status (token booked → WAITING, START → IN_CONSULTATION, COMPLETE, NO_SHOW, CANCEL). Queue-only moves (CALL, HOLD, RELEASE, SKIP, RECALL) don't change the appointment's status, so they are recorded in `AuditLog` (`QUEUE_<ACTION>`), not here. |
| `AuditLog` (`writeAudit` / `writeAuditWith`) | Every mutation. |
| `Notification` + `notify()` + dispatcher | One existing event, `QUEUE_UPDATE` (PUSH), with payload `{appointmentId, tokenNumber, state}` — sent on token booked (WAITING) and on every queue action except RELEASE and COMPLETE. No new notification architecture, no new event names. |
| `AvailabilityRule.startMinute/endMinute` convention (minutes from local midnight) | The token window is stored the same way, so it needs no new type. |
| `src/lib/time.ts` (`zonedWallTimeToUtc`, `localPartsInZone`) | All window maths is clinic-timezone-correct and server-side. |
| `runSerializable` + the `Appointment_org_doctor_no_overlap` EXCLUDE constraint | Concurrency safety model for booking, extended (see §3.6). |
| `tenantDb` client extension + `assertRole` | Tenant isolation and RBAC, unchanged. |
| `/api/public/doctors/:doctorId` + `/slots` | Public doctor page; gains a sibling `/token-window` read. |
| `selfBookAppointment` (`/api/patient/appointments`) | Gains a sibling `/token` route that reuses its `ensurePatientMembership` find-or-create. |
| Flutter `QueueEntry` model + `_QueueCard` | Already models token/state/position — extended, not replaced. |

## 2. Assessment: can the current models already represent this?

Mostly, yes. The only things the current schema genuinely **cannot** express:

1. Whether a doctor offers token booking, and the window (open/close/queue-start/max).
2. Whether a given `Appointment` is a scheduled slot or a same-day token.
3. A queue state for "called but didn't answer — hold for later" and for
   "the clinic decided this patient did not attend".
4. A clinic-local **date** on `Appointment` for token rows (`scheduledStart` is an
   instant, and an instant is not a token day).
5. A race-free daily token counter.
6. A DB-level "one active token per patient per doctor per day" guarantee.

That is the whole of it. Items 1–4 are one enum + five columns; 5 is one small
counter table; 6 is one partial unique index. **No new entity duplicates a
patient, doctor, organization, queue or appointment record.**

## 3. Additive schema changes (all optional / defaulted — zero backfill)

### 3.1 `enum BookingMode { SCHEDULED, SAME_DAY_TOKEN, BOTH }`
`DoctorProfile.bookingMode @default(SCHEDULED)`. Per-doctor, never global.
Default `SCHEDULED` ⇒ no existing doctor's behaviour changes.

### 3.2 `DoctorProfile` window columns (minutes from clinic-local midnight, matching `AvailabilityRule`)
| Column | Default | Meaning |
|---|---|---|
| `tokenOpensMinute` | `420` (07:00) | token booking opens |
| `tokenClosesMinute` | `660` (11:00) | token booking closes |
| `queueStartMinute` | `540` (09:00) | when the queue starts being served |
| `maxDailyTokens` | `50` | daily token cap |

7:00 AM is only the **default**. It is a doctor-configurable value, validated
(minutes 0–1439, `opens < closes`, queue start inside the window, `maxDailyTokens` 1–1000) and surfaced in the doctor's
own settings UI. Nothing in the codebase hardcodes 07:00.

### 3.3 `enum AppointmentBookingKind { SCHEDULED, SAME_DAY_TOKEN }`
`Appointment.bookingKind @default(SCHEDULED)`. The minimum metadata needed to
tell the two booking modes apart, on the *existing* Appointment row.
`Appointment.tokenDate DateTime? @db.Date` — the clinic-local token day, `NULL`
for scheduled appointments. Needed because the queue is a calendar-day concept
while `scheduledStart` is an instant, and it makes the partial unique index in
§3.6 expressible in plain SQL.

### 3.4 `enum QueueState` += `HOLD`, `NO_SHOW`
`HOLD` = called, no answer, may come back (recallable). `NO_SHOW` = the clinic
concluded the patient did not attend (terminal, not recallable). They are
**distinct from `SKIPPED`** (reception merely moved past this queue position,
still recallable) and distinct from the `Appointment` `NO_SHOW` status, which
keeps its own meaning. `QueueEntry.heldAt DateTime?` added for the event log/UI.

Transitions added (`queue/state-machine.ts`):

```
WAITING  ──HOLD──► HOLD        (reception holds a not-yet-arrived patient)
CALLED   ──HOLD──► HOLD        (spec §8 — called, no response)
HOLD     ──RECALL─► CALLED     (spec §10 — brought back, served next)
WAITING/CALLED/HOLD ──NO_SHOW──► NO_SHOW   (appointment → NO_SHOW)
```

`RECALL` from `CALLED`/`SKIPPED` still maps to `WAITING` exactly as before, so
the existing `queue.test.ts` expectations are untouched.

### 3.5 `model QueueTokenCounter`
`(organizationId, doctorId, queueDate) UNIQUE`, `lastToken Int`. Token numbers
are allocated with a single atomic statement (§4.2) instead of
`aggregate(_max) + 1`, so two patients racing at 07:00:00 can never collide.

**Scope:** `(organizationId, doctorId, queueDate)` — deliberately the *same*
scope as the existing `QueueEntry @@unique`, which does **not** include
`locationId`. Changing that would mean re-keying an existing unique constraint
and would let a counter and the constraint disagree. A doctor's token line is
therefore per doctor per clinic-local day across that doctor's locations;
`locationId` is still recorded on the entry and shown in the UI. Documented in
`QUEUE_MANAGEMENT.md`.

### 3.6 One partial unique index + one narrowed EXCLUDE predicate
```sql
-- one ACTIVE token per patient per doctor per clinic-local day
CREATE UNIQUE INDEX "Appointment_one_active_token_per_patient_doctor_day"
  ON "Appointment" ("organizationId","patientId","doctorId","tokenDate")
  WHERE "bookingKind" = 'SAME_DAY_TOKEN'
    AND "tokenDate" IS NOT NULL
    AND "status" NOT IN ('CANCELLED','NO_SHOW','RESCHEDULED','COMPLETED');
```
Because it is scoped to `bookingKind = 'SAME_DAY_TOKEN'`, a patient keeping two
*non-overlapping scheduled* appointments on the same day is unaffected.

The appointment double-booking EXCLUDE constraint is **narrowed** to scheduled
bookings. This is required, not optional: N token bookings all anchor
`scheduledStart` to the clinic's queue-start instant, so without the narrowing
the 2nd token of the day would be rejected as an "overlap".
```sql
ALTER TABLE "Appointment" DROP CONSTRAINT "Appointment_org_doctor_no_overlap";
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
  EXCLUDE USING gist (
    "organizationId" WITH =, "doctorId" WITH =,
    tstzrange("scheduledStart","scheduledEnd",'[)') WITH &&
  ) WHERE ("bookingKind" = 'SCHEDULED')
    AND ("status" NOT IN ('CANCELLED','NO_SHOW','RESCHEDULED'));
```
`double-booking.constraint.test.ts` cases A–D all still hold for scheduled rows.

## 4. Service-level decisions

### 4.1 Booking date rule
Same-day token booking accepts **no date at all**. "Today" is derived
server-side from the clinic/location IANA zone (`localPartsInZone`), never from
the client. The patient's device timezone is never consulted for the window.

### 4.2 Token allocation (concurrency)
One statement, inside the booking's `SERIALIZABLE` transaction:
```sql
INSERT INTO "QueueTokenCounter" (id, organizationId, doctorId, queueDate, lastToken)
VALUES ($1,$2,$3,$4, COALESCE((SELECT MAX(tokenNumber) FROM "QueueEntry" WHERE ...),0) + 1)
ON CONFLICT ("organizationId","doctorId","queueDate")
DO UPDATE SET "lastToken" = "QueueTokenCounter"."lastToken" + 1
RETURNING "lastToken";
```
Atomic in Postgres under `READ COMMITTED`, so it is correct even before
serialization is considered. Three further layers back it up: `SERIALIZABLE` +
`runSerializable` retry, the `QueueEntry` `@@unique`, and the new partial unique
index. The counter is also back-filled from `MAX(tokenNumber)` on first insert so
rows written by the pre-existing check-in path can never be re-issued.
`createEntryForCheckIn` was switched to the same allocator, so **there is exactly
one token sequence per doctor per day**, not two.

### 4.3 What the patient is *not* told
No consultation time is ever fabricated. `scheduledStart` on a token appointment
is the queue-start anchor and is explicitly labelled as such; the API returns
`tokenNumber`, `state`, `ahead` (counted from live queue rows) and
`nowServingToken`. The `etaMinutes` field is simply **not implemented** rather
than guessed — see §"Unresolved".

### 4.4 Who may do what (RBAC — no new capability)
| Action | PATIENT | RECEPTIONIST | DOCTOR | CLINIC_ADMIN |
|---|---|---|---|---|
| Book today's token (self, or dependent with an active MANAGE_APPOINTMENTS grant) | ✅ | — | — | — |
| Register a walk-in token | — | ✅ | ✅ own queue only | ✅ |
| Read own token / dependent's token (VIEW_APPOINTMENTS) | ✅ | — | — | — |
| Read the queue board | — | ✅ | ✅ | ✅ |
| call / call-next / hold / release / skip / recall / no-show | — | ✅ | ✅ own queue only | ✅ |
| start / complete consultation | — | — | ✅ assigned doctor only | — |
| Configure booking mode + window | — | — | ✅ own profile | ✅ any doctor |

The doctor's front-desk rights on their **own** queue are the pre-existing
`queueTransition` rule (an assigned doctor could already CALL/RECALL/SKIP before
this feature), preserved rather than widened or narrowed. A doctor can never act
on another doctor's queue; the board's per-entry `actions` list mirrors that
exactly, so no button is rendered that the API would refuse.
Doctor self-service for booking preferences follows the existing
`updateDoctor` "self or CLINIC_ADMIN" rule — a new restriction was not invented.

### 4.5 Priority handling
The product has no patient-priority concept, so there is nothing to interact
with. Order is `(position, tokenNumber)`: `position` starts equal to the token
and only RECALL changes it (to -1, "serve next"). Nothing reorders silently.

## 5. Rejected alternatives

- **A separate `TokenAppointment`/`Token` table.** Rejected: it would fork the
  appointment lifecycle, double the consultation/prescription/cancel paths, and
  guarantee that web and Flutter disagree.
- **Client-generated token numbers.** Rejected outright: trivially collidable.
- **`count + 1` without a lock.** Rejected: `count` and `insert` are separate
  statements and both can read the same value.
- **`BookingMode` on `ClinicSettings`.** Rejected: §2 requires per-doctor
  configuration, and `DoctorProfile` already holds `consultationDurationMin`,
  `isAcceptingNewPatients`, `isActive` — i.e. booking policy already lives there.
- **WebSockets for live queue updates.** Rejected: §21 forbids new infra where
  it isn't required. Reused the existing `AutoRefresh` (10 s `router.refresh()`)
  on the web and pull-to-refresh + a light poll in Flutter.
- **A hardcoded 07:00.** Rejected: it is a defaulted, per-doctor, validated field.

## 6. Unresolved / deliberately not built

- **No ETA clock time.** Turnover time varies with case mix; the backend exposes
  "people ahead" and "now serving", never "you will be seen at 09:42".
- **No future token days.** Same-day only. A doctor wanting multi-day tokens uses
  `SCHEDULED` (or `BOTH` + scheduled slots); adding future token days later means
  relaxing the `tokenDate = today` check only.
- **Token bookings are not reschedulable to another day** by the patient —
  cancelling and re-booking tomorrow's token is the path. A token day in the
  future does not exist, so a reschedule target never does either.
- **No per-location token lines.** Matches the existing unique constraint; see
  §3.5.

## 7. Follow-up pass (2026-10-01) — gaps closed after the first implementation

- **`CALLED → HOLD` was missing** from the state machine although §3.4 listed it;
  the core "token called, nobody answered, hold them" case was impossible. Added
  and unit-tested (`tests/unit/queue-state-machine.test.ts`).
- **Dependent spoofing (security).** `bookSameDayToken` passed a client
  `patientId` through with only an org check, so any patient could take a token
  in another patient's name. It now enforces ownership or an active
  MANAGE_APPOINTMENTS grant inside the booking transaction — the same rule as
  `bookAppointment`. A client `locationId` must also belong to the org.
- **Window validation** (`opens < closes`, queue start inside the window) was
  documented but not wired into `updateDoctor`; it now validates the merged
  stored+incoming window whenever any window field changes.
- **Board actions** offered CALL/HOLD/SKIP to *any* doctor although the API only
  allows the assigned one; now mirrors the API.
- **Web UI:** booking preferences on the doctor profile page; "Today's token"
  on the public doctor page (scheduled / token / both), `/doctors/:id/token`
  confirm page; reception board regrouped into NOW / NEXT / WAITING / ON HOLD /
  COMPLETED with server-decided "Call next" and a desk walk-in form; doctor
  overview "Today's queue"; live "My token" panel on the appointment page;
  booking-mode badge on search cards.
- **Flutter:** `BookingMode`/`TokenWindow`/`TokenStatus` models, token window +
  booking + status repository calls, "Today's token" card on the doctor
  profile, `TokenBookingScreen`, and a live token card (server `ahead`, polled
  every 20 s while live) that replaces the old `position - 1` estimate.

## 8. Production-hardening QA pass (2026-10-01)

Real-clinic walk-through of the whole token + queue day. Defects found and fixed
(none required a schema change):

1. **Consultation page left the queue stuck (pre-existing, high).** The
   consultation page's *Start* and *Sign & complete* (and the appointment
   `start` / `complete` / `no-show` routes) move the **appointment** through
   `applyStatusChange`, which never touched the `QueueEntry`. A visit finished
   from the SOAP/prescription page left its entry `IN_CONSULTATION`, so
   "Call next" refused ("someone is already called") for the rest of the day.
   `syncQueueEntryForAppointment` now moves the entry in the same transaction
   and writes the matching `QUEUE_*` audit row.
2. **Cancelled appointments could be resurrected (pre-existing, high).**
   Cancel parks the queue entry as `SKIPPED` (recallable), and queue `START`
   updated the appointment without checking its status — so recall → call →
   start turned a `CANCELLED` appointment into `IN_CONSULTATION`. Queue
   actions are now refused for CANCELLED / RESCHEDULED / NO_SHOW appointments
   (and only a stale-entry COMPLETE is allowed on a COMPLETED one); the board
   offers no buttons for them. Cancel now also drops `HOLD` entries.
3. **Cancelled token shown as "you missed your call".** The patient status now
   carries `appointmentStatus`; web and Flutter show "Cancelled" and stop
   polling. The reception board files cancelled entries under the finished
   group rather than the recallable "On hold / skipped" group.
4. **Doomed patient Cancel button on tokens.** The existing policy (patient
   self-cancel only outside `cancellationWindowHours`, measured from
   `scheduledStart` = today's queue-start anchor) is unchanged; the page now
   says "contact reception" instead of offering a button that always fails.

### Documented behaviour (as implemented and pinned by tests)

- **Queue transitions** (`queue/state-machine.ts`):
  WAITING→CALLED (call), WAITING→SKIPPED, WAITING→HOLD, WAITING→NO_SHOW;
  CALLED→WAITING (recall), CALLED→SKIPPED, CALLED→HOLD, CALLED→IN_CONSULTATION
  (start, assigned doctor), CALLED→NO_SHOW; SKIPPED→WAITING (recall),
  SKIPPED→NO_SHOW; HOLD→CALLED (recall), HOLD→WAITING (release), HOLD→NO_SHOW;
  IN_CONSULTATION→COMPLETED (complete, assigned doctor). COMPLETED and NO_SHOW
  are terminal.
- **Recall priority:** RECALL sets `position = -1` (every other entry keeps its
  position; nobody is renumbered). Order is `(position, tokenNumber)`, so a
  recalled-to-WAITING patient is called next; if two are recalled, the lower
  token goes first. Recall from HOLD goes straight to CALLED.
- **`tokenNumber` is never updated** after creation — no code path writes it.
- **Call next** refuses while anyone is CALLED or IN_CONSULTATION, and never
  auto-picks HOLD / SKIPPED.
- **Cap:** counts tokens *issued* (the counter), so a cancelled token still
  uses one of the day's slots. A refused booking (window, cap, ownership)
  rolls back with its transaction and consumes no number.
- **Cancellation:** staff may cancel REQUESTED / CONFIRMED / CHECKED_IN /
  WAITING (including a CALLED or HELD token, whose appointment is still
  WAITING); IN_CONSULTATION, COMPLETED, NO_SHOW cannot be cancelled.
  Patients/guardians are additionally bound by the clinic's cancellation
  window from the queue-start anchor — in practice, a same-day token is
  cancelled by reception.
