import { json, publicCache, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { publicSlotsQuerySchema } from "@/modules/patient-booking/schema.js";
import { getPublicDoctorSlots } from "@/modules/patient-booking/service.js";

export const GET = withApi<{ doctorId: string }>({ auth: "none" }, async ({ req, params }) => {
  const q = parseQuery(req.url, publicSlotsQuerySchema);
  return json(await getPublicDoctorSlots(params.doctorId, q), { headers: publicCache(15, 30) });
});
