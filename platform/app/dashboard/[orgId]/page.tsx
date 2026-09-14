import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { tenantDb } from "@/lib/tenant.js";
import { Card, SectionTitle } from "../ui.js";

export const dynamic = "force-dynamic";

export default async function OrgOverview({
  params,
}: {
  params: Promise<{ orgId: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const t = tenantDb(ctx);
  const role = ctx.org!.role;

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 86_400_000);

  const stats: Array<{ label: string; value: number; href: string }> = [];

  if (role === "CLINIC_ADMIN" || role === "RECEPTIONIST") {
    const [doctors, patients, todayAppts] = await Promise.all([
      t.doctorProfile.count({ where: { organizationId: orgId, isActive: true } }),
      t.patient.count({ where: { organizationId: orgId, isActive: true } }),
      t.appointment.count({
        where: { organizationId: orgId, scheduledStart: { gte: todayStart, lt: todayEnd } },
      }),
    ]);
    stats.push(
      { label: "Doctors", value: doctors, href: `/dashboard/${orgId}/doctors` },
      { label: "Patients", value: patients, href: `/dashboard/${orgId}/patients` },
      { label: "Today's appointments", value: todayAppts, href: `/dashboard/${orgId}/appointments` },
    );
  } else if (role === "DOCTOR") {
    const mine = await t.doctorProfile.findFirst({
      where: { organizationId: orgId, userId: ctx.userId },
      select: { id: true },
    });
    const todayAppts = mine
      ? await t.appointment.count({
          where: {
            organizationId: orgId,
            doctorId: mine.id,
            scheduledStart: { gte: todayStart, lt: todayEnd },
            status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED"] },
          },
        })
      : 0;
    stats.push({ label: "Today's appointments", value: todayAppts, href: `/dashboard/${orgId}/appointments` });
  } else {
    const upcoming = await t.appointment.count({
      where: {
        organizationId: orgId,
        patient: { ownerUserId: ctx.userId },
        scheduledStart: { gte: new Date() },
        status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED"] },
      },
    });
    stats.push({ label: "Upcoming appointments", value: upcoming, href: `/dashboard/${orgId}/appointments` });
  }

  return (
    <div>
      <SectionTitle>Overview</SectionTitle>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12 }}>
        {stats.map((s) => (
          <Link key={s.label} href={s.href} style={{ textDecoration: "none", color: "inherit" }}>
            <Card>
              <div style={{ fontSize: 30, fontWeight: 800 }}>{s.value}</div>
              <div style={{ color: "var(--ink-muted)", fontSize: 13, marginTop: 4 }}>{s.label}</div>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
