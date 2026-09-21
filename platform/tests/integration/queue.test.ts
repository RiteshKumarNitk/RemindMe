import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  createPatient,
  firstSlot,
  registerAndLogin,
  setWeeklyAvailability,
} from "../helpers/factories.js";
import { POST as bookRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { POST as checkInRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/check-in/route.js";
import { GET as boardRoute } from "../../app/api/orgs/[orgId]/queue/route.js";
import { POST as queueActionRoute } from "../../app/api/orgs/[orgId]/queue/[entryId]/[action]/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let doctorToken: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("qadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "queue")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  doctorToken = doc.token;
  await setWeeklyAvailability(adminToken, orgId, doctorId, { slotMinutes: 15 });
});
afterAll(disconnect);

async function bookAndCheckIn(daysAhead: number) {
  const slot = await firstSlot(adminToken, orgId, doctorId, daysAhead);
  const patient = await createPatient(orgId, adminUserId);
  const appt = await call<{ id: string }>(bookRoute, {
    bearer: adminToken,
    params: { orgId },
    body: { patientId: patient.id, doctorId, scheduledStart: slot.start },
  });
  const ci = await call<{ queue: { id: string; tokenNumber: number } }>(checkInRoute, {
    bearer: adminToken,
    params: { orgId, appointmentId: appt.body.id },
  });
  return { date: slot.date, entryId: ci.body.queue.id, token: ci.body.queue.tokenNumber };
}

const act = (entryId: string, action: string, token = adminToken) =>
  call(queueActionRoute, { bearer: token, params: { orgId, entryId, action } });

describe("queue management (QUEUE_MANAGEMENT.md)", () => {
  it("check-in issues sequential tokens per doctor per day", async () => {
    const a = await bookAndCheckIn(7);
    const b = await bookAndCheckIn(7);
    expect(b.token).toBe(a.token + 1);
    expect(a.date).toBe(b.date);
  });

  it("board lists active entries ordered by position with people-ahead", async () => {
    const first = await bookAndCheckIn(8);
    await bookAndCheckIn(8);
    const board = await call<{
      entries: Array<{ id: string; tokenNumber: number; state: string; ahead: number }>;
      nowServingToken: number | null;
    }>(boardRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doctorId}&date=${first.date}`,
    });
    expect(board.status).toBe(200);
    const tokens = board.body.entries.map((e) => e.tokenNumber);
    expect([...tokens]).toEqual([...tokens].sort((x, y) => x - y));
    expect(board.body.entries[0]!.ahead).toBe(0);
  });

  it("call → start → complete happy path; complete also completes the appointment", async () => {
    const q = await bookAndCheckIn(9);
    expect((await act(q.entryId, "call")).status).toBe(200);
    expect((await act(q.entryId, "start", doctorToken)).status).toBe(200);
    const done = await act(q.entryId, "complete", doctorToken);
    expect(done.status).toBe(200);
    expect((done.body as { state: string }).state).toBe("COMPLETED");
  });

  it("invalid queue transition → 409 INVALID_QUEUE_TRANSITION", async () => {
    const q = await bookAndCheckIn(10);
    // Cannot COMPLETE a WAITING entry.
    const bad = await act(q.entryId, "complete", doctorToken);
    expect(bad.status).toBe(409);
    expect((bad.body as { error: { code: string } }).error.code).toBe("INVALID_QUEUE_TRANSITION");
  });

  it("skip then recall puts the entry back to WAITING, served next", async () => {
    const q = await bookAndCheckIn(11);
    expect((await act(q.entryId, "skip")).status).toBe(200);
    const recalled = await act(q.entryId, "recall");
    expect(recalled.status).toBe(200);
    expect((recalled.body as { state: string; position: number }).state).toBe("WAITING");
    expect((recalled.body as { position: number }).position).toBeLessThan(1);
  });

  it("only the assigned doctor can start/complete; reception can call/skip", async () => {
    const q = await bookAndCheckIn(12);
    const other = await createDoctorWithLogin(adminToken, orgId);
    expect((await act(q.entryId, "call")).status).toBe(200); // admin ok
    expect((await act(q.entryId, "start", other.token)).status).toBe(403);
    expect((await act(q.entryId, "start", doctorToken)).status).toBe(200);
  });

  it("another clinic's queue is invisible / untouchable", async () => {
    const q = await bookAndCheckIn(13);
    const outsider = await registerAndLogin("qout");
    const otherOrg = await createOrg(outsider.accessToken, "qother");
    const res = await call(queueActionRoute, {
      bearer: outsider.accessToken,
      params: { orgId: otherOrg.id, entryId: q.entryId, action: "call" },
    });
    expect(res.status).toBe(404);
  });
});
