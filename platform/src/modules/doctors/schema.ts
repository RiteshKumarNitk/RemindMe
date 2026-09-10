import { z } from "zod";

export const createDoctorSchema = z
  .object({
    // Either link an existing member by userId, or create by email+name.
    userId: z.string().uuid().optional(),
    email: z.string().email().max(320).optional(),
    fullName: z.string().min(1).max(200).optional(),
    displayName: z.string().min(1).max(200),
    specialty: z.string().max(160).optional(),
    registrationNumber: z.string().max(80).optional(),
    bio: z.string().max(2000).optional(),
    consultationDurationMin: z.number().int().min(5).max(240).default(15),
    isAcceptingNewPatients: z.boolean().default(true),
  })
  .strict()
  .refine((v) => v.userId || (v.email && v.fullName), {
    message: "Provide userId, or email + fullName.",
  });

export const updateDoctorSchema = z
  .object({
    displayName: z.string().min(1).max(200).optional(),
    specialty: z.string().max(160).nullable().optional(),
    registrationNumber: z.string().max(80).nullable().optional(),
    bio: z.string().max(2000).nullable().optional(),
    consultationDurationMin: z.number().int().min(5).max(240).optional(),
    isAcceptingNewPatients: z.boolean().optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

export const createStaffSchema = z
  .object({
    userId: z.string().uuid().optional(),
    email: z.string().email().max(320).optional(),
    fullName: z.string().min(1).max(200).optional(),
    jobTitle: z.string().max(120).optional(),
  })
  .strict()
  .refine((v) => v.userId || (v.email && v.fullName), {
    message: "Provide userId, or email + fullName.",
  });
