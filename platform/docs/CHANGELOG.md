# DoseWise Platform — Changelog

Dated log of what actually shipped, newest first. Each entry says what changed, why, and what
was verified. See [DECISIONS.md](DECISIONS.md) for the reasoning behind non-obvious choices, and
[STATUS.md](STATUS.md) for the current plain-English state.

## 2026-09-17 — Patient discovery journey: audit found it mostly already built, three real gaps closed (uncommitted)

A detailed brief asked for the full patient discovery→booking journey. Audit found it already
shipped (Phases 5/6/11 earlier this project) — homepage, hospital/doctor discovery and profiles,
availability, public self-booking, the login gate, specialty filtering, unpublished-org exclusion.
Three genuine gaps closed, nothing rebuilt: (1) a real post-booking confirmation — the existing
appointment detail page now shows a success banner + "Book another"/"Go to dashboard" actions via
a `?justBooked=1` flag, instead of redirecting to a busy list; also fixed two pre-existing invalid
`<Link><Button></Button></Link>` nestings found while in that file. (2) The public booking flow
can now book for a dependent, not just yourself — a "Who is this appointment for?" picker appears
only when the logged-in visitor actually holds a `MANAGE_APPOINTMENTS` grant at that specific
clinic (new `listMyAccessInOrg`, deliberately not tenant-scoped since the caller may not be an org
member yet); the submitted patient is trusted only as far as the existing booking authorization
already allows. (3) Added SEO metadata (`generateMetadata`/`metadata`) to every public page,
previously missing entirely. See ADR-019. Verified live: real clinic/doctor publish, per-page SEO
titles confirmed, a guardian with a real access grant sees the dependent picker (a stranger
doesn't), booking for an authorized dependent succeeds while a random/unauthorized patientId is
rejected server-side, confirmation page renders correctly. `pnpm typecheck`/`pnpm build`/
`pnpm test:unit` (40/40) clean; `pnpm test:integration` not re-run (no fresh confirmation for a
truncating run this time).

## 2026-09-17 — Admin console migrated to the current design system (uncommitted)

The last piece of the visual migration: the platform-owner-only `/admin` console (overview,
clinics list, clinic detail, verification queue, audit log). Same shell as the org dashboard —
reuses the mobile drawer and icon-nav components built for it, no parallel admin-specific shell.
Every list became a card-row list except the audit log, which stayed a real table (150 rows of
genuinely tabular data reads better as a table than a card list). See ADR-018. Verified live with
a real superadmin session: created a real clinic, confirmed it renders correctly across all three
admin pages, and exercised a real suspend-clinic mutation to confirm the page reflects it.
`pnpm typecheck`/`pnpm build`/`pnpm test:unit` (40/40) clean. **Every screen in the app now uses
the current design system.**

## 2026-09-17 — Finished the visual migration to the remaining older screens (uncommitted)

Continuation of yesterday's dashboard redesign, onto the six pages it deliberately deferred:
appointments list, patients, doctors, staff, settings, and the queue board. Every raw HTML table
on these pages became a card-row list (colored-initials avatar, name/sub, status badge) matching
the pattern already established for "up next"/queue lists — not a second, competing "styled
table" pattern. Added a shared `Notice` component (`src/components/ui/states.tsx`) so five pages
stopped hand-writing the same inline success/error banner. All server actions and form field
names are unchanged — only how each field renders changed (the old kit's combined
`<Field label name>` became the new kit's `<Field label><Input name /></Field>`). See ADR-017.
Verified live: rendered all six pages with real data (a real doctor, patient, checked-in queue
entry), and exercised one real mutation through the new form UI (adding a clinic location) to
confirm the pages still submit and re-render correctly. `pnpm typecheck`/`pnpm build`/
`pnpm test:unit` (40/40) clean. Every dashboard screen now uses the current design system except
the separate super-admin `/admin` console, which stays explicitly out of scope.

## 2026-09-17 — Modern dashboard redesign + a real in-app notification center (uncommitted)

Outside the original 13-phase plan — requested directly after it shipped. Design was worked out
first as a standalone mockup (published for live feedback, never committed), then built into the
real app. **Notifications**: added `Notification.readAt`, a new `notifications` module
(list/mark-read, tenant-scoped), two new API routes, and a real notification bell in the
dashboard topbar that polls every 30s and shows real events (appointment booked/cancelled/
rescheduled/reminders, queue updates) — not a static icon. **Dashboards**: all four role
landing pages (Patient/Doctor/Reception/Admin) rebuilt with a gradient "what's next" hero, stat
tiles, and colored-initials avatars, sharing new reusable kit pieces (`Hero`, `StatTile`,
`InitialsAvatar`). **Shell**: new icon-based sidebar + topbar with search and the notification
bell, self-hosted Sora/IBM Plex fonts via `next/font`. **Booking**: the appointment booking
widget is now a doctor-chip / date-strip / slot-grid picker with a live sticky summary, same
underlying form submission as before. Caught two issues before they shipped: a first pass at the
mobile sidebar would have reintroduced the exact "unusable on a phone" bug Phase 12 fixed (fixed
with a real slide-in drawer, `src/components/mobile-nav.tsx`), and a couple of hero-card
badges/buttons mixed tone classes with override classes in a way that isn't guaranteed to resolve
correctly in Tailwind's cascade (fixed by adding proper `glass`/`light` variants instead). See
ADR-016. Verified live against the real database — booked a real appointment, confirmed the
resulting notification is correctly addressed and clearable via the real API, rendered the real
dashboards over HTTP. `pnpm typecheck`/`pnpm build`/`pnpm test:unit` (40/40) clean.

## 2026-09-16 — Phase 13 (final): full regression run + a real stored-XSS fix (uncommitted)

The last phase in the plan. Ran the real, DB-truncating integration suite for the first time in
a while (with explicit confirmation, against the shared dev database) to finally resolve an
open item: a prior run had reportedly hit a worker crash and some files collecting 0 tests. This
run came back clean — **19/19 test files, 113/113 tests, no crash** — the earlier instability
didn't reproduce and no specific cause was found to blame (recorded honestly, not claimed as
fixed). Security pass found one real issue: `website`/`logoUrl`/`coverImageUrl`/`photoUrl`
profile fields accepted any URL scheme including `javascript:` and `data:`, and `website`
specifically renders unescaped as `<a href>` on the public, unauthenticated hospital page —
a working stored-XSS a clinic admin (or an attacker who compromises one) could use against any
visitor to their published profile. Fixed at the validation boundary with a new shared
`httpUrlSchema()` (`src/lib/validation.ts`) requiring http(s), applied to all four affected
fields; 6 new regression tests lock it in. See ADR-015. `pnpm typecheck`/`pnpm build`/
`pnpm test:unit` (40/40) clean. **All 13 phases of `PRODUCT_EVOLUTION_PLAN.md` are now done.**
Phases 2–12 were committed separately outside this changelog entry; this phase's changes
(`src/lib/validation.ts`, the two schema files, the new test) are not yet committed.

## 2026-09-16 — Phase 12: responsive + accessibility pass (uncommitted)

Fixed one launch-blocking bug and several systemic smaller ones across everything built in
Phases 2–11. **Biggest fix**: both sidebar layouts (dashboard and admin) used a fixed 220px
sidebar with zero media queries — the entire dashboard was unusable on a phone. Now a single CSS
media query in `globals.css` collapses the sidebar into a wrapping top bar below 768px, no new
client JS. Also: a global, unlayered `:focus-visible` rule guarantees a visible keyboard focus
ring everywhere, including the older inline-styled dashboard kit that couldn't express one itself;
a new `LinkButton` component replaces 11 instances of an invalid `<button>` nested inside an
`<a>` across the four role dashboards; a new `Table` wrapper gives all 15 pages using data tables
a horizontal-scroll fallback instead of squeezing columns unreadably; the queue page's filter
inputs and the verification queue's action column got accessible names; nav links now carry
`aria-current="page"` on the active route; two pages' heading hierarchy (h1→h3, skipping h2) was
fixed. Verified live against the real database — rendered actual dashboard pages via a minted
session and confirmed every new class/attribute in the served HTML, not just build-checked. See
ADR-014. `pnpm typecheck`/`pnpm build`/`pnpm test:unit` (34/34) clean. **Not yet committed.**

## 2026-09-16 — Phase 11: dependent/family booking (uncommitted)

The last phase touching the booking transaction. A guardian with a `PatientAccessGrant`
(`MANAGE_APPOINTMENTS`) on a dependent `Patient` record can now book, view, reschedule, and
cancel that dependent's appointments — previously only the patient's own `ownerUserId` could.
Extended `bookAppointment` (checked inside the same SERIALIZABLE transaction, not a separate
out-of-transaction check), `getAppointment`, `listAppointments`, `cancelAppointment`, and
`rescheduleAppointment` in `appointments/service.ts` to also accept a live family grant alongside
direct ownership — no new authorization system, reuses the existing `PatientAccessGrant`/
`hasFamilyAccess` primitive built for the family module. Web: the booking form offers a patient
picker ("(Myself)" plus any managed dependent) only when the caller actually has a grant; the
appointment-detail page's Reschedule/Cancel buttons now also show for a family manager. Verified
live end to end: dependent with no owner, a separate guardian account granted access, booking
blocked (403) before the grant and succeeding after, guardian can read the appointment directly
and via their own list, cancel correctly hits the same cancellation-window rule the owner path
uses (not a bypass), reschedule succeeds, and a third unrelated in-tenant patient account gets
404/403/excluded-from-list on every attempt — then all test data deleted. See ADR-013.
`pnpm typecheck`/`pnpm build` clean. **Not yet committed.**

## 2026-09-16 — Phase 10: clinic-admin dashboard + the platform verification queue (uncommitted)

Two things. First, the last org-scoped role still on the plain stat grid — `AdminOverview.tsx`
gives CLINIC_ADMIN the same "what's next" treatment doctors/reception got in Phases 8–9 (doctor/
staff counts, today's totals split by status, a schedule list, quick actions), plus a "Verified"/
"Listed, not verified"/"Not listed" badge. Second, closed a real gap: `Organization.verificationStatus`
has existed since Phase 3 but nothing could ever move it out of `DRAFT`. New
`POST /api/orgs/:orgId/request-verification` (CLINIC_ADMIN, gated on the same profile-readiness
check publishing already uses) and `PUT /api/admin/organizations/:targetOrgId/verification`
(SUPER_ADMIN, approve/reject) — mirrors the existing suspend/reactivate pattern exactly, no new
subsystem. New `/admin/verification` queue page + Approve/Reject buttons on the existing org
detail page; a "Request verification" button + status message on the clinic's own profile page.
Verified live end to end: real profile → request → listed in a real superadmin's queue → approved
→ the "Verified" badge correctly appeared on the public hospital page, the clinic's own profile
page, and the new admin dashboard — plus confirmed both request-while-pending and approve-while-
not-pending correctly reject with 409. See ADR-012. `pnpm typecheck`/`pnpm build` clean. **Not
yet committed.**

## 2026-09-16 — Phase 9: a real reception "what's next" workspace (uncommitted)

Reception's `/dashboard/:orgId` landing page now shows today's clinic-wide numbers (total,
checked-in, waiting, in-consultation, no-shows) and an "up next" list across every doctor —
instead of a single generic stat card. Built on `appointments.listAppointments()` unmodified
(same function Phase 8 uses, just without the per-doctor filter); the existing, already-working
live queue board is untouched, just linked to. Verified live: invited a real receptionist
account, booked a same-day appointment, confirmed the stats and "up next" list rendered
correctly with real data, then deleted the test data. See ADR-011. `pnpm typecheck`/`pnpm build`
clean. **Not yet committed.**

## 2026-09-16 — Phases 7–8: a real patient dashboard and a real doctor "what's next" workspace (uncommitted)

Replaced the generic, identical-for-everyone stat-card grid on `/dashboard/:orgId` with two
role-specific views, built entirely on existing, unmodified service functions — no schema or API
changes. **Patient**: a greeting, their next appointment (doctor, time, status, queue token if
checked in) with a "View appointment" link, and quick actions (book / see all / family access).
**Doctor**: today's date, who's currently in consultation or next in the queue (reusing
`queue.getBoard()`'s existing ordering), stat tiles (waiting / today's total / completed /
no-shows), and a chronological list of today's schedule. Also added the single-appointment
detail page that didn't exist for *any* role before (`/dashboard/:orgId/appointments/:id`) —
reachable from both new overviews and from the existing appointments list, reusing the exact
same action functions (confirm/check-in/no-show/cancel/reschedule-link/consultation-link) the
list page already has. Verified live: minted real sessions for a patient and a doctor account,
confirmed the patient view correctly shows/hides the next-appointment card, and confirmed the
doctor view correctly moves from "nobody waiting" to "next patient" with the real token the
moment a check-in happens — then deleted the test data. See ADR-010. `pnpm typecheck`/`pnpm
build` clean. **Not yet committed.**

## 2026-09-16 — Phase 6: patient self-service booking — find a doctor, pick a real slot, book it yourself (uncommitted)

The core loop the last few phases were building toward: a logged-in stranger with zero prior
relationship to a clinic can now book a real appointment from a doctor's public profile. New
`src/modules/patient-booking/` orchestrates two existing, unmodified pieces — `computeSlots`
(availability module) and `bookAppointment` (appointments module) — rather than reimplementing
either; its only new logic is turning "an authenticated User" into "a PATIENT member with a
Patient record" for a clinic that has opted into public listing, via a real `@@unique` constraint
(migration `20260916062902_patient_owner_unique_per_org`) so a double-submitted booking can't
create duplicate patient rows. New routes: `GET /api/public/doctors/:id/slots` (public, reuses
the authoritative slot math), `POST /api/patient/appointments` (authenticated, self-registers +
books in one call), plus `POST /api/orgs/:orgId/{publish,unpublish}` (API parity for the Phase 3
web-only publish action). New pages: a real date/slot picker on `/doctors/:id`, a review +
confirm page at `/doctors/:id/book` with a login gate exactly at the confirm step (never
before), and a `?next=` redirect-back-after-login flow on `/login`/`/register` (new, guarded
against open-redirect by `safeNextPath`). Found and fixed a real, if low-severity, pre-existing
gap while building this: `getAppointment` didn't check patient ownership on a direct-by-id
lookup, unlike `listAppointments` — closed to match. See ADR-009 for the full design reasoning
and the corrected-mid-draft bug (a first attempt referenced a `Membership.patientProfile`
relation that doesn't exist — caught by `tsc`, never shipped).

**Verified live against the real dev database**, not just build-clean: registered two real
accounts through the actual API, created and published a real clinic + doctor, set real weekly
availability, fetched real public slots, self-booked twice as the same new patient (confirmed
the identical `patientId` both times — no duplicate), confirmed a same-slot double-booking
correctly 409s, confirmed booking against an unpublished org 404s, and confirmed the ownership
fix (a different patient gets 404 on someone else's appointment id, the owner gets 200) — then
deleted every row the test created. `pnpm typecheck`/`pnpm build` clean. 13 new unit tests
passing (`organization-publish`, `safe-redirect`); a full integration test file was written for
this flow but deliberately not executed against the shared dev DB (truncation risk — see
`STATUS.md`'s open test-suite item). **Not yet committed.**

## 2026-09-16 — Phase 5: public hospital & doctor discovery — the first pages a patient can actually use (uncommitted)

The platform's first unauthenticated, cross-tenant read surface. New `src/modules/public/`
(schema + service, unscoped `db` client with hardcoded `isActive`/`isPubliclyListed` filters and
named select-allowlist constants — see ADR-008) backs 4 new public API routes:
`GET /api/public/organizations` (+ `/:slug`), `GET /api/public/doctors` (+ `/:doctorId`) — search,
pagination, only ever returning published, active rows and only public-safe fields. New
patient-facing pages: `/` (rebuilt homepage — search, featured hospitals/doctors, honest empty
state when nothing's published yet), `/hospitals` (search + list), `/hospitals/:slug` (profile —
about, contact, locations, doctors), `/doctors` (search + list), `/doctors/:id` (profile — bio,
qualifications, fee, practice location, a clear "online booking isn't live yet" notice since
booking is Phase 6). The old developer status page moved from `/` to `/status`, nothing deleted.
Verified for real, not just build-clean: started the app on a real port (avoided colliding with
an unrelated project already running on 3000 on this machine), confirmed `/api/health` reaches
the real Neon DB, hit every new route and got the correct empty-state copy (no clinics published
yet, which is accurate — this feature is brand new), and confirmed both detail pages 404
correctly for a nonexistent slug/id. `pnpm typecheck`/`pnpm build` clean. **Not yet committed.**

## 2026-09-16 — Phase 4: doctor public-profile fields + self-edit page (uncommitted)

`DoctorProfile` gains `photoUrl`, `qualifications`, `yearsOfExperience`, `languages` (string
array), `consultationFeeMinor`, and its own `isPubliclyListed` flag (independent of the
organization's) — migration `20260916060502_doctor_public_profile`, additive only, applied to
the dev DB. Reused the existing self-edit authorization in `updateDoctor()` (a doctor can edit
their own row, an admin can edit any) rather than building anything new — extending the schema
was the only change needed. New `/dashboard/:orgId/doctors/:doctorId/profile` page (preview +
edit + a "list publicly" checkbox), linked from the doctors list ("Profile") and, for a doctor
viewing their own dashboard, a new "My profile" sidebar link. No publish-readiness gate at the
doctor level (unlike the organization one) — see ADR-007 for why. `PATCH
/api/orgs/:orgId/doctors/:doctorId` picked up the new fields automatically. Verified: `pnpm
typecheck` clean, `pnpm build` clean, new route confirmed in the build output. **Not yet
committed.**

## 2026-09-16 — Phase 3: organization public-profile fields + guided profile/publish page (uncommitted)

`Organization` gains public-profile fields (`orgType`, `tagline`, `about`, `logoUrl`,
`coverImageUrl`, `publicPhone`, `publicEmail`, `website`), a `verificationStatus` enum (default
`DRAFT`), and an `isPubliclyListed` gate — migration `20260916055537_organization_public_profile`,
additive only, applied to the dev DB. New `canPublishOrganization()` pure validator (name/type/
description/contact/≥1 location required to publish) with 8 unit tests. New
`/dashboard/:orgId/profile` page (CLINIC_ADMIN-only) — edit the public profile, see a live preview
of how it'll look once public discovery ships, and publish/unpublish, all built with the new
Tailwind component kit from Phase 2. New clinic creation now lands on this page instead of the
bare dashboard. `PATCH /api/orgs/:orgId` picks up the new fields automatically (same Zod schema
the web app uses). See ADR-006. Verified: `pnpm typecheck` clean, `pnpm build` clean, new unit
tests 8/8 passing. Full integration suite not run against the shared dev DB (known truncation
risk, and an unrelated pre-existing test-suite flakiness investigation is still open — see
`STATUS.md`). **Not yet committed.**

## 2026-09-16 — Product evolution plan + design-system Phase 2 started (Tailwind v4, shared component kit)

Audited the entire `platform/` codebase against actual source (schema, routes, services, RBAC,
pages) and wrote `platform/PRODUCT_EVOLUTION_PLAN.md` — a 16-section plan covering current vs.
missing capabilities/APIs/schema, per-role user journeys, information architecture, and 13
implementation phases toward public hospital/doctor discovery + patient self-service booking on
top of the existing (unmodified) operational core. Key finding: `Organization` has almost no
public-profile fields today (just name/slug/timezone), there is no public API surface at all
beyond `/api/health` and auth, and the homepage is a backend status page, not a marketing page.

Started Phase 2 (design-system foundation): added Tailwind v4 via a `@theme` block in
`app/globals.css` that maps Tailwind tokens onto the *existing* CSS variables (no new palette,
no existing page touched), plus a new `src/components/ui/*` kit (`Button`, `Card`, `Badge`,
`Field`/`Input`/`Select`, `EmptyState`/`ErrorState`/`Skeleton`, `SearchBar`) for the public-facing
pages built in later phases. See ADR-005. Also fixed a small regression found while installing
the new dependency: `pnpm.onlyBuiltDependencies` had silently stopped being read from
`package.json` (pnpm 10 moved it to `pnpm-workspace.yaml`) — see ADR-004's addendum. Verified:
`pnpm typecheck` clean, `pnpm build` clean, every existing route (dashboard/admin/API) still
generates with no errors. **Not yet committed.**

## 2026-09-16 — Docs: added DECISIONS.md (ADR log) and this changelog as standing practice

No code change. Added a decision log and this changelog to match a documentation discipline the
user asked to be kept "every time" going forward — one ADR per non-obvious technical decision,
one dated entry here per shipped change, alongside the existing `STATUS.md` plain-English
summary. Backfilled both with the real decisions/changes from this session (superadmin console,
login performance fix, notification dispatcher, pnpm migration) rather than starting empty.

## 2026-09-16 — npm → pnpm migration (uncommitted)

Migrated `platform/` from npm to pnpm: pinned `pnpm@10.34.5` via `packageManager`, deleted
`package-lock.json`, generated `pnpm-lock.yaml` via `pnpm install` only, added
`pnpm.onlyBuiltDependencies` for Prisma/esbuild build-script approval. No Turborepo, no
workspaces, no dependency version changes, no auth/security code touched. Every npm reference in
`docs/DEPLOYMENT.md`/`docs/README.md`/`tests/README.md`/`docs/ROADMAP.md` updated to pnpm.
Verified: `pnpm install`, `pnpm install --frozen-lockfile`, `pnpm prisma:generate`,
`pnpm prisma:validate`, `pnpm db:seed`, `pnpm typecheck`, `pnpm test:unit` (21/21), `pnpm test`
(92/92), `pnpm build`, `pnpm start`, `pnpm dev` all pass. See ADR-004. **Not yet committed.**

## 2026-09-16 — Fixed: login latency (removed 1 redundant DB round trip); notification dispatcher was never scheduled in production (uncommitted)

Live-timed the production deployment and found login taking a consistent ~4.8s across 4
sequential Postgres round trips — removed the one genuinely redundant round trip
(`accessClaimsFor`'s `tokenVersion` re-fetch, already available from the first query). Separately
discovered the notification dispatcher (built since Phase 2) had never actually been invoked on
a schedule in production — no reminder had ever fired live — and added a GitHub Actions workflow
to run it every 5 minutes. See ADR-002/ADR-003. Full 92-test suite still passes. **Not yet
committed** — needs two manual setup steps (Vercel + GitHub Actions secrets) before the
dispatcher does anything, and a decision on whether to push the login fix now.

## 2026-09-16 — Added STATUS.md — plain-English, always-current progress summary

New `docs/STATUS.md`, organized around the Patient-side/Healthcare-side product flow, with
✅ Done / 🔄 In progress / ⛔ Not started sections — meant to be shown to a non-technical
stakeholder directly. Linked from `docs/README.md`'s documentation map. Committed to keeping it
updated after every finished piece of work going forward.

## 2026-09-15 — Superadmin platform console (`529f57f`)

Added a SUPER_ADMIN web console: list/search/filter organizations across tenants, suspend/
reactivate a clinic (audited both transitions), organization detail with membership roster, a
cross-tenant platform audit log, and platform-wide stats. `src/modules/superadmin/` uses the
**unscoped** `db` client deliberately (see ADR-001) — the one place in the codebase that bypasses
`tenantDb()` — and re-asserts `assertSuperAdmin(ctx)` inside every function regardless of
route-level gating. New routes: `GET/PUT /api/admin/organizations[/:targetOrgId[/status]]`,
`GET /api/admin/audit`, `GET /api/admin/stats`. New pages: `/admin`, `/admin/organizations`,
`/admin/organizations/:orgId`, `/admin/audit`. No self-service way to become a platform admin —
`User.isPlatformAdmin` is a manual DB flag set directly in Neon. 5 new tests (non-admin 403 on
every route, cross-tenant listing, search/status filters, org detail, suspend→audit→reactivate→
audit, platform-wide audit+stats). 92 tests passing overall, `tsc` clean, `next build` green.
