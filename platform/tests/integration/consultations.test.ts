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
import { GET as getConsultationRoute, PUT as saveConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js";
import { POST as signRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/sign/route.js";
import { POST as addItemRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/prescription-items/route.js";
import { DELETE as removeItemRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/prescription-items/[itemId]/route.js";
import { PUT as setCapsRoute } from "../../app/api/orgs/[orgId]/members/[membershipId]/capabilities/route.js";
import { GET as listMembersRoute } from "../../app/api/orgs/[orgId]/members/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let doctorToken: string;
let otherDoctorToken: string;
let appointmentId: string;
let patientOwnerToken: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("cadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "consult")).id;

  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  doctorToken = doc.token;
  const other = await createDoctorWithLogin(adminToken, orgId);
  otherDoctorToken = other.token;

  await setWeeklyAvailability(adminToken, orgId, doctorId, { slotMinutes: 15 });

  const patUser = await registerAndLogin("cpat");
  patientOwnerToken = patUser.accessToken;
  await db.membership.create({
    data: { userId: patUser.userId, organizationId: orgId, role: "PATIENT", status: "ACTIVE" },
  });
  const patient = await createPatient(orgId, adminUserId, patUser.userId);

  const slot = await firstSlot(adminToken, orgId, doctorId, 7);
  const appt = await call<{ id: string }>(bookRoute, {
    bearer: adminToken,
    params: { orgId },
    body: { patientId: patient.id, doctorId, scheduledStart: slot.start },
  });
  appointmentId = appt.body.id;
});
afterAll(disconnect);

describe("consultations & prescriptions (RBAC.md corrected DOCTOR rule)", () => {
  it("the assigned doctor can save notes on their own appointment", async () => {
    const res = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: doctorToken,
      params: { orgId, appointmentId },
      body: { subjective: "Patient reports mild fever.", plan: "Rest and fluids." },
    });
    expect(res.status).toBe(200);
  });

  it("an unassigned doctor cannot read or write it", async () => {
    const read = await call(getConsultationRoute, { bearer: otherDoctorToken, params: { orgId, appointmentId } });
    expect(read.status).toBe(403);
    const write = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: otherDoctorToken,
      params: { orgId, appointmentId },
      body: { subjective: "hijack" },
    });
    expect(write.status).toBe(403);
  });

  it("RECEPTIONIST can never read or write clinical notes", async () => {
    const recEmail = `rec-consult-${Date.now()}@test.local`;
    const invite = await call<{ id: string; user: { id: string } }>(
      (await import("../../app/api/orgs/[orgId]/members/route.js")).POST,
      {
        bearer: adminToken,
        params: { orgId },
        body: { email: recEmail, fullName: "Rec Consult", role: "RECEPTIONIST" },
      },
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
    const res = await call(getConsultationRoute, {
      bearer: login.body.accessToken,
      params: { orgId, appointmentId },
    });
    expect(res.status).toBe(403);
  });

  it("CLINIC_ADMIN without CLINICAL_RECORD_READ cannot read; with the capability, can", async () => {
    const denied = await call(getConsultationRoute, { bearer: adminToken, params: { orgId, appointmentId } });
    expect(denied.status).toBe(403);

    // Grant via a second admin (no-self-grant rule from Phase 1).
    const secondAdminEmail = `admin2-${Date.now()}@test.local`;
    const invite = await call<{ id: string; user: { id: string } }>(
      (await import("../../app/api/orgs/[orgId]/members/route.js")).POST,
      { bearer: adminToken, params: { orgId }, body: { email: secondAdminEmail, fullName: "Admin Two", role: "CLINIC_ADMIN" } },
    );
    const { hashPassword } = await import("@/lib/auth/password.js");
    await db.user.update({
      where: { id: invite.body.user.id },
      data: { passwordHash: await hashPassword("Passw0rd!长test") },
    });
    const login = await call<{ accessToken: string }>(
      (await import("../../app/api/auth/login/route.js")).POST,
      { client: "app", body: { email: secondAdminEmail, password: "Passw0rd!长test" } },
    );

    const members = await call<{ data: Array<{ id: string; role: string; user: { email: string } }> }>(
      listMembersRoute,
      { bearer: login.body.accessToken, params: { orgId } },
    );
    const firstAdminMembership = members.body.data.find((m) => m.role === "CLINIC_ADMIN" && m.user.email !== secondAdminEmail)!;

    const grant = await call(setCapsRoute, {
      bearer: login.body.accessToken,
      params: { orgId, membershipId: firstAdminMembership.id },
      body: { capabilities: ["CLINICAL_RECORD_READ"] },
    });
    expect(grant.status).toBe(200);

    const allowed = await call(getConsultationRoute, { bearer: adminToken, params: { orgId, appointmentId } });
    expect(allowed.status).toBe(200);
  });

  it("the patient owner can read their own consultation, never write it", async () => {
    const read = await call(getConsultationRoute, { bearer: patientOwnerToken, params: { orgId, appointmentId } });
    expect(read.status).toBe(200);
    const write = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: patientOwnerToken,
      params: { orgId, appointmentId },
      body: { plan: "self-prescribed" },
    });
    expect(write.status).toBe(403);
  });

  it("adds and removes prescription items; audited", async () => {
    const added = await call<{ id: string; drugName: string }>(addItemRoute, {
      bearer: doctorToken,
      params: { orgId, appointmentId },
      body: { drugName: "Paracetamol", dosage: "1 tablet", frequency: "Twice daily", durationDays: 3 },
    });
    expect(added.status).toBe(201);
    expect(added.body.drugName).toBe("Paracetamol");

    const auditRow = await db.auditLog.findFirst({
      where: { organizationId: orgId, action: "PRESCRIPTION_ITEM_ADDED", entityId: added.body.id },
    });
    expect(auditRow).not.toBeNull();

    const removed = await call(removeItemRoute, {
      method: "DELETE",
      bearer: doctorToken,
      params: { orgId, appointmentId, itemId: added.body.id },
    });
    expect(removed.status).toBe(200);
  });

  it("signing locks the consultation from further edits", async () => {
    const signed = await call(signRoute, { bearer: doctorToken, params: { orgId, appointmentId } });
    expect(signed.status).toBe(200);

    const editAfterSign = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: doctorToken,
      params: { orgId, appointmentId },
      body: { plan: "too late" },
    });
    expect(editAfterSign.status).toBe(409);

    const addAfterSign = await call(addItemRoute, {
      bearer: doctorToken,
      params: { orgId, appointmentId },
      body: { drugName: "Ibuprofen" },
    });
    expect(addAfterSign.status).toBe(409);
  });
});
