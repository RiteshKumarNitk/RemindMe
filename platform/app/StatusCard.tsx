"use client";

import { useEffect, useState } from "react";

type Health = { status: string; db: "ok" | "down"; time: string };
type State =
  | { kind: "loading" }
  | { kind: "ok"; data: Health }
  | { kind: "error"; message: string };

export function StatusCard() {
  const [state, setState] = useState<State>({ kind: "loading" });

  useEffect(() => {
    let cancelled = false;
    fetch("/api/health")
      .then(async (res) => {
        const data = (await res.json()) as Health;
        if (!cancelled) setState({ kind: "ok", data });
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setState({ kind: "error", message: err instanceof Error ? err.message : "Request failed" });
        }
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const dbOk = state.kind === "ok" && state.data.db === "ok";
  const dotColor =
    state.kind === "loading" ? "var(--ink-muted)" : dbOk ? "var(--ok)" : "var(--down)";
  const label =
    state.kind === "loading"
      ? "Checking…"
      : state.kind === "error"
        ? `Unreachable (${state.message})`
        : dbOk
          ? "API + database reachable"
          : "API up, database unreachable";

  return (
    <div
      style={{
        background: "var(--card)",
        border: "1px solid var(--border)",
        borderRadius: 20,
        padding: "20px 24px",
        display: "flex",
        alignItems: "center",
        gap: 14,
      }}
    >
      <span
        style={{
          width: 10,
          height: 10,
          borderRadius: "50%",
          background: dotColor,
          flexShrink: 0,
        }}
        aria-hidden
      />
      <div>
        <div style={{ fontWeight: 700 }}>{label}</div>
        <div style={{ color: "var(--ink-muted)", fontSize: 13, marginTop: 2 }}>
          {state.kind === "ok" ? (
            <>GET /api/health · {new Date(state.data.time).toLocaleString()}</>
          ) : (
            <>GET /api/health</>
          )}
        </div>
      </div>
    </div>
  );
}
