import { json, withApi } from "@/lib/http.js";
import { parseQuery, z } from "@/lib/validation.js";
import { getPatientTokenStatus } from "@/modules/tokens/service.js";

const querySchema = z
  .object({
    appointmentId: z.string().uuid(),
  })
  .strict();

/**
 * A patient's own token status: token number, live position, what's happening,
 * and the server-rendered next step to take. No ETA in minutes.
 *
 * Patient-authenticated: the service itself enforces that only the owner or a
 * guardian with VIEW_APPOINTMENTS can read it.
 */
export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, querySchema);
  return json(await getPatientTokenStatus(ctx, q.appointmentId));
});