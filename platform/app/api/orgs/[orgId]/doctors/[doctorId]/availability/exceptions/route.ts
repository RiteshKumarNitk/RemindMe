import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createExceptionSchema } from "@/modules/availability/schema.js";
import { createException, listExceptions } from "@/modules/availability/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json({ data: await listExceptions(ctx, params.doctorId!) });
});

export const POST = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, createExceptionSchema);
  return json(await createException(ctx, params.doctorId!, input), { status: 201 });
});
