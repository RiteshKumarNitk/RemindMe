"use server";

import { redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { requireWebUser } from "@/lib/web-context.js";
import { selfBookAppointmentSchema } from "@/modules/patient-booking/schema.js";
import { selfBookAppointment } from "@/modules/patient-booking/service.js";

export async function confirmBookingAction(doctorId: string, slot: string, formData: FormData) {
  const ctx = await requireWebUser();

  const parsed = selfBookAppointmentSchema.safeParse({
    organizationId: String(formData.get("organizationId") ?? ""),
    doctorId,
    scheduledStart: slot,
    reason: String(formData.get("reason") ?? "").trim() || undefined,
    patient: {
      firstName: String(formData.get("firstName") ?? "").trim(),
      lastName: String(formData.get("lastName") ?? "").trim(),
      phone: String(formData.get("phone") ?? "").trim() || undefined,
      dateOfBirth: String(formData.get("dateOfBirth") ?? "").trim() || undefined,
      sex: String(formData.get("sex") ?? "").trim() || undefined,
    },
  });

  if (!parsed.success) {
    redirect(
      `/doctors/${doctorId}/book?slot=${encodeURIComponent(slot)}&error=${encodeURIComponent(
        parsed.error.issues[0]?.message ?? "Please check the form and try again.",
      )}`,
    );
  }

  let organizationId: string;
  try {
    const appt = await selfBookAppointment(ctx, parsed.data);
    organizationId = appt.organizationId;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not book that appointment.";
    redirect(`/doctors/${doctorId}/book?slot=${encodeURIComponent(slot)}&error=${encodeURIComponent(message)}`);
  }

  redirect(`/dashboard/${organizationId}/appointments?booked=1`);
}
