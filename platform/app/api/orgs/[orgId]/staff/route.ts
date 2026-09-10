import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createStaffSchema } from "@/modules/doctors/schema.js";
import { createStaff, listStaff } from "@/modules/staff/service.js";

export const GET = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ ctx }) => json({ data: await listStaff(ctx) }),
);

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, createStaffSchema);
    return json(await createStaff(ctx, input), { status: 201 });
  },
);
