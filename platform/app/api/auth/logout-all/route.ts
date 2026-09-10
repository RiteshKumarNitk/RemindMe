import { json, withApi } from "@/lib/http.js";
import { clearSessionCookie } from "@/lib/auth/session.js";
import { logoutEverywhere } from "@/modules/auth/service.js";

export const POST = withApi({ auth: "required", rateClass: "auth" }, async ({ ctx }) => {
  await logoutEverywhere(ctx.userId);
  return json({ ok: true }, { headers: { "Set-Cookie": clearSessionCookie() } });
});
