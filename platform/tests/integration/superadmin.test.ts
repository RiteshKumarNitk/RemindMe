import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { createOrg, registerAndLogin } from "../helpers/factories.js";
import { GET as listOrgsRoute } from "../../app/api/admin/organizations/route.js";
import { GET as getOrgRoute } from "../../app/api/admin/organizations/[targetOrgId]/route.js";
import { PUT as setStatusRoute } from "../../app/api/admin/organizations/[targetOrgId]/status/route.js";
import { GET as platformAuditRoute } from "../../app/api/admin/audit/route.js";
import { GET as platformStatsRoute } from "../../app/api/admin/stats/route.js";

let adminToken: string;
let adminUserId: string;
let ordinaryToken: string;
let orgId: string;
let orgName: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("platadmin");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  await db.user.update({ where: { id: adminUserId }, data: { isPlatformAdmin: true } });

  const ordinary = await registerAndLogin("platuser");
  ordinaryToken = ordinary.accessToken;

  const org = await createOrg(adminToken, "superadmin");
  orgId = org.id;
  orgName = `superadmin ${org.slug}`;
});
afterAll(disconnect);

describe("superadmin platform console", () => {
  it("a non-platform-admin is rejected on every admin route", async () => {
    const list = await call(listOrgsRoute, { bearer: ordinaryToken });
    expect(list.status).toBe(403);

    const detail = await call(getOrgRoute, { bearer: ordinaryToken, params: { targetOrgId: orgId } });
    expect(detail.status).toBe(403);

    const status = await call(setStatusRoute, {
      method: "PUT",
      bearer: ordinaryToken,
      params: { targetOrgId: orgId },
      body: { isActive: false },
    });
    expect(status.status).toBe(403);

    const audit = await call(platformAuditRoute, { bearer: ordinaryToken });
    expect(audit.status).toBe(403);

    const stats = await call(platformStatsRoute, { bearer: ordinaryToken });
    expect(stats.status).toBe(403);
  });

  it("lists organizations across tenants, with search and status filters", async () => {
    const all = await call<{ data: Array<{ id: string; name: string }> }>(listOrgsRoute, { bearer: adminToken });
    expect(all.status).toBe(200);
    expect(all.body.data.some((o) => o.id === orgId)).toBe(true);

    const searched = await call<{ data: Array<{ id: string }> }>(listOrgsRoute, {
      bearer: adminToken,
      url: `http://test.local/api?q=${encodeURIComponent(orgName)}`,
    });
    expect(searched.body.data.map((o) => o.id)).toEqual([orgId]);

    const activeOnly = await call<{ data: Array<{ id: string }> }>(listOrgsRoute, {
      bearer: adminToken,
      url: "http://test.local/api?status=active",
    });
    expect(activeOnly.body.data.some((o) => o.id === orgId)).toBe(true);
  });

  it("returns org detail with membership roster", async () => {
    const detail = await call<{
      org: { id: string; name: string; _count: { memberships: number } };
      memberships: Array<{ role: string; user: { id: string } }>;
    }>(getOrgRoute, { bearer: adminToken, params: { targetOrgId: orgId } });
    expect(detail.status).toBe(200);
    expect(detail.body.org.id).toBe(orgId);
    expect(detail.body.org._count.memberships).toBeGreaterThanOrEqual(1);
    expect(detail.body.memberships.some((m) => m.role === "CLINIC_ADMIN")).toBe(true);
  });

  it("suspends and reactivates a clinic, auditing both transitions", async () => {
    const suspend = await call<{ isActive: boolean }>(setStatusRoute, {
      method: "PUT",
      bearer: adminToken,
      params: { targetOrgId: orgId },
      body: { isActive: false },
    });
    expect(suspend.status).toBe(200);
    expect(suspend.body.isActive).toBe(false);

    const suspendedFilter = await call<{ data: Array<{ id: string }> }>(listOrgsRoute, {
      bearer: adminToken,
      url: "http://test.local/api?status=suspended",
    });
    expect(suspendedFilter.body.data.map((o) => o.id)).toContain(orgId);

    const suspendAudit = await db.auditLog.findFirst({
      where: { organizationId: orgId, action: "ORGANIZATION_SUSPENDED" },
    });
    expect(suspendAudit).not.toBeNull();

    const reactivate = await call<{ isActive: boolean }>(setStatusRoute, {
      method: "PUT",
      bearer: adminToken,
      params: { targetOrgId: orgId },
      body: { isActive: true },
    });
    expect(reactivate.status).toBe(200);
    expect(reactivate.body.isActive).toBe(true);

    const reactivateAudit = await db.auditLog.findFirst({
      where: { organizationId: orgId, action: "ORGANIZATION_REACTIVATED" },
    });
    expect(reactivateAudit).not.toBeNull();
  });

  it("platform audit log spans tenants and platform stats aggregate correctly", async () => {
    const audit = await call<{ data: Array<{ organization: { id: string } | null; action: string }> }>(
      platformAuditRoute,
      { bearer: adminToken },
    );
    expect(audit.status).toBe(200);
    expect(audit.body.data.some((r) => r.organization?.id === orgId)).toBe(true);

    const stats = await call<{ organizations: number; activeOrganizations: number }>(platformStatsRoute, {
      bearer: adminToken,
    });
    expect(stats.status).toBe(200);
    expect(stats.body.organizations).toBeGreaterThanOrEqual(1);
    expect(stats.body.activeOrganizations).toBeGreaterThanOrEqual(1);
  });
});
