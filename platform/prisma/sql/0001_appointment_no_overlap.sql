-- =============================================================================
-- Double-booking protection (spec §11) — Postgres EXCLUDE constraint.
--
-- Prisma cannot express EXCLUDE constraints, so this is applied as a manual
-- step inside the generated migration. After
--   npx prisma migrate dev --create-only --name init
-- paste this into the generated migration.sql (after the CREATE TABLE
-- "Appointment" statement), or keep it as its own follow-up migration that
-- depends on the table.
--
-- GUARANTEE
-- ---------
-- Within ONE organization, for one doctor, no two appointments whose time
-- ranges overlap can both be in an "active" status. The overlap key is:
--
--   (organizationId, doctorId, [scheduledStart, scheduledEnd))
--
-- so the SAME doctor CAN legitimately hold overlapping appointments in
-- DIFFERENT clinics:
--
--   Clinic A · Doctor X · 10:00-10:30 · Patient A   -> allowed
--   Clinic B · Doctor X · 10:00-10:30 · Patient B   -> allowed
--   Clinic A · Doctor X · 10:00-10:30 · Patient C   -> REJECTED (overlaps Patient A)
--
-- Note: `DoctorProfile` is already org-scoped (@@unique([organizationId,
-- userId])), so a physical doctor has a distinct `doctorId` per clinic and the
-- doctorId column alone would technically suffice today. `organizationId` is
-- included anyway: (a) it makes the tenant boundary explicit at the DB level,
-- (b) it keeps the constraint correct if doctor identity is ever refactored to
-- be shared across clinics, and (c) it lets the planner use the leading
-- organizationId for locality.
--
-- Two patients racing the same slot -> the second INSERT/UPDATE fails with a
-- constraint (exclusion_violation) or serialization error, which the booking
-- service maps to HTTP 409 APPOINTMENT_SLOT_TAKEN. This runs IN ADDITION TO a
-- SERIALIZABLE transaction in the booking service: the constraint is the final
-- authority, the transaction gives a clean retry path. The database remains the
-- last line of defence — this is never solved in application code alone.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "Appointment"
  ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
  EXCLUDE USING gist (
    "organizationId" WITH =,
    "doctorId"       WITH =,
    tstzrange("scheduledStart", "scheduledEnd", '[)') WITH &&
  )
  WHERE ("status" NOT IN ('CANCELLED', 'NO_SHOW', 'RESCHEDULED'));

-- Rollback:
-- ALTER TABLE "Appointment" DROP CONSTRAINT "Appointment_org_doctor_no_overlap";
