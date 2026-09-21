import { AppError } from "@/lib/errors.js";
import { json, withApi } from "@/lib/http.js";
import { queueTransition } from "@/modules/queue/service.js";
import type { QueueAction } from "@/modules/queue/state-machine.js";

const ACTIONS: Record<string, QueueAction> = {
  call: "CALL",
  recall: "RECALL",
  skip: "SKIP",
  start: "START",
  complete: "COMPLETE",
};

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  const action = ACTIONS[params.action ?? ""];
  if (!action) throw new AppError("NOT_FOUND", "Unknown queue action.");
  return json(await queueTransition(ctx, params.entryId!, action));
});
