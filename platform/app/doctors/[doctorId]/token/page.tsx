import Link from "next/link";
import { notFound } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { db } from "@/lib/db.js";
import { optionalWebUser } from "@/lib/web-context.js";
import { getPublicDoctor } from "@/modules/public/service.js";
import { listMyAccessInOrg } from "@/modules/family/service.js";
import { findMyActiveToken, getTokenWindow } from "@/modules/tokens/service.js";
import { Button, Card, CardSubtitle, CardTitle, Field, Input, LinkButton, Notice, Select } from "@/components/ui/index.js";
import { PublicHeader } from "../../../public-header";
import { bookTokenAction } from "./actions.js";

export const dynamic = "force-dynamic";

/**
 * Confirm today's token: log in → choose self/dependent → confirm. The window
 * shown here is the same server computation the booking endpoint enforces, so
 * the button state and the API answer can't disagree.
 */
export default async function TokenBookingPage({
  params,
  searchParams,
}: {
  params: Promise<{ doctorId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { doctorId } = await params;
  const { error } = await searchParams;

  let doctor: Awaited<ReturnType<typeof getPublicDoctor>>;
  let window: Awaited<ReturnType<typeof getTokenWindow>>;
  try {
    [doctor, window] = await Promise.all([getPublicDoctor(doctorId), getTokenWindow(doctorId)]);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") notFound();
    throw err;
  }
  if (window.status === "UNAVAILABLE") notFound();

  const ctx = await optionalWebUser();
  const existing = ctx ? await findMyActiveToken(ctx.userId, doctorId) : null;
  const currentPath = `/doctors/${doctorId}/token`;
  const day = new Date(`${window.date}T12:00:00Z`).toLocaleDateString(undefined, {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  });

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-lg px-5 py-10">
        <h1 className="text-xl font-semibold text-ink">Today&rsquo;s token</h1>

        <Card className="mt-4">
          <CardSubtitle>Token with</CardSubtitle>
          <CardTitle as="p" className="mt-1">{doctor.displayName}</CardTitle>
          <p className="text-sm text-ink-muted">{doctor.organization.name}</p>
          <dl className="mt-3 grid grid-cols-2 gap-y-1 text-sm">
            <dt className="text-ink-muted">Date</dt>
            <dd className="text-ink">{day}</dd>
            <dt className="text-ink-muted">Booking</dt>
            <dd className="text-ink">{window.opensAt}–{window.closesAt}</dd>
            <dt className="text-ink-muted">Queue starts</dt>
            <dd className="text-ink">{window.queueStartAt}</dd>
          </dl>
          <p className="mt-3 text-xs text-ink-muted">
            You get a queue number, not a fixed time. Patients are seen in token order. Times are clinic local
            time ({window.timezone}).
          </p>
        </Card>

        {error ? (
          <div className="mt-4">
            <Notice tone="down">{error}</Notice>
          </div>
        ) : null}

        {existing?.queueEntry ? (
          <Card className="mt-4">
            <p className="text-sm text-ink">
              You already have a token for today&rsquo;s clinic:{" "}
              <span className="font-semibold">#{existing.queueEntry.tokenNumber}</span> ({existing.patient.firstName}{" "}
              {existing.patient.lastName}).
            </p>
            <div className="mt-3">
              <LinkButton href={`/dashboard/${existing.organizationId}/appointments/${existing.id}`}>View token</LinkButton>
            </div>
          </Card>
        ) : !window.bookable ? (
          <Card className="mt-4">
            <p className="text-sm text-ink">{window.reason}</p>
            <div className="mt-3">
              <Button disabled>
                {window.status === "NOT_YET_OPEN" ? `Booking opens at ${window.opensAt}` : "Booking closed for today"}
              </Button>
            </div>
          </Card>
        ) : !ctx ? (
          <Card className="mt-4">
            <p className="text-sm text-ink">Log in or create an account to take today&rsquo;s token.</p>
            <div className="mt-4 flex gap-3">
              <LinkButton href={`/login?next=${encodeURIComponent(currentPath)}`}>Log in</LinkButton>
              <LinkButton variant="secondary" href={`/register?next=${encodeURIComponent(currentPath)}`}>
                Sign up
              </LinkButton>
            </div>
          </Card>
        ) : (
          <TokenForm doctorId={doctorId} organizationId={doctor.organization.id} userId={ctx.userId} />
        )}

        <p className="mt-4 text-xs text-ink-muted">
          Want a fixed time instead?{" "}
          <Link href={`/doctors/${doctorId}`} className="text-indigo">
            Back to the doctor
          </Link>
          .
        </p>
      </main>
    </div>
  );
}

async function TokenForm({ doctorId, organizationId, userId }: { doctorId: string; organizationId: string; userId: string }) {
  const [user, dependents] = await Promise.all([
    db.user.findUnique({ where: { id: userId }, select: { fullName: true, phone: true } }),
    listMyAccessInOrg(userId, organizationId),
  ]);
  const [defaultFirst = "", ...restName] = (user?.fullName ?? "").trim().split(/\s+/);

  return (
    <Card className="mt-4">
      <CardSubtitle>Your details</CardSubtitle>
      <form action={bookTokenAction.bind(null, doctorId)} className="mt-3 flex flex-col gap-4">
        <input type="hidden" name="organizationId" value={organizationId} />
        {dependents.length > 0 ? (
          <Field label="Who is this token for?">
            <Select name="patientId" className="w-full" defaultValue="">
              <option value="">Myself</option>
              {dependents.map((d) => (
                <option key={d.patient.id} value={d.patient.id}>
                  {d.patient.firstName} {d.patient.lastName}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        <div className="grid grid-cols-2 gap-3">
          <Field label="First name" hint="Your own details — used even when booking for a dependent.">
            <Input name="firstName" required defaultValue={defaultFirst} className="w-full" />
          </Field>
          <Field label="Last name">
            <Input name="lastName" required defaultValue={restName.join(" ")} className="w-full" />
          </Field>
        </div>
        <Field label="Phone" hint="Optional, but helps the clinic reach you.">
          <Input name="phone" type="tel" autoComplete="tel" defaultValue={user?.phone ?? ""} className="w-full" />
        </Field>
        <Field label="Reason for visit" hint="Optional.">
          <Input name="reason" maxLength={200} className="w-full" />
        </Field>
        <Button type="submit" size="lg" className="w-full">
          Confirm today&rsquo;s token
        </Button>
      </form>
    </Card>
  );
}
