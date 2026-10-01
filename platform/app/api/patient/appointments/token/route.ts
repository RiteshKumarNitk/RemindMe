import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { bookTokenSchema } from "@/modules/tokens/schema.js";
import { bookSameDayToken } from "@/modules/tokens/service.js";

/**
 * Take a same-day queue token for yourself (or a dependent you manage).
 *
 * Authenticated but deliberately NOT under `/api/orgs/:orgId/...`, for the same
 * reason as `POST /api/patient/appointments`: a first-time patient has no
 * membership yet, so the tenant-resolution pipeline can't apply. `organizationId`
 * is trusted only as far as "self-enrol this caller as a PATIENT of this clinic"
 * (DECISIONS.md) — never to reach an existing membership or record on their
 * behalf.
 *
 * Returns 201 with the token. If the caller already holds an active token for
 * this doctor today, the SAME token comes back with `reused: true` and a 200 —
 * double-submitting is not an error, it just never mints a second ticket.
 */
export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, bookTokenSchema);
  const result = await bookSameDayToken(ctx, input);
  return json(result, { status: result.reused ? 200 : 201 });
});