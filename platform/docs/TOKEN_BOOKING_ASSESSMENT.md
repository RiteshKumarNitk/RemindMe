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
| `AppointmentEvent` | Every token/queue transition is logged here. |
| `AuditLog` (`writeAudit` / `writeAuditWith`) | Every mutation. |
| `Notification` + `notify()` + dispatcher | `TOKEN_BOOKED`, `TOKEN_CALLED`, `TOKEN_RECALLED`, `TOKEN_ON_HOLD`, `CONSULTATION_STARTED`. No new notification architecture. |
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
(0–1440, `opens < closes`, `maxDailyTokens` 1–500) and surfaced in the doctor's
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
| Action | PATIENT | RECEPTIONIST | DOCTOR (own queue) | CLINIC_ADMIN |
|---|---|---|---|---|
| Book today's token (self/dependent w/ MANAGE_APPOINTMENTS grant) | ✅ | — | — | — |
| Register a walk-in token | — | ✅ | — | ✅ |
| Read own token | ✅ | — | — | — |
| Read the queue board | — | ✅ | ✅ (own doctor only) | ✅ |
| call / hold / skip / no-show / callNext / recall | — | ✅ | — | ✅ |
| start / complete consultation | — | — | ✅ (assigned doctor only, unchanged) | — |
| Configure booking mode + window | — | — | ✅ (own profile) | ✅ (any doctor) |

Doctor cannot bypass reception on `call`/`hold`/`skip`/`no-show` — that matches
the pre-existing `queueTransition` rule (`START`/`COMPLETE` are doctor-only,
everything else is reception/admin), so no RBAC change was needed.
Doctor self-service for booking preferences follows the existing
`updateDoctor` "self or CLINIC_ADMIN" rule — a new restriction was not invented.

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
