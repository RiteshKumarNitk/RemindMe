import { z } from "zod";
import type { Prisma, PrismaClient } from "@prisma/client";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import {
  isoWeekday,
  localDateStringInZone,
  parseDateString,
  rangesOverlap,
  zonedWallTimeToUtc,
} from "@/lib/time.js";
import type { RequestContext } from "@/lib/context.js";
import type { createExceptionSchema, putRulesSchema } from "./schema.js";

type Db = PrismaClient | Prisma.TransactionClient | ReturnType<typeof tenantDb>;

/** Location tz wins over org tz. */
async function clinicTimezone(
  database: Db,
  organizationId: string,
  locationId?: string | null,
): Promise<string> {
  const org = await (database as PrismaClient).organization.findFirstOrThrow({
    where: { id: organizationId },
    select: { timezone: true },
  });
  if (locationId) {
    const loc = await (database as PrismaClient).clinicLocation.findFirst({
      where: { id: locationId, organizationId },
      select: { timezone: true },
    });
    if (loc?.timezone) return loc.timezone;
  }
  return org.timezone;
}

async function requireDoctorEditable(ctx: RequestContext, doctorId: string) {
  const t = tenantDb(ctx);
  const doc = await t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: ctx.org!.id },
    select: { id: true, userId: true },
  });
  if (doc.userId !== ctx.userId) assertRole(ctx, "CLINIC_ADMIN");
  return doc;
}

export async function getRules(ctx: RequestContext, doctorId: string) {
  const t = tenantDb(ctx);
  await t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: ctx.org!.id },
    select: { id: true },
  });
  return t.availabilityRule.findMany({
    where: { doctorId, organizationId: ctx.org!.id },
    orderBy: [{ weekday: "asc" }, { startMinute: "asc" }],
  });
}

export async function replaceRules(
  ctx: RequestContext,
  doctorId: string,
  input: z.infer<typeof putRulesSchema>,
) {
  await requireDoctorEditable(ctx, doctorId);
  const orgId = ctx.org!.id;

  const created = await db.$transaction(async (tx) => {
    await tx.availabilityRule.deleteMany({ where: { doctorId, organizationId: orgId } });
    if (input.rules.length === 0) return [];
    await tx.availabilityRule.createMany({
      data: input.rules.map((r) => ({
        organizationId: orgId,
        doctorId,
        locationId: r.locationId ?? null,
        weekday: r.weekday,
        startMinute: r.startMinute,
        endMinute: r.endMinute,
        slotMinutes: r.slotMinutes,
        effectiveFrom: r.effectiveFrom ? new Date(`${r.effectiveFrom}T00:00:00Z`) : null,
        effectiveTo: r.effectiveTo ? new Date(`${r.effectiveTo}T00:00:00Z`) : null,
      })),
    });
    return tx.availabilityRule.findMany({
      where: { doctorId, organizationId: orgId },
      orderBy: [{ weekday: "asc" }, { startMinute: "asc" }],
    });
  });

  await writeAudit(ctx, {
    action: "AVAILABILITY_RULES_REPLACED",
    entityType: "DoctorProfile",
    entityId: doctorId,
    after: { ruleCount: created.length },
  });
  return created;
}

export async function listExceptions(ctx: RequestContext, doctorId: string) {
  const t = tenantDb(ctx);
  return t.availabilityException.findMany({
    where: { doctorId, organizationId: ctx.org!.id },
    orderBy: { startsAt: "asc" },
  });
}

export async function createException(
  ctx: RequestContext,
  doctorId: string,
  input: z.infer<typeof createExceptionSchema>,
) {
  await requireDoctorEditable(ctx, doctorId);
  const t = tenantDb(ctx);
  const ex = await t.availabilityException.create({
    data: {
      organizationId: ctx.org!.id,
      doctorId,
      locationId: input.locationId ?? null,
      kind: input.kind,
      startsAt: new Date(input.startsAt),
      endsAt: new Date(input.endsAt),
      reason: input.reason ?? null,
      createdById: ctx.userId,
    },
  });
  await writeAudit(ctx, {
    action: "AVAILABILITY_EXCEPTION_CREATED",
    entityType: "AvailabilityException",
    entityId: ex.id,
    after: { kind: ex.kind, startsAt: ex.startsAt, endsAt: ex.endsAt },
  });
  return ex;
}

export async function deleteException(
  ctx: RequestContext,
  doctorId: string,
  exceptionId: string,
) {
  await requireDoctorEditable(ctx, doctorId);
  const t = tenantDb(ctx);
  await t.availabilityException.findFirstOrThrow({
    where: { id: exceptionId, doctorId, organizationId: ctx.org!.id },
    select: { id: true },
  });
  await t.availabilityException.delete({ where: { id: exceptionId } });
  await writeAudit(ctx, {
    action: "AVAILABILITY_EXCEPTION_DELETED",
    entityType: "AvailabilityException",
    entityId: exceptionId,
  });
  return { deleted: true };
}

// ---------------------------------------------------------------------------
// Slot calculation (APPOINTMENT_WORKFLOW.md "Slot calculation")
// ---------------------------------------------------------------------------

export interface FreeWindow {
  start: Date;
  end: Date;
  slotMinutes: number;
}
export interface Slot {
  start: string; // ISO UTC
  end: string; // ISO UTC
}

/**
 * The doctor's bookable windows on `dateStr` (clinic-local calendar day):
 * recurring rules for that weekday, minus DAY_OFF/HOLIDAY/LEAVE/BREAK,
 * plus EXTRA_HOURS. Timezone-correct via the clinic/location zone.
 */
export async function computeFreeWindows(
  database: Db,
  organizationId: string,
  doctorId: string,
  dateStr: string,
): Promise<{ windows: FreeWindow[]; timezone: string }> {
  const { y, m, d } = parseDateString(dateStr);
  const weekday = isoWeekday(y, m, d);

  const rules = await (database as PrismaClient).availabilityRule.findMany({
    where: { organizationId, doctorId, weekday, isActive: true },
  });
  const exceptions = await (database as PrismaClient).availabilityException.findMany({
    where: { organizationId, doctorId },
  });

  // Resolve tz from the first rule's location, else org.
  const locId = rules.find((r) => r.locationId)?.locationId ?? null;
  const tz = await clinicTimezone(database, organizationId, locId);

  const dateOnly = new Date(Date.UTC(y, m - 1, d));
  const effectiveRules = rules.filter((r) => {
    if (r.effectiveFrom && dateOnly < r.effectiveFrom) return false;
    if (r.effectiveTo && dateOnly > r.effectiveTo) return false;
    return true;
  });

  // Base windows from rules.
  let windows: FreeWindow[] = effectiveRules.map((r) => ({
    start: zonedWallTimeToUtc(y, m, d, Math.floor(r.startMinute / 60), r.startMinute % 60, tz),
    end: zonedWallTimeToUtc(y, m, d, Math.floor(r.endMinute / 60), r.endMinute % 60, tz),
    slotMinutes: r.slotMinutes,
  }));

  // Add EXTRA_HOURS that intersect this local day.
  for (const ex of exceptions) {
    if (ex.kind !== "EXTRA_HOURS") continue;
    if (!rangesOverlap(ex.startsAt, ex.endsAt, dayBoundStart(y, m, d, tz), dayBoundEnd(y, m, d, tz))) {
      continue;
    }
    windows.push({
      start: ex.startsAt,
      end: ex.endsAt,
      slotMinutes: effectiveRules[0]?.slotMinutes ?? 15,
    });
  }

  // Subtract blocking exceptions.
  const blockers = exceptions.filter((ex) =>
    ["DAY_OFF", "HOLIDAY", "LEAVE", "BREAK"].includes(ex.kind),
  );
  for (const b of blockers) {
    windows = windows.flatMap((w) => subtractInterval(w, b.startsAt, b.endsAt));
  }

  windows = windows.filter((w) => w.end > w.start).sort((a, b) => +a.start - +b.start);
  return { windows, timezone: tz };
}

function dayBoundStart(y: number, m: number, d: number, tz: string): Date {
  return zonedWallTimeToUtc(y, m, d, 0, 0, tz);
}
function dayBoundEnd(y: number, m: number, d: number, tz: string): Date {
  return zonedWallTimeToUtc(y, m, d, 23, 59, tz);
}

function subtractInterval(w: FreeWindow, cutStart: Date, cutEnd: Date): FreeWindow[] {
  if (cutEnd <= w.start || cutStart >= w.end) return [w];
  const out: FreeWindow[] = [];
  if (cutStart > w.start) out.push({ start: w.start, end: cutStart, slotMinutes: w.slotMinutes });
  if (cutEnd < w.end) out.push({ start: cutEnd, end: w.end, slotMinutes: w.slotMinutes });
  return out;
}

/** Full slot list for the API. */
export async function computeSlots(
  ctx: RequestContext,
  doctorId: string,
  dateStr: string,
  typeId?: string,
): Promise<{ slots: Slot[]; timezone: string; durationMinutes: number }> {
  const t = tenantDb(ctx);
  const orgId = ctx.org!.id;
  await t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: orgId },
    select: { id: true },
  });

  const settings = await t.clinicSettings.findFirstOrThrow({
    where: { organizationId: orgId },
  });
  let duration = settings.defaultAppointmentDurationMin;
  if (typeId) {
    const type = await t.appointmentType.findFirstOrThrow({
      where: { id: typeId, organizationId: orgId },
      select: { durationMinutes: true },
    });
    duration = type.durationMinutes;
  }

  const { windows, timezone } = await computeFreeWindows(db, orgId, doctorId, dateStr);

  // Existing active appointments for the doctor overlapping this day.
  const { y, m, d } = parseDateString(dateStr);
  const dayStart = zonedWallTimeToUtc(y, m, d, 0, 0, timezone);
  const dayEnd = zonedWallTimeToUtc(y, m, d + 1, 0, 0, timezone);
  const busy = await t.appointment.findMany({
    where: {
      organizationId: orgId,
      doctorId,
      status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED"] },
      scheduledStart: { lt: dayEnd },
      scheduledEnd: { gt: dayStart },
    },
    select: { scheduledStart: true, scheduledEnd: true },
  });

  const leadCutoff = new Date(Date.now() + settings.bookingLeadTimeMinutes * 60_000);
  const stepMs = (w: FreeWindow) => w.slotMinutes * 60_000;
  const durMs = duration * 60_000;

  const slots: Slot[] = [];
  for (const w of windows) {
    for (let s = +w.start; s + durMs <= +w.end + 1; s += stepMs(w)) {
      const start = new Date(s);
      const end = new Date(s + durMs);
      if (start < leadCutoff) continue;
      if (busy.some((b) => rangesOverlap(start, end, b.scheduledStart, b.scheduledEnd))) {
        continue;
      }
      slots.push({ start: start.toISOString(), end: end.toISOString() });
    }
  }
  return { slots, timezone, durationMinutes: duration };
}

/**
 * Booking-time check: is [start, end) fully inside a free availability window
 * for the doctor on that clinic-local day? (Overlap with existing appointments
 * is left to the EXCLUDE constraint.)
 */
export async function assertWithinAvailability(
  database: Db,
  organizationId: string,
  doctorId: string,
  start: Date,
  end: Date,
  timezone: string,
): Promise<void> {
  const dateStr = localDateStringInZone(start, timezone);
  const { windows } = await computeFreeWindows(database, organizationId, doctorId, dateStr);
  const ok = windows.some((w) => start >= w.start && end <= w.end);
  if (!ok) {
    throw new AppError(
      "OUTSIDE_AVAILABILITY",
      "That time is outside the doctor's availability.",
    );
  }
}
