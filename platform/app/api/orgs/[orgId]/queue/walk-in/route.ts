import { json, withApi } from "@/lib/http.js";
import { parseBody, parseQuery, z } from "@/lib/validation.js";
import { walkInTokenSchema } from "@/modules/tokens/schema.js";
import { walkInToken } from "@/modules/tokens/service.js";

const querySchema = z.object({ doctorId: z.string().uuid() }).strict();

/**
 * Reception issues a token to a patient standing at the desk.
 *
 * Deliberately subject to the SAME window and daily cap as patient self-service
 * — otherwise the walk-in button would be a trivial way to oversubscribe a
 * doctor's day, which is exactly the thing the cap exists to prevent.
 */
export const POST = withApi(
  { auth: "required", roles: ["RECEPTIONIST", "CLINIC_ADMIN", "DOCTOR"] },
  async ({ req, ctx, params }) => {
    const { doctorId } = parseQuery(req.url, querySchema);
    const input = await parseBody(req, walkInTokenSchema);
    const result = await walkInToken(ctx, doctorId, input);
    return json(result, { status: result.reused ? 200 : 201 });
  },
);