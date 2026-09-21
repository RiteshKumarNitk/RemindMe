# Database Design

Source of truth: [`prisma/schema.prisma`](../prisma/schema.prisma). This file
explains the intent, the indexes, and the non-obvious choices.

## Principles

- **UUID PKs** everywhere (`@default(uuid())`).
- **`organizationId` on every tenant-owned table**, leading every composite
  index for that table.
- **Real FKs** for the core clinical graph. **Actor columns**
  (`createdById`, `updatedById`, `cancelledById`, `actorUserId`,
  `uploadedById`, `grantedById`, `invitedById`, …) are plain indexed UUID
  strings — logical references to `User.id`, enforced in the app layer. This
  keeps the relation graph maintainable; the trade-off is accepted and listed
  here so it is not a surprise.
- **Soft deletes** where sync or audit needs the tombstone
  (`Medication.deletedAt`, `MedicationDose.deletedAt`, `Organization.isActive`,
  `Patient.isActive`). Hard deletes elsewhere via `onDelete` rules.
- **No business logic in the DB** except the one thing the DB must own:
  double-booking (`EXCLUDE` constraint).

## Table groups

### Tenancy & identity

| Table | Purpose | Notable columns / constraints |
|---|---|---|
| `Organization` | the tenant | `slug @unique`, `timezone` (IANA) |
| `ClinicSettings` | per-tenant policy | 1:1 with org; booking lead time, cancellation window, self-booking flag, locales |
| `ClinicLocation` | physical site | optional `timezone` override |
| `User` | global identity | `email @unique` (lower-cased; citext in prod), `passwordHash?` (argon2id), `isPlatformAdmin` |
| `IdentityAccount` | OAuth link | `@@unique([provider, providerAccountId])` |
| `Session` | web cookie session | `hashedSessionToken @unique`, `expiresAt` |
| `RefreshToken` | Flutter/API refresh | `hashedToken @unique`, `familyId` (rotation lineage), `revokedAt` |
| `Membership` | user × org × role | `@@unique([userId, organizationId, role])`, `@@index([organizationId, role])`; `capabilities MembershipCapability[] @default([])` — fine-grained grants layered on the role (`CLINICAL_RECORD_READ/WRITE`, `BILLING_MANAGE`, `DATA_EXPORT`); **empty for every role by default**, so no role (incl. `CLINIC_ADMIN`) implies clinical-record access. See [RBAC.md](RBAC.md). |
| `DoctorProfile` / `StaffProfile` | clinic-side profile | `@@unique([organizationId, userId])` |

### Patients & family

| Table | Purpose | Notable |
|---|---|---|
| `Patient` | org-scoped patient record | `ownerUserId?` (self-managing patient), `@@unique([organizationId, mrn])`, `@@index([organizationId, lastName])`, `@@index([organizationId, ownerUserId])` |
| `FamilyRelationship` | guardian ↔ dependent | `@@unique([guardianUserId, dependentPatientId])` |
| `PatientAccessGrant` | scoped access to a patient | `permissions AccessPermission[]`, `expiresAt?`, `revokedAt?`, `@@unique([patientId, granteeUserId])` |
| `Invitation` | staff / patient / family join token | `hashedToken @unique` (raw only in link/QR), `scope`, `expiresAt`, `usedAt`, `revokedAt` |

### Scheduling & appointments

| Table | Purpose | Notable |
|---|---|---|
| `AppointmentType` | duration/colour presets | `@@unique([organizationId, name])` |
| `AvailabilityRule` | recurring weekly availability | `weekday` ISO 1..7, `startMinute`/`endMinute` from local midnight (avoids `time` tz ambiguity), `slotMinutes`, `@@index([organizationId, doctorId, weekday])` |
| `AvailabilityException` | leave / holiday / extra hours / break | `startsAt`/`endsAt` `timestamptz`, `@@index([organizationId, doctorId, startsAt])` |
| `Appointment` | the booking | `scheduledStart`/`scheduledEnd` `timestamptz(6)`, `timezone` snapshot, `status`, lifecycle timestamps, reschedule self-relation, indexes on `(org, doctor, start)`, `(org, patient, start)`, `(org, status)` |
| `AppointmentEvent` | append-only transition log | `fromStatus`, `toStatus`, `actorId`, `at`, `@@index([appointmentId])` |

### Queue

| Table | Purpose | Notable |
|---|---|---|
| `QueueEntry` | one row per checked-in appointment | `queueDate @db.Date`, `tokenNumber`, `state`, `position`, `recallCount`, `@@unique([organizationId, doctorId, queueDate, tokenNumber])`, `@@index([organizationId, doctorId, queueDate, state, position])` |

### Clinical documentation

| Table | Purpose | Notable |
|---|---|---|
| `Consultation` | SOAP-style structured notes | 1:1 with `Appointment`; free text only, **no AI fields**; `followUpDate`, `signedAt` |
| `Prescription` / `PrescriptionItem` | issued prescription | item has `drugName`, `strength`, `dosage`, `frequency`, `durationDays`, `foodInstruction` |
| `MedicalDocument` | file **metadata only** | `storageProvider`, `storageKey`, `mimeType`, `sizeBytes`, `checksum`, `@@index([organizationId, patientId, kind])` |

### Medication domain (migrated from DoseWise)

| Table | DoseWise origin | Notable |
|---|---|---|
| `Medication` | `medicines` | `selectedDays Int[]`, `stockCount`/`refillAt`, `legacyLocalId` + `sourceDeviceId` (`@@unique`) for idempotent import, `deletedAt` tombstone |
| `MedicationSchedule` | `medicine_schedules` | `hour`, `minute`, `enabled` |
| `MedicationDose` | `medicine_doses` | identity `@@unique([medicationId, scheduledAtLocal])`; `scheduledAtLocal` is **wall-clock local**, plus `timezone`; `status` enum; `takenAt`/`skippedAt` are `timestamptz` |
| `VitalReading` | SharedPreferences `vital_*` | new table; `type`, `value`, `value2` (diastolic), `recordedAt` |

### Platform

| Table | Purpose | Notable |
|---|---|---|
| `Notification` | outbound message record + reliable-delivery state | `channel`, `event`, `payload Json`; `status` (`PENDING`→`SENDING`→`SENT`/`FAILED`/`SUPPRESSED`); `scheduledFor`; `dedupeKey @unique` (idempotent creation); `attempts`/`maxAttempts`/`nextAttemptAt` (backoff); `claimedAt` (crash-recovery reap); indexes `[status, scheduledFor]` + `[status, nextAttemptAt]`. Drained by a cron-invoked dispatcher with `FOR UPDATE SKIP LOCKED` — no Redis/queue. See [NOTIFICATION_ARCHITECTURE.md](NOTIFICATION_ARCHITECTURE.md). |
| `AuditLog` | who/what/when | `action`, `entityType`, `entityId`, `before`/`after Json`, `ip`, `userAgent`, `requestId`; indexes `(org, entityType, entityId)`, `(org, at)`, `(actorUserId)`; **never** stores passwords, tokens, or FCM tokens |

## Time handling (spec §9)

| Concept | Storage | Why |
|---|---|---|
| Appointment start/end | `timestamptz(6)` + `timezone` (IANA) snapshot | canonical instant; unambiguous across DST and travel; the tz string drives display and slot math |
| Availability rule | `weekday` + minutes-from-local-midnight | recurring wall-clock; no date, no tz on the row (resolved against the doctor/location tz) |
| Availability exception | `timestamptz` range | a concrete blocked/extra interval |
| Medication dose | `scheduledAtLocal` (naive local) + `timezone` | DoseWise semantics: "09:00 every day" must not shift when the device changes zone |
| `takenAt` / `skippedAt` / audit `at` | `timestamptz` | real events, real instants |

## Double-booking constraint (spec §11)

`ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
EXCLUDE USING gist ("organizationId" WITH =, "doctorId" WITH =,
tstzrange("scheduledStart","scheduledEnd",'[)') WITH &&) WHERE ("status" NOT IN
('CANCELLED','NO_SHOW','RESCHEDULED'))`. Requires `btree_gist`. Applied via
[`prisma/sql/0001_appointment_no_overlap.sql`](../prisma/sql/0001_appointment_no_overlap.sql)
inside the migration that creates `Appointment`.

- **Scoped by `(organizationId, doctorId, time range)`** — the same physical
  doctor may hold overlapping appointments in **different** clinics, but never
  within one clinic. (`DoctorProfile` is already org-scoped, so `doctorId`
  alone would suffice today; `organizationId` is included to make the tenant
  boundary explicit at the DB level and to stay correct if doctor identity is
  ever shared across clinics.)
- The booking service also runs in a `SERIALIZABLE` transaction and maps the
  `exclusion_violation` / serialization failure to **409
  `APPOINTMENT_SLOT_TAKEN`**.
- The database is the last line of defence — this is never solved in
  application code alone. "The slot was free when the page loaded" is never
  trusted.
- Covered by `platform/tests/double-booking.constraint.test.ts` (see
  [TESTING.md](TESTING.md)): same-org overlap rejected; cross-org overlap for
  the same doctor allowed.

## Index rationale (spec §21)

Every index above exists to serve a specific query:

- `Appointment(org, doctor, scheduledStart)` — doctor day view, slot conflict
  scan, availability subtraction.
- `Appointment(org, patient, scheduledStart)` — patient history / upcoming.
- `Appointment(org, status)` — reception dashboards, no-show sweeps.
- `QueueEntry(org, doctor, queueDate, state, position)` — "call next", live
  board.
- `AvailabilityRule(org, doctor, weekday)` — slot generation for a date.
- `MedicationDose(medicationId, status)` and `(patientId, scheduledAtLocal)` —
  adherence stats, sync deltas.
- `AuditLog(org, entityType, entityId)` — entity history; `(org, at)` — recent
  activity feed.

## Toolchain

Targets **Prisma 6.x** — `url` / `directUrl` live in the `datasource` block
(the Prisma ≤6 idiom). `prisma@6 validate` and `prisma@6 format` both pass
(2026-09-10). Prisma 7 moved datasource URLs into a `prisma.config.ts` file; if
the team adopts 7 later that is a mechanical config move with no model changes.

## Migrations (spec §27)

Prisma migrations only. `prisma migrate dev` in development; `prisma migrate
deploy` in production. No manual schema edits to a live DB. **No `migrate
reset` / `db push --force-reset` against anything but a local/dev database.**
The `btree_gist` extension and `Appointment_org_doctor_no_overlap` constraint
are part of migration history (raw SQL pasted into the `init` migration), not a
manual production step. Commands are in [DEPLOYMENT.md](DEPLOYMENT.md).
