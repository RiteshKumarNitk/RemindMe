import type { CSSProperties, ReactNode } from "react";

export function Card({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  return (
    <div
      style={{
        background: "var(--card)",
        border: "1px solid var(--border)",
        borderRadius: 16,
        padding: 20,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

export function SectionTitle({ children }: { children: ReactNode }) {
  return (
    <h2
      style={{
        fontSize: 13,
        textTransform: "uppercase",
        letterSpacing: 0.6,
        color: "var(--ink-muted)",
        margin: "0 0 12px",
      }}
    >
      {children}
    </h2>
  );
}

export function Badge({ children, tone = "indigo" }: { children: ReactNode; tone?: "indigo" | "coral" | "ok" | "muted" }) {
  const colors: Record<string, string> = {
    indigo: "var(--indigo)",
    coral: "var(--coral)",
    ok: "var(--ok)",
    muted: "var(--ink-muted)",
  };
  return (
    <span
      style={{
        display: "inline-block",
        fontSize: 12,
        fontWeight: 700,
        color: colors[tone],
        background: `color-mix(in srgb, ${colors[tone]} 14%, transparent)`,
        borderRadius: 999,
        padding: "2px 10px",
      }}
    >
      {children}
    </span>
  );
}

export function Button({
  children,
  variant = "primary",
  type = "submit",
}: {
  children: ReactNode;
  variant?: "primary" | "ghost" | "danger";
  type?: "submit" | "button";
}) {
  const styles: Record<string, CSSProperties> = {
    primary: { background: "var(--indigo)", color: "#fff", border: "1px solid var(--indigo)" },
    ghost: { background: "transparent", color: "var(--ink)", border: "1px solid var(--border)" },
    danger: { background: "transparent", color: "var(--down)", border: "1px solid var(--down)" },
  };
  return (
    <button
      type={type}
      style={{
        borderRadius: 10,
        padding: "8px 14px",
        fontSize: 13,
        fontWeight: 700,
        cursor: "pointer",
        ...styles[variant],
      }}
    >
      {children}
    </button>
  );
}

export function Field({
  label,
  name,
  type = "text",
  required,
  defaultValue,
  placeholder,
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  defaultValue?: string;
  placeholder?: string;
}) {
  return (
    <label style={{ display: "block", marginBottom: 12 }}>
      <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
        {label}
      </div>
      <input
        name={name}
        type={type}
        required={required}
        defaultValue={defaultValue}
        placeholder={placeholder}
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
  );
}

export function Select({
  label,
  name,
  children,
  required,
  defaultValue,
}: {
  label: string;
  name: string;
  children: ReactNode;
  required?: boolean;
  defaultValue?: string;
}) {
  return (
    <label style={{ display: "block", marginBottom: 12 }}>
      <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
        {label}
      </div>
      <select
        name={name}
        required={required}
        defaultValue={defaultValue}
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
        {children}
      </select>
    </label>
  );
}

export function ErrorNote({ message }: { message?: string }) {
  if (!message) return null;
  return (
    <div
      style={{
        background: "color-mix(in srgb, var(--down) 12%, transparent)",
        color: "var(--down)",
        borderRadius: 10,
        padding: "10px 14px",
        fontSize: 13,
        marginBottom: 16,
      }}
    >
      {message}
    </div>
  );
}

export function EmptyState({ children }: { children: ReactNode }) {
  return (
    <div style={{ color: "var(--ink-muted)", fontSize: 14, padding: "24px 0" }}>{children}</div>
  );
}

export const table: CSSProperties = { width: "100%", minWidth: 560, borderCollapse: "collapse", fontSize: 14 };

/** Wraps `table` in a horizontally-scrolling container so a wide table degrades
 * to a scroll on a narrow screen instead of clipping columns or breaking the
 * page layout. */
export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="table-scroll">
      <table style={table}>{children}</table>
    </div>
  );
}
export const th: CSSProperties = {
  textAlign: "left",
  padding: "8px 10px",
  color: "var(--ink-muted)",
  fontSize: 12,
  textTransform: "uppercase",
  letterSpacing: 0.4,
  borderBottom: "1px solid var(--border)",
};
export const td: CSSProperties = { padding: "10px 10px", borderBottom: "1px solid var(--border)" };
