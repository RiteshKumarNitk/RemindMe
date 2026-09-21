"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { rescheduleSchema } from "@/modules/appointments/schema.js";
import { rescheduleAppointment } from "@/modules/appointments/service.js";

export async function rescheduleAppointmentAction(orgId: string, appointmentId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = rescheduleSchema.safeParse({
    scheduledStart: String(formData.get("scheduledStart") ?? ""),
    reason: String(formData.get("reason") ?? "") || undefined,
  });
  if (!parsed.success) {
    redirect(
      `/dashboard/${orgId}/appointments/${appointmentId}/reschedule?error=${encodeURIComponent(
        parsed.error.issues[0]?.message ?? "Pick a new time.",
      )}`,
    );
  }
  try {
    await rescheduleAppointment(ctx, appointmentId, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not reschedule.";
    redirect(`/dashboard/${orgId}/appointments/${appointmentId}/reschedule?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/appointments`);
  redirect(`/dashboard/${orgId}/appointments`);
}
