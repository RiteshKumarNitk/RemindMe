import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listPlatformAuditQuerySchema } from "@/modules/superadmin/schema.js";
import { listPlatformAuditLog } from "@/modules/superadmin/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listPlatformAuditQuerySchema);
  return json(await listPlatformAuditLog(ctx, q));
});
