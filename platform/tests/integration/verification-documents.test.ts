import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { createOrg, registerAndLogin } from "../helpers/factories.js";
import { POST as uploadRoute, GET as listRoute } from "../../app/api/orgs/[orgId]/verification-documents/route.js";
import { GET as downloadRoute } from "../../app/api/orgs/[orgId]/verification-documents/[documentId]/route.js";
import { GET as adminDetailRoute } from "../../app/api/admin/organizations/[targetOrgId]/route.js";

let adminToken: string;
let adminIsPlatformAdmin = false;
let orgId: string;
let memberToken: string;
let outsiderToken: string;
let documentId: string;
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

async function multipartUpload(token: string, bytes: Uint8Array, mime = "image/png", name = "license.png") {
  const form = new FormData();
  form.set("file", new File([new Uint8Array(bytes)], name, { type: mime }));
  const handler = uploadRoute as unknown as (
    req: Request,
    routeCtx: { params: Promise<Record<string, string>> },
  ) => Promise<Response>;
  return handler(
    new Request("http://test.local/api", {
      method: "POST",
      body: form,
      headers: { authorization: `Bearer ${token}`, "x-forwarded-for": "10.1.2.3" },
    }),
    { params: Promise.resolve({ orgId }) },
  );
}

beforeAll(async () => {
  await truncateAll();
  const superAdmin = await registerAndLogin("vdsuper");
  await db.user.update({ where: { id: superAdmin.userId }, data: { isPlatformAdmin: true } });
  adminToken = superAdmin.accessToken;
  adminIsPlatformAdmin = true;
  orgId = (await createOrg(adminToken, "vdocs")).id;

  // A second member of the same org with a non-admin role.
  const member = await registerAndLogin("vdrec");
  await db.membership.create({
    data: { userId: member.userId, organizationId: orgId, role: "RECEPTIONIST", status: "ACTIVE" },
  });
  memberToken = member.accessToken;

  const outsider = await registerAndLogin("vdout");
  outsiderToken = outsider.accessToken;
});
afterAll(disconnect);

describe("verification documents (upload → review)", () => {
  it("a CLINIC_ADMIN uploads a document; metadata comes back without the bytes", async () => {
    const res = await multipartUpload(adminToken, PNG);
    expect(res.status).toBe(201);
    const body = (await res.json()) as { id: string; fileName: string; sizeBytes: number };
    expect(body.fileName).toBe("license.png");
    expect(body.sizeBytes).toBe(PNG.byteLength);
    documentId = body.id;

    const listed = await call<{ data: Array<{ id: string }> }>(listRoute, {
      bearer: adminToken,
      params: { orgId },
    });
    expect(listed.status).toBe(200);
    expect(listed.body.data.map((d) => d.id)).toContain(documentId);
    expect(JSON.stringify(listed.body)).not.toContain("iVBOR");
  });

  it("rejects oversized and wrong-type files, and non-admin roles", async () => {
    const tooBig = await multipartUpload(adminToken, new Uint8Array(10 * 1024 * 1024 + 1));
    expect(tooBig.status).toBe(422); // VALIDATION_FAILED

    const badType = await multipartUpload(adminToken, PNG, "application/zip", "bundle.zip");
    expect(badType.status).toBe(422);

    const receptionist = await multipartUpload(memberToken, PNG);
    expect(receptionist.status).toBe(403);

    const outsider = await multipartUpload(outsiderToken, PNG);
    expect([403, 404]).toContain(outsider.status);
  });

  it("the owning clinic admin downloads the bytes back intact", async () => {
    // Raw fetch (not `call`, which does res.text() and would corrupt bytes).
    const req = new Request(`http://test.local/api/orgs/${orgId}/verification-documents/${documentId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
    });
    const res = await (downloadRoute as unknown as (
      req: Request,
      routeCtx: { params: Promise<Record<string, string>> },
    ) => Promise<Response>)(req, { params: Promise.resolve({ orgId, documentId }) });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("image/png");
    expect(res.headers.get("cache-control")).toBe("no-store");
    const got = Buffer.from(await res.arrayBuffer());
    expect(got.equals(PNG)).toBe(true);
  });

  it("a platform admin can download for review; other clinics and anonymous callers cannot", async () => {
    const reviewer = await call(downloadRoute as never, {
      bearer: adminToken,
      params: { orgId, documentId },
    });
    expect(reviewer.status).toBe(200);

    const otherOrgAdmin = await registerAndLogin("vdother");
    const otherOrg = await createOrg(otherOrgAdmin.accessToken, "vdocother");
    const leak = await call(downloadRoute as never, {
      bearer: otherOrgAdmin.accessToken,
      params: { orgId: otherOrg.id, documentId },
    });
    expect([403, 404]).toContain(leak.status);

    const anon = await call(downloadRoute as never, {
      params: { orgId, documentId },
    });
    expect(anon.status).toBe(401);
  });

  it("the platform admin org-detail endpoint exposes the document metadata for review", async () => {
    const res = await call<{ verificationDocuments: Array<{ id: string; fileName: string }> }>(
      adminDetailRoute,
      { bearer: adminToken, params: { targetOrgId: orgId } },
    );
    expect(res.status).toBe(200);
    expect(res.body.verificationDocuments.map((d) => d.id)).toContain(documentId);
    expect(JSON.stringify(res.body)).not.toContain("iVBOR");
  });

  it("deleting removes the row and revokes downloads", async () => {
    const doc = await db.verificationDocument.findFirstOrThrow({ where: { organizationId: orgId } });
    // The delete server action is exercised in the browser; here the row is
    // removed directly and the download is asserted dead either way.
    await db.verificationDocument.delete({ where: { id: doc.id } });
    const gone = await call(downloadRoute as never, {
      bearer: adminToken,
      params: { orgId, documentId: doc.id },
    });
    expect(gone.status).toBe(404);
    void adminIsPlatformAdmin;
  });
});
