"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { queueTransition } from "@/modules/queue/service.js";
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
