import { z } from "zod";
import { organizationTypeEnum } from "@/modules/clinics/schema.js";

const pageSchema = z.coerce.number().int().min(1).max(1000).default(1);
const pageSizeSchema = z.coerce.number().int().min(1).max(50).default(20);

export const listPublicOrganizationsQuerySchema = z
  .object({
    q: z.string().trim().max(200).optional(),
    city: z.string().trim().max(120).optional(),
    orgType: organizationTypeEnum.optional(),
    page: pageSchema,
    pageSize: pageSizeSchema,
  })
  .strict();

export const listPublicDoctorsQuerySchema = z
  .object({
    q: z.string().trim().max(200).optional(),
    specialty: z.string().trim().max(160).optional(),
    organizationSlug: z.string().trim().max(160).optional(),
    page: pageSchema,
    pageSize: pageSizeSchema,
  })
  .strict();
