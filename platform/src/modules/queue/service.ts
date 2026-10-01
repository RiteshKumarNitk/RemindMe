import { Prisma } from "@prisma/client";
import type { QueueState } from "@prisma/client";
import { randomUUID } from "node:crypto";
import { AppError } from "@/lib/errors.js";
import { writeAuditWith } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { notify } from "@/lib/notifications/notify.js";
import { db } from "@/lib/db.js";
import { localPartsInZone } from "@/lib/time.js";
import type { RequestContext } from "@/lib/context.js";
import { nextQueueState, type QueueAction, canQueueTransition, hasUnfinishedCall } from "./state-machine.js";
import { canTransition as canAppointmentTransition } from "@/modules/appointments/state-machine.js";

/**
 * Allocate the next token number for a (org, doctor, clinic-local day).
 *
 * WHY NOT `count + 1` (what this used to do): two patients booking in the same
 * millisecond — very much a real scenario at the opening minute, when a
 * notification blast lands — both read the same max and both insert the same
 * number. There is no client-side lock to make that safe.
 *
 * This is ONE statement:
 *   INSERT … ON CONFLICT ("organizationId","doctorId","queueDate")
 *   DO UPDATE SET "lastToken" = "lastToken" + 1 RETURNING "lastToken"
 * Postgres serialises conflicting upserts on the unique index, so the RETURNING
 * row is this caller's own number, and `lastToken + 1` is evaluated against the
 * post-conflict (locked) row rather than a stale snapshot read.
 *
 * The INSERT branch back-fills from `MAX(QueueEntry.tokenNumber)` so a counter
 * row first created *after* queue entries already exist for that day (e.g. the
 * day's first entry came from a scheduled check-in) can't restart the sequence
 * at 1 and collide with `@@unique(org, doctor, queueDate, tokenNumber)`.
 *
 * Must be called inside the caller's transaction. Together with `runSerializable`
 * (which retries on 40001) and that unique index there are three independent
 * layers between a client and a duplicate token number.
 */
export async function allocateTokenNumber(
  tx: Prisma.TransactionClient,
  args: { organizationId: string; doctorId: string; queueDate: Date },
): Promise<number> {
  const rows = await tx.$queryRaw<Array<{ lastToken: number }>>(Prisma.sql`
    INSERT INTO "QueueTokenCounter"
      ("id", "organizationId", "doctorId", "queueDate", "lastToken", "createdAt", "updatedAt")
    VALUES (
      ${randomUUID()},
      ${args.organizationId},
      ${args.doctorId},
      ${args.queueDate},
      COALESCE((
        SELECT MAX("tokenNumber") FROM "QueueEntry"
         WHERE "organizationId" = ${args.organizationId}
           AND "doctorId" = ${args.doctorId}
           AND "queueDate" = ${args.queueDate}
      ), 0) + 1,
      NOW(), NOW()
    )
    ON CONFLICT ("organizationId", "doctorId", "queueDate")
    DO UPDATE SET "lastToken" = "QueueTokenCounter"."lastToken" + 1,
                  "updatedAt" = NOW()
    RETURNING "lastToken"
  `);
  const n = rows[0]?.lastToken;
  if (typeof n !== "number") {
    throw new AppError("INTERNAL", "Could not allocate a token number.");
  }
  return n;
}

/**
 * Allocate a token and create a QueueEntry for a checked-in appointment.
 * Runs inside the caller's transaction; the allocator plus the
 * `@@unique(org, doctor, queueDate, tokenNumber)` constraint is the backstop
 * against two receptionists racing.
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

  const tokenNumber = await allocateTokenNumber(tx, {
    organizationId: appt.organizationId,
    doctorId: appt.doctorId,
    queueDate,
  });

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

/** Appointment statuses after which the queue entry must never move again. */
const CLOSED_APPOINTMENT_STATUSES = ["CANCELLED", "RESCHEDULED", "NO_SHOW"] as const;

/**
 * Keep the QueueEntry in step when the APPOINTMENT is moved directly — the
 * consultation page's Start / Sign & complete and the appointment no-show
 * action go through `applyStatusChange`, not the queue. Without this, a visit
 * finished from the consultation page left its entry IN_CONSULTATION forever,
 * which made "Call next" refuse for the rest of the day.
 *
 * Runs inside the caller's transaction. Only non-final entries move; a
 * missing entry (appointment never checked in) is a no-op.
 */
export async function syncQueueEntryForAppointment(
  tx: Prisma.TransactionClient,
  ctx: RequestContext,
  appointmentId: string,
  action: "START" | "COMPLETE" | "NO_SHOW",
  now: Date,
): Promise<void> {
  const entry = await tx.queueEntry.findFirst({
    where: { appointmentId, organizationId: ctx.org!.id },
    select: { id: true, state: true },
  });
  if (!entry) return;
  const target =
    action === "START" ? "IN_CONSULTATION" : action === "COMPLETE" ? "COMPLETED" : "NO_SHOW";
  const from: QueueState[] =
    action === "START"
      ? ["WAITING", "CALLED", "HOLD", "SKIPPED"]
      : action === "COMPLETE"
        ? ["WAITING", "CALLED", "HOLD", "SKIPPED", "IN_CONSULTATION"]
        : ["WAITING", "CALLED", "HOLD", "SKIPPED"];
  if (!from.includes(entry.state)) return;

  await tx.queueEntry.update({
    where: { id: entry.id },
    data: {
      state: target,
      ...(action === "START" ? { consultationStartedAt: now } : {}),
      ...(action === "COMPLETE" ? { completedAt: now } : {}),
    },
  });
  await writeAuditWith(tx, ctx, {
    action: `QUEUE_${action}`,
    entityType: "QueueEntry",
    entityId: entry.id,
    before: { state: entry.state },
    after: { state: target, via: "appointment" },
  });
}

/**
 * How many people are still ahead of this entry, counted from the LIVE queue
 * rows — never from a token-number subtraction and never into an estimated
 * minutes-until-turn (a consultation length is a guess, so any ETA built on it
 * is a fabrication; the UI shows position only).
 *
 * Only meaningful while WAITING: a CALLED/HOLD/SKIPPED/COMPLETED/NO_SHOW entry
 * is out of the running order and reports 0.
 */
function peopleAhead(
  entries: Array<{ position: number; tokenNumber: number; state: string }>,
  self: { position: number; tokenNumber: number; state: string },
): number {
  if (self.state !== "WAITING") return 0;
  return entries.filter(
    (e) =>
      e.state === "WAITING" &&
      (e.position < self.position ||
        (e.position === self.position && e.tokenNumber < self.tokenNumber)),
  ).length;
}

const EMPTY_SUMMARY = {
  waiting: 0,
  called: 0,
  inConsultation: 0,
  onHold: 0,
  completed: 0,
  skipped: 0,
  noShow: 0,
};

type BoardSummary = { total: number } & typeof EMPTY_SUMMARY;

/**
 * Which transitions this actor may legally perform on this entry right now.
 *
 * Derived from the state machine (never a hand-maintained list in the client)
 * AND the same role rule `queueTransition` enforces server-side, so the board
 * can never render a button that the API will reject.
 */
function availableActions(
  state: string,
  role: string,
  isAssignedDoctor: boolean,
  appointmentStatus: string,
): QueueAction[] {
  // Same guard as queueTransition.
  if ((CLOSED_APPOINTMENT_STATUSES as readonly string[]).includes(appointmentStatus)) return [];
  if (appointmentStatus === "COMPLETED") state = state === "IN_CONSULTATION" ? state : "COMPLETED";
  const all: QueueAction[] = [
    "CALL",
    "RECALL",
    "SKIP",
    "START",
    "COMPLETE",
    "HOLD",
    "RELEASE",
    "NO_SHOW",
  ];
  return all.filter((a) => {
    if (!canQueueTransition(state as never, a)) return false;
    // Clinical actions belong to the assigned doctor; the rest to front desk.
    if (a === "START" || a === "COMPLETE") return isAssignedDoctor && role === "DOCTOR";
    // Mirrors queueTransition: front desk, or the doctor on their OWN queue.
    return role === "RECEPTIONIST" || role === "CLINIC_ADMIN" || isAssignedDoctor;
  });
}

export async function getBoard(
  ctx: RequestContext,
  filter: { doctorId: string; date?: string },
) {
  const t = tenantDb(ctx);
  const doctor = await t.doctorProfile.findFirstOrThrow({
    where: { id: filter.doctorId, organizationId: ctx.org!.id },
    select: { id: true, userId: true },
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
    // position first, tokenNumber as the tiebreak: RECALL sets position = -1, so
    // every recalled entry ties on position and the token order is what makes
    // "served next" deterministic rather than DB-order-dependent.
    orderBy: [{ position: "asc" }, { tokenNumber: "asc" }],
    select: {
      id: true,
      tokenNumber: true,
      state: true,
      position: true,
      recallCount: true,
      calledAt: true,
      heldAt: true,
      checkedInAt: true,
      appointmentId: true,
      appointment: { select: { status: true } },
      patient: { select: { id: true, firstName: true, lastName: true } },
    },
  });

  const nowServing =
    entries.find((e) => e.state === "IN_CONSULTATION") ??
    entries.find((e) => e.state === "CALLED") ??
    null;

  const summary: BoardSummary = { ...EMPTY_SUMMARY, total: entries.length };
  for (const e of entries) {
    if (e.state === "WAITING") summary.waiting++;
    else if (e.state === "CALLED") summary.called++;
    else if (e.state === "IN_CONSULTATION") summary.inConsultation++;
    else if (e.state === "HOLD") summary.onHold++;
    else if (e.state === "COMPLETED") summary.completed++;
    else if (e.state === "SKIPPED") summary.skipped++;
    else if (e.state === "NO_SHOW") summary.noShow++;
  }

  return {
    queueDate: queueDate.toISOString().slice(0, 10),
    nowServingToken: nowServing?.tokenNumber ?? null,
    summary,
    entries: entries.map((e) => ({
      ...e,
      ahead: peopleAhead(entries, e),
      actions: availableActions(e.state, ctx.org!.role, doctor.userId === ctx.userId, e.appointment.status),
    })),
  };
}

/**
 * The next eligible patient, chosen SERVER-SIDE from the live queue — the
 * frontend must never compute this (it has no consistent snapshot, and two
 * receptionists would disagree).
 *
 * "Eligible" = state WAITING, earliest by (position, tokenNumber). HOLD and
 * SKIPPED are deliberately NOT auto-picked: a held patient is in the building
 * but out of the running order, and a skipped one already missed their call —
 * both need a human to RECALL them, which is exactly what RECALL is for.
 *
 * Refuses while someone is already CALLED or IN_CONSULTATION, because
 * "call next" must never silently abandon the patient who is already up.
 *
 * The pick and the transition are two steps, so two receptionists pressing
 * "next" simultaneously can both choose the same patient; the loser gets a 409
 * from the state machine rather than a double-call. That is the intended
 * failure mode — deterministic and safe.
 */
export async function callNext(
  ctx: RequestContext,
  filter: { doctorId: string; date?: string },
) {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN", "DOCTOR");
  const board = await getBoard(ctx, filter);
  if (hasUnfinishedCall(board.entries)) {
    throw new AppError(
      "CONFLICT",
      "Someone is already called. Start or skip them first.",
    );
  }
  const next = board.entries.find((e) => e.state === "WAITING");
  if (!next) {
    throw new AppError("CONFLICT", "Nobody is waiting in this queue.");
  }
  return queueTransition(ctx, next.id, "CALL");
}

/** The next WAITING entry without calling it — used to preview "NEXT" on the board. */
export async function peekNext(
  ctx: RequestContext,
  filter: { doctorId: string; date?: string },
) {
  const board = await getBoard(ctx, filter);
  const next = board.entries.find((e) => e.state === "WAITING") ?? null;
  return { next, nowServingToken: board.nowServingToken, summary: board.summary };
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

  // The appointment is the source of truth. A cancelled / rescheduled /
  // no-show appointment's entry is parked as SKIPPED or NO_SHOW for history;
  // it must not be recallable back into the line, or START would resurrect
  // the appointment. A COMPLETED appointment only allows closing a stale entry.
  const apptStatus = entry.appointment.status;
  if ((CLOSED_APPOINTMENT_STATUSES as readonly string[]).includes(apptStatus)) {
    throw new AppError(
      "INVALID_QUEUE_TRANSITION",
      `This appointment is ${apptStatus.toLowerCase().replace("_", "-")}; its queue entry can't be changed.`,
    );
  }
  if (apptStatus === "COMPLETED" && action !== "COMPLETE") {
    throw new AppError("INVALID_QUEUE_TRANSITION", "This visit is already completed.");
  }

  const to = nextQueueState(entry.state, action);
  const now = new Date();

  const updated = await db.$transaction(async (tx) => {
    // Compare-and-swap on `state`, not a blind update. Without the state
    // predicate, two receptionists pressing "call next" at once both read
    // WAITING, both pass the state machine check above, and both write CALLED —
    // two "now serving" rows. With it, exactly one UPDATE matches a row and the
    // other gets a 409 instead.
    const swapped = await tx.queueEntry.updateMany({
      where: { id: entryId, organizationId: ctx.org!.id, state: entry.state },
      data: {
        state: to,
        ...(action === "CALL" ? { calledAt: now } : {}),
        ...(action === "RECALL" ? { recallCount: { increment: 1 }, calledAt: now } : {}),
        ...(action === "SKIP" ? { skippedAt: now } : {}),
        ...(action === "START" ? { consultationStartedAt: now } : {}),
        ...(action === "COMPLETE" ? { completedAt: now } : {}),
        ...(action === "HOLD" ? { heldAt: now } : {}),
        ...(action === "RELEASE" ? { heldAt: null } : {}),
        // A recalled entry is served next. Applies to both RECALL shapes:
        // SKIPPED/CALLED -> WAITING and HOLD -> CALLED.
        ...(action === "RECALL" ? { position: -1 } : {}),
      },
    });
    if (swapped.count === 0) {
      throw new AppError(
        "CONFLICT",
        "This patient was just moved by someone else. Reload the queue and try again.",
      );
    }

    // Started/completed from the consultation page first? Then the appointment
    // is already there and only the queue row needed to catch up.
    if (action === "START" && canAppointmentTransition(entry.appointment.status, "START")) {
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
    if (action === "COMPLETE" && entry.appointment.status === "IN_CONSULTATION") {
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
    if (action === "NO_SHOW") {
      // The queue and the appointment must not disagree about whether the
      // patient turned up, so a NO_SHOW on the queue drives the appointment
      // too. Guarded: a cancelled/completed appointment can't be re-opened as
      // NO_SHOW just because a stale board row was clicked.
      if (canAppointmentTransition(entry.appointment.status, "NO_SHOW")) {
        await tx.appointment.update({
          where: { id: entry.appointment.id },
          data: { status: "NO_SHOW", noShowMarkedAt: now },
        });
        await tx.appointmentEvent.create({
          data: {
            organizationId: ctx.org!.id,
            appointmentId: entry.appointment.id,
            fromStatus: entry.appointment.status,
            toStatus: "NO_SHOW",
            actorId: ctx.userId,
            reason: "queue:no-show",
          },
        });
      }
    }

    await writeAuditWith(tx, ctx, {
      action: `QUEUE_${action}`,
      entityType: "QueueEntry",
      entityId: entryId,
      before: { state: entry.state },
      after: { state: to },
    });
    return tx.queueEntry.findFirstOrThrow({
      where: { id: entryId },
      include: { patient: { select: { firstName: true, lastName: true } } },
    });
  });

  // The patient should hear about every state change that affects what they
  // should do next — being called, being recalled, being held, being skipped,
  // or being written off as a no-show all change their situation. RELEASE and
  // COMPLETE don't: nothing is being asked of them.
  if (action !== "RELEASE" && action !== "COMPLETE") {
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
