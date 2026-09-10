/**
 * Development seed — a single DEMO clinic with entirely synthetic data
 * (spec §28). Never run against production. Idempotent: keyed on the
 * `demo-clinic` slug; re-running replaces the demo org.
 */
import { PrismaClient } from "@prisma/client";
import { hash } from "@node-rs/argon2";

const db = new PrismaClient();

const DEMO_SLUG = "demo-clinic";
const DEMO_PASSWORD = "DemoPassw0rd!"; // documented, non-secret; demo only

async function pw(p: string) {
  return hash(p, { memoryCost: 19456, timeCost: 2, parallelism: 1 });
}

async function main() {
  // Clean any previous demo org (cascades to its rows).
  await db.organization.deleteMany({ where: { slug: DEMO_SLUG } });
  // Demo users are re-created fresh each run.
  await db.user.deleteMany({ where: { email: { endsWith: "@demo.dosewise.test" } } });

  const passwordHash = await pw(DEMO_PASSWORD);

  const admin = await db.user.create({
    data: { email: "admin@demo.dosewise.test", fullName: "Demo Admin", passwordHash, emailVerifiedAt: new Date() },
  });
  const doctorUser = await db.user.create({
    data: { email: "doctor@demo.dosewise.test", fullName: "Dr. Demo Sharma", passwordHash, emailVerifiedAt: new Date() },
  });
  const receptionUser = await db.user.create({
    data: { email: "reception@demo.dosewise.test", fullName: "Demo Reception", passwordHash, emailVerifiedAt: new Date() },
  });

  const org = await db.organization.create({
    data: {
      name: "Demo Clinic (synthetic data — not real patients)",
      slug: DEMO_SLUG,
      timezone: "Asia/Kolkata",
      settings: { create: {} },
      locations: { create: { name: "Demo Clinic — Main Branch", city: "Bengaluru" } },
      memberships: {
        create: [
          { userId: admin.id, role: "CLINIC_ADMIN", status: "ACTIVE" },
          { userId: doctorUser.id, role: "DOCTOR", status: "ACTIVE" },
          { userId: receptionUser.id, role: "RECEPTIONIST", status: "ACTIVE" },
        ],
      },
    },
    include: { locations: true },
  });
  const locationId = org.locations[0]!.id;

  const doctor = await db.doctorProfile.create({
    data: {
      organizationId: org.id,
      userId: doctorUser.id,
      displayName: "Dr. Demo Sharma",
      specialty: "General Medicine",
      consultationDurationMin: 15,
      availabilityRules: {
        create: [
          // Mon–Fri 09:00–13:00, 15-min slots.
          ...[1, 2, 3, 4, 5].map((weekday) => ({
            organizationId: org.id,
            locationId,
            weekday,
            startMinute: 9 * 60,
            endMinute: 13 * 60,
            slotMinutes: 15,
          })),
        ],
      },
    },
  });

  await db.staffProfile.create({
    data: { organizationId: org.id, userId: receptionUser.id, jobTitle: "Front Desk" },
  });

  const apptType = await db.appointmentType.create({
    data: { organizationId: org.id, name: "Consultation", durationMinutes: 15 },
  });

  const patients = await Promise.all(
    [
      ["Aarav", "Demo"],
      ["Isha", "Demo"],
      ["Rohan", "Demo"],
    ].map(([firstName, lastName]) =>
      db.patient.create({
        data: {
          organizationId: org.id,
          firstName: firstName!,
          lastName: lastName!,
          createdById: admin.id,
        },
      }),
    ),
  );

  // A couple of demo appointments (well in the future, non-overlapping).
  const base = new Date();
  base.setUTCDate(base.getUTCDate() + 2);
  base.setUTCHours(4, 0, 0, 0); // 09:30 IST-ish; exact tz math lands in Phase 2
  for (let i = 0; i < 2; i++) {
    const start = new Date(base.getTime() + i * 15 * 60_000);
    const end = new Date(start.getTime() + 15 * 60_000);
    await db.appointment.create({
      data: {
        organizationId: org.id,
        patientId: patients[i]!.id,
        doctorId: doctor.id,
        locationId,
        appointmentTypeId: apptType.id,
        scheduledStart: start,
        scheduledEnd: end,
        timezone: "Asia/Kolkata",
        status: "CONFIRMED",
        bookingSource: "RECEPTION",
        createdById: receptionUser.id,
        confirmedAt: new Date(),
      },
    });
  }

  console.log(
    [
      "Seeded DEMO clinic (synthetic data only):",
      `  org:        ${org.slug} (${org.id})`,
      `  admin:      admin@demo.dosewise.test / ${DEMO_PASSWORD}`,
      `  doctor:     doctor@demo.dosewise.test / ${DEMO_PASSWORD}`,
      `  reception:  reception@demo.dosewise.test / ${DEMO_PASSWORD}`,
      `  patients:   ${patients.length}   appointments: 2`,
    ].join("\n"),
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => db.$disconnect());
