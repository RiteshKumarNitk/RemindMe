"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createLocationSchema, updateSettingsSchema } from "@/modules/clinics/schema.js";
import { createLocation, updateSettings } from "@/modules/clinics/service.js";
import { createTypeSchema } from "@/modules/appointments/schema.js";
import { createAppointmentType } from "@/modules/appointments/service.js";

function fail(orgId: string, message: string): never {
  redirect(`/dashboard/${orgId}/settings?error=${encodeURIComponent(message)}`);
}

export async function saveSettingsAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = updateSettingsSchema.safeParse({
    allowPatientSelfBooking: formData.get("allowPatientSelfBooking") === "on",
    bookingLeadTimeMinutes: Number(formData.get("bookingLeadTimeMinutes")),
    cancellationWindowHours: Number(formData.get("cancellationWindowHours")),
    maxAdvanceBookingDays: Number(formData.get("maxAdvanceBookingDays")),
    defaultAppointmentDurationMin: Number(formData.get("defaultAppointmentDurationMin")),
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid settings.");
  try {
    await updateSettings(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not save settings.");
  }
  revalidatePath(`/dashboard/${orgId}/settings`);
}

export async function addLocationAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createLocationSchema.safeParse({
    name: String(formData.get("name") ?? ""),
    city: String(formData.get("city") ?? "") || undefined,
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid location.");
  try {
    await createLocation(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not add the location.");
  }
  revalidatePath(`/dashboard/${orgId}/settings`);
}

export async function addAppointmentTypeAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createTypeSchema.safeParse({
    name: String(formData.get("name") ?? ""),
    durationMinutes: Number(formData.get("durationMinutes") ?? 15),
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid appointment type.");
  try {
    await createAppointmentType(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not add the appointment type.");
  }
  revalidatePath(`/dashboard/${orgId}/settings`);
}
