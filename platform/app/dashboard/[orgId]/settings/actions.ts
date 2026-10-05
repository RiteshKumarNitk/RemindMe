"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createLocationSchema, updateLocationSchema, updateSettingsSchema } from "@/modules/clinics/schema.js";
import { createLocation, listLocations, updateLocation, updateSettings } from "@/modules/clinics/service.js";
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
  redirect(`/dashboard/${orgId}/settings?saved=1`);
}

export async function addLocationAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createLocationSchema.safeParse({
    name: String(formData.get("name") ?? ""),
    addressLine1: String(formData.get("addressLine1") ?? "") || undefined,
    city: String(formData.get("city") ?? "") || undefined,
    state: String(formData.get("state") ?? "") || undefined,
    postalCode: String(formData.get("postalCode") ?? "") || undefined,
    phone: String(formData.get("phone") ?? "") || undefined,
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid location.");
  try {
    await createLocation(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not add the location.");
  }
  revalidatePath(`/dashboard/${orgId}/settings`);
}

export async function deactivateLocationAction(orgId: string, locationId: string) {
  const ctx = await requireOrgContext(orgId);
  const locations = await listLocations(ctx);
  // Never let a clinic strand its last active branch — publishing and
  // readiness both require at least one active location.
  if (locations.filter((l) => l.isActive).length <= 1) {
    fail(orgId, "A clinic needs at least one active location. Add another branch first.");
  }
  try {
    await updateLocation(ctx, locationId, { isActive: false });
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not deactivate the location.");
  }
  revalidatePath(`/dashboard/${orgId}/settings`);
  revalidatePath(`/dashboard/${orgId}`);
}

export async function updateLocationAction(orgId: string, locationId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const name = String(formData.get("name") ?? "").trim();
  // The edit form's name field isn't `required` in the HTML; an empty submit
  // would otherwise pass zod as `undefined` (no-op) and report success.
  if (!name) fail(orgId, "Location name is required.");
  const parsed = updateLocationSchema.safeParse({
    name,
    addressLine1: formData.has("addressLine1") ? String(formData.get("addressLine1") ?? "").trim() || null : undefined,
    addressLine2: formData.has("addressLine2") ? String(formData.get("addressLine2") ?? "").trim() || null : undefined,
    city: formData.has("city") ? String(formData.get("city") ?? "").trim() || null : undefined,
    state: formData.has("state") ? String(formData.get("state") ?? "").trim() || null : undefined,
    postalCode: formData.has("postalCode") ? String(formData.get("postalCode") ?? "").trim() || null : undefined,
    phone: formData.has("phone") ? String(formData.get("phone") ?? "").trim() || null : undefined,
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid location.");
  try {
    await updateLocation(ctx, locationId, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not update the location.");
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
