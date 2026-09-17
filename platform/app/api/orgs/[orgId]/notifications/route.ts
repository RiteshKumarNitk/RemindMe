import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listNotificationsQuerySchema } from "@/modules/notifications/schema.js";
import { listMyNotifications } from "@/modules/notifications/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listNotificationsQuerySchema);
  return json(await listMyNotifications(ctx, q));
});
