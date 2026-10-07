import { z } from "zod";
import { httpUrlSchema } from "@/lib/validation.js";

export const organizationTypeEnum = z.enum([
  "HOSPITAL",
  "CLINIC",
  "DIAGNOSTIC_CENTER",
  "POLYCLINIC",
  "OTHER",
]);

export const updateOrgSchema = z
  .object({
    name: z.string().min(2).max(160).optional(),
    timezone: z.string().min(1).max(64).optional(),
    // Public profile fields (PRODUCT_EVOLUTION_PLAN.md §6/§15 Phase 3).
    // `null` explicitly clears a field; `undefined` (omitted) leaves it as-is.
    orgType: organizationTypeEnum.nullable().optional(),
    tagline: z.string().max(200).nullable().optional(),
    about: z.string().max(4000).nullable().optional(),
    logoUrl: httpUrlSchema(1000).nullable().optional(),
    coverImageUrl: httpUrlSchema(1000).nullable().optional(),
    publicPhone: z.string().max(40).nullable().optional(),
    publicEmail: z.string().email().max(320).nullable().optional(),
    website: httpUrlSchema(500).nullable().optional(),
  })
  .strict();

export const updateSettingsSchema = z
  .object({
    allowPatientSelfBooking: z.boolean().optional(),
    bookingLeadTimeMinutes: z.number().int().min(0).max(60 * 24 * 7).optional(),
    cancellationWindowHours: z.number().int().min(0).max(24 * 14).optional(),
    maxAdvanceBookingDays: z.number().int().min(1).max(365).optional(),
    defaultAppointmentDurationMin: z.number().int().min(5).max(240).optional(),
    localeDefault: z.enum(["en", "hi"]).optional(),
    supportedLocales: z.array(z.enum(["en", "hi"])).min(1).optional(),
  })
  .strict();

/** WGS84 coordinates for "clinics near me". */
const latitudeSchema = z.number().min(-90).max(90);
const longitudeSchema = z.number().min(-180).max(180);

export const createLocationSchema = z
  .object({
    name: z.string().min(1).max(160),
    addressLine1: z.string().max(200).optional(),
    city: z.string().max(120).optional(),
    state: z.string().max(120).optional(),
    postalCode: z.string().max(20).optional(),
    country: z.string().max(80).optional(),
    phone: z.string().max(40).optional(),
    timezone: z.string().max(64).optional(),
    latitude: latitudeSchema.optional(),
    longitude: longitudeSchema.optional(),
  })
  .strict();

// Partial update for an existing location. `null` clears a field;
// `undefined` leaves it as-is (same convention as updateOrgSchema).
export const updateLocationSchema = z
  .object({
    name: z.string().min(1).max(160).optional(),
    addressLine1: z.string().max(200).nullable().optional(),
    addressLine2: z.string().max(200).nullable().optional(),
    city: z.string().max(120).nullable().optional(),
    state: z.string().max(120).nullable().optional(),
    postalCode: z.string().max(20).nullable().optional(),
    country: z.string().max(80).nullable().optional(),
    phone: z.string().max(40).nullable().optional(),
    timezone: z.string().max(64).nullable().optional(),
    latitude: latitudeSchema.nullable().optional(),
    longitude: longitudeSchema.nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

export const roleEnum = z.enum([
  "PATIENT",
  "DOCTOR",
  "RECEPTIONIST",
  "CLINIC_ADMIN",
]);

export const inviteMemberSchema = z
  .object({
    email: z.string().email().max(320),
    fullName: z.string().min(1).max(200),
    role: roleEnum,
  })
  .strict();

export const updateMemberSchema = z
  .object({
    role: roleEnum.optional(),
    status: z.enum(["ACTIVE", "SUSPENDED"]).optional(),
  })
  .strict();

export const capabilitiesSchema = z
  .object({
    capabilities: z
      .array(
        z.enum([
          "CLINICAL_RECORD_READ",
          "CLINICAL_RECORD_WRITE",
          "BILLING_MANAGE",
          "DATA_EXPORT",
        ]),
      )
      .max(4),
  })
  .strict();
