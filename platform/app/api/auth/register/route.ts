import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { registerSchema } from "@/modules/auth/schema.js";
import { registerUser } from "@/modules/auth/service.js";

export const POST = withApi({ auth: "none", rateClass: "auth" }, async ({ req }) => {
  const input = await parseBody(req, registerSchema);
  const { userId } = await registerUser(input);
  return json({ userId }, { status: 201 });
});
