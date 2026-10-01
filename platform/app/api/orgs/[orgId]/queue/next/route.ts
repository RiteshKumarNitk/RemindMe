import { json, withApi } from "@/lib/http.js";
import { parseQuery, z } from "@/lib/validation.js";
import { callNext, peekNext } from "@/modules/queue/service.js";

const querySchema = z
  .object({
    doctorId: z.string().uuid(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  })
  .strict();

/**
 * The explicit "next" endpoint: pick the next eligible WAITING patient and CALL
 * them. The frontend must never compute "next" itself — two receptionists with a
 * stale board would disagree. This is server-authoritative and blocks while
 * someone is already CALLED/IN_CONSULTATION (409).
 */
export const POST = withApi(
  { auth: "required", roles: ["RECEPTIONIST", "CLINIC_ADMIN", "DOCTOR"] },
  async ({ req, ctx }) => {
    const q = parseQuery(req.url, querySchema);
    return json(await callNext(ctx, q));
  },
);

/** Preview the next WAITING entry without calling it. Used by the NOW/NEXT rail. */
export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, querySchema);
  return json(await peekNext(ctx, q));
});