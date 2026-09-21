import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listAuditQuerySchema } from "@/modules/audit/schema.js";
import { listAuditLog } from "@/modules/audit/service.js";

export const GET = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const q = parseQuery(req.url, listAuditQuerySchema);
    return json(await listAuditLog(ctx, q));
  },
);
