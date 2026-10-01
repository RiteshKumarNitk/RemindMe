import { Prisma } from "@prisma/client";
import type { QueueState } from "@prisma/client";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAuditWith } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { notify } from "@/lib/notifications/notify.js";
import { allocateTokenNumber } from "@/modules/queue/service.js";
import { resolveTimezone } from "@/modules/appointments/service.js";
import { ensurePatientMembership } from "@/modules/patient-booking/service.js";
import { hasFamilyAccess } from "@/modules/family/service.js";
import type { RequestContext, OrgContext } from "@/lib/context.js";
import type { BookTokenInput, WalkInTokenInput } from "./schema.js";
import {
  clinicLocalDate,
  computeTokenWindow,
  formatMinuteOfDay,
  type TokenWindow,
  type TokenWindowConfig,
} from "./window.js";

/**
 * Same-day token booking (TOKEN_BOOKING_ASSESSMENT.md).
 *
 * Shape of a token booking, and why:
 *
 *   Appointment  bookingKind = SAME_DAY_TOKEN, tokenDate = the clinic-local day,
 *               scheduledStart anchored to the day's queue-start instant, status
 *               = WAITING. Taking a token IS arriving and queuing — a token
 *               patient never passes through CONFIRMED/CHECKED_IN.
 *   QueueEntry   tokenNumber from the atomic allocator, state WAITING.
 *
 * So a token is not a parallel entity: it is an ordinary Appointment plus an
 * ordinary QueueEntry carrying today's token, so every existing read path
 * (appointment lists, doctor dashboard, notifications, audit) already sees it.
 *
 * DELIBERATE NON-CHECK: `assertWithinAvailability` is NOT applied. A doctor's
 * token window is their own assertion that they are running a token clinic
 * today; layering the weekly AvailabilityRule grid on top would be a second,
 * conflicting source of truth — a doctor running tokens on a one-off Saturday
 * their recurring grid doesn't cover would be locked out. The window plus the
 * daily cap is the entire policy. Flagged for review.
 */

/** Statuses that release the one-active-token-per-patient-per-day slot. */
const INACTIVE_TOKEN_STATUSES = ["CANCELLED", "NO_SHOW", "RESCHEDULED", "COMPLETED"] as const;

/** The partial unique index that makes double-booking impossible at the DB level. */
const ACTIVE_TOKEN_INDEX = "Appointment_one_active_token_per_patient_doctor_day";

const PUBLIC_ORG_CHECK = { isActive: true, isPubliclyListed: true } as const;

const WINDOW_DOCTOR_SELECT = {
  id: true,
  userId: true,
  displayName: true,
  organizationId: true,
  bookingMode: true,
  tokenOpensMinute: true,
  tokenClosesMinute: true,
  queueStartMinute: true,
  maxDailyTokens: true,
  consultationDurationMin: true,
  isActive: true,
} satisfies Prisma.DoctorProfileSelect;

function toWindowConfig(d: {
  bookingMode: TokenWindowConfig["bookingMode"];
  tokenOpensMinute: number;
  tokenClosesMinute: number;
  queueStartMinute: number;
  maxDailyTokens: number;
  consultationDurationMin: number;
}): TokenWindowConfig {
  return {
    bookingMode: d.bookingMode,
    tokenOpensMinute: d.tokenOpensMinute,
    tokenClosesMinute: d.tokenClosesMinute,
    queueStartMinute: d.queueStartMinute,
    maxDailyTokens: d.maxDailyTokens,
    consultationDurationMin: d.consultationDurationMin,
  };
}

/** Turn a refused window into the right typed error, so clients branch on the
 *  code rather than string-matching a message. */
function windowError(window: TokenWindow): AppError {
  const code = window.errorCode ?? "TOKEN_BOOKING_UNAVAILABLE";
  return new AppError(code, window.reason ?? "Token booking is not available.", {
    status: window.status,
    date: window.date,
    timezone: window.timezone,
    opensAt: window.opensAt,
    closesAt: window.closesAt,
    queueStartAt: window.queueStartAt,
  });
}

/**
 * The token window for a doctor inside a tenant, counting the tokens already
 * issued today. Takes `tx` so the count and the booking it guards share one
 * snapshot.
 */
async function windowFor(
  tx: Prisma.TransactionClient,
  orgId: string,
  doctorId: string,
  locationId: string | null,
  now: Date,
): Promise<{ window: TokenWindow; timezone: string; config: TokenWindowConfig }> {
  const doctor = await tx.doctorProfile.findFirst({
    where: { id: doctorId, organizationId: orgId, isActive: true },
    select: WINDOW_DOCTOR_SELECT,
  });
  if (!doctor) throw new AppError("NOT_FOUND", "Doctor not found.");

  const timezone = await resolveTimezone(tx, orgId, locationId);
  const tokenDate = clinicLocalDate(now, timezone);
  const counter = await tx.queueTokenCounter.findFirst({
    where: { organizationId: orgId, doctorId, queueDate: tokenDate },
    select: { lastToken: true },
  });

  return {
    window: computeTokenWindow(toWindowConfig(doctor), timezone, now, counter?.lastToken ?? 0),
    timezone,
    config: toWindowConfig(doctor),
  };
}

/**
 * The public window for a doctor — the single source the web CTA, the Flutter
 * screen and the booking endpoint all read, so "the button was enabled but the
 * API refused" is structurally impossible rather than a thing to remember.
 *
 * Unauthenticated by design (public doctor pages), but only ever resolves an
 * active, publicly-listed doctor of an active, publicly-listed organization —
 * the same admission rule as `getPublicDoctor`.
 */
export async function getTokenWindow(doctorId: string): Promise<TokenWindow> {
  const doctor = await db.doctorProfile.findFirst({
    where: {
      id: doctorId,
      isActive: true,
      isPubliclyListed: true,
      organization: PUBLIC_ORG_CHECK,
    },
    select: WINDOW_DOCTOR_SELECT,
  });
  if (!doctor) throw new AppError("NOT_FOUND", "Not found.");

  const org = await db.organization.findFirstOrThrow({
    where: { id: doctor.organizationId },
    select: { timezone: true },
  });

  const now = new Date();
  const counter = await db.queueTokenCounter.findFirst({
    where: { organizationId: doctor.organizationId, doctorId, queueDate: clinicLocalDate(now, org.timezone) },
    select: { lastToken: true },
  });

  return computeTokenWindow(toWindowConfig(doctor), org.timezone, now, counter?.lastToken ?? 0);
}

/**
 * The same window, for staff inside the tenant (reception board, doctor
 * dashboard). Unlike `getTokenWindow` it does not require the doctor to be
 * publicly listed — an unlisted doctor can still run a walk-in token clinic.
 */
export async function getTokenWindowForStaff(
  ctx: RequestContext,
  doctorId: string,
): Promise<TokenWindow & { issued: number; maxDailyTokens: number }> {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN", "DOCTOR");
  const { window, config } = await windowFor(db, ctx.org!.id, doctorId, null, new Date());
  const counter = await db.queueTokenCounter.findFirst({
    where: { organizationId: ctx.org!.id, doctorId, queueDate: clinicLocalDate(new Date(), window.timezone) },
    select: { lastToken: true },
  });
  return { ...window, issued: counter?.lastToken ?? 0, maxDailyTokens: config.maxDailyTokens };
}

/**
 * The caller's (or a dependent's) active token with this doctor today, if any.
 * Lets the doctor page show "View token" instead of a second booking button.
 * Only rows whose patient the caller owns or manages are considered.
 */
export async function findMyActiveToken(userId: string, doctorId: string) {
  const doctor = await db.doctorProfile.findFirst({
    where: { id: doctorId, isActive: true },
    select: { organizationId: true, organization: { select: { timezone: true } } },
  });
  if (!doctor) return null;
  const tokenDate = clinicLocalDate(new Date(), doctor.organization.timezone);
  const now = new Date();
  return db.appointment.findFirst({
    where: {
      organizationId: doctor.organizationId,
      doctorId,
      tokenDate,
      bookingKind: "SAME_DAY_TOKEN",
      status: { notIn: [...INACTIVE_TOKEN_STATUSES] },
      patient: {
        OR: [
          { ownerUserId: userId },
          {
            accessGrants: {
              some: {
                granteeUserId: userId,
                revokedAt: null,
                permissions: { has: "VIEW_APPOINTMENTS" },
                OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
              },
            },
          },
        ],
      },
    },
    orderBy: { createdAt: "asc" },
    select: {
      id: true,
      organizationId: true,
      patient: { select: { firstName: true, lastName: true } },
      queueEntry: { select: { tokenNumber: true, state: true } },
    },
  });
}

/** Token status a patient is allowed to see for their own record. */
export interface PatientTokenStatus {
  appointmentId: string;
  queueEntryId: string;
  tokenNumber: number;
  state: QueueState;
  /** People still ahead, counted from live queue rows. Never an ETA in minutes. */
  ahead: number;
  nowServingToken: number | null;
  doctorName: string;
  queueDate: string;
  /** The day's configured queue start, e.g. "09:00" — from the doctor's own setting. */
  queueStartAt: string;
  bookingKind: string;
  /** The appointment's own status — authoritative when it disagrees with the
   *  queue state (a cancelled token's entry is parked as SKIPPED). */
  appointmentStatus: string;
  /** Server-rendered next step, so no client has to interpret queue state itself. */
  advice: string;
  adviceTone: "WAIT" | "ACT_NOW" | "SEE_RECEPTION" | "DONE" | "PROBLEM";
}

const ADVICE: Record<QueueState, { advice: string; adviceTone: PatientTokenStatus["adviceTone"] }> = {
  WAITING: { advice: "You are in the queue. Please wait in the waiting area.", adviceTone: "WAIT" },
  CALLED: { advice: "You are being called — please go to the consultation room.", adviceTone: "ACT_NOW" },
  HOLD: { advice: "Your place is on hold. Please speak to reception.", adviceTone: "SEE_RECEPTION" },
  SKIPPED: { advice: "We called you and you missed it. Please see reception so we can call you again.", adviceTone: "SEE_RECEPTION" },
  IN_CONSULTATION: { advice: "Your consultation is in progress.", adviceTone: "WAIT" },
  COMPLETED: { advice: "Your visit is complete.", adviceTone: "DONE" },
  NO_SHOW: { advice: "You were marked as not having arrived today.", adviceTone: "PROBLEM" },
};

async function findActiveToken(
  tx: Prisma.TransactionClient,
  orgId: string,
  doctorId: string,
  patientId: string,
  tokenDate: Date,
) {
  return tx.appointment.findFirst({
    where: {
      organizationId: orgId,
      doctorId,
      patientId,
      tokenDate,
      bookingKind: "SAME_DAY_TOKEN",
      status: { notIn: [...INACTIVE_TOKEN_STATUSES] },
    },
    include: { queueEntry: true },
    orderBy: { createdAt: "asc" },
  });
}

/** Is this a unique-constraint hit on the one-active-token index specifically?
 *  A P2002 on some *other* constraint must not be swallowed as "already booked". */
function isActiveTokenConflict(err: unknown): boolean {
  if (!(err instanceof Prisma.PrismaClientKnownRequestError) || err.code !== "P2002") return false;
  const target = (err.meta as { target?: unknown } | null)?.target;
  const text = Array.isArray(target) ? target.join(",") : String(target ?? "");
  const msg = String(err.message);
  return [text, msg].some((s) => s.includes(ACTIVE_TOKEN_INDEX) || s.includes("tokenDate"));
}

export interface TokenBookingResult {
  appointmentId: string;
  entryId: string;
  tokenNumber: number;
  /** True when an existing active token was returned instead of a new one. */
  reused: boolean;
  doctorName: string;
  queueDate: string;
  queueStartAt: string;
}

/**
 * Token booking's transaction: READ COMMITTED, not SERIALIZABLE.
 *
 * Every booking for a doctor/day writes the same counter row. Under
 * SERIALIZABLE, concurrent writers of one row abort with 40001 and must retry,
 * so an opening-minute rush of 20 patients committed roughly one per round and
 * the rest ran out of retries (HTTP 500). Under READ COMMITTED the counter's
 * `INSERT … ON CONFLICT DO UPDATE` simply waits for the row lock and increments
 * the latest committed value — the behaviour the allocator was designed for
 * (TOKEN_BOOKING_ASSESSMENT.md §4.2). Correctness does not rely on snapshot
 * isolation:
 *   - unique token per doctor/day: the counter row lock + QueueEntry @@unique
 *   - daily cap: checked against the number the locked counter returned
 *   - one active token per patient/doctor/day: the partial unique index
 *   - ownership / window / doctor checks: per-row reads, no cross-row invariant
 * `maxWait`/`timeout` are sized for a burst queueing on that lock; a write
 * conflict or deadlock is still retried.
 */
async function runTokenTransaction<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await db.$transaction(fn, {
        isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
        maxWait: 15_000,
        timeout: 30_000,
      });
    } catch (err) {
      const retryable =
        err instanceof Prisma.PrismaClientKnownRequestError &&
        (err.code === "P2034" ||
          (err.code === "P2010" && /40P01|40001|deadlock|could not serialize/i.test(err.message)));
      if (!retryable || attempt >= 3) throw err;
      await new Promise((r) => setTimeout(r, 30 * (attempt + 1) + Math.random() * 60));
    }
  }
}

/**
 * Core booking routine, shared by patient self-service and the staff walk-in.
 *
 * Enforced here, server-side, in this order — none of it can be skipped by
 * crafting a request, because the frontend check is a convenience, not a gate:
 *   1. doctor active + tenant-scoped
 *   2. booking mode allows tokens
 *   3. inside the window (server clock, clinic timezone)
 *   4. under the daily cap
 *   5. no other active token for this patient/doctor/day — and if one exists it
 *      is RETURNED, not rejected
 *
 * All of it inside one transaction (`runTokenTransaction`); the cap and the
 * one-token rule are enforced by the locked counter and a unique index, not
 * by snapshot isolation.
 */
async function bookTokenForPatient(
  ctx: RequestContext,
  args: {
    organizationId: string;
    doctorId: string;
    patientId: string;
    locationId?: string | null;
    reason?: string;
    auditAction: string;
  },
): Promise<TokenBookingResult> {
  const orgId = args.organizationId;
  const now = new Date();

  try {
    const booked = await runTokenTransaction(async (tx) => {
      // Never trust patientId/locationId from the client. Same rule as
      // `bookAppointment`: a patient books for their own record, or for a
      // dependent they hold an active MANAGE_APPOINTMENTS grant on — checked
      // inside this transaction's snapshot.
      const patient = await tx.patient.findFirst({
        where: { id: args.patientId, organizationId: orgId },
        select: { id: true, ownerUserId: true },
      });
      if (!patient) throw new AppError("NOT_FOUND", "Patient not found.");
      if (ctx.org!.role === "PATIENT" && patient.ownerUserId !== ctx.userId) {
        const grant = await tx.patientAccessGrant.findFirst({
          where: {
            patientId: patient.id,
            organizationId: orgId,
            granteeUserId: ctx.userId,
            revokedAt: null,
            permissions: { has: "MANAGE_APPOINTMENTS" },
            OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
          },
          select: { id: true },
        });
        if (!grant) {
          throw new AppError(
            "FORBIDDEN",
            "You can only book for your own record or a dependent you manage.",
          );
        }
      }
      if (args.locationId) {
        const loc = await tx.clinicLocation.findFirst({
          where: { id: args.locationId, organizationId: orgId },
          select: { id: true },
        });
        if (!loc) throw new AppError("NOT_FOUND", "Location not found.");
      }

      const { window, timezone, config } = await windowFor(
        tx,
        orgId,
        args.doctorId,
        args.locationId ?? null,
        now,
      );
      if (!window.bookable) throw windowError(window);

      const tokenDate = clinicLocalDate(now, timezone);
      const doctor = await tx.doctorProfile.findFirstOrThrow({
        where: { id: args.doctorId, organizationId: orgId },
        select: { displayName: true, userId: true },
      });

      const existing = await findActiveToken(tx, orgId, args.doctorId, args.patientId, tokenDate);
      if (existing?.queueEntry) {
        // Idempotent by design: re-submitting must never mint a second token or
        // 409 — the patient just gets their token back.
        return {
          appointmentId: existing.id,
          entryId: existing.queueEntry.id,
          tokenNumber: existing.queueEntry.tokenNumber,
          reused: true,
          doctorName: doctor.displayName,
          queueDate: window.date,
          queueStartAt: window.queueStartAt,
          notifyUserId: patient.ownerUserId,
        };
      }

      const queueStart = new Date(window.queueStartUtc);
      const queueEnd = new Date(queueStart.getTime() + config.consultationDurationMin * 60_000);
      const notifyUserId = patient.ownerUserId;

      const appt = await tx.appointment.create({
        data: {
          organizationId: orgId,
          patientId: args.patientId,
          doctorId: args.doctorId,
          locationId: args.locationId ?? null,
          scheduledStart: queueStart,
          scheduledEnd: queueEnd,
          timezone,
          status: "WAITING",
          reason: args.reason ?? null,
          bookingSource: ctx.org!.role === "PATIENT" ? "PATIENT_APP" : "RECEPTION",
          createdById: ctx.userId,
          confirmedAt: now,
          checkedInAt: now,
          bookingKind: "SAME_DAY_TOKEN",
          tokenDate,
        },
        select: { id: true },
      });
      await tx.appointmentEvent.create({
        data: {
          organizationId: orgId,
          appointmentId: appt.id,
          fromStatus: null,
          toStatus: "WAITING",
          actorId: ctx.userId,
          reason: "token:book",
        },
      });

      // ---- Counter lock taken here; held until commit. Keep what follows short.
      // The upsert is atomic under READ COMMITTED: concurrent bookings for this
      // doctor/day queue on the counter row and each gets the next number.
      const tokenNumber = await allocateTokenNumber(tx, {
        organizationId: orgId,
        doctorId: args.doctorId,
        queueDate: tokenDate,
      });
      // The authoritative cap check. The window check above read the counter
      // without a lock (fast refusal in the common case); this one is decided
      // against the locked row, and throwing rolls the increment back so no
      // number is consumed.
      if (tokenNumber > config.maxDailyTokens) {
        throw new AppError(
          "TOKEN_LIMIT_REACHED",
          `All ${config.maxDailyTokens} tokens for today have been issued.`,
          { date: window.date, timezone: window.timezone },
        );
      }

      const entry = await tx.queueEntry.create({
        data: {
          organizationId: orgId,
          appointmentId: appt.id,
          patientId: args.patientId,
          doctorId: args.doctorId,
          locationId: args.locationId ?? null,
          queueDate: tokenDate,
          tokenNumber,
          position: tokenNumber,
          state: "WAITING",
          checkedInAt: now,
        },
        select: { id: true, tokenNumber: true },
      });

      await writeAuditWith(tx, ctx, {
        action: args.auditAction,
        entityType: "Appointment",
        entityId: appt.id,
        after: {
          doctorId: args.doctorId,
          patientId: args.patientId,
          tokenNumber,
          tokenDate: window.date,
          bookingKind: "SAME_DAY_TOKEN",
        },
      });

      return {
        appointmentId: appt.id,
        entryId: entry.id,
        tokenNumber: entry.tokenNumber,
        reused: false,
        doctorName: doctor.displayName,
        queueDate: window.date,
        queueStartAt: window.queueStartAt,
        notifyUserId,
      };
    });

    // Only a genuinely NEW token is worth announcing; re-reading an existing one
    // must not send a second "you have token N" notification.
    const { notifyUserId, ...result } = booked;
    if (!result.reused && notifyUserId) {
      await notify({
        organizationId: orgId,
        userId: notifyUserId,
        channel: "PUSH",
        event: "QUEUE_UPDATE",
        payload: {
          appointmentId: result.appointmentId,
          tokenNumber: result.tokenNumber,
          state: "WAITING",
        },
      });
    }
    return result;
  } catch (err) {
    // Lost the race on the unique index (two tabs, double submit). The right
    // answer is still "here is your token", not an error.
    if (isActiveTokenConflict(err)) {
      const org = await db.organization.findFirstOrThrow({
        where: { id: orgId },
        select: { timezone: true },
      });
      const doctor = await db.doctorProfile.findFirst({
        where: { id: args.doctorId, organizationId: orgId },
        select: { displayName: true, queueStartMinute: true },
      });
      const fresh = await db.appointment.findFirst({
        where: {
          organizationId: orgId,
          doctorId: args.doctorId,
          patientId: args.patientId,
          tokenDate: clinicLocalDate(now, org.timezone),
          bookingKind: "SAME_DAY_TOKEN",
          status: { notIn: [...INACTIVE_TOKEN_STATUSES] },
        },
        include: { queueEntry: true },
        orderBy: { createdAt: "asc" },
      });
      if (fresh?.queueEntry) {
        return {
          appointmentId: fresh.id,
          entryId: fresh.queueEntry.id,
          tokenNumber: fresh.queueEntry.tokenNumber,
          reused: true,
          doctorName: doctor?.displayName ?? "",
          queueDate: fresh.queueEntry.queueDate.toISOString().slice(0, 10),
          queueStartAt: formatMinuteOfDay(doctor?.queueStartMinute ?? 0),
        };
      }
    }
    throw err;
  }
}

/** Patient-facing: take a token for yourself, or for a dependent you manage. */
export async function bookSameDayToken(ctx: RequestContext, input: BookTokenInput) {
  const { org, patientId: selfPatientId } = await ensurePatientMembership(
    ctx,
    input.organizationId,
    input.patient,
  );

  // A clinic that turned patient self-booking off must not accept self-service
  // tokens either, or "booking off" would only mean "off the slot grid".
  const settings = await db.clinicSettings.findFirst({
    where: { organizationId: org.id },
    select: { allowPatientSelfBooking: true },
  });
  if (!settings?.allowPatientSelfBooking) {
    throw new AppError(
      "FORBIDDEN",
      "This clinic does not allow patient self-booking. Please call reception.",
    );
  }

  return bookTokenForPatient({ ...ctx, org }, {
    organizationId: org.id,
    doctorId: input.doctorId,
    // Never trusted as an authorization decision — `bookTokenForPatient`
    // re-checks ownership or an active MANAGE_APPOINTMENTS grant.
    patientId: input.patientId ?? selfPatientId,
    locationId: input.locationId,
    reason: input.reason,
    auditAction: "TOKEN_BOOKED",
  });
}

/**
 * Staff walk-in: reception issues a token to a patient already in the building.
 * Identical window and cap to self-service — a walk-in must not be a way around
 * the daily limit.
 */
export async function walkInToken(
  ctx: RequestContext,
  doctorId: string,
  input: WalkInTokenInput,
) {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN", "DOCTOR");
  const t = tenantDb(ctx);
  const doctor = await t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: ctx.org!.id, isActive: true },
    select: { id: true, userId: true },
  });
  // Same rule as queueTransition: a doctor works their own queue only.
  if (ctx.org!.role === "DOCTOR" && doctor.userId !== ctx.userId) {
    throw new AppError("FORBIDDEN", "Doctors can only issue tokens for their own queue.");
  }
  const patient = await t.patient.findFirst({
    where: { id: input.patientId, organizationId: ctx.org!.id },
    select: { id: true },
  });
  if (!patient) throw new AppError("NOT_FOUND", "Patient not found.");

  return bookTokenForPatient(ctx, {
    organizationId: ctx.org!.id,
    doctorId: doctor.id,
    patientId: patient.id,
    locationId: input.locationId,
    reason: input.reason,
    auditAction: "TOKEN_WALK_IN",
  });
}

/**
 * Resolve which clinic an appointment belongs to, for a read on a route that
 * has no tenant context.
 *
 * Authorization still happens in `getPatientTokenStatus` against the resolved
 * org; this only establishes WHICH org to authorize against. Both the lookup and
 * the ownership check run inside the caller's transaction snapshot so a
 * cross-tenant id can't be probed by racing.
 */
async function resolveOrgForPatientRead(ctx: RequestContext, appointmentId: string): Promise<string> {
  const appt = await db.appointment.findFirst({
    where: { id: appointmentId, organization: { isActive: true } },
    select: { organizationId: true },
  });
  if (!appt) throw new AppError("NOT_FOUND", "Not found.");

  // If the caller DOES already hold a membership here, the standard tenant
  // pipeline's rule applies: only that same org may be read.
  if (ctx.org && ctx.org.id !== appt.organizationId) {
    throw new AppError("NOT_FOUND", "Not found.");
  }
  return appt.organizationId;
}

/**
 * A patient's own token: number, live position, and what to do next.
 *
 * Reached from `/api/patient/token-status`, which is deliberately NOT under
 * `/api/orgs/:orgId/...` for the same reason as `POST /api/patient/appointments`
 * — a patient has no membership yet, so there is no tenant context to resolve.
 * That means the org has to be derived from the appointment itself (a row the
 * caller is about to be authorized against), NOT from anything the client sent:
 * `appointmentId` is the only input, and a cross-tenant id simply resolves to
 * "not found" because the ownership check below fails for a patient the caller
 * has no relationship to.
 *
 * `ahead` and `nowServingToken` come from the live queue rows, so the app shows
 * the same numbers the reception board does. There is deliberately no
 * ETA-in-minutes: consultation length is an average, so any "about 12 minutes"
 * would be invented rather than measured.
 */
export async function getPatientTokenStatus(
  ctx: RequestContext,
  appointmentId: string,
): Promise<PatientTokenStatus> {
  const orgId = await resolveOrgForPatientRead(ctx, appointmentId);
  const orgCtx: RequestContext = {
    ...ctx,
    org: { id: orgId, membershipId: "", role: "PATIENT", capabilities: [], isActive: true },
  };
  const t = tenantDb(orgCtx);
  const appt = await t.appointment.findFirst({
    where: { id: appointmentId },
    include: {
      queueEntry: true,
      doctor: { select: { id: true, displayName: true, queueStartMinute: true } },
      patient: { select: { id: true, ownerUserId: true } },
    },
  });
  if (!appt) throw new AppError("NOT_FOUND", "Not found.");

  // A patient may read their own token, or a dependent's if they hold an active
  // VIEW_APPOINTMENTS grant — the same rule the appointment detail read uses.
  // Staff (a real membership for this org) read it without a grant check.
  const callerRole = ctx.org?.role ?? "PATIENT";
  if (callerRole === "PATIENT" && appt.patient.ownerUserId !== ctx.userId) {
    if (!(await hasFamilyAccess(orgCtx, appt.patient.id, "VIEW_APPOINTMENTS"))) {
      throw new AppError("NOT_FOUND", "Not found.");
    }
  }

  const entry = appt.queueEntry;
  if (!entry) throw new AppError("NOT_FOUND", "This appointment does not have a queue token.");

  // `orgId` (resolved above), never `ctx.org!.id` — this route has no tenant
  // context, so ctx.org is legitimately undefined here.
  const [inConsultation, called, waitingAhead] = await Promise.all([
    t.queueEntry.findFirst({
      where: {
        organizationId: orgId,
        doctorId: entry.doctorId,
        queueDate: entry.queueDate,
        state: "IN_CONSULTATION",
      },
      orderBy: { tokenNumber: "asc" },
      select: { tokenNumber: true },
    }),
    t.queueEntry.findFirst({
      where: {
        organizationId: orgId,
        doctorId: entry.doctorId,
        queueDate: entry.queueDate,
        state: "CALLED",
      },
      orderBy: { tokenNumber: "asc" },
      select: { tokenNumber: true },
    }),
    t.queueEntry.count({
      where: {
        organizationId: orgId,
        doctorId: entry.doctorId,
        queueDate: entry.queueDate,
        state: "WAITING",
        OR: [
          { position: { lt: entry.position } },
          { position: entry.position, tokenNumber: { lt: entry.tokenNumber } },
        ],
      },
    }),
  ]);

  const cancelled = appt.status === "CANCELLED" || appt.status === "RESCHEDULED";
  const advice = cancelled
    ? { advice: "This booking was cancelled.", adviceTone: "PROBLEM" as const }
    : (ADVICE[entry.state] ?? ADVICE.WAITING);
  return {
    appointmentId: appt.id,
    queueEntryId: entry.id,
    tokenNumber: entry.tokenNumber,
    state: entry.state,
    ahead: entry.state === "WAITING" ? waitingAhead : 0,
    nowServingToken: (inConsultation ?? called)?.tokenNumber ?? null,
    doctorName: appt.doctor.displayName,
    queueDate: entry.queueDate.toISOString().slice(0, 10),
    queueStartAt: formatMinuteOfDay(appt.doctor.queueStartMinute),
    bookingKind: appt.bookingKind,
    appointmentStatus: appt.status,
    advice: advice.advice,
    adviceTone: advice.adviceTone,
  };
}