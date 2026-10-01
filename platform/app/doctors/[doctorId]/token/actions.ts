"use server";

import { redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { requireWebUser } from "@/lib/web-context.js";
import { bookTokenSchema } from "@/modules/tokens/schema.js";
import { bookSameDayToken } from "@/modules/tokens/service.js";

/**
 * Take today's token. No date is sent — the server decides "today" in the
 * clinic's timezone and enforces the window, cap and one-token-per-patient rule.
 */
export async function bookTokenAction(doctorId: string, formData: FormData) {
  const ctx = await requireWebUser();
  const back = `/doctors/${doctorId}/token`;

  const parsed = bookTokenSchema.safeParse({
    organizationId: String(formData.get("organizationId") ?? ""),
    doctorId,
    patientId: String(formData.get("patientId") ?? "").trim() || undefined,
    reason: String(formData.get("reason") ?? "").trim() || undefined,
    patient: {
      firstName: String(formData.get("firstName") ?? "").trim(),
      lastName: String(formData.get("lastName") ?? "").trim(),
      phone: String(formData.get("phone") ?? "").trim() || undefined,
      dateOfBirth: String(formData.get("dateOfBirth") ?? "").trim() || undefined,
    },
  });
  if (!parsed.success) {
    redirect(`${back}?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Please check the form and try again.")}`);
  }

  let target: string;
  try {
    const res = await bookSameDayToken(ctx, parsed.data);
    target = `/dashboard/${parsed.data.organizationId}/appointments/${res.appointmentId}?${res.reused ? "existingToken=1" : "justBooked=1"}`;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not book a token.";
    redirect(`${back}?error=${encodeURIComponent(message)}`);
  }
  redirect(target);
}
