import { env } from "@/lib/env.js";
import { AppError } from "@/lib/errors.js";
import { json, withApi } from "@/lib/http.js";
import { timingSafeEqualStr } from "@/lib/crypto.js";
import { runDispatch } from "@/lib/notifications/dispatch.js";

export const dynamic = "force-dynamic";

/**
 * Cron-invoked notification dispatcher. NOT user-authenticated: a shared
 * secret in `X-Cron-Key` (constant-time compare). A miss → 404 (don't
 * advertise the route). No tenant scope, no PHI in or out.
 */
export const POST = withApi({ auth: "none", rateClass: "default" }, async ({ req }) => {
  const key = req.headers.get("x-cron-key") ?? "";
  if (
    env.NOTIFICATIONS_CRON_SECRET.length === 0 ||
    !timingSafeEqualStr(key, env.NOTIFICATIONS_CRON_SECRET)
  ) {
    throw new AppError("NOT_FOUND", "Not found.");
  }
  const result = await runDispatch();
  return json(result);
});
