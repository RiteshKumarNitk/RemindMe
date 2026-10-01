-- =============================================================================
-- Same-day token booking (TOKEN_BOOKING_ASSESSMENT.md).
--
-- Purely additive: every new column is NULLABLE or DEFAULTED, so no existing
-- row needs a backfill and no existing query changes behaviour.
--
--   1. QueueState gains HOLD + NO_SHOW (spec §9 — hold/skip/no-show are NOT
--      the same thing).
--   2. Appointment gains bookingKind + tokenDate (spec §22 — same core
--      Appointment entity, minimum metadata).
--   3. DoctorProfile gains the per-doctor booking mode + token window (spec §2/§3).
--   4. QueueTokenCounter: race-free daily token sequence (spec §18).
--   5. QueueEntry.heldAt + a supporting index.
--   6. Two constraints that make the guarantees DB-enforced rather than
--      application-enforced:
--        - one ACTIVE token per patient per doctor per clinic-local day (§19)
--        - the appointment double-booking EXCLUDE narrowed to SCHEDULED rows,
--          because N token bookings legitimately share one queue-start anchor.
-- =============================================================================

-- AlterEnum
ALTER TYPE "QueueState" ADD VALUE 'HOLD';
ALTER TYPE "QueueState" ADD VALUE 'NO_SHOW';

-- CreateEnum
CREATE TYPE "BookingMode" AS ENUM ('SCHEDULED', 'SAME_DAY_TOKEN', 'BOTH');

-- CreateEnum
CREATE TYPE "AppointmentBookingKind" AS ENUM ('SCHEDULED', 'SAME_DAY_TOKEN');

-- AlterTable: Appointment
ALTER TABLE "Appointment" ADD COLUMN     "bookingKind" "AppointmentBookingKind" NOT NULL DEFAULT 'SCHEDULED';
ALTER TABLE "Appointment" ADD COLUMN     "tokenDate" DATE;

-- AlterTable: DoctorProfile
ALTER TABLE "DoctorProfile" ADD COLUMN "bookingMode"       "BookingMode" NOT NULL DEFAULT 'SCHEDULED';
ALTER TABLE "DoctorProfile" ADD COLUMN "tokenOpensMinute"  INTEGER NOT NULL DEFAULT 420;
ALTER TABLE "DoctorProfile" ADD COLUMN "tokenClosesMinute" INTEGER NOT NULL DEFAULT 660;
ALTER TABLE "DoctorProfile" ADD COLUMN "queueStartMinute"  INTEGER NOT NULL DEFAULT 540;
ALTER TABLE "DoctorProfile" ADD COLUMN "maxDailyTokens"    INTEGER NOT NULL DEFAULT 50;

-- AlterTable: QueueEntry
ALTER TABLE "QueueEntry" ADD COLUMN "heldAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "QueueTokenCounter" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "queueDate" DATE NOT NULL,
    "lastToken" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QueueTokenCounter_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "QueueTokenCounter_organizationId_doctorId_queueDate_key"
  ON "QueueTokenCounter"("organizationId", "doctorId", "queueDate");
CREATE INDEX "QueueTokenCounter_organizationId_doctorId_queueDate_idx"
  ON "QueueTokenCounter"("organizationId", "doctorId", "queueDate");

-- CreateIndex
CREATE INDEX "QueueEntry_organizationId_doctorId_queueDate_tokenNumber_idx"
  ON "QueueEntry"("organizationId", "doctorId", "queueDate", "tokenNumber");

-- CreateIndex
CREATE INDEX "Appointment_organizationId_bookingKind_tokenDate_idx"
  ON "Appointment"("organizationId", "bookingKind", "tokenDate");

-- AddForeignKey
ALTER TABLE "QueueTokenCounter" ADD CONSTRAINT "QueueTokenCounter_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "QueueTokenCounter" ADD CONSTRAINT "QueueTokenCounter_doctorId_fkey"
  FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- -----------------------------------------------------------------------------
-- One ACTIVE token per patient per doctor per clinic-local day (spec §19).
--
-- Partial on bookingKind = 'SAME_DAY_TOKEN' AND tokenDate IS NOT NULL, so a
-- patient keeping two NON-OVERLAPPING scheduled appointments on the same day is
-- completely unaffected. Terminal statuses are excluded: a patient who
-- completed, cancelled, was marked no-show, or whose token was skipped is not
-- "active" and may book again.
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX "Appointment_one_active_token_per_patient_doctor_day"
  ON "Appointment"("organizationId", "patientId", "doctorId", "tokenDate")
  WHERE "bookingKind" = 'SAME_DAY_TOKEN'
    AND "tokenDate" IS NOT NULL
    AND "status" NOT IN ('CANCELLED', 'NO_SHOW', 'RESCHEDULED', 'COMPLETED');

-- -----------------------------------------------------------------------------
-- Narrow the appointment double-booking EXCLUDE to SCHEDULED rows.
--
-- REQUIRED, not cosmetic: every same-day token booking anchors scheduledStart to
-- the doctor's queue-start instant for that day, so without this predicate the
-- 2nd token of the day would be rejected as an "overlap". Slot double-booking
-- protection for scheduled appointments is unchanged (tests
-- double-booking.constraint.test.ts cases A-D all still hold).
--
-- The insert side and the UPDATE side of the constraint differ in Postgres:
-- for an UPDATE the predicate is evaluated against the NEW row, which is what
-- we want (moving a SCHEDULED row to COMPLETED must drop it from the index).
-- -----------------------------------------------------------------------------
-- NOTE the extra outer parenthesis pair: an EXCLUDE index predicate parsed
-- after EXCLUDE element list must be one parenthesised expression. `WHERE (a)
-- AND (b)` is a syntax error (E42601) at the AND; `WHERE ((a) AND (b))` is
-- accepted. Verified against Postgres 16.
ALTER TABLE "Appointment" DROP CONSTRAINT "Appointment_org_doctor_no_overlap";

ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
  EXCLUDE USING gist (
    "organizationId" WITH =,
    "doctorId"       WITH =,
    tstzrange("scheduledStart", "scheduledEnd", '[)') WITH &&
  )
  WHERE (("bookingKind" = 'SCHEDULED')
     AND ("status" NOT IN ('CANCELLED', 'NO_SHOW', 'RESCHEDULED')));

-- Rollback:
--   ALTER TABLE "Appointment" DROP CONSTRAINT "Appointment_one_active_token_per_patient_doctor_day";
--   ALTER TABLE "Appointment" DROP CONSTRAINT "Appointment_org_doctor_no_overlap";
--   ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
--     EXCLUDE USING gist ("organizationId" WITH =, "doctorId" WITH =,
--       tstzrange("scheduledStart","scheduledEnd",'[)') WITH &&)
--     WHERE ("status" NOT IN ('CANCELLED','NO_SHOW','RESCHEDULED'));
--   DROP TABLE "QueueTokenCounter";
