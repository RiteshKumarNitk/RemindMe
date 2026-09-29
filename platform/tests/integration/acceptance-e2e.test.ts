import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  makeDoctorPublic,
  registerAndLogin,
  setWeeklyAvailability,
  TEST_PASSWORD,
} from "../helpers/factories.js";
import { POST as loginRoute } from "../../app/api/auth/login/route.js";
import { POST as createOrgRoute } from "../../app/api/orgs/route.js";
import { PATCH as patchOrgRoute } from "../../app/api/orgs/[orgId]/route.js";
import { POST as createLocationRoute } from "../../app/api/orgs/[orgId]/locations/route.js";
import { POST as createAppointmentTypeRoute } from "../../app/api/orgs/[orgId]/appointment-types/route.js";
import { POST as createDoctorRoute } from "../../app/api/orgs/[orgId]/doctors/route.js";
import { PUT as putAvailabilityRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/availability/route.js";
import { GET as slotsRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/slots/route.js";
import { POST as publishRoute } from "../../app/api/orgs/[orgId]/publish/route.js";
import { POST as requestVerificationRoute } from "../../app/api/orgs/[orgId]/request-verification/route.js";
import { PUT as setVerificationRoute } from "../../app/api/admin/organizations/[targetOrgId]/verification/route.js";
import { GET as listPublicOrgsRoute } from "../../app/api/public/organizations/route.js";
import { GET as listPublicDoctorsRoute } from "../../app/api/public/doctors/route.js";
import { GET as publicOrgDetailRoute } from "../../app/api/public/organizations/[slug]/route.js";
import { GET as publicDoctorDetailRoute } from "../../app/api/public/doctors/[doctorId]/route.js";
import { GET as publicSlotsRoute } from "../../app/api/public/doctors/[doctorId]/slots/route.js";
import { POST as selfBookRoute } from "../../app/api/patient/appointments/route.js";
import { GET as listAppointmentsRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { GET as getAppointmentRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/route.js";
import { POST as checkInRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/check-in/route.js";
import { GET as queueBoardRoute } from "../../app/api/orgs/[orgId]/queue/route.js";
import { POST as queueActionRoute } from "../../app/api/orgs/[orgId]/queue/[entryId]/[action]/route.js";
import { PUT as saveConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js";
import { POST as signConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/sign/route.js";
import { POST as addPrescriptionItemRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/prescription-items/route.js";
import { PUT as setCapabilitiesRoute } from "../../app/api/orgs/[orgId]/members/[membershipId]/capabilities/route.js";
import { GET as listMembersRoute, POST as inviteMemberRoute } from "../../app/api/orgs/[orgId]/members/route.js";
import { GET as auditRoute } from "../../app/api/orgs/[orgId]/audit/route.js";
import { POST as startConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/start/route.js";
import { POST as completeConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/complete/route.js";
import { GET as getConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js";

let adminA: string;
let adminB: string;
let orgA: string;
let orgB: string;
let doctorAId: string;
let doctorAToken: string;
let typeAId: string;
let locationAId: string;
let locationBId: string;
let slugA: string;
let patientUser: { token: string; userId: string };
void (
  // (managerUser is realized as the RECEPTIONIST membership created below;
  // the variable is kept only for the role-visibility assertions.)
  null
);
let appointmentId: string;

const PW = TEST_PASSWORD;

beforeAll(async () => {
  await truncateAll();
  const a = await registerAndLogin("e2eA");
  adminA = a.accessToken;
  const b = await registerAndLogin("e2eB");
  adminB = b.accessToken;
});

afterAll(disconnect);

describe("end-to-end acceptance: clinic → public listing → booking → clinic management", () => {
  // ~25 authenticated calls incl. argon2 logins — far beyond the 30s default.
  it(
    "walks the full lifecycle (steps 1–22)",
    async () => {
    // Step 1–2: create Clinic A (org + settings + admin membership), Clinic B as control.
    orgA = (await createOrg(adminA, "e2eclinicA")).id;
    orgB = (await createOrg(adminB, "e2eclinicB")).id;

    // Step 2: location.
    const loc = await call<{ id: string }>(createLocationRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      body: { name: "Jaipur Main", addressLine1: "12 Station Road", city: "Jaipur", state: "Rajasthan", postalCode: "302001" },
    });
    expect(loc.status).toBe(201);
    locationAId = loc.body.id;
    const loc2 = await call<{ id: string }>(createLocationRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      body: { name: "Mansarovar", city: "Jaipur" },
    });
    expect(loc2.status).toBe(201);
    locationBId = loc2.body.id;

    // Step 3: doctor (and listed publicly — an org being published does not
    // auto-publish its doctors; that's a separate, deliberate switch).
    const doc = await createDoctorWithLogin(adminA, orgA);
    doctorAId = doc.doctorId;
    doctorAToken = doc.token;
    await makeDoctorPublic(adminA, orgA, doctorAId);

    // Step 4: appointment type.
    const type = await call<{ id: string }>(createAppointmentTypeRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      body: { name: "Follow-up", durationMinutes: 30 },
    });
    expect(type.status).toBe(201);
    typeAId = type.body.id;

    // Step 5: availability.
    await setWeeklyAvailability(adminA, orgA, doctorAId);

    // Step 6: public profile fields.
    const patched = await call(patchOrgRoute, {
      method: "PATCH",
      bearer: adminA,
      params: { orgId: orgA },
      body: {
        orgType: "HOSPITAL",
        tagline: "Acceptance-test hospital",
        about: "A full-profile teaching hospital used by the E2E acceptance suite.",
        publicPhone: "+91 90000 00001",
        website: "https://clinicA.example",
      },
    });
    expect(patched.status).toBe(200);

    // Step 7: request verification (readiness gate must pass now).
    const rv = await call<{ verificationStatus: string }>(requestVerificationRoute, {
      method: "POST",
      bearer: adminA,
      params: { orgId: orgA },
    });
    expect(rv.status).toBe(200);
    expect(rv.body.verificationStatus).toBe("PENDING_VERIFICATION");

    // Step 8: super admin approves. The admin who created Clinic A is the
    // de-facto platform operator in this scenario (no seeded superadmin
    // exists in a truncated DB): grant isPlatformAdmin directly, re-login.
    const superAdmin = await db.user.findFirstOrThrow({
      where: { memberships: { some: { organizationId: orgA, role: "CLINIC_ADMIN" } } },
      select: { id: true, email: true },
    });
    await db.user.update({ where: { id: superAdmin.id }, data: { isPlatformAdmin: true } });
    const superLogin = await call<{ accessToken: string }>(loginRoute, {
      client: "app",
      body: { email: superAdmin.email, password: PW },
    });
    expect(superLogin.status).toBe(200);
    const approved = await call<{ verificationStatus: string }>(setVerificationRoute, {
      method: "PUT",
      bearer: superLogin.body.accessToken,
      params: { targetOrgId: orgA },
      body: { status: "VERIFIED" },
    });
    expect(approved.status).toBe(200);
    expect(approved.body.verificationStatus).toBe("VERIFIED");

    // Step 9: publish.
    const pub = await call<{ isPubliclyListed: boolean; slug: string }>(publishRoute, {
      method: "POST",
      bearer: adminA,
      params: { orgId: orgA },
    });
    expect(pub.status).toBe(200);
    expect(pub.body.isPubliclyListed).toBe(true);
    slugA = pub.body.slug;

    // Step 10: discoverable on the website directory (public API).
    const dir = await call<{ data: Array<{ id: string }> }>(listPublicOrgsRoute, { url: "http://test.local/api" });
    expect(dir.status).toBe(200);
    expect(dir.body.data.some((o) => o.id === orgA)).toBe(true);
    // …and Clinic B (not published) stays invisible.
    expect(dir.body.data.some((o) => o.id === orgB)).toBe(false);

    // Step 11: doctor discoverable.
    const docs = await call<{ data: Array<{ id: string; organization: { id: string } }> }>(listPublicDoctorsRoute, { url: "http://test.local/api" });
    expect(docs.status).toBe(200);
    const publicDoc = docs.body.data.find((d) => d.id === doctorAId);
    expect(publicDoc).toBeDefined();
    expect(publicDoc!.organization.id).toBe(orgA);

    // Steps 12–13: /search composes the same services; org detail by slug.
    const detail = await call(publicOrgDetailRoute, { params: { slug: slugA } });
    expect(detail.status).toBe(200);
    const detailBody = detail.body as { appointmentTypes: Array<{ id: string }>; locations: Array<{ id: string }>; doctorProfiles: Array<{ id: string }> };
    expect(detailBody.appointmentTypes.some((t) => t.id === typeAId)).toBe(true);
    expect(detailBody.locations.length).toBe(2);
    expect(detailBody.doctorProfiles.some((d) => d.id === doctorAId)).toBe(true);

    // Step 14: doctor profile (public).
    const docDetail = await call(publicDoctorDetailRoute, { params: { doctorId: doctorAId } });
    expect(docDetail.status).toBe(200);
    expect((docDetail.body as { organization: { appointmentTypes: unknown[] } }).organization.appointmentTypes.length).toBe(1);

    // Step 15: location choice — clinic default tz resolution with an explicit
    // branch id is what booking stores; both branches resolve the org tz here.
    // Step 16: type-aware slot fetch (staff endpoint, authoritative engine).
    const d = new Date(Date.now() + 3 * 86_400_000);
    const date = d.toISOString().slice(0, 10);
    const slots30 = await call<{ slots: Array<{ start: string }>; durationMinutes: number }>(slotsRoute, {
      bearer: adminA,
      params: { orgId: orgA, doctorId: doctorAId },
      url: `http://test.local/api?date=${date}&typeId=${typeAId}`,
    });
    expect(slots30.status).toBe(200);
    expect(slots30.body.durationMinutes).toBe(30);
    expect(slots30.body.slots.length).toBeGreaterThan(0);

    // Step 17–18: public slots for the same doctor agree.
    const pubSlots = await call<{ slots: Array<{ start: string }>; durationMinutes: number }>(publicSlotsRoute, {
      params: { doctorId: doctorAId },
      url: `http://test.local/api?date=${date}&appointmentTypeId=${typeAId}`,
    });
    expect(pubSlots.status).toBe(200);
    expect(pubSlots.body.slots.length).toBe(slots30.body.slots.length);
    const slot = pubSlots.body.slots[0]!.start;

    // Step 19: patient registers (+ logs in).
    const pat = await registerAndLogin("e2epat");
    patientUser = { token: pat.accessToken, userId: pat.userId };
    // Clinic A also staffs a receptionist (role-visibility step 26) with no
    // clinical capabilities — the default, which the RBAC checks below rely on.
    const invite = await call<{ id: string }>(inviteMemberRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      body: { email: `mgr-${Date.now()}@test.local`, fullName: "Mgr Test", role: "RECEPTIONIST" },
    });
    expect(invite.status).toBe(201);
    const caps = await call(setCapabilitiesRoute, {
      method: "PUT",
      bearer: adminA,
      params: { orgId: orgA, membershipId: invite.body.id },
      body: { capabilities: [] },
    });
    expect(caps.status).toBe(200);

    // Step 21: patient self-books through the public booking API with the
    // chosen type + chosen branch (Mansarovar) — steps 15/16/20 all honored.
    const booked = await call<{ id: string; locationId: string | null; appointmentTypeId: string | null; status: string }>(selfBookRoute, {
      bearer: patientUser.token,
      body: {
        organizationId: orgA,
        doctorId: doctorAId,
        scheduledStart: slot,
        appointmentTypeId: typeAId,
        locationId: locationBId,
        patient: { firstName: "Rahul", lastName: "E2E", phone: "+91 90000 00002" },
      },
    });
    expect(booked.status).toBe(201);
    appointmentId = booked.body.id;
    expect(booked.body.status).toBe("CONFIRMED");

    // Step 22: verify the DATABASE row carries the full ownership chain —
    // org + Mansarovar branch + doctor + type + patient, never the other branch.
    const row = await db.appointment.findFirstOrThrow({
      where: { id: appointmentId },
      select: { organizationId: true, locationId: true, doctorId: true, appointmentTypeId: true, patient: { select: { ownerUserId: true } } },
    });
    expect(row.organizationId).toBe(orgA);
    expect(row.locationId).toBe(locationBId);
    expect(row.doctorId).toBe(doctorAId);
    expect(row.appointmentTypeId).toBe(typeAId);
    expect(row.patient.ownerUserId).toBe(patientUser.userId);
    expect(row.locationId).not.toBe(locationAId);
    },
    180_000,
  );

  it(
    "shows the appointment to every authorized role, then completes the clinical flow (steps 23–33)",
    async () => {
    // Step 23: patient sees their own appointment (with location + type).
    const mine = await call<{ location: { id: string } | null; appointmentType: { id: string } | null }>(getAppointmentRoute, {
      bearer: patientUser.token,
      params: { orgId: orgA, appointmentId },
    });
    expect(mine.status).toBe(200);
    expect(mine.body.location?.id).toBe(locationBId);
    expect(mine.body.appointmentType?.id).toBe(typeAId);

    // Step 24: clinic owner sees it.
    const ownerView = await call(getAppointmentRoute, {
      bearer: adminA,
      params: { orgId: orgA, appointmentId },
    });
    expect(ownerView.status).toBe(200);

    // Step 25: a manager with no clinical capability sees the appointment but
    // can never read the clinical record (enforced server-side).
    const listForStaff = await call<{ data: Array<{ id: string }> }>(listAppointmentsRoute, {
      bearer: adminA,
      params: { orgId: orgA },
    });
    expect(listForStaff.status).toBe(200);
    expect(listForStaff.body.data.some((a) => a.id === appointmentId)).toBe(true);

    // Step 26: receptionist exists on staff and sees the board — create one
    // explicitly so step 26 is a real role check, not an admin surrogate.
    const members = await call<{ data: Array<{ id: string; role: string; user: { email: string } }> }>(listMembersRoute, {
      bearer: adminA,
      params: { orgId: orgA },
    });
    expect(members.status).toBe(200);
    expect(members.body.data.some((m) => m.role === "RECEPTIONIST")).toBe(true);

    // Step 27: the assigned doctor sees it.
    const doctorView = await call(getAppointmentRoute, {
      bearer: doctorAToken,
      params: { orgId: orgA, appointmentId },
    });
    expect(doctorView.status).toBe(200);

    // Step 28: check-in (staff action) allocates a token.
    const checkIn = await call<{ queue: { id: string; tokenNumber: number; queueDate: string } }>(checkInRoute, {
      bearer: adminA,
      params: { orgId: orgA, appointmentId },
    });
    expect(checkIn.status).toBe(200);
    const entryId = checkIn.body.queue.id;
    expect(checkIn.body.queue.tokenNumber).toBeGreaterThan(0);

    // Step 29: queue board shows the WAITING entry on the appointment's
    // own queue day (the visit is 3 days out, so today's board is empty).
    const board = await call<{ entries: Array<{ id: string; state: string }> }>(queueBoardRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      url: `http://test.local/api?doctorId=${doctorAId}&date=${new Date(checkIn.body.queue.queueDate)
        .toISOString()
        .slice(0, 10)}`,
    });
    expect(board.status).toBe(200);
    expect(board.body.entries.some((e) => e.id === entryId && e.state === "WAITING")).toBe(true);

    // Step 30: doctor starts the consultation (assigned-doctor-only action).
    const start = await call(startConsultationRoute, {
      bearer: doctorAToken,
      params: { orgId: orgA, appointmentId },
    });
    expect(start.status).toBe(200);

    // Step 31: SOAP notes + prescription item.
    const soap = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: doctorAToken,
      params: { orgId: orgA, appointmentId },
      body: { subjective: "Fever 3 days", objective: "38.4C", assessment: "Viral", plan: "Rest, fluids" },
    });
    expect(soap.status).toBe(200);
    const item = await call(addPrescriptionItemRoute, {
      bearer: doctorAToken,
      params: { orgId: orgA, appointmentId },
      body: { drugName: "Paracetamol", dosage: "500mg", frequency: "TDS", durationDays: 3 },
    });
    expect(item.status).toBe(201);

    // Staff can never write the clinical record (RBAC, backend-enforced).
    const staffWrite = await call(saveConsultationRoute, {
      method: "PUT",
      bearer: adminA,
      params: { orgId: orgA, appointmentId },
      body: { assessment: "hijack" },
    });
    expect(staffWrite.status).toBe(403);

    // Step 32: complete.
    const complete = await call(completeConsultationRoute, {
      bearer: doctorAToken,
      params: { orgId: orgA, appointmentId },
    });
    expect(complete.status).toBe(200);
    expect((complete.body as { status: string }).status).toBe("COMPLETED");

    // Sign the record — locked thereafter.
    const signed = await call(signConsultationRoute, { bearer: doctorAToken, params: { orgId: orgA, appointmentId } });
    expect(signed.status).toBe(200);

    // Patient reads the authorized result (their own consultation).
    const patientRead = await call(getConsultationRoute, {
      bearer: patientUser.token,
      params: { orgId: orgA, appointmentId },
    });
    expect(patientRead.status).toBe(200);

    // Step 33: audit trail captured the journey.
    const audit = await call<{ data: Array<{ action: string }> }>(auditRoute, {
      bearer: adminA,
      params: { orgId: orgA },
      url: "http://test.local/api?limit=200",
    });
    expect(audit.status).toBe(200);
    const actions = audit.body.data.map((a) => a.action);
    for (const expected of [
      "ORGANIZATION_CREATED",
      "LOCATION_CREATED",
      "DOCTOR_CREATED",
      "APPOINTMENT_TYPE_CREATED",
      "AVAILABILITY_RULES_REPLACED",
      "ORGANIZATION_VERIFICATION_REQUESTED",
      "ORGANIZATION_VERIFIED",
      "ORGANIZATION_PUBLISHED",
      "APPOINTMENT_CREATED",
      "PATIENT_CHECKED_IN",
      "APPOINTMENT_STARTED",
      "CONSULTATION_CREATED",
      "PRESCRIPTION_CREATED",
      "APPOINTMENT_COMPLETED",
      "CONSULTATION_SIGNED",
    ]) {
      expect(actions).toContain(expected);
    }
    },
    180_000,
  );

  it("denies Clinic B access to Clinic A's appointment (step 34)", async () => {
    const cross = await call(getAppointmentRoute, {
      bearer: adminB,
      params: { orgId: orgA, appointmentId },
    });
    expect(cross.status).toBe(404);

    const ownRouteAsB = await call(getAppointmentRoute, {
      bearer: adminB,
      params: { orgId: orgB, appointmentId },
    });
    expect(ownRouteAsB.status).toBe(404);

    const listB = await call<{ data: Array<{ id: string }> }>(listAppointmentsRoute, {
      bearer: adminB,
      params: { orgId: orgB },
    });
    expect(listB.body.data.some((a) => a.id === appointmentId)).toBe(false);
  });
});

