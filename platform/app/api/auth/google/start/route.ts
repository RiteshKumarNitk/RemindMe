import { withApi } from "@/lib/http.js";
import { buildAuthUrl } from "@/lib/auth/oauth-google.js";

export const GET = withApi({ auth: "none", rateClass: "auth" }, async () => {
  const { url, stateCookie } = await buildAuthUrl();
  return new Response(null, {
    status: 302,
    headers: { Location: url, "Set-Cookie": stateCookie },
  });
});
