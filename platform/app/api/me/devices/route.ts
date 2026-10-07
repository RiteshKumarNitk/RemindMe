import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { registerDeviceSchema, unregisterDeviceSchema } from "@/modules/devices/schema.js";
import { registerDevice, unregisterDevice } from "@/modules/devices/service.js";

/** Register this phone's FCM token for push notifications. */
export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, registerDeviceSchema);
  return json(await registerDevice(ctx, input));
});

/** Unregister on logout. */
export const DELETE = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, unregisterDeviceSchema);
  return json(await unregisterDevice(ctx, input));
});
