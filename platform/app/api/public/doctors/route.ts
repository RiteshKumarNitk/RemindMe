import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listPublicDoctorsQuerySchema } from "@/modules/public/schema.js";
import { listPublicDoctors } from "@/modules/public/service.js";

export const GET = withApi({ auth: "none" }, async ({ req }) => {
  const q = parseQuery(req.url, listPublicDoctorsQuerySchema);
  return json(await listPublicDoctors(q));
});
