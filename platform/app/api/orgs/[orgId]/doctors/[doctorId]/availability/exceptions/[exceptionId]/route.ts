import { json, withApi } from "@/lib/http.js";
import { deleteException } from "@/modules/availability/service.js";

export const DELETE = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await deleteException(ctx, params.doctorId!, params.exceptionId!));
});
