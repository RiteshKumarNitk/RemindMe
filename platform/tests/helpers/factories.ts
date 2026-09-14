import { randomUUID } from "node:crypto";
import { POST as registerRoute } from "../../app/api/auth/register/route.js";
import { POST as loginRoute } from "../../app/api/auth/login/route.js";
import { POST as orgsRoute } from "../../app/api/orgs/route.js";
import { POST as createDoctorRoute } from "../../app/api/orgs/[orgId]/doctors/route.js";
import { PUT as putAvailabilityRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/availability/route.js";
import { GET as slotsRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/slots/route.js";
import { db } from "./db.js";
import { call } from "./http.js";
import { hashPassword } from "@/lib/auth/password.js";

const PW = "Passw0rd!长test";

export interface TestUser {
  userId: string;
  email: string;
  accessToken: string;
  refreshToken: string;
}

export async function registerAndLogin(prefix = "u"): Promise<TestUser> {
  const email = `${prefix}-${randomUUID().slice(0, 8)}@test.local`;
  const reg = await call<{ userId: string }>(registerRoute, {
    body: { email, password: PW, fullName: `${prefix} tester` },
  });
  if (reg.status !== 201) {
    throw new Error(`register failed: ${reg.status} ${JSON.stringify(reg.body)}`);
  }
  const login = await call<{ accessToken: string; refreshToken: string }>(loginRoute, {
    client: "app",
    body: { email, password: PW },
  });
  if (login.status !== 200) {
    throw new Error(`login failed: ${login.status} ${JSON.stringify(login.body)}`);
  }
  return {
    userId: reg.body.userId,
    email,
    accessToken: login.body.accessToken,
    refreshToken: login.body.refreshToken,
  };
}

export interface TestOrg {
  id: string;
  slug: string;
}

export async function createOrg(accessToken: string, prefix = "clinic"): Promise<TestOrg> {
  const slug = `${prefix}-${randomUUID().slice(0, 8)}`
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "");
  const res = await call<{ id: string; slug: string }>(orgsRoute, {
    bearer: accessToken,
    body: { name: `${prefix} ${slug}`, slug },
  });
  if (res.status !== 201) {
    throw new Error(`createOrg failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return { id: res.body.id, slug: res.body.slug };
}

/** Create a DOCTOR profile (+ its user + membership) and log that user in. */
export async function createDoctorWithLogin(
  adminToken: string,
  orgId: string,
): Promise<{ doctorId: string; userId: string; token: string; email: string }> {
  const email = `doc-${randomUUID().slice(0, 8)}@test.local`;
  const res = await call<{ id: string; userId: string }>(createDoctorRoute, {
    bearer: adminToken,
    params: { orgId },
    body: { email, fullName: "Dr Test", displayName: "Dr Test" },
  });
  if (res.status !== 201) {
    throw new Error(`createDoctor failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  await db.user.update({
    where: { id: res.body.userId },
    data: { passwordHash: await hashPassword(PW) },
  });
  const login = await call<{ accessToken: string }>(loginRoute, {
    client: "app",
    body: { email, password: PW },
  });
  return { doctorId: res.body.id, userId: res.body.userId, token: login.body.accessToken, email };
}

/** All 7 weekdays, `start`–`end` local, `slot`-min slots. */
export async function setWeeklyAvailability(
  editorToken: string,
  orgId: string,
  doctorId: string,
  opts: { startMinute?: number; endMinute?: number; slotMinutes?: number } = {},
): Promise<void> {
  const startMinute = opts.startMinute ?? 9 * 60;
  const endMinute = opts.endMinute ?? 17 * 60;
  const slotMinutes = opts.slotMinutes ?? 15;
  const rules = [1, 2, 3, 4, 5, 6, 7].map((weekday) => ({
    weekday,
    startMinute,
    endMinute,
    slotMinutes,
  }));
  const res = await call(putAvailabilityRoute, {
    bearer: editorToken,
    params: { orgId, doctorId },
    body: { rules },
  });
  if (res.status !== 200) {
    throw new Error(`setAvailability failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
}

export async function createPatient(
  orgId: string,
  createdById: string,
  ownerUserId?: string,
): Promise<{ id: string }> {
  return db.patient.create({
    data: {
      organizationId: orgId,
      firstName: "Test",
      lastName: `Patient-${randomUUID().slice(0, 6)}`,
      createdById,
      ownerUserId: ownerUserId ?? null,
    },
    select: { id: true },
  });
}

/** First free slot ~`daysAhead` from now for a doctor (uses the slots API). */
export async function firstSlot(
  token: string,
  orgId: string,
  doctorId: string,
  daysAhead = 7,
): Promise<{ start: string; end: string; date: string }> {
  const d = new Date(Date.now() + daysAhead * 86_400_000);
  const date = d.toISOString().slice(0, 10);
  const res = await call<{ slots: Array<{ start: string; end: string }> }>(slotsRoute, {
    bearer: token,
    params: { orgId, doctorId },
    url: `http://test.local/api?date=${date}`,
  });
  if (res.status !== 200 || !res.body.slots?.length) {
    throw new Error(`no slots for ${date}: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return { ...res.body.slots[0]!, date };
}

export { PW as TEST_PASSWORD };
