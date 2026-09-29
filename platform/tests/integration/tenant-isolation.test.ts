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
  type TestOrg,
  type TestUser,
} from "../helpers/factories.js";
import { GET as getOrg, PATCH as patchOrg } from "../../app/api/orgs/[orgId]/route.js";
import { GET as listMembers, POST as inviteMember } from "../../app/api/orgs/[orgId]/members/route.js";
import { GET as listDoctors, POST as createDoctor } from "../../app/api/orgs/[orgId]/doctors/route.js";
import { GET as getSettings } from "../../app/api/orgs/[orgId]/settings/route.js";
import { GET as getAppointmentRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/route.js";
import { GET as listAppointmentsRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { POST as bookAppointmentRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { db } from "../helpers/db.js";

let userA: TestUser;
let userB: TestUser;
let orgA: TestOrg;
let orgB: TestOrg;

beforeAll(async () => {
  await truncateAll();
  userA = await registerAndLogin("A");
  userB = await registerAndLogin("B");
  orgA = await createOrg(userA.accessToken, "clinicA");
  orgB = await createOrg(userB.accessToken, "clinicB");
});
afterAll(disconnect);

describe("tenant isolation (MULTI_TENANCY.md)", () => {
  it("A can read A's org", async () => {
    const res = await call(getOrg, { bearer: userA.accessToken, params: { orgId: orgA.id } });
    expect(res.status).toBe(200);
  });

  it("A reading B's org → 404, no leak", async () => {
    const res = await call(getOrg, { bearer: userA.accessToken, params: { orgId: orgB.id } });
    expect(res.status).toBe(404);
    expect(JSON.stringify(res.body)).not.toContain("clinicB");
    expect((res.body as { error: { code: string } }).error.code).toBe("NOT_FOUND");
  });

  it("A PATCHing B's org → 404", async () => {
    const res = await call(patchOrg, {
      bearer: userA.accessToken,
      params: { orgId: orgB.id },
      body: { name: "hijacked" },
    });
    expect(res.status).toBe(404);
  });

  it("A listing B's members / settings / doctors → 404", async () => {
    for (const h of [listMembers, getSettings, listDoctors]) {
      const res = await call(h, { bearer: userA.accessToken, params: { orgId: orgB.id } });
      expect(res.status).toBe(404);
    }
  });

  it("A's members list never contains B's members", async () => {
    // Seed a member into B.
    await call(inviteMember, {
      bearer: userB.accessToken,
      params: { orgId: orgB.id },
      body: { email: `bmem-${Date.now()}@test.local`, fullName: "B Mem", role: "RECEPTIONIST" },
    });
    const res = await call<{ data: Array<{ user: { email: string } }> }>(listMembers, {
      bearer: userA.accessToken,
      params: { orgId: orgA.id },
    });
    expect(res.status).toBe(200);
    expect(res.body.data.every((m) => !m.user.email.startsWith("bmem-"))).toBe(true);
  });

  it("a body-supplied organizationId is rejected (strict schema), never honored", async () => {
    const res = await call(createDoctor, {
      bearer: userA.accessToken,
      params: { orgId: orgA.id },
      body: {
        email: `d-${Date.now()}@test.local`,
        fullName: "D",
        displayName: "Dr D",
        organizationId: orgB.id, // attempt to cross tenants via the body
      },
    });
    expect(res.status).toBe(422);
    expect((res.body as { error: { code: string } }).error.code).toBe("VALIDATION_FAILED");
  });

  it("no X-Org-Id header path: an unknown :orgId is a plain 404", async () => {
    const res = await call(getOrg, {
      bearer: userA.accessToken,
      params: { orgId: "00000000-0000-0000-0000-000000000000" },
    });
    expect(res.status).toBe(404);
  });

  it("a non-member with a valid token still gets 404 for an org they don't belong to", async () => {
    const stranger = await registerAndLogin("S");
    const res = await call(getOrg, {
      bearer: stranger.accessToken,
      params: { orgId: orgA.id },
    });
    expect(res.status).toBe(404);
  });

  // §30 of the dashboard/directory request: an appointment belongs to its
  // clinic's tenant scope exactly like every other resource — a Clinic A
  // user can read their own appointment, a Clinic A user reading a Clinic B
  // appointment gets the same 404 (existence never confirmed), and B's
  // private appointment never leaks into A's list endpoint.
  it(
    "appointments are tenant-scoped: A reads own, A reading B's → 404, no leak",
    async () => {
    // Clinic A: doctor + availability + patient + one booked appointment.
    const adminA = userA.accessToken;
    const docA = await createDoctorWithLogin(adminA, orgA.id);
    await setWeeklyAvailability(adminA, orgA.id, docA.doctorId);
    const patientA = await createPatient(orgA.id, userA.userId);
    const slotA = await firstSlot(adminA, orgA.id, docA.doctorId);
    const bookA = await call<{ id: string }>(bookAppointmentRoute, {
      bearer: adminA,
      params: { orgId: orgA.id },
      body: { patientId: patientA.id, doctorId: docA.doctorId, scheduledStart: slotA.start },
    });
    expect(bookA.status).toBe(201);
    const apptAId = bookA.body.id;

    // Clinic B: private appointment the same way.
    const adminB = userB.accessToken;
    const docB = await createDoctorWithLogin(adminB, orgB.id);
    await setWeeklyAvailability(adminB, orgB.id, docB.doctorId);
    const patientB = await createPatient(orgB.id, userB.userId);
    const slotB = await firstSlot(adminB, orgB.id, docB.doctorId);
    const bookB = await call<{ id: string }>(bookAppointmentRoute, {
      bearer: adminB,
      params: { orgId: orgB.id },
      body: { patientId: patientB.id, doctorId: docB.doctorId, scheduledStart: slotB.start },
    });
    expect(bookB.status).toBe(201);
    const apptBId = bookB.body.id;

    // A reading their own → 200.
    const own = await call(getAppointmentRoute, {
      bearer: adminA,
      params: { orgId: orgA.id, appointmentId: apptAId },
    });
    expect(own.status).toBe(200);

    // A reading B's by id → 404, body must not leak B's data.
    const cross = await call(getAppointmentRoute, {
      bearer: adminA,
      params: { orgId: orgA.id, appointmentId: apptBId },
    });
    expect(cross.status).toBe(404);
    expect(JSON.stringify(cross.body)).not.toContain("clinicB");

    // B's appointment never appears in A's list, and A's id can't fetch it
    // through B's route with A's token either.
    const listA = await call<{ data: Array<{ id: string }> }>(listAppointmentsRoute, {
      bearer: adminA,
      params: { orgId: orgA.id },
    });
    expect(listA.status).toBe(200);
    expect(listA.body.data.some((a) => a.id === apptBId)).toBe(false);

    const viaB = await call(getAppointmentRoute, {
      bearer: adminA,
      params: { orgId: orgB.id, appointmentId: apptBId },
    });
    expect(viaB.status).toBe(404);

    // Sanity: the rows really exist (proves the 404 is scoping, not absence).
    expect(await db.appointment.count({ where: { id: { in: [apptAId, apptBId] } } })).toBe(2);
    },
    120_000,
  );
});
