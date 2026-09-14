"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createExceptionSchema, putRulesSchema } from "@/modules/availability/schema.js";
import { createException, deleteException, replaceRules } from "@/modules/availability/service.js";

const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;

function toMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(":").map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

export async function saveAvailabilityAction(orgId: string, doctorId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const base = `/dashboard/${orgId}/doctors/${doctorId}/availability`;

  const rules = WEEKDAYS.flatMap((weekday) => {
    if (formData.get(`open-${weekday}`) !== "on") return [];
    const start = String(formData.get(`start-${weekday}`) ?? "09:00");
    const end = String(formData.get(`end-${weekday}`) ?? "17:00");
    const slot = Number(formData.get(`slot-${weekday}`) ?? 15);
    return [{ weekday, startMinute: toMinutes(start), endMinute: toMinutes(end), slotMinutes: slot }];
  });

  const parsed = putRulesSchema.safeParse({ rules });
  if (!parsed.success) {
    redirect(`${base}?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid schedule.")}`);
  }
  try {
    await replaceRules(ctx, doctorId, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not save the schedule.";
    redirect(`${base}?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(base);
}

export async function addExceptionAction(orgId: string, doctorId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const base = `/dashboard/${orgId}/doctors/${doctorId}/availability`;
  const kind = String(formData.get("kind") ?? "DAY_OFF");
  const date = String(formData.get("date") ?? "");
  const reason = String(formData.get("reason") ?? "") || undefined;

  const parsed = createExceptionSchema.safeParse({
    kind,
    startsAt: `${date}T00:00:00.000Z`,
    endsAt: `${date}T23:59:00.000Z`,
    reason,
  });
  if (!parsed.success) {
    redirect(`${base}?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid date.")}`);
  }
  try {
    await createException(ctx, doctorId, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not add the exception.";
    redirect(`${base}?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(base);
}

export async function deleteExceptionAction(orgId: string, doctorId: string, exceptionId: string) {
  const ctx = await requireOrgContext(orgId);
  await deleteException(ctx, doctorId, exceptionId);
  revalidatePath(`/dashboard/${orgId}/doctors/${doctorId}/availability`);
}
