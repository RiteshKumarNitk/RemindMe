import { json, publicCache, withApi } from "@/lib/http.js";
import { getPublicFilters } from "@/modules/public/service.js";

/** Cities + specialties that exist in public discovery (filter chips). */
export const GET = withApi({ auth: "none" }, async () => {
  return json(await getPublicFilters(), { headers: publicCache(300, 3600) });
});
