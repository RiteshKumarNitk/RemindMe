import { z } from "zod";

export const registerSchema = z
  .object({
    email: z.string().email().max(320),
    password: z.string().min(10).max(200),
    fullName: z.string().min(1).max(200),
  })
  .strict();
export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z
  .object({
    email: z.string().email().max(320),
    password: z.string().min(1).max(200),
  })
  .strict();
export type LoginInput = z.infer<typeof loginSchema>;

export const refreshSchema = z
  .object({ refreshToken: z.string().min(1) })
  .strict();

export const logoutSchema = z
  .object({ refreshToken: z.string().min(1).optional() })
  .strict();
