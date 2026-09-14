"use client";

import { useEffect, useState } from "react";
import { Button, Field, Select } from "../../ui.js";

type Doctor = { id: string; displayName: string };
type PatientOpt = { id: string; firstName: string; lastName: string };
type Slot = { start: string; end: string };

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
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [slots, setSlots] = useState<Slot[]>([]);
  const [selected, setSelected] = useState("");
  const [loading, setLoading] = useState(false);

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
        <Select label="Patient" name="patientId" required>
          {patients.map((p) => (
            <option key={p.id} value={p.id}>
              {p.firstName} {p.lastName}
            </option>
          ))}
        </Select>
      )}

      <label style={{ display: "block", marginBottom: 12 }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
          Doctor
        </div>
        <select
          value={doctorId}
          onChange={(e) => setDoctorId(e.target.value)}
          style={{
            width: "100%",
            padding: "9px 12px",
            borderRadius: 10,
            border: "1px solid var(--border)",
            background: "var(--surface)",
            color: "var(--ink)",
            fontSize: 14,
          }}
        >
          {doctors.map((d) => (
            <option key={d.id} value={d.id}>
              {d.displayName}
            </option>
          ))}
        </select>
      </label>
      <input type="hidden" name="doctorId" value={doctorId} />

      <label style={{ display: "block", marginBottom: 12 }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
          Date
        </div>
        <input
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          style={{
            width: "100%",
            padding: "9px 12px",
            borderRadius: 10,
            border: "1px solid var(--border)",
            background: "var(--surface)",
            color: "var(--ink)",
            fontSize: 14,
          }}
        />
      </label>

      <label style={{ display: "block", marginBottom: 12 }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
          Time slot
        </div>
        <select
          value={selected}
          onChange={(e) => setSelected(e.target.value)}
          required
          style={{
            width: "100%",
            padding: "9px 12px",
            borderRadius: 10,
            border: "1px solid var(--border)",
            background: "var(--surface)",
            color: "var(--ink)",
            fontSize: 14,
          }}
        >
          <option value="" disabled>
            {loading ? "Loading…" : slots.length === 0 ? "No slots available" : "Choose a time"}
          </option>
          {slots.map((s) => (
            <option key={s.start} value={s.start}>
              {new Date(s.start).toLocaleString([], {
                weekday: "short",
                hour: "2-digit",
                minute: "2-digit",
              })}
            </option>
          ))}
        </select>
      </label>
      <input type="hidden" name="scheduledStart" value={selected} />

      <Field label="Reason (optional)" name="reason" placeholder="Follow-up, check-up…" />

      <div style={{ marginTop: 8 }}>
        <Button>Book appointment</Button>
      </div>
    </form>
  );
}
