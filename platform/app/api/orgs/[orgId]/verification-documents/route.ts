import { json, withApi } from "@/lib/http.js";
import { AppError } from "@/lib/errors.js";
import {
  listMyVerificationDocuments,
  uploadVerificationDocument,
} from "@/modules/verification-documents/service.js";

export const dynamic = "force-dynamic";

/**
 * Multipart upload + metadata list for the clinic's own verification
 * documents (CLINIC_ADMIN only — `withApi` resolves :orgId against ACTIVE
 * memberships, and the service re-asserts the role).
 */
export const POST = withApi({ auth: "required", rateClass: "default" }, async ({ req, ctx }) => {
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.includes("multipart/form-data")) {
    throw new AppError("VALIDATION_FAILED", "Send the file as multipart/form-data.");
  }
  const form = await req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    throw new AppError("VALIDATION_FAILED", "Attach a file under the `file` field.");
  }
  return json(await uploadVerificationDocument(ctx, file), { status: 201 });
});

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json({ data: await listMyVerificationDocuments(ctx) });
});
