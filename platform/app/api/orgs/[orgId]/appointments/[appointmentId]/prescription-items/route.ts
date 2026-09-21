import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { addItemSchema } from "@/modules/prescriptions/schema.js";
import { addPrescriptionItem } from "@/modules/prescriptions/service.js";

export const POST = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, addItemSchema);
  return json(await addPrescriptionItem(ctx, params.appointmentId!, input), { status: 201 });
});
