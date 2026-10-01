import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getClinicAnalytics } from "@/modules/analytics/service.js";
import { Card, CardSubtitle, CardTitle, EmptyState } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

function labelForHour(hour: number): string {
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${h12}${hour < 12 ? "am" : "pm"}`;
}

/**
 * Operations insights (owner-only): wait times from the real queue timeline,
 * no-show rates from decided appointments, and demand shape by hour — all
 * computed from rows the clinic already produced, nothing newly recorded.
 */
export default async function InsightsPage({ params }: { params: Promise<{ orgId: string }> }) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);

  const a = await getClinicAnalytics(ctx, orgId);
  const maxBucket = Math.max(1, ...a.waitTimes.buckets.map((b) => b.count));
  const maxHour = Math.max(1, ...a.peakHours.map((h) => h.count));

  return (
    <div className="flex max-w-4xl flex-col gap-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Insights</h1>
        <p className="mt-1 text-sm text-ink-muted">
          The last 30 days, computed from your clinic&rsquo;s own queue and appointment records.
        </p>
      </div>

      {/* Headline outcomes */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {[
          { label: "Appointments", value: a.totals.appointments },
          { label: "Completed", value: a.totals.completed },
          { label: "No-shows", value: a.totals.noShow },
          { label: "Cancellations", value: a.totals.cancelled },
        ].map((t) => (
          <div key={t.label} className="rounded-card border border-border bg-card px-5 py-4">
            <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">{t.label}</div>
            <div className="mt-1 font-display text-2xl font-bold tabular-nums text-ink">{t.value}</div>
          </div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* No-show + cancellation rates */}
        <Card>
          <CardTitle>Lost time</CardTitle>
          <p className="mt-2 text-sm text-ink-muted">
            Of appointments whose time already passed and that ended as either a visit or a no-show:
          </p>
          <div className="mt-4 grid grid-cols-2 gap-4">
            <div>
              <div className="font-display text-3xl font-bold tabular-nums text-down">
                {a.noShowRate == null ? "—" : `${a.noShowRate}%`}
              </div>
              <div className="mt-1 text-[12px] text-ink-muted">no-show rate</div>
            </div>
            <div>
              <div className="font-display text-3xl font-bold tabular-nums text-warn">
                {a.cancellationRate == null ? "—" : `${a.cancellationRate}%`}
              </div>
              <div className="mt-1 text-[12px] text-ink-muted">of all bookings cancelled</div>
            </div>
          </div>
          {a.noShowRate != null && a.noShowRate >= 15 ? (
            <p className="mt-4 rounded-xl bg-warn/10 px-3 py-2 text-[12.5px] text-warn">
              No-shows are high — reminders go out 24h and 2h before each confirmed appointment; the
              4-hour cancellation window keeps late cancellations from hiding here.
            </p>
          ) : null}
        </Card>

        {/* Wait times */}
        <Card>
          <CardTitle>Waiting-room wait</CardTitle>
          {a.waitTimes.sampleSize === 0 ? (
            <p className="mt-2 text-sm text-ink-muted">
              Not enough queue history yet — this fills in as patients are checked in and seen.
            </p>
          ) : (
            <>
              <div className="mt-3 grid grid-cols-3 gap-3">
                <div>
                  <div className="font-display text-2xl font-bold tabular-nums text-ink">
                    {a.waitTimes.medianMinutes}<span className="text-sm text-ink-muted"> min</span>
                  </div>
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Median</div>
                </div>
                <div>
                  <div className="font-display text-2xl font-bold tabular-nums text-ink">
                    {a.waitTimes.p90Minutes}<span className="text-sm text-ink-muted"> min</span>
                  </div>
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Worst 10%</div>
                </div>
                <div>
                  <div className="font-display text-2xl font-bold tabular-nums text-ink">
                    {a.waitTimes.averageMinutes}<span className="text-sm text-ink-muted"> min</span>
                  </div>
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Average</div>
                </div>
              </div>
              <div className="mt-4 flex flex-col gap-1.5">
                {a.waitTimes.buckets.map((b) => (
                  <div key={b.label} className="flex items-center gap-2">
                    <span className="w-24 shrink-0 text-[11.5px] text-ink-muted">{b.label}</span>
                    <span className="h-2.5 rounded-full bg-indigo" style={{ width: `${(b.count / maxBucket) * 100}%`, minWidth: b.count > 0 ? 4 : 0 }} />
                    <span className="text-[11.5px] tabular-nums text-ink-faint">{b.count}</span>
                  </div>
                ))}
              </div>
              <p className="mt-2 text-[11.5px] text-ink-faint">
                From check-in to consultation start, {a.waitTimes.sampleSize} patient{a.waitTimes.sampleSize === 1 ? "" : "s"}.
              </p>
            </>
          )}
        </Card>
      </div>

      {/* Demand by hour */}
      <Card>
        <CardTitle>When patients book</CardTitle>
        {a.peakHours.length === 0 ? (
          <p className="mt-2 text-sm text-ink-muted">No bookings in the window yet.</p>
        ) : (
          <>
            <div className="mt-4 flex h-28 items-end gap-1">
              {a.peakHours.map((h) => (
                <div key={h.hour} className="flex flex-1 flex-col items-center gap-1" title={`${labelForHour(h.hour)} — ${h.count}`}>
                  <div
                    className="w-full rounded-t-md bg-indigo/80"
                    style={{ height: `${Math.max((h.count / maxHour) * 100, 6)}%` }}
                  />
                </div>
              ))}
            </div>
            <div className="mt-1.5 flex gap-1">
              {a.peakHours.map((h) => (
                <div key={h.hour} className="flex-1 text-center text-[10px] text-ink-faint">
                  {labelForHour(h.hour)}
                </div>
              ))}
            </div>
          </>
        )}
      </Card>

      {/* Per doctor */}
      <Card>
        <CardTitle>By doctor</CardTitle>
        {a.perDoctor.length === 0 ? (
          <EmptyState title="No appointments in the window yet." />
        ) : (
          <div className="table-scroll mt-3">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="py-2 pr-3">Doctor</th>
                  <th className="py-2 pr-3 text-right">Appointments</th>
                  <th className="py-2 pr-3 text-right">No-shows</th>
                  <th className="py-2 pr-3 text-right">No-show rate</th>
                  <th className="py-2 text-right">Median wait</th>
                </tr>
              </thead>
              <tbody>
                {a.perDoctor.map((d) => (
                  <tr key={d.doctorId} className="border-b border-border last:border-b-0">
                    <td className="py-2.5 pr-3 font-medium text-ink">{d.doctorName}</td>
                    <td className="py-2.5 pr-3 text-right tabular-nums">{d.appointments}</td>
                    <td className="py-2.5 pr-3 text-right tabular-nums">{d.noShow}</td>
                    <td className={`py-2.5 pr-3 text-right tabular-nums ${(d.noShowRate ?? 0) >= 15 ? "font-semibold text-down" : "text-ink-muted"}`}>
                      {d.noShowRate == null ? "—" : `${d.noShowRate}%`}
                    </td>
                    <td className="py-2.5 text-right tabular-nums text-ink-muted">
                      {d.medianWaitMinutes == null ? "—" : `${d.medianWaitMinutes} min`}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
