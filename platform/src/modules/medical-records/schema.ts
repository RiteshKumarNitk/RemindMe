import { z } from "zod";
import { paginationSchema } from "@/lib/validation.js";

export const listConsultationsQuerySchema = paginationSchema.extend({
  patientId: z.string().uuid().optional(),
  doctorId: z.string().uuid().optional(),
});

export const listPrescriptionsQuerySchema = paginationSchema.extend({
  patientId: z.string().uuid().optional(),
  doctorId: z.string().uuid().optional(),
});
