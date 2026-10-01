"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { callNext, queueTransition } from "@/modules/queue/service.js";
import { walkInToken } from "@/modules/tokens/service.js";
import type { QueueAction } from "@/modules/queue/state-machine.js";

export async function queueAction(
  orgId: string,
  entryId: string,
  action: QueueAction,
  redirectQuery: string,
) {
  const ctx = await requireOrgContext(orgId);
  try {
    await queueTransition(ctx, entryId, action);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "That action failed.";
    redirect(`/dashboard/${orgId}/queue?${redirectQuery}&error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/queue`);
  revalidatePath(`/dashboard/${orgId}/appointments`);
}

/** "Call next" — the server picks the next eligible token, never the browser. */
export async function callNextAction(orgId: string, doctorId: string, redirectQuery: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await callNext(ctx, { doctorId });
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not call the next patient.";
    redirect(`/dashboard/${orgId}/queue?${redirectQuery}&error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/queue`);
}

/** Reception registers a patient at the desk: issues today's token under the same window and cap. */
export async function walkInAction(orgId: string, doctorId: string, redirectQuery: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const patientId = String(formData.get("patientId") ?? "");
  let token: number | null = null;
  try {
    const res = await walkInToken(ctx, doctorId, { patientId });
    token = res.tokenNumber;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not issue a token.";
    redirect(`/dashboard/${orgId}/queue?${redirectQuery}&error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/queue`);
  redirect(`/dashboard/${orgId}/queue?${redirectQuery}&issued=${token}`);
}
