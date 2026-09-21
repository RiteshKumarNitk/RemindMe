import { json, withApi } from "@/lib/http.js";
import { parseQuery, z } from "@/lib/validation.js";
import { getBoard } from "@/modules/queue/service.js";

const querySchema = z
  .object({
    doctorId: z.string().uuid(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  })
  .strict();

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, querySchema);
  return json(await getBoard(ctx, q));
});
