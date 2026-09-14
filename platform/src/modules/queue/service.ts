import type { Prisma } from "@prisma/client";
import { AppError } from "@/lib/errors.js";
import { writeAuditWith } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { notify } from "@/lib/notifications/notify.js";
import { db } from "@/lib/db.js";
import { localPartsInZone } from "@/lib/time.js";
import type { RequestContext } from "@/lib/context.js";
import { nextQueueState, type QueueAction } from "./state-machine.js";

/**
 * Allocate the next token and create a QueueEntry for a checked-in appointment.
 * Runs inside the caller's transaction; the `@@unique(org, doctor, queueDate,
 * tokenNumber)` constraint is the backstop against two receptionists racing.
 */
export async function createEntryForCheckIn(
  tx: Prisma.TransactionClient,
  appt: {
    id: string;
    organizationId: string;
    doctorId: string;
    patientId: string;
    locationId: string | null;
    scheduledStart: Date;
    timezone: string;
  },
): Promise<{ id: string; tokenNumber: number; queueDate: Date }> {
  const local = localPartsInZone(appt.scheduledStart, appt.timezone);
  const queueDate = new Date(Date.UTC(local.year, local.month - 1, local.day));

  const agg = await tx.queueEntry.aggregate({
    where: { organizationId: appt.organizationId, doctorId: appt.doctorId, queueDate },
    _max: { tokenNumber: true },
  });
  const tokenNumber = (agg._max.tokenNumber ?? 0) + 1;

  const entry = await tx.queueEntry.create({
    data: {
      organizationId: appt.organizationId,
      appointmentId: appt.id,
      patientId: appt.patientId,
      doctorId: appt.doctorId,
      locationId: appt.locationId,
      queueDate,
      tokenNumber,
      position: tokenNumber,
      state: "WAITING",
      checkedInAt: new Date(),
    },
    select: { id: true, tokenNumber: true, queueDate: true },
  });
  return entry;
}

function peopleAhead(
  entries: Array<{ position: number; state: string }>,
  self: { position: number },
): number {
  return entries.filter(
    (e) => e.state === "WAITING" && e.position < self.position,
  ).length;
}

export async function getBoard(
  ctx: RequestContext,
  filter: { doctorId: string; date?: string },
) {
  const t = tenantDb(ctx);
  await t.doctorProfile.findFirstOrThrow({
    where: { id: filter.doctorId, organizationId: ctx.org!.id },
    select: { id: true },
  });

  let queueDate: Date;
  if (filter.date) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(filter.date);
    if (!m) throw new AppError("VALIDATION_FAILED", "date must be YYYY-MM-DD");
    queueDate = new Date(Date.UTC(+m[1]!, +m[2]! - 1, +m[3]!));
  } else {
    const org = await t.organization.findFirstOrThrow({
      where: { id: ctx.org!.id },
      select: { timezone: true },
    });
    const now = localPartsInZone(new Date(), org.timezone);
    queueDate = new Date(Date.UTC(now.year, now.month - 1, now.day));
  }

  const entries = await t.queueEntry.findMany({
    where: { organizationId: ctx.org!.id, doctorId: filter.doctorId, queueDate },
    orderBy: [{ position: "asc" }],
    select: {
      id: true,
      tokenNumber: true,
      state: true,
      position: true,
      recallCount: true,
      calledAt: true,
      patient: { select: { id: true, firstName: true, lastName: true } },
      appointmentId: true,
    },
  });

  const nowServing =
    entries.find((e) => e.state === "IN_CONSULTATION") ??
    entries.find((e) => e.state === "CALLED") ??
    null;

  return {
    queueDate: queueDate.toISOString().slice(0, 10),
    nowServingToken: nowServing?.tokenNumber ?? null,
    entries: entries.map((e) => ({
      ...e,
      ahead: peopleAhead(entries, e),
    })),
  };
}

export async function queueTransition(
  ctx: RequestContext,
  entryId: string,
  action: QueueAction,
) {
  const t = tenantDb(ctx);
  const entry = await t.queueEntry.findFirstOrThrow({
    where: { id: entryId, organizationId: ctx.org!.id },
    include: {
      doctor: { select: { userId: true } },
      appointment: { select: { id: true, status: true, patient: { select: { ownerUserId: true } } } },
    },
  });

  const isAssignedDoctor = entry.doctor.userId === ctx.userId;
  if (action === "START" || action === "COMPLETE") {
    if (!isAssignedDoctor) {
      throw new AppError("FORBIDDEN", "Only the assigned doctor can do that.");
    }
  } else if (!isAssignedDoctor) {
    assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN");
  }

  const to = nextQueueState(entry.state, action);
  const now = new Date();

  const updated = await db.$transaction(async (tx) => {
    const q = await tx.queueEntry.update({
      where: { id: entryId },
      data: {
        state: to,
        ...(action === "CALL" ? { calledAt: now } : {}),
        ...(action === "RECALL" ? { recallCount: { increment: 1 }, calledAt: now } : {}),
        ...(action === "SKIP" ? { skippedAt: now } : {}),
        ...(action === "START" ? { consultationStartedAt: now } : {}),
        ...(action === "COMPLETE" ? { completedAt: now } : {}),
        // A recalled entry is served next.
        ...(action === "RECALL" ? { position: -1 } : {}),
      },
    });

    if (action === "START") {
      await tx.appointment.update({
        where: { id: entry.appointment.id },
        data: { status: "IN_CONSULTATION", consultationStartedAt: now },
      });
      await tx.appointmentEvent.create({
        data: {
          organizationId: ctx.org!.id,
          appointmentId: entry.appointment.id,
          fromStatus: entry.appointment.status,
          toStatus: "IN_CONSULTATION",
          actorId: ctx.userId,
          reason: "queue:start",
        },
      });
    }
    if (action === "COMPLETE") {
      await tx.appointment.update({
        where: { id: entry.appointment.id },
        data: { status: "COMPLETED", completedAt: now },
      });
      await tx.appointmentEvent.create({
        data: {
          organizationId: ctx.org!.id,
          appointmentId: entry.appointment.id,
          fromStatus: "IN_CONSULTATION",
          toStatus: "COMPLETED",
          actorId: ctx.userId,
          reason: "queue:complete",
        },
      });
    }

    await writeAuditWith(tx, ctx, {
      action: `QUEUE_${action}`,
      entityType: "QueueEntry",
      entityId: entryId,
      before: { state: entry.state },
      after: { state: to },
    });
    return q;
  });

  if (action === "CALL" || action === "RECALL") {
    await notify({
      organizationId: ctx.org!.id,
      userId: entry.appointment.patient.ownerUserId,
      channel: "PUSH",
      event: "QUEUE_UPDATE",
      payload: { appointmentId: entry.appointment.id, tokenNumber: entry.tokenNumber, state: to },
    });
  }

  return updated;
}
