import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { createOrg, registerAndLogin, type TestOrg, type TestUser } from "../helpers/factories.js";
import { GET as getOrg, PATCH as patchOrg } from "../../app/api/orgs/[orgId]/route.js";
import { GET as listMembers, POST as inviteMember } from "../../app/api/orgs/[orgId]/members/route.js";
import { GET as listDoctors, POST as createDoctor } from "../../app/api/orgs/[orgId]/doctors/route.js";
import { GET as getSettings } from "../../app/api/orgs/[orgId]/settings/route.js";

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
});
