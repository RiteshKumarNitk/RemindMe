import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { markNotificationsReadSchema } from "@/modules/notifications/schema.js";
import { markNotificationsRead } from "@/modules/notifications/service.js";

export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, markNotificationsReadSchema);
  return json(await markNotificationsRead(ctx, input));
});
