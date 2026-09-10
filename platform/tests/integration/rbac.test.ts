import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { createOrg, registerAndLogin, TEST_PASSWORD } from "../helpers/factories.js";
import { POST as loginRoute } from "../../app/api/auth/login/route.js";
import { GET as listMembers, POST as inviteMember } from "../../app/api/orgs/[orgId]/members/route.js";
import { PUT as setCaps } from "../../app/api/orgs/[orgId]/members/[membershipId]/capabilities/route.js";
import { GET as getSettings } from "../../app/api/orgs/[orgId]/settings/route.js";

let adminTok: string;
let orgId: string;
let adminMembershipId: string;
let receptionTok: string;
let receptionMembershipId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("adm");
  adminTok = admin.accessToken;
  const org = await createOrg(adminTok, "rbac");
  orgId = org.id;

  const members = await call<{ data: Array<{ id: string; role: string }> }>(listMembers, {
    bearer: adminTok,
    params: { orgId },
  });
  adminMembershipId = members.body.data.find((m) => m.role === "CLINIC_ADMIN")!.id;

  // Add a receptionist and log in as them.
  const recEmail = `rec-${Date.now()}@test.local`;
  const inv = await call<{ id: string; user: { id: string } }>(inviteMember, {
    bearer: adminTok,
    params: { orgId },
    body: { email: recEmail, fullName: "Reception R", role: "RECEPTIONIST" },
  });
  receptionMembershipId = inv.body.id;
  // Give them a usable password so they can log in.
  const { hashPassword } = await import("@/lib/auth/password.js");
  await db.user.update({
    where: { id: inv.body.user.id },
    data: { passwordHash: await hashPassword(TEST_PASSWORD) },
  });
  const recLogin = await call<{ accessToken: string }>(loginRoute, {
    client: "app",
    body: { email: recEmail, password: TEST_PASSWORD },
  });
  receptionTok = recLogin.body.accessToken;
});
afterAll(disconnect);

describe("RBAC (RBAC.md)", () => {
  it("RECEPTIONIST cannot read clinic settings (admin-only route) → 403", async () => {
    const res = await call(getSettings, { bearer: receptionTok, params: { orgId } });
    expect(res.status).toBe(403);
    expect((res.body as { error: { code: string } }).error.code).toBe("FORBIDDEN_ROLE");
  });

  it("RECEPTIONIST cannot list members → 403", async () => {
    const res = await call(listMembers, { bearer: receptionTok, params: { orgId } });
    expect(res.status).toBe(403);
  });

  it("CLINIC_ADMIN cannot self-grant CLINICAL_RECORD_READ → 403 CANNOT_SELF_GRANT_CAPABILITY", async () => {
    const res = await call(setCaps, {
      bearer: adminTok,
      params: { orgId, membershipId: adminMembershipId },
      body: { capabilities: ["CLINICAL_RECORD_READ"] },
    });
    expect(res.status).toBe(403);
    expect((res.body as { error: { code: string } }).error.code).toBe("CANNOT_SELF_GRANT_CAPABILITY");

    const still = await db.membership.findUniqueOrThrow({ where: { id: adminMembershipId } });
    expect(still.capabilities).toEqual([]);
  });

  it("CLINIC_ADMIN CAN self-grant BILLING_MANAGE / DATA_EXPORT", async () => {
    const res = await call(setCaps, {
      bearer: adminTok,
      params: { orgId, membershipId: adminMembershipId },
      body: { capabilities: ["BILLING_MANAGE", "DATA_EXPORT"] },
    });
    expect(res.status).toBe(200);
  });

  it("CLINIC_ADMIN CAN grant CLINICAL_RECORD_READ to a DIFFERENT membership, and it is audited", async () => {
    const res = await call<{ capabilities: string[] }>(setCaps, {
      bearer: adminTok,
      params: { orgId, membershipId: receptionMembershipId },
      body: { capabilities: ["CLINICAL_RECORD_READ"] },
    });
    expect(res.status).toBe(200);
    expect(res.body.capabilities).toContain("CLINICAL_RECORD_READ");

    const audit = await db.auditLog.findFirst({
      where: {
        organizationId: orgId,
        action: "MEMBER_CAPABILITY_GRANTED",
        entityId: receptionMembershipId,
      },
    });
    expect(audit).not.toBeNull();
  });

  it("audit rows never carry a password/hash/token", async () => {
    const rows = await db.auditLog.findMany({ where: { organizationId: orgId } });
    const blob = JSON.stringify(rows);
    expect(blob).not.toMatch(/\$argon2id\$/);
    expect(blob).not.toContain(TEST_PASSWORD);
  });
});
