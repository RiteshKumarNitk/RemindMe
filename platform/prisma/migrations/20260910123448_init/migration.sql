-- CreateEnum
CREATE TYPE "Role" AS ENUM ('PATIENT', 'DOCTOR', 'RECEPTIONIST', 'CLINIC_ADMIN', 'SUPER_ADMIN');

-- CreateEnum
CREATE TYPE "MembershipStatus" AS ENUM ('ACTIVE', 'INVITED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "MembershipCapability" AS ENUM ('CLINICAL_RECORD_READ', 'CLINICAL_RECORD_WRITE', 'BILLING_MANAGE', 'DATA_EXPORT');

-- CreateEnum
CREATE TYPE "AppointmentStatus" AS ENUM ('REQUESTED', 'CONFIRMED', 'CHECKED_IN', 'WAITING', 'IN_CONSULTATION', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'RESCHEDULED');

-- CreateEnum
CREATE TYPE "BookingSource" AS ENUM ('PATIENT_APP', 'RECEPTION', 'DOCTOR', 'ADMIN', 'IMPORT');

-- CreateEnum
CREATE TYPE "QueueState" AS ENUM ('WAITING', 'CALLED', 'IN_CONSULTATION', 'COMPLETED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "AvailabilityExceptionKind" AS ENUM ('DAY_OFF', 'HOLIDAY', 'LEAVE', 'EXTRA_HOURS', 'BREAK');

-- CreateEnum
CREATE TYPE "DoseStatus" AS ENUM ('PENDING', 'TAKEN', 'SKIPPED', 'MISSED');

-- CreateEnum
CREATE TYPE "MedicationFrequency" AS ENUM ('DAILY', 'SPECIFIC_DAYS', 'ONCE', 'MULTIPLE');

-- CreateEnum
CREATE TYPE "FoodInstruction" AS ENUM ('NONE', 'BEFORE', 'AFTER', 'WITH_FOOD');

-- CreateEnum
CREATE TYPE "DocumentKind" AS ENUM ('PRESCRIPTION', 'LAB_REPORT', 'DISCHARGE_SUMMARY', 'IMAGING', 'INSURANCE', 'OTHER');

-- CreateEnum
CREATE TYPE "FamilyRelation" AS ENUM ('SELF', 'SPOUSE', 'FATHER', 'MOTHER', 'CHILD', 'GUARDIAN', 'OTHER');

-- CreateEnum
CREATE TYPE "AccessPermission" AS ENUM ('VIEW_PROFILE', 'VIEW_APPOINTMENTS', 'MANAGE_APPOINTMENTS', 'VIEW_MEDICATIONS', 'MANAGE_MEDICATIONS', 'VIEW_DOCUMENTS');

-- CreateEnum
CREATE TYPE "InvitationScope" AS ENUM ('CLINIC_STAFF', 'CLINIC_PATIENT', 'FAMILY_ACCESS');

-- CreateEnum
CREATE TYPE "VitalType" AS ENUM ('BLOOD_PRESSURE', 'BLOOD_SUGAR', 'WEIGHT', 'TEMPERATURE', 'HEART_RATE');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('PUSH', 'EMAIL', 'SMS', 'WHATSAPP', 'IN_APP');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'SENDING', 'SENT', 'FAILED', 'SUPPRESSED');

-- CreateTable
CREATE TABLE "Organization" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Organization_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClinicSettings" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "allowPatientSelfBooking" BOOLEAN NOT NULL DEFAULT true,
    "bookingLeadTimeMinutes" INTEGER NOT NULL DEFAULT 120,
    "cancellationWindowHours" INTEGER NOT NULL DEFAULT 4,
    "maxAdvanceBookingDays" INTEGER NOT NULL DEFAULT 60,
    "defaultAppointmentDurationMin" INTEGER NOT NULL DEFAULT 15,
    "localeDefault" TEXT NOT NULL DEFAULT 'en',
    "supportedLocales" TEXT[] DEFAULT ARRAY['en', 'hi']::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ClinicSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClinicLocation" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "addressLine1" TEXT,
    "addressLine2" TEXT,
    "city" TEXT,
    "state" TEXT,
    "postalCode" TEXT,
    "country" TEXT,
    "phone" TEXT,
    "timezone" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ClinicLocation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "fullName" TEXT NOT NULL,
    "phone" TEXT,
    "avatarUrl" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "isPlatformAdmin" BOOLEAN NOT NULL DEFAULT false,
    "emailVerifiedAt" TIMESTAMP(3),
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IdentityAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "providerAccountId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IdentityAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "hashedSessionToken" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip" TEXT,
    "userAgent" TEXT,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "hashedToken" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "replacedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip" TEXT,
    "userAgent" TEXT,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Membership" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "status" "MembershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "capabilities" "MembershipCapability"[] DEFAULT ARRAY[]::"MembershipCapability"[],
    "invitedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Membership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DoctorProfile" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "membershipId" TEXT,
    "displayName" TEXT NOT NULL,
    "specialty" TEXT,
    "registrationNumber" TEXT,
    "bio" TEXT,
    "consultationDurationMin" INTEGER NOT NULL DEFAULT 15,
    "isAcceptingNewPatients" BOOLEAN NOT NULL DEFAULT true,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DoctorProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StaffProfile" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "membershipId" TEXT,
    "jobTitle" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StaffProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Patient" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "ownerUserId" TEXT,
    "mrn" TEXT,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "dateOfBirth" DATE,
    "sex" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "addressLine1" TEXT,
    "city" TEXT,
    "state" TEXT,
    "postalCode" TEXT,
    "country" TEXT,
    "bloodGroup" TEXT,
    "allergies" TEXT,
    "notes" TEXT,
    "externalRef" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdById" TEXT NOT NULL,
    "updatedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Patient_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FamilyRelationship" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "guardianUserId" TEXT NOT NULL,
    "dependentPatientId" TEXT NOT NULL,
    "relation" "FamilyRelation" NOT NULL,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FamilyRelationship_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PatientAccessGrant" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "granteeUserId" TEXT NOT NULL,
    "permissions" "AccessPermission"[],
    "grantedById" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PatientAccessGrant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Invitation" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT,
    "scope" "InvitationScope" NOT NULL,
    "hashedToken" TEXT NOT NULL,
    "email" TEXT,
    "role" "Role",
    "patientId" TEXT,
    "permissions" "AccessPermission"[],
    "createdById" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "usedById" TEXT,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Invitation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppointmentType" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "colorHex" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "AppointmentType_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AvailabilityRule" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "locationId" TEXT,
    "weekday" INTEGER NOT NULL,
    "startMinute" INTEGER NOT NULL,
    "endMinute" INTEGER NOT NULL,
    "slotMinutes" INTEGER NOT NULL,
    "effectiveFrom" DATE,
    "effectiveTo" DATE,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AvailabilityRule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AvailabilityException" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "locationId" TEXT,
    "kind" "AvailabilityExceptionKind" NOT NULL,
    "startsAt" TIMESTAMPTZ(6) NOT NULL,
    "endsAt" TIMESTAMPTZ(6) NOT NULL,
    "reason" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AvailabilityException_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Appointment" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "locationId" TEXT,
    "appointmentTypeId" TEXT,
    "scheduledStart" TIMESTAMPTZ(6) NOT NULL,
    "scheduledEnd" TIMESTAMPTZ(6) NOT NULL,
    "timezone" TEXT NOT NULL,
    "status" "AppointmentStatus" NOT NULL DEFAULT 'REQUESTED',
    "reason" TEXT,
    "notes" TEXT,
    "bookingSource" "BookingSource" NOT NULL,
    "createdById" TEXT NOT NULL,
    "updatedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "confirmedAt" TIMESTAMP(3),
    "checkedInAt" TIMESTAMP(3),
    "consultationStartedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "cancelledById" TEXT,
    "cancellationReason" TEXT,
    "noShowMarkedAt" TIMESTAMP(3),
    "rescheduledFromId" TEXT,

    CONSTRAINT "Appointment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppointmentEvent" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "appointmentId" TEXT NOT NULL,
    "fromStatus" "AppointmentStatus",
    "toStatus" "AppointmentStatus" NOT NULL,
    "actorId" TEXT,
    "reason" TEXT,
    "metadata" JSONB,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AppointmentEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QueueEntry" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "appointmentId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "locationId" TEXT,
    "queueDate" DATE NOT NULL,
    "tokenNumber" INTEGER NOT NULL,
    "state" "QueueState" NOT NULL DEFAULT 'WAITING',
    "position" INTEGER NOT NULL,
    "recallCount" INTEGER NOT NULL DEFAULT 0,
    "checkedInAt" TIMESTAMP(3),
    "calledAt" TIMESTAMP(3),
    "consultationStartedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "skippedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QueueEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Consultation" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "appointmentId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "subjective" TEXT,
    "objective" TEXT,
    "assessment" TEXT,
    "plan" TEXT,
    "followUpDate" DATE,
    "testsAdvised" TEXT,
    "instructions" TEXT,
    "signedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Consultation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Prescription" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "consultationId" TEXT,
    "patientId" TEXT NOT NULL,
    "doctorId" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "notes" TEXT,

    CONSTRAINT "Prescription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrescriptionItem" (
    "id" TEXT NOT NULL,
    "prescriptionId" TEXT NOT NULL,
    "drugName" TEXT NOT NULL,
    "strength" TEXT,
    "form" TEXT,
    "dosage" TEXT,
    "frequency" TEXT,
    "durationDays" INTEGER,
    "foodInstruction" "FoodInstruction" NOT NULL DEFAULT 'NONE',
    "instructions" TEXT,

    CONSTRAINT "PrescriptionItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MedicalDocument" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "kind" "DocumentKind" NOT NULL,
    "title" TEXT,
    "storageProvider" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "checksum" TEXT,
    "consultationId" TEXT,
    "uploadedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MedicalDocument_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Medication" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "ownerUserId" TEXT,
    "name" TEXT NOT NULL,
    "dosage" TEXT NOT NULL DEFAULT '',
    "dosageUnit" TEXT NOT NULL DEFAULT '',
    "notes" TEXT NOT NULL DEFAULT '',
    "foodInstruction" "FoodInstruction" NOT NULL DEFAULT 'NONE',
    "frequency" "MedicationFrequency" NOT NULL DEFAULT 'DAILY',
    "selectedDays" INTEGER[],
    "onceDate" DATE,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "stockCount" INTEGER,
    "refillAt" INTEGER,
    "source" TEXT,
    "legacyLocalId" INTEGER,
    "sourceDeviceId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Medication_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MedicationSchedule" (
    "id" TEXT NOT NULL,
    "medicationId" TEXT NOT NULL,
    "hour" INTEGER NOT NULL,
    "minute" INTEGER NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "MedicationSchedule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MedicationDose" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "medicationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "scheduledAtLocal" TIMESTAMP(3) NOT NULL,
    "timezone" TEXT NOT NULL,
    "status" "DoseStatus" NOT NULL DEFAULT 'PENDING',
    "takenAt" TIMESTAMPTZ(6),
    "skippedAt" TIMESTAMPTZ(6),
    "snoozedUntil" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "MedicationDose_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VitalReading" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "patientId" TEXT NOT NULL,
    "type" "VitalType" NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "value2" DOUBLE PRECISION,
    "recordedAt" TIMESTAMPTZ(6) NOT NULL,
    "notes" TEXT,
    "source" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VitalReading_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT,
    "userId" TEXT,
    "channel" "NotificationChannel" NOT NULL,
    "event" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "scheduledFor" TIMESTAMP(3),
    "dedupeKey" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 5,
    "claimedAt" TIMESTAMP(3),
    "nextAttemptAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT,
    "actorUserId" TEXT,
    "actorRole" "Role",
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "userAgent" TEXT,
    "requestId" TEXT,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Organization_slug_key" ON "Organization"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "ClinicSettings_organizationId_key" ON "ClinicSettings"("organizationId");

-- CreateIndex
CREATE INDEX "ClinicLocation_organizationId_idx" ON "ClinicLocation"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "IdentityAccount_userId_idx" ON "IdentityAccount"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "IdentityAccount_provider_providerAccountId_key" ON "IdentityAccount"("provider", "providerAccountId");

-- CreateIndex
CREATE UNIQUE INDEX "Session_hashedSessionToken_key" ON "Session"("hashedSessionToken");

-- CreateIndex
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_hashedToken_key" ON "RefreshToken"("hashedToken");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- CreateIndex
CREATE INDEX "RefreshToken_familyId_idx" ON "RefreshToken"("familyId");

-- CreateIndex
CREATE INDEX "Membership_organizationId_role_idx" ON "Membership"("organizationId", "role");

-- CreateIndex
CREATE UNIQUE INDEX "Membership_userId_organizationId_role_key" ON "Membership"("userId", "organizationId", "role");

-- CreateIndex
CREATE UNIQUE INDEX "DoctorProfile_membershipId_key" ON "DoctorProfile"("membershipId");

-- CreateIndex
CREATE INDEX "DoctorProfile_organizationId_idx" ON "DoctorProfile"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "DoctorProfile_organizationId_userId_key" ON "DoctorProfile"("organizationId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "StaffProfile_membershipId_key" ON "StaffProfile"("membershipId");

-- CreateIndex
CREATE INDEX "StaffProfile_organizationId_idx" ON "StaffProfile"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "StaffProfile_organizationId_userId_key" ON "StaffProfile"("organizationId", "userId");

-- CreateIndex
CREATE INDEX "Patient_organizationId_lastName_idx" ON "Patient"("organizationId", "lastName");

-- CreateIndex
CREATE INDEX "Patient_organizationId_ownerUserId_idx" ON "Patient"("organizationId", "ownerUserId");

-- CreateIndex
CREATE UNIQUE INDEX "Patient_organizationId_mrn_key" ON "Patient"("organizationId", "mrn");

-- CreateIndex
CREATE INDEX "FamilyRelationship_organizationId_idx" ON "FamilyRelationship"("organizationId");

-- CreateIndex
CREATE INDEX "FamilyRelationship_dependentPatientId_idx" ON "FamilyRelationship"("dependentPatientId");

-- CreateIndex
CREATE UNIQUE INDEX "FamilyRelationship_guardianUserId_dependentPatientId_key" ON "FamilyRelationship"("guardianUserId", "dependentPatientId");

-- CreateIndex
CREATE INDEX "PatientAccessGrant_organizationId_idx" ON "PatientAccessGrant"("organizationId");

-- CreateIndex
CREATE INDEX "PatientAccessGrant_granteeUserId_idx" ON "PatientAccessGrant"("granteeUserId");

-- CreateIndex
CREATE UNIQUE INDEX "PatientAccessGrant_patientId_granteeUserId_key" ON "PatientAccessGrant"("patientId", "granteeUserId");

-- CreateIndex
CREATE UNIQUE INDEX "Invitation_hashedToken_key" ON "Invitation"("hashedToken");

-- CreateIndex
CREATE INDEX "Invitation_organizationId_scope_idx" ON "Invitation"("organizationId", "scope");

-- CreateIndex
CREATE INDEX "Invitation_expiresAt_idx" ON "Invitation"("expiresAt");

-- CreateIndex
CREATE INDEX "AppointmentType_organizationId_idx" ON "AppointmentType"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "AppointmentType_organizationId_name_key" ON "AppointmentType"("organizationId", "name");

-- CreateIndex
CREATE INDEX "AvailabilityRule_organizationId_doctorId_weekday_idx" ON "AvailabilityRule"("organizationId", "doctorId", "weekday");

-- CreateIndex
CREATE INDEX "AvailabilityException_organizationId_doctorId_startsAt_idx" ON "AvailabilityException"("organizationId", "doctorId", "startsAt");

-- CreateIndex
CREATE UNIQUE INDEX "Appointment_rescheduledFromId_key" ON "Appointment"("rescheduledFromId");

-- CreateIndex
CREATE INDEX "Appointment_organizationId_doctorId_scheduledStart_idx" ON "Appointment"("organizationId", "doctorId", "scheduledStart");

-- CreateIndex
CREATE INDEX "Appointment_organizationId_patientId_scheduledStart_idx" ON "Appointment"("organizationId", "patientId", "scheduledStart");

-- CreateIndex
CREATE INDEX "Appointment_organizationId_status_idx" ON "Appointment"("organizationId", "status");

-- CreateIndex
CREATE INDEX "AppointmentEvent_appointmentId_idx" ON "AppointmentEvent"("appointmentId");

-- CreateIndex
CREATE INDEX "AppointmentEvent_organizationId_at_idx" ON "AppointmentEvent"("organizationId", "at");

-- CreateIndex
CREATE UNIQUE INDEX "QueueEntry_appointmentId_key" ON "QueueEntry"("appointmentId");

-- CreateIndex
CREATE INDEX "QueueEntry_organizationId_doctorId_queueDate_state_position_idx" ON "QueueEntry"("organizationId", "doctorId", "queueDate", "state", "position");

-- CreateIndex
CREATE UNIQUE INDEX "QueueEntry_organizationId_doctorId_queueDate_tokenNumber_key" ON "QueueEntry"("organizationId", "doctorId", "queueDate", "tokenNumber");

-- CreateIndex
CREATE UNIQUE INDEX "Consultation_appointmentId_key" ON "Consultation"("appointmentId");

-- CreateIndex
CREATE INDEX "Consultation_organizationId_patientId_idx" ON "Consultation"("organizationId", "patientId");

-- CreateIndex
CREATE INDEX "Prescription_organizationId_patientId_idx" ON "Prescription"("organizationId", "patientId");

-- CreateIndex
CREATE INDEX "PrescriptionItem_prescriptionId_idx" ON "PrescriptionItem"("prescriptionId");

-- CreateIndex
CREATE INDEX "MedicalDocument_organizationId_patientId_kind_idx" ON "MedicalDocument"("organizationId", "patientId", "kind");

-- CreateIndex
CREATE INDEX "Medication_organizationId_patientId_idx" ON "Medication"("organizationId", "patientId");

-- CreateIndex
CREATE INDEX "Medication_patientId_isActive_idx" ON "Medication"("patientId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "Medication_sourceDeviceId_legacyLocalId_key" ON "Medication"("sourceDeviceId", "legacyLocalId");

-- CreateIndex
CREATE INDEX "MedicationSchedule_medicationId_idx" ON "MedicationSchedule"("medicationId");

-- CreateIndex
CREATE INDEX "MedicationDose_patientId_scheduledAtLocal_idx" ON "MedicationDose"("patientId", "scheduledAtLocal");

-- CreateIndex
CREATE INDEX "MedicationDose_medicationId_status_idx" ON "MedicationDose"("medicationId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "MedicationDose_medicationId_scheduledAtLocal_key" ON "MedicationDose"("medicationId", "scheduledAtLocal");

-- CreateIndex
CREATE INDEX "VitalReading_organizationId_patientId_type_recordedAt_idx" ON "VitalReading"("organizationId", "patientId", "type", "recordedAt");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_dedupeKey_key" ON "Notification"("dedupeKey");

-- CreateIndex
CREATE INDEX "Notification_status_scheduledFor_idx" ON "Notification"("status", "scheduledFor");

-- CreateIndex
CREATE INDEX "Notification_status_nextAttemptAt_idx" ON "Notification"("status", "nextAttemptAt");

-- CreateIndex
CREATE INDEX "Notification_userId_idx" ON "Notification"("userId");

-- CreateIndex
CREATE INDEX "AuditLog_organizationId_entityType_entityId_idx" ON "AuditLog"("organizationId", "entityType", "entityId");

-- CreateIndex
CREATE INDEX "AuditLog_organizationId_at_idx" ON "AuditLog"("organizationId", "at");

-- CreateIndex
CREATE INDEX "AuditLog_actorUserId_idx" ON "AuditLog"("actorUserId");

-- AddForeignKey
ALTER TABLE "ClinicSettings" ADD CONSTRAINT "ClinicSettings_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClinicLocation" ADD CONSTRAINT "ClinicLocation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "IdentityAccount" ADD CONSTRAINT "IdentityAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Membership" ADD CONSTRAINT "Membership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Membership" ADD CONSTRAINT "Membership_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DoctorProfile" ADD CONSTRAINT "DoctorProfile_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DoctorProfile" ADD CONSTRAINT "DoctorProfile_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffProfile" ADD CONSTRAINT "StaffProfile_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffProfile" ADD CONSTRAINT "StaffProfile_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Patient" ADD CONSTRAINT "Patient_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRelationship" ADD CONSTRAINT "FamilyRelationship_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRelationship" ADD CONSTRAINT "FamilyRelationship_guardianUserId_fkey" FOREIGN KEY ("guardianUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FamilyRelationship" ADD CONSTRAINT "FamilyRelationship_dependentPatientId_fkey" FOREIGN KEY ("dependentPatientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PatientAccessGrant" ADD CONSTRAINT "PatientAccessGrant_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PatientAccessGrant" ADD CONSTRAINT "PatientAccessGrant_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PatientAccessGrant" ADD CONSTRAINT "PatientAccessGrant_granteeUserId_fkey" FOREIGN KEY ("granteeUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppointmentType" ADD CONSTRAINT "AppointmentType_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityRule" ADD CONSTRAINT "AvailabilityRule_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityRule" ADD CONSTRAINT "AvailabilityRule_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityRule" ADD CONSTRAINT "AvailabilityRule_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "ClinicLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityException" ADD CONSTRAINT "AvailabilityException_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityException" ADD CONSTRAINT "AvailabilityException_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AvailabilityException" ADD CONSTRAINT "AvailabilityException_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "ClinicLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "ClinicLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_appointmentTypeId_fkey" FOREIGN KEY ("appointmentTypeId") REFERENCES "AppointmentType"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_rescheduledFromId_fkey" FOREIGN KEY ("rescheduledFromId") REFERENCES "Appointment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppointmentEvent" ADD CONSTRAINT "AppointmentEvent_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AppointmentEvent" ADD CONSTRAINT "AppointmentEvent_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "Appointment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QueueEntry" ADD CONSTRAINT "QueueEntry_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QueueEntry" ADD CONSTRAINT "QueueEntry_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "Appointment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QueueEntry" ADD CONSTRAINT "QueueEntry_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QueueEntry" ADD CONSTRAINT "QueueEntry_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QueueEntry" ADD CONSTRAINT "QueueEntry_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "ClinicLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_appointmentId_fkey" FOREIGN KEY ("appointmentId") REFERENCES "Appointment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Consultation" ADD CONSTRAINT "Consultation_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_consultationId_fkey" FOREIGN KEY ("consultationId") REFERENCES "Consultation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Prescription" ADD CONSTRAINT "Prescription_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "DoctorProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrescriptionItem" ADD CONSTRAINT "PrescriptionItem_prescriptionId_fkey" FOREIGN KEY ("prescriptionId") REFERENCES "Prescription"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicalDocument" ADD CONSTRAINT "MedicalDocument_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicalDocument" ADD CONSTRAINT "MedicalDocument_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Medication" ADD CONSTRAINT "Medication_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Medication" ADD CONSTRAINT "Medication_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicationSchedule" ADD CONSTRAINT "MedicationSchedule_medicationId_fkey" FOREIGN KEY ("medicationId") REFERENCES "Medication"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicationDose" ADD CONSTRAINT "MedicationDose_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicationDose" ADD CONSTRAINT "MedicationDose_medicationId_fkey" FOREIGN KEY ("medicationId") REFERENCES "Medication"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MedicationDose" ADD CONSTRAINT "MedicationDose_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VitalReading" ADD CONSTRAINT "VitalReading_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VitalReading" ADD CONSTRAINT "VitalReading_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- =============================================================================
-- Double-booking protection (spec §11) — see prisma/sql/0001_appointment_no_overlap.sql
-- Scoped by (organizationId, doctorId, time range): the same doctor may hold
-- overlapping appointments in DIFFERENT clinics, never within one clinic.
-- Prisma cannot express EXCLUDE constraints, so this is added here by hand.
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
