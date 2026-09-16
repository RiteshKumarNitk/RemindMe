import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { selfBookAppointmentSchema } from "@/modules/patient-booking/schema.js";
import { selfBookAppointment } from "@/modules/patient-booking/service.js";

/**
 * Authenticated, but deliberately NOT under `/api/orgs/:orgId/...` — a
 * first-time patient has no membership yet, so the standard tenant-
 * resolution pipeline (which 404s before the handler runs) can't apply
 * here. `organizationId` is trusted only to the extent of "self-enroll the
 * caller as a PATIENT of this org" (see patient-booking/service.ts and
 * DECISIONS.md) — never to select an existing membership on their behalf.
 */
export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, selfBookAppointmentSchema);
  return json(await selfBookAppointment(ctx, input), { status: 201 });
});
