import type { z } from "zod";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { listNotificationsQuerySchema, markNotificationsReadSchema } from "./schema.js";

/**
 * Turns a raw `{event, payload}` row into what the notification bell actually
 * renders. Kept server-side (not duplicated in the client component) so the
 * event-name-to-copy mapping has one home and evolves with the backend that
 * defines the events, not with whichever page happens to render them.
 */
function describe(event: string, payload: unknown): { message: string; href: string | null } {
  const p = (payload ?? {}) as Record<string, unknown>;
  const appointmentId = typeof p.appointmentId === "string" ? p.appointmentId : null;
  const href = appointmentId ? `appointments/${appointmentId}` : null;

  switch (event) {
    case "APPOINTMENT_BOOKED":
      return { message: "An appointment was booked.", href };
    case "APPOINTMENT_CANCELLED":
      return { message: "An appointment was cancelled.", href };
    case "APPOINTMENT_RESCHEDULED":
      return { message: "An appointment was rescheduled.", href };
    case "APPOINTMENT_REMINDER":
      return { message: "You have an upcoming appointment.", href };
    case "CHECK_IN_CONFIRMED":
      return { message: "Checked in — you're in the queue.", href };
    case "QUEUE_UPDATE":
      return { message: "Your queue position was updated.", href };
    default:
      return { message: event.replaceAll("_", " ").toLowerCase(), href };
  }
}

export async function listMyNotifications(
  ctx: RequestContext,
  query: z.infer<typeof listNotificationsQuerySchema>,
) {
  const t = tenantDb(ctx);
  const [rows, unreadCount] = await Promise.all([
    t.notification.findMany({
      where: { userId: ctx.userId, channel: "IN_APP" },
      orderBy: { createdAt: "desc" },
      take: query.limit,
      select: { id: true, event: true, payload: true, createdAt: true, readAt: true },
    }),
    t.notification.count({ where: { userId: ctx.userId, channel: "IN_APP", readAt: null } }),
  ]);

  return {
    data: rows.map((r) => ({
      id: r.id,
      createdAt: r.createdAt,
      read: r.readAt !== null,
      ...describe(r.event, r.payload),
    })),
    unreadCount,
  };
}

export async function markNotificationsRead(
  ctx: RequestContext,
  input: z.infer<typeof markNotificationsReadSchema>,
) {
  const t = tenantDb(ctx);
  await t.notification.updateMany({
    where: {
      userId: ctx.userId,
      channel: "IN_APP",
      readAt: null,
      ...(input.ids ? { id: { in: input.ids } } : {}),
    },
    data: { readAt: new Date() },
  });
  return { ok: true };
}
