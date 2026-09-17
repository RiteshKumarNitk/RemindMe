"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { BellIcon } from "./dashboard-icons.js";

interface NotificationItem {
  id: string;
  message: string;
  href: string | null;
  createdAt: string;
  read: boolean;
}

function timeAgo(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  const min = Math.floor(ms / 60_000);
  if (min < 1) return "just now";
  if (min < 60) return `${min} min ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr} hr ago`;
  const days = Math.floor(hr / 24);
  return `${days}d ago`;
}

/**
 * The dashboard's live notification center. Polls `/api/orgs/:orgId/notifications`
 * (every 30s while open, once on mount) rather than a websocket/SSE stream —
 * this app has no realtime transport, and a 30s-stale unread count is a fine
 * tradeoff against standing up one just for this.
 */
export function NotificationBell({ orgId }: { orgId: string }) {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch(`/api/orgs/${orgId}/notifications?limit=20`);
      if (!res.ok) return;
      const body = (await res.json()) as { data: NotificationItem[]; unreadCount: number };
      setItems(body.data);
      setUnreadCount(body.unreadCount);
      setLoaded(true);
    } catch {
      // best-effort — the bell just stays at its last known state
    }
  }, [orgId]);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 30_000);
    return () => clearInterval(id);
  }, [refresh]);

  useEffect(() => {
    if (!open) return;
    function onClick(e: MouseEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [open]);

  async function markAllRead() {
    setItems((prev) => prev.map((i) => ({ ...i, read: true })));
    setUnreadCount(0);
    try {
      await fetch(`/api/orgs/${orgId}/notifications/read`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
    } catch {
      // next open's refresh() will reconcile if this failed
    }
  }

  return (
    <div className="relative" ref={panelRef}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="true"
        aria-expanded={open}
        aria-label={unreadCount > 0 ? `Notifications, ${unreadCount} unread` : "Notifications"}
        className="relative flex h-10 w-10 items-center justify-center rounded-xl border border-border bg-card text-ink-muted hover:bg-surface-2 hover:text-ink"
      >
        <BellIcon className="h-4.5 w-4.5" />
        {unreadCount > 0 ? (
          <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full border-2 border-surface bg-coral px-1 text-[9.5px] font-bold text-white">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        ) : null}
      </button>

      {open ? (
        <div className="absolute right-0 top-12 z-30 w-80 max-w-[calc(100vw-2rem)] overflow-hidden rounded-2xl border border-border bg-card shadow-lg">
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <h3 className="font-display text-sm font-bold text-ink">Notifications</h3>
            {unreadCount > 0 ? (
              <button type="button" onClick={markAllRead} className="text-xs font-semibold text-indigo hover:text-indigo-dark">
                Mark all read
              </button>
            ) : null}
          </div>
          <div className="max-h-80 overflow-y-auto">
            {!loaded ? (
              <div className="px-4 py-6 text-center text-xs text-ink-muted">Loading…</div>
            ) : items.length === 0 ? (
              <div className="px-4 py-6 text-center text-xs text-ink-muted">Nothing yet.</div>
            ) : (
              items.map((item) => {
                const body = (
                  <div className={`flex gap-2.5 border-b border-border px-4 py-3 last:border-0 ${item.read ? "" : "bg-indigo/[0.03]"}`}>
                    <span className={`mt-1.5 h-2 w-2 flex-shrink-0 rounded-full ${item.read ? "" : "bg-indigo"}`} />
                    <div>
                      <p className="text-[12.5px] leading-snug text-ink">{item.message}</p>
                      <time className="text-[11px] text-ink-muted">{timeAgo(item.createdAt)}</time>
                    </div>
                  </div>
                );
                return item.href ? (
                  <Link
                    key={item.id}
                    href={`/dashboard/${orgId}/${item.href}`}
                    className="block no-underline"
                    onClick={() => setOpen(false)}
                  >
                    {body}
                  </Link>
                ) : (
                  <div key={item.id}>{body}</div>
                );
              })
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
