"use client";

import { useEffect, useMemo, useState } from "react";
import { Button, Field, InitialsAvatar, Input, Select } from "@/components/ui/index.js";

type Doctor = { id: string; displayName: string; specialty?: string | null };
type PatientOpt = { id: string; firstName: string; lastName: string };
type Slot = { start: string; end: string };

function nextDays(n: number): Date[] {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Array.from({ length: n }, (_, i) => new Date(today.getTime() + i * 86_400_000));
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/**
 * A patient/doctor/time picker over the same booking mechanics the old form
 * used (a plain server action, doctorId/scheduledStart as hidden inputs) —
 * only the picker UI changed, not what gets submitted or how the server
 * validates it.
 */
export function BookForm({
  orgId,
  doctors,
  patients,
  action,
}: {
  orgId: string;
  doctors: Doctor[];
  patients?: PatientOpt[];
  action: (formData: FormData) => void;
}) {
  const [doctorId, setDoctorId] = useState(doctors[0]?.id ?? "");
  const days = useMemo(() => nextDays(14), []);
  const [date, setDate] = useState(() => isoDate(days[0]!));
  const [slots, setSlots] = useState<Slot[]>([]);
  const [selected, setSelected] = useState("");
  const [loading, setLoading] = useState(false);

  const doctor = doctors.find((d) => d.id === doctorId);

  useEffect(() => {
    if (!doctorId || !date) return;
    let cancelled = false;
    setLoading(true);
    setSelected("");
    fetch(`/api/orgs/${orgId}/doctors/${doctorId}/slots?date=${date}`)
      .then((r) => r.json())
      .then((data: { slots?: Slot[] }) => {
        if (!cancelled) setSlots(data.slots ?? []);
      })
      .catch(() => {
        if (!cancelled) setSlots([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [orgId, doctorId, date]);

  return (
    <form action={action}>
      {patients && patients.length > 0 && (
        <div className="mb-5">
          <Field label="Patient">
            <Select name="patientId" required className="w-full">
              {patients.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.firstName} {p.lastName}
                </option>
              ))}
            </Select>
          </Field>
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-[1fr_260px]">
        <div className="flex flex-col gap-5">
          <div>
            <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Doctor</div>
            <div className="flex gap-2 overflow-x-auto pb-1" role="radiogroup" aria-label="Choose a doctor">
              {doctors.map((d) => (
                <button
                  key={d.id}
                  type="button"
                  onClick={() => setDoctorId(d.id)}
                  aria-pressed={d.id === doctorId}
                  className={`flex shrink-0 items-center gap-2.5 rounded-2xl border px-3.5 py-2.5 text-left ${
                    d.id === doctorId ? "border-indigo bg-indigo/10" : "border-border bg-card hover:bg-surface-2"
                  }`}
                >
                  <InitialsAvatar name={d.displayName} />
                  <span>
                    <span className="block text-[12.5px] font-semibold text-ink">{d.displayName}</span>
                    {d.specialty ? <span className="block text-[11px] text-ink-muted">{d.specialty}</span> : null}
                  </span>
                </button>
              ))}
            </div>
          </div>
          <input type="hidden" name="doctorId" value={doctorId} />

          <div>
            <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Date</div>
            <div className="flex gap-2 overflow-x-auto pb-1" role="radiogroup" aria-label="Choose a date">
              {days.map((d) => {
                const iso = isoDate(d);
                const active = iso === date;
                return (
                  <button
                    key={iso}
                    type="button"
                    onClick={() => setDate(iso)}
                    aria-pressed={active}
                    className={`w-13.5 shrink-0 rounded-xl border py-2 text-center ${
                      active ? "border-indigo bg-indigo text-white" : "border-border bg-card hover:bg-surface-2"
                    }`}
                  >
                    <div className={`text-[10.5px] uppercase ${active ? "text-white/75" : "text-ink-faint"}`}>
                      {d.toLocaleDateString(undefined, { weekday: "short" })}
                    </div>
                    <div className="font-display mt-0.5 text-base font-bold">{d.getDate()}</div>
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Time</div>
            {loading ? (
              <p className="text-[13px] text-ink-muted">Loading available times…</p>
            ) : slots.length === 0 ? (
              <p className="text-[13px] text-ink-muted">No slots available this day.</p>
            ) : (
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-4" role="radiogroup" aria-label="Choose a time">
                {slots.map((s) => {
                  const active = s.start === selected;
                  return (
                    <button
                      key={s.start}
                      type="button"
                      onClick={() => setSelected(s.start)}
                      aria-pressed={active}
                      className={`rounded-xl border py-2.5 text-center font-mono text-[12.5px] font-medium ${
                        active ? "border-indigo bg-indigo text-white" : "border-border bg-card hover:border-indigo"
                      }`}
                    >
                      {new Date(s.start).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
          <input type="hidden" name="scheduledStart" value={selected} required />

          <Field label="Reason (optional)">
            <Input name="reason" placeholder="Follow-up, check-up…" className="w-full" />
          </Field>
        </div>

        <div className="flex h-fit flex-col gap-3 rounded-2xl border border-border bg-surface-2 p-4 lg:sticky lg:top-20">
          <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Your booking</div>
          {doctor ? (
            <div className="flex flex-col gap-0.5">
              <span className="text-[10.5px] font-semibold uppercase tracking-wide text-ink-faint">Doctor</span>
              <span className="text-[13.5px] font-semibold text-ink">{doctor.displayName}</span>
              {doctor.specialty ? <span className="text-[11.5px] text-ink-muted">{doctor.specialty}</span> : null}
            </div>
          ) : null}
          <div className="border-t border-dashed border-border" />
          <div className="flex flex-col gap-0.5">
            <span className="text-[10.5px] font-semibold uppercase tracking-wide text-ink-faint">Date &amp; time</span>
            <span className="text-[13.5px] font-semibold text-ink">
              {selected
                ? `${new Date(date).toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })} · ${new Date(selected).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
                : "Pick a time above"}
            </span>
          </div>
          <Button className="mt-1 w-full justify-center" disabled={!selected || !doctorId}>
            Confirm booking
          </Button>
        </div>
      </div>
    </form>
  );
}
