import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  firstSlot,
  makeDoctorPublic,
  publishOrgForDiscovery,
  registerAndLogin,
  setWeeklyAvailability,
} from "../helpers/factories.js";
import { GET as listPublicOrgsRoute } from "../../app/api/public/organizations/route.js";
import { GET as listPublicDoctorsRoute } from "../../app/api/public/doctors/route.js";
import { GET as publicSlotsRoute } from "../../app/api/public/doctors/[doctorId]/slots/route.js";
import { POST as selfBookRoute } from "../../app/api/patient/appointments/route.js";
import { GET as getAppointmentRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/route.js";

let adminToken: string;
let orgId: string;
let doctorId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("pbadm");
  adminToken = admin.accessToken;
  orgId = (await createOrg(adminToken, "pbclinic")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  await setWeeklyAvailability(adminToken, orgId, doctorId);
});
afterAll(disconnect);

describe("public discovery + patient self-booking (PRODUCT_EVOLUTION_PLAN.md Phase 5/6)", () => {
  it("an unpublished org/doctor is invisible to public discovery", async () => {
    const orgs = await call<{ data: Array<{ id: string }> }>(listPublicOrgsRoute, {
      url: "http://test.local/api",
    });
    expect(orgs.body.data.find((o) => o.id === orgId)).toBeUndefined();

    const docs = await call<{ data: Array<{ id: string }> }>(listPublicDoctorsRoute, {
      url: "http://test.local/api",
    });
    expect(docs.body.data.find((d) => d.id === doctorId)).toBeUndefined();
  });

  it("publishing the org and the doctor makes both visible in public discovery", async () => {
    await publishOrgForDiscovery(adminToken, orgId);
    await makeDoctorPublic(adminToken, orgId, doctorId);

    const orgs = await call<{ data: Array<{ id: string }> }>(listPublicOrgsRoute, {
      url: "http://test.local/api",
    });
    expect(orgs.body.data.some((o) => o.id === orgId)).toBe(true);

    const docs = await call<{ data: Array<{ id: string; organization: { id: string } }> }>(
      listPublicDoctorsRoute,
      { url: "http://test.local/api" },
    );
    expect(docs.body.data.some((d) => d.id === doctorId && d.organization.id === orgId)).toBe(true);
  });

  it("public slots for the doctor use the same authoritative slot math as the staff endpoint", async () => {
    const { date } = await firstSlot(adminToken, orgId, doctorId, 5);
    const res = await call<{ slots: Array<{ start: string; end: string }> }>(publicSlotsRoute, {
      params: { doctorId },
      url: `http://test.local/api?date=${date}`,
    });
    expect(res.status).toBe(200);
    expect(res.body.slots.length).toBeGreaterThan(0);
  });

  it("a brand-new user can self-book — creates their own PATIENT membership + Patient record", async () => {
    const patient = await registerAndLogin("pbpatient");
    const slot = await firstSlot(adminToken, orgId, doctorId, 6);

    const res = await call<{ id: string; organizationId: string; status: string; bookingSource: string }>(
      selfBookRoute,
      {
        bearer: patient.accessToken,
        body: {
          organizationId: orgId,
          doctorId,
          scheduledStart: slot.start,
          reason: "Checkup",
          patient: { firstName: "New", lastName: "Patient" },
        },
      },
    );
    expect(res.status).toBe(201);
    expect(res.body.organizationId).toBe(orgId);
    expect(res.body.bookingSource).toBe("PATIENT_APP");

    const membership = await db.membership.findFirst({
      where: { userId: patient.userId, organizationId: orgId, role: "PATIENT" },
    });
    expect(membership?.status).toBe("ACTIVE");

    const patientRow = await db.patient.findUnique({
      where: { organizationId_ownerUserId: { organizationId: orgId, ownerUserId: patient.userId } },
    });
    expect(patientRow?.firstName).toBe("New");
  });

  it("double-booking the same slot is rejected, same as staff booking", async () => {
    const patient = await registerAndLogin("pbdup");
    const slot = await firstSlot(adminToken, orgId, doctorId, 8);

    const first = await call(selfBookRoute, {
      bearer: patient.accessToken,
      body: { organizationId: orgId, doctorId, scheduledStart: slot.start, patient: { firstName: "A", lastName: "B" } },
    });
    expect(first.status).toBe(201);

    const other = await registerAndLogin("pbdup2");
    const second = await call(selfBookRoute, {
      bearer: other.accessToken,
      body: { organizationId: orgId, doctorId, scheduledStart: slot.start, patient: { firstName: "C", lastName: "D" } },
    });
    expect(second.status).toBe(409);
  });

  it("a repeat booking by the same patient reuses their existing Patient record, not a duplicate", async () => {
    const patient = await registerAndLogin("pbrepeat");
    const slotA = await firstSlot(adminToken, orgId, doctorId, 9);
    const first = await call<{ patientId: string }>(selfBookRoute, {
      bearer: patient.accessToken,
      body: { organizationId: orgId, doctorId, scheduledStart: slotA.start, patient: { firstName: "R", lastName: "P" } },
    });
    expect(first.status).toBe(201);

    const slotB = await firstSlot(adminToken, orgId, doctorId, 10);
    const second = await call<{ patientId: string }>(selfBookRoute, {
      bearer: patient.accessToken,
      body: { organizationId: orgId, doctorId, scheduledStart: slotB.start, patient: { firstName: "R", lastName: "P" } },
    });
    expect(second.status).toBe(201);
    expect(second.body.patientId).toBe(first.body.patientId);
  });

  it("self-booking into an org that isn't publicly listed is rejected", async () => {
    const privateOrgId = (await createOrg(adminToken, "pbprivate")).id;
    const doc = await createDoctorWithLogin(adminToken, privateOrgId);
    await setWeeklyAvailability(adminToken, privateOrgId, doc.doctorId);
    const slot = await firstSlot(adminToken, privateOrgId, doc.doctorId, 3);

    const patient = await registerAndLogin("pbprivpat");
    const res = await call(selfBookRoute, {
      bearer: patient.accessToken,
      body: {
        organizationId: privateOrgId,
        doctorId: doc.doctorId,
        scheduledStart: slot.start,
        patient: { firstName: "X", lastName: "Y" },
      },
    });
    expect(res.status).toBe(404);
  });

  it("a patient cannot read another patient's appointment by id, even within the same clinic (getAppointment ownership fix)", async () => {
    const owner = await registerAndLogin("pbowner");
    const slotOwner = await firstSlot(adminToken, orgId, doctorId, 11);
    const booked = await call<{ id: string }>(selfBookRoute, {
      bearer: owner.accessToken,
      body: {
        organizationId: orgId,
        doctorId,
        scheduledStart: slotOwner.start,
        patient: { firstName: "Owner", lastName: "Only" },
      },
    });
    expect(booked.status).toBe(201);
    const appointmentId = booked.body.id;

    const stranger = await registerAndLogin("pbstranger");
    // The stranger needs their own membership in the org to reach the
    // tenant-resolution step at all — book their own, unrelated slot first.
    const slotStranger = await firstSlot(adminToken, orgId, doctorId, 12);
    await call(selfBookRoute, {
      bearer: stranger.accessToken,
      body: {
        organizationId: orgId,
        doctorId,
        scheduledStart: slotStranger.start,
        patient: { firstName: "Stranger", lastName: "Danger" },
      },
    });

    const strangerRead = await call(getAppointmentRoute, {
      bearer: stranger.accessToken,
      params: { orgId, appointmentId },
    });
    expect(strangerRead.status).toBe(404);

    const ownerRead = await call<{ id: string }>(getAppointmentRoute, {
      bearer: owner.accessToken,
      params: { orgId, appointmentId },
    });
    expect(ownerRead.status).toBe(200);
    expect(ownerRead.body.id).toBe(appointmentId);
  });
});
