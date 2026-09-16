import { json, withApi } from "@/lib/http.js";
import { getPublicDoctor } from "@/modules/public/service.js";

export const GET = withApi<{ doctorId: string }>({ auth: "none" }, async ({ params }) => {
  return json(await getPublicDoctor(params.doctorId));
});
