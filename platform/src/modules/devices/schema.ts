import { z } from "zod";

export const registerDeviceSchema = z
  .object({
    token: z.string().min(20).max(4096),
    platform: z.enum(["android", "ios"]),
  })
  .strict();

export const unregisterDeviceSchema = z
  .object({ token: z.string().min(20).max(4096) })
  .strict();
