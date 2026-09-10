import { randomUUID } from "node:crypto";
import { POST as registerRoute } from "../../app/api/auth/register/route.js";
import { POST as loginRoute } from "../../app/api/auth/login/route.js";
import { POST as orgsRoute } from "../../app/api/orgs/route.js";
import { call } from "./http.js";

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

export { PW as TEST_PASSWORD };
