import { Prisma } from "@prisma/client";
import type { AppointmentStatus, BookingSource } from "@prisma/client";
import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit, writeAuditWith } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { runSerializable } from "@/lib/serializable.js";
import { notify } from "@/lib/notifications/notify.js";
import { assertWithinAvailability } from "@/modules/availability/service.js";
import { createEntryForCheckIn } from "@/modules/queue/service.js";
import type { RequestContext } from "@/lib/context.js";
import { nextStatus, type AppointmentAction } from "./state-machine.js";
import type {
  bookSchema,
  createTypeSchema,
  listQuerySchema,
  rescheduleSchema,
} from "./schema.js";

// ---------------------------------------------------------------------------
// Appointment types
// ---------------------------------------------------------------------------

export async function listAppointmentTypes(ctx: RequestContext) {
  const t = tenantDb(ctx);
  return t.appointmentType.findMany({
    where: { organizationId: ctx.org!.id, isActive: true },
    orderBy: { name: "asc" },
  });
}

export async function createAppointmentType(
  ctx: RequestContext,
  input: z.infer<typeof createTypeSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  try {
    const type = await t.appointmentType.create({
      data: {
        organizationId: ctx.org!.id,
        name: input.name.trim(),
        durationMinutes: input.durationMinutes,
        colorHex: input.colorHex ?? null,
      },
    });
    await writeAudit(ctx, {
      action: "APPOINTMENT_TYPE_CREATED",
      entityType: "AppointmentType",
      entityId: type.id,
      after: type,
    });
    return type;
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      throw new AppError("CONFLICT", "An appointment type with that name exists.");
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Booking
// ---------------------------------------------------------------------------

function bookingSourceFor(role: string): BookingSource {
  switch (role) {
    case "PATIENT":
      return "PATIENT_APP";
    case "RECEPTIONIST":
      return "RECEPTION";
    case "DOCTOR":
      return "DOCTOR";
    default:
      return "ADMIN";
  }
}

async function resolveTimezone(
  client: Prisma.TransactionClient,
  orgId: string,
  locationId?: string | null,
): Promise<string> {
  const org = await client.organization.findFirstOrThrow({
    where: { id: orgId },
    select: { timezone: true },
  });
  if (locationId) {
    const loc = await client.clinicLocation.findFirst({
      where: { id: locationId, organizationId: orgId },
      select: { timezone: true },
    });
    if (loc?.timezone) return loc.timezone;
  }
  return org.timezone;
}

export async function bookAppointment(
  ctx: RequestContext,
  input: z.infer<typeof bookSchema>,
) {
  assertRole(ctx, "PATIENT", "DOCTOR", "RECEPTIONIST", "CLINIC_ADMIN");
  const orgId = ctx.org!.id;
  const role = ctx.org!.role;
  const start = new Date(input.scheduledStart);
  if (Number.isNaN(start.getTime())) {
    throw new AppError("VALIDATION_FAILED", "scheduledStart is not a valid instant.");
  }

  const appointment = await runSerializable(async (tx) => {
    const settings = await tx.clinicSettings.findFirstOrThrow({
      where: { organizationId: orgId },
    });

    const patient = await tx.patient.findFirst({
      where: { id: input.patientId, organizationId: orgId },
      select: { id: true, ownerUserId: true, firstName: true, lastName: true },
    });
    if (!patient) throw new AppError("NOT_FOUND", "Patient not found.");

    const doctor = await tx.doctorProfile.findFirst({
      where: { id: input.doctorId, organizationId: orgId, isActive: true },
      select: { id: true, userId: true, displayName: true },
    });
    if (!doctor) throw new AppError("NOT_FOUND", "Doctor not found.");

    // Patient self-booking gate.
    if (role === "PATIENT") {
      if (patient.ownerUserId !== ctx.userId) {
        throw new AppError("FORBIDDEN", "You can only book for your own record.");
      }
      if (!settings.allowPatientSelfBooking) {
        throw new AppError("FORBIDDEN", "This clinic does not allow patient self-booking.");
      }
    }

    // Duration.
    let duration = settings.defaultAppointmentDurationMin;
    if (input.appointmentTypeId) {
      const type = await tx.appointmentType.findFirst({
        where: { id: input.appointmentTypeId, organizationId: orgId },
        select: { durationMinutes: true },
      });
      if (!type) throw new AppError("NOT_FOUND", "Appointment type not found.");
      duration = type.durationMinutes;
    }
    const end = new Date(start.getTime() + duration * 60_000);
    const timezone = await resolveTimezone(tx, orgId, input.locationId);

    // Policy checks.
    const now = Date.now();
    if (start.getTime() < now + settings.bookingLeadTimeMinutes * 60_000) {
      throw new AppError("CONFLICT", "That time is too soon to book.");
    }
    if (
      start.getTime() >
      now + settings.maxAdvanceBookingDays * 24 * 60 * 60_000
    ) {
      throw new AppError("CONFLICT", "That time is too far in advance.");
    }

    await assertWithinAvailability(tx, orgId, doctor.id, start, end, timezone);

    const status: AppointmentStatus =
      role === "PATIENT" && !settings.allowPatientSelfBooking
        ? "REQUESTED"
        : "CONFIRMED";

    const appt = await tx.appointment.create({
      data: {
        organizationId: orgId,
        patientId: patient.id,
        doctorId: doctor.id,
        locationId: input.locationId ?? null,
        appointmentTypeId: input.appointmentTypeId ?? null,
        scheduledStart: start,
        scheduledEnd: end,
        timezone,
        status,
        reason: input.reason ?? null,
        notes: input.notes ?? null,
        bookingSource: bookingSourceFor(role),
        createdById: ctx.userId,
        confirmedAt: status === "CONFIRMED" ? new Date() : null,
      },
    });

    await tx.appointmentEvent.create({
      data: {
        organizationId: orgId,
        appointmentId: appt.id,
        fromStatus: null,
        toStatus: status,
        actorId: ctx.userId,
        reason: "book",
      },
    });
    await writeAuditWith(tx, ctx, {
      action: "APPOINTMENT_CREATED",
      entityType: "Appointment",
      entityId: appt.id,
      after: {
        patientId: patient.id,
        doctorId: doctor.id,
        scheduledStart: start,
        status,
      },
    });

    if (status === "CONFIRMED") {
      await scheduleReminders(tx, appt.id, orgId, patient.ownerUserId, start);
    }

    return { appt, patientOwner: patient.ownerUserId, doctorUserId: doctor.userId };
  });

  await notify({
    organizationId: orgId,
    userId: appointment.patientOwner,
    event: "APPOINTMENT_BOOKED",
    payload: { appointmentId: appointment.appt.id, scheduledStart: appointment.appt.scheduledStart },
  });
  await notify({
    organizationId: orgId,
    userId: appointment.doctorUserId,
    event: "APPOINTMENT_BOOKED",
    payload: { appointmentId: appointment.appt.id, scheduledStart: appointment.appt.scheduledStart },
  });

  return appointment.appt;
}

async function scheduleReminders(
  tx: Prisma.TransactionClient,
  appointmentId: string,
  orgId: string,
  patientUserId: string | null,
  start: Date,
) {
  if (!patientUserId) return;
  for (const [label, offsetMin] of [
    ["T-24H", 24 * 60],
    ["T-2H", 2 * 60],
  ] as const) {
    const when = new Date(start.getTime() - offsetMin * 60_000);
    if (when.getTime() <= Date.now()) continue;
    await notify(
      {
        organizationId: orgId,
        userId: patientUserId,
        channel: "PUSH",
        event: "APPOINTMENT_REMINDER",
        payload: { appointmentId, label },
        scheduledFor: when,
        dedupeKey: `APPOINTMENT_REMINDER:${appointmentId}:${label}`,
      },
      tx,
    );
  }
}

async function cancelReminders(tx: Prisma.TransactionClient, appointmentId: string) {
  await tx.notification.updateMany({
    where: {
      event: "APPOINTMENT_REMINDER",
      status: "PENDING",
      dedupeKey: { startsWith: `APPOINTMENT_REMINDER:${appointmentId}:` },
    },
    data: { status: "SUPPRESSED" },
  });
}

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

export async function getAppointment(ctx: RequestContext, id: string) {
  const t = tenantDb(ctx);
  return t.appointment.findFirstOrThrow({
    where: { id, organizationId: ctx.org!.id },
    include: {
      events: { orderBy: { at: "asc" } },
      queueEntry: true,
      patient: { select: { id: true, firstName: true, lastName: true } },
      doctor: { select: { id: true, displayName: true } },
    },
  });
}

export async function listAppointments(
  ctx: RequestContext,
  q: z.infer<typeof listQuerySchema>,
) {
  const t = tenantDb(ctx);
  const where: Prisma.AppointmentWhereInput = { organizationId: ctx.org!.id };
  if (q.doctorId) where.doctorId = q.doctorId;
  if (q.patientId) where.patientId = q.patientId;
  if (q.status) where.status = q.status;
  if (q.from || q.to) {
    const range: Prisma.DateTimeFilter = {};
    if (q.from) range.gte = new Date(q.from);
    if (q.to) range.lte = new Date(q.to);
    where.scheduledStart = range;
  }
  // A PATIENT only ever sees their own appointments.
  if (ctx.org!.role === "PATIENT") {
    where.patient = { ownerUserId: ctx.userId };
  }
  const data = await t.appointment.findMany({
    where,
    orderBy: { scheduledStart: "asc" },
    take: q.limit,
    include: {
      patient: { select: { id: true, firstName: true, lastName: true } },
      doctor: { select: { id: true, displayName: true } },
    },
  });
  return { data };
}

// ---------------------------------------------------------------------------
// Lifecycle transitions
// ---------------------------------------------------------------------------

interface LoadedAppt {
  id: string;
  organizationId: string;
  status: AppointmentStatus;
  doctorId: string;
  patientId: string;
  locationId: string | null;
  scheduledStart: Date;
  timezone: string;
  doctorUserId: string;
  patientOwnerUserId: string | null;
}

async function loadForTransition(ctx: RequestContext, id: string): Promise<LoadedAppt> {
  const t = tenantDb(ctx);
  const a = await t.appointment.findFirstOrThrow({
    where: { id, organizationId: ctx.org!.id },
    include: {
      doctor: { select: { userId: true } },
      patient: { select: { ownerUserId: true } },
    },
  });
  return {
    id: a.id,
    organizationId: a.organizationId,
    status: a.status,
    doctorId: a.doctorId,
    patientId: a.patientId,
    locationId: a.locationId,
    scheduledStart: a.scheduledStart,
    timezone: a.timezone,
    doctorUserId: a.doctor.userId,
    patientOwnerUserId: a.patient.ownerUserId,
  };
}

function isAssignedDoctor(ctx: RequestContext, a: LoadedAppt) {
  return ctx.org!.role === "DOCTOR" && a.doctorUserId === ctx.userId;
}
function isPatientOwner(ctx: RequestContext, a: LoadedAppt) {
  return ctx.org!.role === "PATIENT" && a.patientOwnerUserId === ctx.userId;
}

export async function confirmAppointment(ctx: RequestContext, id: string) {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN");
  return applyStatusChange(ctx, id, "CONFIRM", { confirmedAt: new Date() }, "APPOINTMENT_CONFIRMED", {
    scheduleReminders: true,
  });
}

export async function noShowAppointment(ctx: RequestContext, id: string) {
  const a = await loadForTransition(ctx, id);
  if (!(isAssignedDoctor(ctx, a))) assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN");
  if (Date.now() < a.scheduledStart.getTime()) {
    throw new AppError("CONFLICT", "Cannot mark no-show before the appointment time.");
  }
  return applyStatusChange(ctx, id, "NO_SHOW", { noShowMarkedAt: new Date() }, "APPOINTMENT_NO_SHOW", {
    cancelReminders: true,
  });
}

export async function startConsultation(ctx: RequestContext, id: string) {
  const a = await loadForTransition(ctx, id);
  if (!isAssignedDoctor(ctx, a)) {
    throw new AppError("FORBIDDEN", "Only the assigned doctor can start the consultation.");
  }
  return applyStatusChange(
    ctx,
    id,
    "START",
    { consultationStartedAt: new Date() },
    "APPOINTMENT_STARTED",
    { cancelReminders: true },
  );
}

export async function completeConsultation(ctx: RequestContext, id: string) {
  const a = await loadForTransition(ctx, id);
  if (!isAssignedDoctor(ctx, a)) {
    throw new AppError("FORBIDDEN", "Only the assigned doctor can complete the consultation.");
  }
  return applyStatusChange(ctx, id, "COMPLETE", { completedAt: new Date() }, "APPOINTMENT_COMPLETED", {});
}

export async function cancelAppointment(
  ctx: RequestContext,
  id: string,
  input: { reason: string },
) {
  const a = await loadForTransition(ctx, id);
  const staff = ["RECEPTIONIST", "CLINIC_ADMIN"].includes(ctx.org!.role);
  if (!staff && !isAssignedDoctor(ctx, a) && !isPatientOwner(ctx, a)) {
    throw new AppError("FORBIDDEN", "You cannot cancel this appointment.");
  }
  if (isPatientOwner(ctx, a) && !staff) {
    const settings = await tenantDb(ctx).clinicSettings.findFirstOrThrow({
      where: { organizationId: ctx.org!.id },
    });
    const windowMs = settings.cancellationWindowHours * 60 * 60_000;
    if (a.scheduledStart.getTime() - Date.now() < windowMs) {
      throw new AppError(
        "OUTSIDE_CANCELLATION_WINDOW",
        `Cancellations must be at least ${settings.cancellationWindowHours}h before the appointment.`,
      );
    }
  }

  const to = nextStatus(a.status, "CANCEL");
  const now = new Date();
  const updated = await db.$transaction(async (tx) => {
    const appt = await tx.appointment.update({
      where: { id },
      data: {
        status: to,
        cancelledAt: now,
        cancelledById: ctx.userId,
        cancellationReason: input.reason,
      },
    });
    await tx.appointmentEvent.create({
      data: {
        organizationId: a.organizationId,
        appointmentId: id,
        fromStatus: a.status,
        toStatus: to,
        actorId: ctx.userId,
        reason: input.reason,
      },
    });
    // Drop any queue entry.
    await tx.queueEntry.updateMany({
      where: { appointmentId: id, state: { in: ["WAITING", "CALLED"] } },
      data: { state: "SKIPPED", skippedAt: now },
    });
    await cancelReminders(tx, id);
    await writeAuditWith(tx, ctx, {
      action: "APPOINTMENT_CANCELLED",
      entityType: "Appointment",
      entityId: id,
      before: { status: a.status },
      after: { status: to, reason: input.reason },
    });
    return appt;
  });

  await notify({
    organizationId: a.organizationId,
    userId: a.patientOwnerUserId,
    event: "APPOINTMENT_CANCELLED",
    payload: { appointmentId: id, reason: input.reason },
  });
  return updated;
}

export async function checkInAppointment(ctx: RequestContext, id: string) {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN");
  const a = await loadForTransition(ctx, id);
  // CONFIRMED -> CHECKED_IN -> (enqueue) -> WAITING
  nextStatus(a.status, "CHECK_IN");
  const now = new Date();

  const result = await db.$transaction(async (tx) => {
    await tx.appointment.update({
      where: { id },
      data: { status: "CHECKED_IN", checkedInAt: now },
    });
    await tx.appointmentEvent.create({
      data: {
        organizationId: a.organizationId,
        appointmentId: id,
        fromStatus: a.status,
        toStatus: "CHECKED_IN",
        actorId: ctx.userId,
        reason: "check-in",
      },
    });

    const entry = await createEntryForCheckIn(tx, {
      id: a.id,
      organizationId: a.organizationId,
      doctorId: a.doctorId,
      patientId: a.patientId,
      locationId: a.locationId,
      scheduledStart: a.scheduledStart,
      timezone: a.timezone,
    });

    const appt = await tx.appointment.update({
      where: { id },
      data: { status: "WAITING" },
    });
    await tx.appointmentEvent.create({
      data: {
        organizationId: a.organizationId,
        appointmentId: id,
        fromStatus: "CHECKED_IN",
        toStatus: "WAITING",
        actorId: ctx.userId,
        reason: "enqueue",
      },
    });
    await cancelReminders(tx, id);
    await writeAuditWith(tx, ctx, {
      action: "PATIENT_CHECKED_IN",
      entityType: "Appointment",
      entityId: id,
      after: { queueEntryId: entry.id, tokenNumber: entry.tokenNumber },
    });
    return { appt, entry };
  });

  await notify({
    organizationId: a.organizationId,
    userId: a.patientOwnerUserId,
    event: "CHECK_IN_CONFIRMED",
    payload: { appointmentId: id, tokenNumber: result.entry.tokenNumber },
  });
  return { appointment: result.appt, queue: result.entry };
}

export async function rescheduleAppointment(
  ctx: RequestContext,
  id: string,
  input: z.infer<typeof rescheduleSchema>,
) {
  const a = await loadForTransition(ctx, id);
  const staff = ["RECEPTIONIST", "CLINIC_ADMIN"].includes(ctx.org!.role);
  if (!staff && !isAssignedDoctor(ctx, a) && !isPatientOwner(ctx, a)) {
    throw new AppError("FORBIDDEN", "You cannot reschedule this appointment.");
  }
  nextStatus(a.status, "RESCHEDULE"); // validates the source state

  const newStart = new Date(input.scheduledStart);
  const orgId = a.organizationId;

  const created = await runSerializable(async (tx) => {
    const settings = await tx.clinicSettings.findFirstOrThrow({
      where: { organizationId: orgId },
    });
    let duration = settings.defaultAppointmentDurationMin;
    if (input.appointmentTypeId) {
      const type = await tx.appointmentType.findFirst({
        where: { id: input.appointmentTypeId, organizationId: orgId },
        select: { durationMinutes: true },
      });
      if (!type) throw new AppError("NOT_FOUND", "Appointment type not found.");
      duration = type.durationMinutes;
    }
    const newEnd = new Date(newStart.getTime() + duration * 60_000);
    if (newStart.getTime() < Date.now() + settings.bookingLeadTimeMinutes * 60_000) {
      throw new AppError("CONFLICT", "That time is too soon to book.");
    }
    await assertWithinAvailability(tx, orgId, a.doctorId, newStart, newEnd, a.timezone);

    const newStatus: AppointmentStatus = ["CONFIRMED", "CHECKED_IN", "WAITING"].includes(
      a.status,
    )
      ? "CONFIRMED"
      : "REQUESTED";

    const fresh = await tx.appointment.create({
      data: {
        organizationId: orgId,
        patientId: a.patientId,
        doctorId: a.doctorId,
        locationId: a.locationId,
        appointmentTypeId: input.appointmentTypeId ?? null,
        scheduledStart: newStart,
        scheduledEnd: newEnd,
        timezone: a.timezone,
        status: newStatus,
        reason: input.reason ?? null,
        bookingSource: bookingSourceFor(ctx.org!.role),
        createdById: ctx.userId,
        confirmedAt: newStatus === "CONFIRMED" ? new Date() : null,
        rescheduledFromId: a.id,
      },
    });
    await tx.appointment.update({
      where: { id: a.id },
      data: { status: "RESCHEDULED" },
    });
    await tx.appointmentEvent.createMany({
      data: [
        {
          organizationId: orgId,
          appointmentId: a.id,
          fromStatus: a.status,
          toStatus: "RESCHEDULED",
          actorId: ctx.userId,
          reason: "reschedule:out",
        },
        {
          organizationId: orgId,
          appointmentId: fresh.id,
          fromStatus: null,
          toStatus: newStatus,
          actorId: ctx.userId,
          reason: "reschedule:in",
        },
      ],
    });
    await cancelReminders(tx, a.id);
    if (newStatus === "CONFIRMED") {
      await scheduleReminders(tx, fresh.id, orgId, a.patientOwnerUserId, newStart);
    }
    await writeAuditWith(tx, ctx, {
      action: "APPOINTMENT_RESCHEDULED",
      entityType: "Appointment",
      entityId: a.id,
      before: { scheduledStart: a.scheduledStart, status: a.status },
      after: { newAppointmentId: fresh.id, scheduledStart: newStart },
    });
    return fresh;
  });

  await notify({
    organizationId: orgId,
    userId: a.patientOwnerUserId,
    event: "APPOINTMENT_RESCHEDULED",
    payload: { previousId: a.id, appointmentId: created.id, scheduledStart: created.scheduledStart },
  });
  return { previousId: a.id, appointment: created };
}

// ---------------------------------------------------------------------------

async function applyStatusChange(
  ctx: RequestContext,
  id: string,
  action: AppointmentAction,
  timestamps: Record<string, Date>,
  auditAction: string,
  opts: { scheduleReminders?: boolean; cancelReminders?: boolean },
) {
  const t = tenantDb(ctx);
  const before = await t.appointment.findFirstOrThrow({
    where: { id, organizationId: ctx.org!.id },
    include: { patient: { select: { ownerUserId: true } } },
  });
  const to = nextStatus(before.status, action);

  const updated = await db.$transaction(async (tx) => {
    const appt = await tx.appointment.update({
      where: { id },
      data: { status: to, ...timestamps },
    });
    await tx.appointmentEvent.create({
      data: {
        organizationId: ctx.org!.id,
        appointmentId: id,
        fromStatus: before.status,
        toStatus: to,
        actorId: ctx.userId,
        reason: action.toLowerCase(),
      },
    });
    if (opts.scheduleReminders) {
      await scheduleReminders(tx, id, ctx.org!.id, before.patient.ownerUserId, before.scheduledStart);
    }
    if (opts.cancelReminders) {
      await cancelReminders(tx, id);
    }
    await writeAuditWith(tx, ctx, {
      action: auditAction,
      entityType: "Appointment",
      entityId: id,
      before: { status: before.status },
      after: { status: to },
    });
    return appt;
  });

  await notify({
    organizationId: ctx.org!.id,
    userId: before.patient.ownerUserId,
    event: auditAction,
    payload: { appointmentId: id, status: to },
  });
  return updated;
}
