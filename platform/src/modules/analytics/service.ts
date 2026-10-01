import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";

/**
 * Operations analytics for the owner dashboard, computed from rows the clinic
 * already produces — no new writes, no new state (same read-only composition
 * pattern as `clinics/insights.ts`). Window: the last 30 days.
 *
 *   • Wait time  — QueueEntry.checkedInAt → consultationStartedAt (minutes),
 *                  for entries that reached IN_CONSULTATION/COMPLETED.
 *   • No-show    — appointments whose scheduledStart passed: NO_SHOW ÷
 *                  (NO_SHOW + COMPLETED + WAITING-left-open handled as active
 *                  denominator = decided outcomes only).
 *   • Peak hours — booked appointments grouped by clock hour of scheduledStart.
 *
 * Aggregation happens in Postgres (not JS) so the query stays one round trip
 * even with thousands of rows.
 */

export interface ClinicAnalytics {
  windowDays: 30;
  generatedAt: string;
  totals: {
    appointments: number;
    completed: number;
    cancelled: number;
    noShow: number;
    checkedIn: number;
  };
  noShowRate: number | null; // percent of decided (completed+no-show) appointments
  cancellationRate: number | null; // percent of all appointments in window
  waitTimes: {
    sampleSize: number;
    medianMinutes: number | null;
    averageMinutes: number | null;
    p90Minutes: number | null;
    /** "Under 15 min", "15–30", "30–60", "60+" counts, for the bar strip. */
    buckets: Array<{ label: string; count: number }>;
  };
  peakHours: Array<{ hour: number; count: number }>; // 0–23, only hours with bookings
  perDoctor: Array<{
    doctorId: string;
    doctorName: string;
    appointments: number;
    noShow: number;
    noShowRate: number | null;
    medianWaitMinutes: number | null;
  }>;
}

function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid]! : Math.round((sorted[mid - 1]! + sorted[mid]!) / 2);
}

function p90(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.ceil(0.9 * sorted.length) - 1);
  return sorted[idx]!;
}

function rate(numerator: number, denominator: number): number | null {
  if (denominator === 0) return null;
  return Math.round((numerator / denominator) * 100);
}

export async function getClinicAnalytics(
  ctx: RequestContext,
  orgId: string,
): Promise<ClinicAnalytics> {
  const t = tenantDb(ctx);
  const since = new Date(Date.now() - 30 * 86_400_000);

  const [statusCounts, waits, perDoctorRows] = await Promise.all([
    // 1) Appointment outcome counts in the window (all non-rescheduled rows).
    t.appointment.groupBy({
      by: ["status"],
      where: {
        organizationId: orgId,
        scheduledStart: { gte: since },
        status: { notIn: ["RESCHEDULED"] },
      },
      _count: { _all: true },
    }),

    // 2) Wait-time samples: check-in → consultation start, minutes.
    t.queueEntry.findMany({
      where: {
        organizationId: orgId,
        checkedInAt: { gte: since, not: null },
        consultationStartedAt: { not: null },
      },
      select: { checkedInAt: true, consultationStartedAt: true },
    }),

    // 3) Per-doctor outcomes + waits, in JS (small row counts per clinic);
    //    also the source for the per-hour demand shape — no second query.
    t.appointment.findMany({
      where: {
        organizationId: orgId,
        scheduledStart: { gte: since },
        status: { notIn: ["RESCHEDULED"] },
      },
      select: {
        doctorId: true,
        status: true,
        scheduledStart: true,
        doctor: { select: { displayName: true } },
        queueEntry: { select: { checkedInAt: true, consultationStartedAt: true } },
      },
    }),
  ]);

  const countOf = (status: string) =>
    statusCounts.find((s) => s.status === status)?._count._all ?? 0;
  const totals = {
    appointments: statusCounts.reduce((sum, s) => sum + s._count._all, 0),
    completed: countOf("COMPLETED"),
    cancelled: countOf("CANCELLED"),
    noShow: countOf("NO_SHOW"),
    checkedIn: countOf("CHECKED_IN"),
  };

  const waitMinutes = waits.map((w) =>
    Math.max(
      0,
      Math.round(
        (w.consultationStartedAt!.getTime() - w.checkedInAt!.getTime()) / 60_000,
      ),
    ),
  );
  const buckets = [
    { label: "Under 15 min", count: waitMinutes.filter((m) => m < 15).length },
    { label: "15–30 min", count: waitMinutes.filter((m) => m >= 15 && m < 30).length },
    { label: "30–60 min", count: waitMinutes.filter((m) => m >= 30 && m < 60).length },
    { label: "60+ min", count: waitMinutes.filter((m) => m >= 60).length },
  ];

  // Peak hours from per-doctor rows' scheduledStart (one source, no extra query).
  const hourMap = new Map<number, number>();
  for (const row of perDoctorRows) {
    const h = new Date(row.scheduledStart).getHours();
    hourMap.set(h, (hourMap.get(h) ?? 0) + 1);
  }
  const peakHours = [...hourMap.entries()]
    .map(([hour, count]) => ({ hour, count }))
    .sort((a, b) => a.hour - b.hour);

  const byDoctor = new Map<string, { name: string; appointments: number; noShow: number; waits: number[] }>();
  for (const row of perDoctorRows) {
    let entry = byDoctor.get(row.doctorId);
    if (!entry) {
      entry = { name: row.doctor.displayName, appointments: 0, noShow: 0, waits: [] };
      byDoctor.set(row.doctorId, entry);
    }
    entry.appointments += 1;
    if (row.status === "NO_SHOW") entry.noShow += 1;
    if (row.queueEntry?.checkedInAt && row.queueEntry.consultationStartedAt) {
      entry.waits.push(
        Math.max(0, Math.round((row.queueEntry.consultationStartedAt.getTime() - row.queueEntry.checkedInAt.getTime()) / 60_000)),
      );
    }
  }

  return {
    windowDays: 30,
    generatedAt: new Date().toISOString(),
    totals,
    noShowRate: rate(totals.noShow, totals.completed + totals.noShow),
    cancellationRate: rate(totals.cancelled, totals.appointments),
    waitTimes: {
      sampleSize: waitMinutes.length,
      medianMinutes: median(waitMinutes),
      averageMinutes:
        waitMinutes.length === 0
          ? null
          : Math.round(waitMinutes.reduce((a, b) => a + b, 0) / waitMinutes.length),
      p90Minutes: p90(waitMinutes),
      buckets,
    },
    peakHours,
    perDoctor: [...byDoctor.entries()]
      .map(([doctorId, d]) => ({
        doctorId,
        doctorName: d.name,
        appointments: d.appointments,
        noShow: d.noShow,
        noShowRate: rate(d.noShow, d.appointments),
        medianWaitMinutes: median(d.waits),
      }))
      .sort((a, b) => b.appointments - a.appointments),
  };
}
