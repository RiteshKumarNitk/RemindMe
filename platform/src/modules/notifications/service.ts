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
    case "APPOINTMENT_REMINDER": {
      // Copy carries the actual time ("Tomorrow at 3:20 PM") when the payload
      // has it — a bare "you have an appointment" makes the patient open the
      // detail page just to learn when.
      const start = typeof p.scheduledStart === "string" ? new Date(p.scheduledStart) : null;
      const when =
        start && !Number.isNaN(start.getTime())
          ? start.toLocaleString(undefined, {
              weekday: start.getTime() - Date.now() < 36 * 3600_000 ? "long" : "short",
              month: "short",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })
          : null;
      return { message: when ? `Reminder: appointment at ${when}.` : "You have an upcoming appointment.", href };
    }
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
  // Scheduled rows (future appointment reminders) are enqueued ahead of time
  // and only become visible once `scheduledFor` passes — otherwise a reminder
  // for next week would sit in the bell feed unread today, and its future
  // "scheduled" unread state would also inflate the badge.
  const [rows, unreadCount] = await Promise.all([
    t.notification.findMany({
      where: {
        userId: ctx.userId,
        channel: "IN_APP",
        OR: [{ scheduledFor: null }, { scheduledFor: { lte: new Date() } }],
      },
      orderBy: { createdAt: "desc" },
      take: query.limit,
      select: { id: true, event: true, payload: true, createdAt: true, readAt: true },
    }),
    t.notification.count({
      where: {
        userId: ctx.userId,
        channel: "IN_APP",
        readAt: null,
        OR: [{ scheduledFor: null }, { scheduledFor: { lte: new Date() } }],
      },
    }),
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
