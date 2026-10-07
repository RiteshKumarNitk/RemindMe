// Build-time migration step (Vercel `vercel-build`).
//
// Production was originally created without Prisma's migration history (the
// schema exists but `_prisma_migrations` does not), so a plain
// `prisma migrate deploy` stops with P3005. This script:
//
//   1. Baselines once: if there is no migration history but the schema is
//      already at BASELINE (verified by a sentinel column), it records every
//      migration up to BASELINE as applied — without running them.
//   2. Ensures the two raw-SQL safety objects `db push` can never create
//      exist (double-booking EXCLUDE constraint, one-active-token index).
//   3. Runs `prisma migrate deploy` for everything newer.
//
// Safe to run on every deploy: after the first run step 1 is skipped and
// step 2 finds the objects already present.
import { execFileSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { PrismaClient } from "@prisma/client";

const BASELINE = "20261001120000_same_day_token_booking";

const prisma = new PrismaClient({
  datasourceUrl: process.env.DIRECT_URL || process.env.DATABASE_URL,
});

function prismaCli(...args) {
  execFileSync("prisma", args, { stdio: "inherit", shell: process.platform === "win32" });
}

async function scalar(sql) {
  const rows = await prisma.$queryRawUnsafe(sql);
  return rows[0] ? Object.values(rows[0])[0] : null;
}

async function baselineIfNeeded() {
  const history = await scalar(`SELECT to_regclass('public._prisma_migrations')::text`);
  if (history) return;

  const appointment = await scalar(`SELECT to_regclass('public."Appointment"')::text`);
  if (!appointment) return; // empty database: migrate deploy builds it from scratch

  // Sentinel from BASELINE itself: refuse to guess if the schema is older.
  const hasBookingKind = await scalar(`
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'Appointment' AND column_name = 'bookingKind'`);
  if (!hasBookingKind) {
    throw new Error(
      `No migration history and the schema is older than ${BASELINE}; baseline manually (https://pris.ly/d/migrate-baseline).`,
    );
  }

  const migrations = readdirSync(new URL("../prisma/migrations", import.meta.url), {
    withFileTypes: true,
  })
    .filter((d) => d.isDirectory() && d.name <= BASELINE)
    .map((d) => d.name)
    .sort();
  console.log(`[migrate] No migration history; baselining ${migrations.length} migrations up to ${BASELINE}.`);
  for (const name of migrations) prismaCli("migrate", "resolve", "--applied", name);
}

async function ensureSafetyObjects() {
  const exclusion = await scalar(`
    SELECT 1 FROM pg_constraint WHERE conname = 'Appointment_org_doctor_no_overlap'`);
  if (!exclusion) {
    try {
      await prisma.$executeRawUnsafe(`CREATE EXTENSION IF NOT EXISTS btree_gist`);
      await prisma.$executeRawUnsafe(`
        ALTER TABLE "Appointment" ADD CONSTRAINT "Appointment_org_doctor_no_overlap"
          EXCLUDE USING gist (
            "organizationId" WITH =,
            "doctorId"       WITH =,
            tstzrange("scheduledStart", "scheduledEnd", '[)') WITH &&
          )
          WHERE (("bookingKind" = 'SCHEDULED')
             AND ("status" NOT IN ('CANCELLED', 'NO_SHOW', 'RESCHEDULED')))`);
      console.log("[migrate] Added missing double-booking constraint.");
    } catch (e) {
      console.warn(
        "[migrate] WARNING: could not add the double-booking constraint (existing overlapping appointments?). " +
          "Booking still checks overlaps in code, but resolve this. " + String(e).slice(0, 300),
      );
    }
  }

  const tokenIndex = await scalar(
    `SELECT to_regclass('public."Appointment_one_active_token_per_patient_doctor_day"')::text`,
  );
  if (!tokenIndex) {
    try {
      await prisma.$executeRawUnsafe(`
        CREATE UNIQUE INDEX IF NOT EXISTS "Appointment_one_active_token_per_patient_doctor_day"
          ON "Appointment"("organizationId", "patientId", "doctorId", "tokenDate")
          WHERE "bookingKind" = 'SAME_DAY_TOKEN'
            AND "tokenDate" IS NOT NULL
            AND "status" NOT IN ('CANCELLED', 'NO_SHOW', 'RESCHEDULED', 'COMPLETED')`);
      console.log("[migrate] Added missing one-active-token index.");
    } catch (e) {
      console.warn("[migrate] WARNING: could not add the one-active-token index. " + String(e).slice(0, 300));
    }
  }
}

try {
  await baselineIfNeeded();
  await ensureSafetyObjects();
} finally {
  await prisma.$disconnect();
}
prismaCli("migrate", "deploy");
