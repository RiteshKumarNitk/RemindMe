import { json, publicCache, withApi } from "@/lib/http.js";
import { getPublicOrganization } from "@/modules/public/service.js";

export const GET = withApi<{ slug: string }>({ auth: "none" }, async ({ params }) => {
  return json(await getPublicOrganization(params.slug), { headers: publicCache(60, 600) });
});
