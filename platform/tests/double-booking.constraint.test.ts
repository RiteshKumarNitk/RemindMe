/**
 * DB-level double-booking + cross-tenant proof (TESTING.md §5b).
 * Exercises the Postgres EXCLUDE constraint `Appointment_org_doctor_no_overlap`
 * directly — no app layer. Needs a migrated dev/test DB (ALLOW_DB_TESTS=1).
 *
 *   A) Same clinic + same doctor + overlapping time  -> 2nd insert FAILS.
 *   B) Different clinics + same underlying doctor + identical time -> BOTH OK.
 *   C) Same clinic + same doctor + adjacent (non-overlapping) -> BOTH OK.
 *   D) A CANCELLED appointment frees the range.
 */
import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect } from "./helpers/db.js";

const RUN = randomUUID().slice(0, 8);
const T0 = new Date("2027-03-01T10:00:00.000Z");
const T15 = new Date("2027-03-01T10:15:00.000Z");
const T30 = new Date("2027-03-01T10:30:00.000Z");
const T45 = new Date("2027-03-01T10:45:00.000Z");
const T60 = new Date("2027-03-01T11:00:00.000Z");

const ctx = {} as {
  userId: string;
  orgA: string;
  orgB: string;
  docA: string;
  docB: string;
  patients: string[];
};

async function makeOrg(name: string) {
  return db.organization.create({
    data: { name, slug: `${name}-${RUN}`.toLowerCase() },
  });
}
async function makeDoctor(organizationId: string, userId: string) {
  return db.doctorProfile.create({
    data: { organizationId, userId, displayName: "Dr X", consultationDurationMin: 30 },
  });
}
async function makePatient(organizationId: string, createdById: string, tag: string) {
  return db.patient.create({
    data: { organizationId, firstName: "Pat", lastName: tag, createdById },
  });
}
function appt(
  organizationId: string,
  doctorId: string,
  patientId: string,
  start: Date,
  end: Date,
  status: "CONFIRMED" | "CANCELLED" = "CONFIRMED",
) {
  return {
    organizationId,
    doctorId,
    patientId,
    scheduledStart: start,
    scheduledEnd: end,
    timezone: "Asia/Kolkata",
    status,
    bookingSource: "RECEPTION" as const,
    createdById: ctx.userId,
  };
}

beforeAll(async () => {
  const user = await db.user.create({
    data: { email: `drx-${RUN}@test.local`, fullName: "Dr X" },
  });
  ctx.userId = user.id;
  const [a, b] = await Promise.all([makeOrg("clinicdbA"), makeOrg("clinicdbB")]);
  ctx.orgA = a.id;
  ctx.orgB = b.id;
  const [da, dbp] = await Promise.all([
    makeDoctor(a.id, user.id),
    makeDoctor(b.id, user.id),
  ]);
  ctx.docA = da.id;
  ctx.docB = dbp.id;
  ctx.patients = [];
  for (const tag of ["A1", "A2", "B1"]) {
    const org = tag.startsWith("A") ? a.id : b.id;
    ctx.patients.push((await makePatient(org, user.id, tag + RUN)).id);
  }
});

afterAll(async () => {
  await db.organization.deleteMany({ where: { slug: { contains: RUN } } });
  await db.user.deleteMany({ where: { email: { contains: RUN } } });
  await disconnect();
});

describe("Appointment_org_doctor_no_overlap", () => {
  it("A) rejects an overlapping appointment for the same doctor in the same clinic", async () => {
    await db.appointment.create({
      data: appt(ctx.orgA, ctx.docA, ctx.patients[0]!, T0, T30),
    });
    await expect(
      db.appointment.create({
        data: appt(ctx.orgA, ctx.docA, ctx.patients[1]!, T15, T45),
      }),
    ).rejects.toThrow(/Appointment_org_doctor_no_overlap|exclusion|23P01|conflicting key/i);
  });

  it("B) allows the SAME doctor to hold the SAME time in a DIFFERENT clinic", async () => {
    const b = await db.appointment.create({
      data: appt(ctx.orgB, ctx.docB, ctx.patients[2]!, T0, T30),
    });
    expect(b.id).toBeTruthy();
    expect(b.organizationId).toBe(ctx.orgB);
  });

  it("C) allows adjacent, non-overlapping slots in the same clinic", async () => {
    const adj = await db.appointment.create({
      data: appt(ctx.orgA, ctx.docA, ctx.patients[1]!, T30, T60),
    });
    expect(adj.id).toBeTruthy();
  });

  it("D) a CANCELLED appointment frees the range", async () => {
    const org = await makeOrg("clinicdbC");
    const doc = await makeDoctor(org.id, ctx.userId);
    const p1 = await makePatient(org.id, ctx.userId, "C1" + RUN);
    const p2 = await makePatient(org.id, ctx.userId, "C2" + RUN);
    const first = await db.appointment.create({
      data: appt(org.id, doc.id, p1.id, T0, T30),
    });
    await db.appointment.update({
      where: { id: first.id },
      data: { status: "CANCELLED", cancelledAt: new Date(), cancellationReason: "test" },
    });
    const second = await db.appointment.create({
      data: appt(org.id, doc.id, p2.id, T0, T30),
    });
    expect(second.id).toBeTruthy();
  });
});
