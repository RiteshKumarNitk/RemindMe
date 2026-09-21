import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
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
import { PUT as saveConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js";
import { GET as getPatientRoute } from "../../app/api/orgs/[orgId]/patients/[patientId]/route.js";
import {
  GET as listGrantsRoute,
  POST as createGrantRoute,
} from "../../app/api/orgs/[orgId]/patients/[patientId]/access-grants/route.js";
import { DELETE as revokeGrantRoute } from "../../app/api/orgs/[orgId]/patients/[patientId]/access-grants/[grantId]/route.js";
import { GET as myAccessRoute } from "../../app/api/orgs/[orgId]/my-access/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let patientOwnerToken: string;
let patientId: string;
let guardianToken: string;
let guardianEmail: string;
let appointmentId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("famadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "family")).id;

  const owner = await registerAndLogin("fampat");
  patientOwnerToken = owner.accessToken;
  await db.membership.create({
    data: { userId: owner.userId, organizationId: orgId, role: "PATIENT", status: "ACTIVE" },
  });
  const patient = await createPatient(orgId, adminUserId, owner.userId);
  patientId = patient.id;

  const guardian = await registerAndLogin("famguard");
  guardianToken = guardian.accessToken;
  guardianEmail = guardian.email;
  await db.membership.create({
    data: { userId: guardian.userId, organizationId: orgId, role: "PATIENT", status: "ACTIVE" },
  });

  const doc = await createDoctorWithLogin(adminToken, orgId);
  await setWeeklyAvailability(adminToken, orgId, doc.doctorId, { slotMinutes: 15 });
  const slot = await firstSlot(adminToken, orgId, doc.doctorId, 7);
  const appt = await call<{ id: string }>(bookRoute, {
    bearer: adminToken,
    params: { orgId },
    body: { patientId, doctorId: doc.doctorId, scheduledStart: slot.start },
  });
  appointmentId = appt.body.id;
  await call(saveConsultationRoute, {
    method: "PUT",
    bearer: doc.token,
    params: { orgId, appointmentId },
    body: { subjective: "Routine checkup." },
  });
});
afterAll(disconnect);

describe("family / guardian access grants", () => {
  it("a guardian with no grant cannot read the patient", async () => {
    const res = await call(getPatientRoute, { bearer: guardianToken, params: { orgId, patientId } });
    expect(res.status).toBe(403);
  });

  it("rejects a grant for an email with no platform account", async () => {
    const res = await call(createGrantRoute, {
      bearer: patientOwnerToken,
      params: { orgId, patientId },
      body: { granteeEmail: "nobody@test.local", permissions: ["VIEW_PROFILE"] },
    });
    expect(res.status).toBe(422);
  });

  it("rejects granting access to yourself", async () => {
    const admin = await db.user.findUniqueOrThrow({ where: { id: adminUserId }, select: { email: true } });
    const res = await call(createGrantRoute, {
      bearer: adminToken,
      params: { orgId, patientId },
      body: { granteeEmail: admin.email, permissions: ["VIEW_PROFILE"] },
    });
    expect(res.status).toBe(422);
  });

  it("RECEPTIONIST cannot manage access grants", async () => {
    const recEmail = `rec-fam-${Date.now()}@test.local`;
    const invite = await call<{ user: { id: string } }>(
      (await import("../../app/api/orgs/[orgId]/members/route.js")).POST,
      { bearer: adminToken, params: { orgId }, body: { email: recEmail, fullName: "Rec Fam", role: "RECEPTIONIST" } },
    );
    const { hashPassword } = await import("@/lib/auth/password.js");
    await db.user.update({
      where: { id: invite.body.user.id },
      data: { passwordHash: await hashPassword("Passw0rd!长test") },
    });
    const login = await call<{ accessToken: string }>(
      (await import("../../app/api/auth/login/route.js")).POST,
      { client: "app", body: { email: recEmail, password: "Passw0rd!长test" } },
    );
    const res = await call(createGrantRoute, {
      bearer: login.body.accessToken,
      params: { orgId, patientId },
      body: { granteeEmail: guardianEmail, permissions: ["VIEW_PROFILE"] },
    });
    expect(res.status).toBe(403);
  });

  it("the patient owner can grant a guardian VIEW_PROFILE only — profile readable, clinical still denied", async () => {
    const grant = await call<{ id: string }>(createGrantRoute, {
      bearer: patientOwnerToken,
      params: { orgId, patientId },
      body: { granteeEmail: guardianEmail, permissions: ["VIEW_PROFILE"], relation: "GUARDIAN" },
    });
    expect(grant.status).toBe(201);

    const familyRow = await db.familyRelationship.findFirst({ where: { dependentPatientId: patientId } });
    expect(familyRow?.relation).toBe("GUARDIAN");

    const profile = await call(getPatientRoute, { bearer: guardianToken, params: { orgId, patientId } });
    expect(profile.status).toBe(200);

    const notes = await call(
      (await import("../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js")).GET,
      { bearer: guardianToken, params: { orgId, appointmentId } },
    );
    expect(notes.status).toBe(403);
  });

  it("re-granting with VIEW_MEDICATIONS extends the same grant to clinical reads", async () => {
    const grant = await call<{ id: string; permissions: string[] }>(createGrantRoute, {
      bearer: patientOwnerToken,
      params: { orgId, patientId },
      body: { granteeEmail: guardianEmail, permissions: ["VIEW_PROFILE", "VIEW_MEDICATIONS"] },
    });
    expect(grant.status).toBe(201);
    expect(grant.body.permissions.sort()).toEqual(["VIEW_MEDICATIONS", "VIEW_PROFILE"]);

    const list = await call<{ data: Array<{ id: string }> }>(listGrantsRoute, {
      bearer: patientOwnerToken,
      params: { orgId, patientId },
    });
    expect(list.body.data).toHaveLength(1); // upserted, not duplicated

    const notes = await call(
      (await import("../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js")).GET,
      { bearer: guardianToken, params: { orgId, appointmentId } },
    );
    expect(notes.status).toBe(200);
  });

  it("shows up in the guardian's own my-access listing", async () => {
    const mine = await call<{ data: Array<{ patient: { id: string } }> }>(myAccessRoute, {
      bearer: guardianToken,
      params: { orgId },
    });
    expect(mine.body.data.map((d) => d.patient.id)).toContain(patientId);
  });

  it("revoking removes access immediately", async () => {
    const list = await call<{ data: Array<{ id: string }> }>(listGrantsRoute, {
      bearer: patientOwnerToken,
      params: { orgId, patientId },
    });
    const grantId = list.body.data[0]!.id;

    const revoke = await call(revokeGrantRoute, {
      method: "DELETE",
      bearer: patientOwnerToken,
      params: { orgId, patientId, grantId },
    });
    expect(revoke.status).toBe(200);

    const profile = await call(getPatientRoute, { bearer: guardianToken, params: { orgId, patientId } });
    expect(profile.status).toBe(403);
  });
});
