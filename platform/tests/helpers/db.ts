import { PrismaClient } from "@prisma/client";

if (process.env.ALLOW_DB_TESTS !== "1") {
  throw new Error(
    "Integration tests need a disposable database. Set ALLOW_DB_TESTS=1 and " +
      "point DATABASE_URL at a dev/test database (its app tables are TRUNCATEd).",
  );
}

export const db = new PrismaClient();

// Every app table (keep _prisma_migrations). Child-first not required — CASCADE.
const TABLES = [
  "AuditLog",
  "Notification",
  "VitalReading",
  "MedicationDose",
  "MedicationSchedule",
  "Medication",
  "MedicalDocument",
  "PrescriptionItem",
  "Prescription",
  "Consultation",
  "QueueEntry",
  "AppointmentEvent",
  "Appointment",
  "AvailabilityException",
  "AvailabilityRule",
  "AppointmentType",
  "Invitation",
  "PatientAccessGrant",
  "FamilyRelationship",
  "Patient",
  "StaffProfile",
  "DoctorProfile",
  "Membership",
  "ClinicLocation",
  "ClinicSettings",
  "Organization",
  "RefreshToken",
  "Session",
  "IdentityAccount",
  "User",
];

export async function truncateAll(): Promise<void> {
  const list = TABLES.map((t) => `"${t}"`).join(", ");
  await db.$executeRawUnsafe(`TRUNCATE TABLE ${list} RESTART IDENTITY CASCADE`);
}

export async function disconnect(): Promise<void> {
  await db.$disconnect();
}
