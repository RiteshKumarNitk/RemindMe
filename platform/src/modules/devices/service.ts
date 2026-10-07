import type { z } from "zod";
import { db } from "@/lib/db.js";
import type { RequestContext } from "@/lib/context.js";
import type { registerDeviceSchema, unregisterDeviceSchema } from "./schema.js";

/**
 * Register this phone for push. A token is unique per install; if it was
 * registered to another account (shared phone, new sign-in) it moves to the
 * caller rather than notifying both.
 */
export async function registerDevice(
  ctx: RequestContext,
  input: z.infer<typeof registerDeviceSchema>,
) {
  await db.deviceToken.upsert({
    where: { token: input.token },
    create: { userId: ctx.userId, token: input.token, platform: input.platform },
    update: { userId: ctx.userId, platform: input.platform, lastSeenAt: new Date() },
  });
  return { ok: true };
}

/** Stop pushing to this phone (logout). Only the caller's own token. */
export async function unregisterDevice(
  ctx: RequestContext,
  input: z.infer<typeof unregisterDeviceSchema>,
) {
  await db.deviceToken.deleteMany({ where: { token: input.token, userId: ctx.userId } });
  return { ok: true };
}
