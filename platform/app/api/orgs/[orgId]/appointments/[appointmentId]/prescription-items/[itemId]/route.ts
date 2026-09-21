import { json, withApi } from "@/lib/http.js";
import { removePrescriptionItem } from "@/modules/prescriptions/service.js";

export const DELETE = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await removePrescriptionItem(ctx, params.appointmentId!, params.itemId!));
});
