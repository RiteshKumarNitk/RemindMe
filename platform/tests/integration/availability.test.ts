import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  registerAndLogin,
  setWeeklyAvailability,
} from "../helpers/factories.js";
import { GET as slotsRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/slots/route.js";
import { GET as getRules, PUT as putRules } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/availability/route.js";
import { POST as createException } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/availability/exceptions/route.js";

let adminToken: string;
let orgId: string;
let doctorId: string;
let doctorToken: string;

const dateAhead = (days: number) =>
  new Date(Date.now() + days * 86_400_000).toISOString().slice(0, 10);

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("avadm");
  adminToken = admin.accessToken;
  orgId = (await createOrg(adminToken, "avail")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  doctorToken = doc.token;
});
afterAll(disconnect);

async function slots<E = unknown>(date: string, token = adminToken) {
  return call<
    { slots: Array<{ start: string; end: string }>; timezone: string; durationMinutes: number } & E
  >(slotsRoute, {
    bearer: token,
    params: { orgId, doctorId },
    url: `http://x/api?date=${date}`,
  });
}

describe("availability & slot calculation (APPOINTMENT_WORKFLOW.md)", () => {
  it("no rules → no slots", async () => {
    const res = await slots(dateAhead(9));
    expect(res.status).toBe(200);
    expect(res.body.slots).toEqual([]);
  });

  it("a doctor can set their own rules; an admin can too; a stranger cannot", async () => {
    await setWeeklyAvailability(doctorToken, orgId, doctorId, {
      startMinute: 9 * 60,
      endMinute: 12 * 60,
      slotMinutes: 30,
    });
    const rules = await call<{ data: unknown[] }>(getRules, {
      bearer: adminToken,
      params: { orgId, doctorId },
    });
    expect(rules.body.data.length).toBe(7);

    const stranger = await registerAndLogin("str");
    const res = await call(putRules, {
      bearer: stranger.accessToken,
      params: { orgId, doctorId },
      body: { rules: [] },
    });
    expect(res.status).toBe(404); // not a member of this org
  });

  it("generates slots stepped by slotMinutes, duration = clinic default, none before lead time", async () => {
    const res = await slots<{ durationMinutes: number }>(dateAhead(10));
    expect(res.status).toBe(200);
    // 09:00–12:00, step 30, default duration 15 → 6 slots (09:00..11:30).
    expect(res.body.slots.length).toBe(6);
    expect(res.body.durationMinutes).toBe(15);
    for (const s of res.body.slots) {
      expect(new Date(s.start).getTime()).toBeGreaterThan(Date.now() + 100 * 60_000);
      expect(new Date(s.end).getTime() - new Date(s.start).getTime()).toBe(15 * 60_000);
    }
    for (let i = 1; i < res.body.slots.length; i++) {
      const gap =
        new Date(res.body.slots[i]!.start).getTime() -
        new Date(res.body.slots[i - 1]!.start).getTime();
      expect(gap).toBe(30 * 60_000);
    }
  });

  it("a DAY_OFF exception removes all slots for that day", async () => {
    const date = dateAhead(11);
    const before = await slots(date);
    expect(before.body.slots.length).toBeGreaterThan(0);

    await call(createException, {
      bearer: adminToken,
      params: { orgId, doctorId },
      body: {
        kind: "DAY_OFF",
        startsAt: `${date}T00:00:00.000Z`,
        endsAt: `${date}T23:59:59.000Z`,
        reason: "leave",
      },
    });
    const after = await slots(date);
    expect(after.body.slots).toEqual([]);
  });

  it("a BREAK exception carves the blocked interval out of the window", async () => {
    const date = dateAhead(12);
    const full = await slots(date);
    const blockStart = full.body.slots[2]!.start; // 10:00 local
    const blockEnd = full.body.slots[3]!.end; // 10:45 local
    await call(createException, {
      bearer: adminToken,
      params: { orgId, doctorId },
      body: { kind: "BREAK", startsAt: blockStart, endsAt: blockEnd, reason: "lunch" },
    });
    const after = await slots(date);
    expect(after.body.slots.length).toBeLessThan(full.body.slots.length);
    // No surviving slot overlaps [blockStart, blockEnd).
    const bs = new Date(blockStart).getTime();
    const be = new Date(blockEnd).getTime();
    for (const s of after.body.slots) {
      const ss = new Date(s.start).getTime();
      const se = new Date(s.end).getTime();
      expect(ss < be && bs < se).toBe(false);
    }
  });
});
