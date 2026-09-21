import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { env } from "@/lib/env.js";
import { POST as dispatchRoute } from "../../app/api/internal/notifications/dispatch/route.js";

beforeAll(truncateAll);
beforeEach(async () => {
  await db.notification.deleteMany({});
});
afterAll(disconnect);

const cronKey = () => env.NOTIFICATIONS_CRON_SECRET;

async function makeNotification(over: Partial<Parameters<typeof db.notification.create>[0]["data"]> = {}) {
  return db.notification.create({
    data: {
      channel: "IN_APP",
      event: "APPOINTMENT_CONFIRMED",
      payload: {},
      status: "PENDING",
      ...over,
    },
  });
}

describe("notification dispatcher (TESTING.md §13)", () => {
  it("rejects a missing / wrong X-Cron-Key with 404", async () => {
    const noKey = await call(dispatchRoute, { method: "POST" });
    expect(noKey.status).toBe(404);
    const badKey = await call(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": "nope" },
    });
    expect(badKey.status).toBe(404);
  });

  it("delivers a due IN_APP notification exactly once → SENT", async () => {
    const n = await makeNotification();
    const res = await call<{ sent: number; claimed: number }>(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": cronKey() },
    });
    expect(res.status).toBe(200);
    expect(res.body.sent).toBe(1);
    const row = await db.notification.findUniqueOrThrow({ where: { id: n.id } });
    expect(row.status).toBe("SENT");
    expect(row.sentAt).not.toBeNull();

    // Second run does nothing (already terminal).
    const again = await call<{ claimed: number }>(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": cronKey() },
    });
    expect(again.body.claimed).toBe(0);
  });

  it("two concurrent dispatch calls never double-send", async () => {
    await Promise.all(Array.from({ length: 5 }, () => makeNotification()));
    const [a, b] = await Promise.all([
      call<{ sent: number }>(dispatchRoute, { method: "POST", headers: { "x-cron-key": cronKey() } }),
      call<{ sent: number }>(dispatchRoute, { method: "POST", headers: { "x-cron-key": cronKey() } }),
    ]);
    expect((a.body.sent ?? 0) + (b.body.sent ?? 0)).toBe(5);
    const sent = await db.notification.count({ where: { status: "SENT" } });
    expect(sent).toBe(5);
  });

  it("does not claim a notification scheduled for the future", async () => {
    await makeNotification({ scheduledFor: new Date(Date.now() + 60 * 60_000) });
    const res = await call<{ claimed: number }>(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": cronKey() },
    });
    expect(res.body.claimed).toBe(0);
  });

  it("PUSH without FCM configured → SUPPRESSED (not FAILED)", async () => {
    const n = await makeNotification({ channel: "PUSH" });
    await call(dispatchRoute, { method: "POST", headers: { "x-cron-key": cronKey() } });
    const row = await db.notification.findUniqueOrThrow({ where: { id: n.id } });
    expect(row.status).toBe("SUPPRESSED");
  });

  it("reaps a stale SENDING row back to PENDING and then delivers it", async () => {
    const n = await makeNotification({
      status: "SENDING",
      claimedAt: new Date(Date.now() - (env.NOTIFICATIONS_CLAIM_TIMEOUT_MIN + 5) * 60_000),
    });
    const res = await call<{ reaped: number; sent: number }>(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": cronKey() },
    });
    expect(res.body.reaped).toBe(1);
    expect(res.body.sent).toBe(1);
    const row = await db.notification.findUniqueOrThrow({ where: { id: n.id } });
    expect(row.status).toBe("SENT");
  });
});
