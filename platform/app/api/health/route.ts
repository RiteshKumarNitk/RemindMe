import { db } from "@/lib/db.js";
import { json, withApi } from "@/lib/http.js";

export const dynamic = "force-dynamic";

export const GET = withApi({ auth: "none", rateClass: "default" }, async () => {
  let dbOk = false;
  try {
    await db.$queryRaw`SELECT 1`;
    dbOk = true;
  } catch {
    dbOk = false;
  }
  return json(
    { status: dbOk ? "ok" : "degraded", db: dbOk ? "ok" : "down", time: new Date().toISOString() },
    { status: dbOk ? 200 : 503 },
  );
});
