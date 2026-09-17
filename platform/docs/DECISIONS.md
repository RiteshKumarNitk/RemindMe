# DoseWise Platform — Architecture Decision Records

Short, dated records of *why* a non-obvious technical choice was made — not what the code does
(the code shows that), but the alternatives considered and the reasoning. Updated every time a
real decision is made, not just when something breaks. See [CHANGELOG.md](CHANGELOG.md) for the
dated log of what actually shipped, and [STATUS.md](STATUS.md) for the current plain-English
state.

## ADR-001: Superadmin console uses the unscoped Prisma client, not `tenantDb()`

- **Context.** Every other module in this codebase reads/writes through `tenantDb(ctx)`, a
  Prisma `$extends` wrapper that automatically scopes every query to the caller's own
  organization (`MULTI_TENANCY.md`). A platform-wide superadmin console needs to list, inspect,
  and act on *every* organization — the tenant scope itself is the thing being bypassed by design.
- **Decision.** `src/modules/superadmin/service.ts` is the **one deliberate exception**: it uses
  the base, unscoped `db` client directly, and every function re-asserts
  `assertSuperAdmin(ctx)` internally, regardless of what the calling route already checked. This
  means the safety property is "no unscoped query runs without its own superadmin check inside
  the function," not "only trusted callers can reach this file."
- **Consequences.** Any future contributor adding a new superadmin function must remember to call
  `assertSuperAdmin` themselves — there's no route-level middleware doing it for them, by design,
  so the check travels with the function even if it's called from somewhere unexpected later.
  The admin API routes use a dynamic segment named `targetOrgId`, not `orgId`, specifically so
  `withApi()`'s auto tenant-resolution (keyed on a literal `params.orgId`) doesn't try and fail to
  find the admin's own membership in the org being inspected.

## ADR-002: Login latency fix — remove the redundant `tokenVersion` re-fetch, don't defer writes with `after()`

- **Context.** A live audit (curl timing against the production deployment) found login taking a
  consistent ~4.8s, tracing to 4 sequential Postgres round trips in `loginUser`/`authSuccessResponse`:
  user lookup → `lastLoginAt` update → an access-claims re-lookup (`accessClaimsFor`, fetching
  `tokenVersion` again) → a refresh-token insert. The third one is pure waste — `tokenVersion` was
  already returned by the first query.
- **Decision.** `loginUser` now returns `{ userId, tokenVersion }` directly from its first query;
  `authSuccessResponse` accepts an optional `knownTokenVersion` and skips its own re-fetch when
  the caller already has it. Cuts 4 round trips to 3.
- **Rejected alternative: defer `lastLoginAt`/token-version bookkeeping writes via Next's
  `after()`.** This worked correctly under a real `next start` server (verified: `pnpm build &&
  pnpm start`, curled register+login successfully) but broke the test suite outright —
  `Error: 'after' was called outside a request scope` — because the vitest harness
  (`tests/helpers/http.ts`) invokes exported route handlers directly, bypassing the real Next
  request-context machinery `after()` needs. Reverted entirely rather than accept a permanently
  broken/skipped test path for a login-latency optimization; kept only the zero-risk fix above.
- **Consequences.** This closes 1 of 4 round trips. The dominant remaining suspects (Neon
  connection pooling, Vercel↔Neon region mismatch, Neon auto-suspend cold starts) are
  infrastructure/dashboard configuration, not something a code change can fix — see
  `DEPLOYMENT.md`'s "Performance troubleshooting" section.

## ADR-003: Notification dispatcher scheduled via GitHub Actions, not Vercel Cron

- **Context.** The notification dispatcher (`POST /api/internal/notifications/dispatch`) has
  existed since Phase 2 but was never actually invoked on a schedule in production — confirmed by
  the endpoint 404ing to every unauthenticated probe and the total absence of a `vercel.json` or
  `.github/workflows/` before this fix. No reminder or missed-dose alert had ever fired live.
- **Decision.** A GitHub Actions workflow (`.github/workflows/notifications-dispatch.yml`) curls
  the endpoint on `cron: "*/5 * * * *"` (every 5 minutes), authenticated via
  `X-Cron-Key: ${{ secrets.NOTIFICATIONS_CRON_SECRET }}`. Vercel's Hobby tier caps cron jobs at
  once-per-day, which is unusable for a dispatcher meant to run near-continuously; GitHub Actions
  has no such cap on a public/private repo's own workflows.
- **Consequences.** 5-minute granularity, not 60-second — a deliberate, disclosed tradeoff, not
  an attempt to match the original 60s design. Needs two manual, one-time setup steps that only
  the account owner can do: set `NOTIFICATIONS_CRON_SECRET` in Vercel's env vars, and mirror the
  same value as a GitHub Actions repository secret of the same name. Until both are set, the
  workflow runs and gets a clean 401/403, which is a harmless no-op, not a broken pipeline.

## ADR-004: npm → pnpm migration — pinned via `packageManager`, no workspaces/monorepo, no dependency upgrades

- **Context.** Requested migration of `platform/` from npm to pnpm for install/CI speed and
  reproducibility. Explicit constraints: no Turborepo, no pnpm workspaces (this is a single
  package, not a monorepo), no dependency version changes, no touching auth/security logic.
- **Decision.** Added `"packageManager": "pnpm@10.34.5"` to `package.json` (exact version, not a
  range) so `corepack` resolves the identical pnpm version in every environment — local, CI,
  Docker — without relying on whatever pnpm happens to be globally installed. Deleted
  `package-lock.json`; `pnpm-lock.yaml` was generated purely by running `pnpm install`, never
  hand-edited. Added `pnpm.onlyBuiltDependencies: ["@prisma/client", "@prisma/engines", "esbuild",
  "prisma"]` — pnpm 10 blocks dependency postinstall/preinstall scripts by default (npm doesn't),
  and this field is the non-interactive, reproducible equivalent of manually running
  `pnpm approve-builds` on every fresh clone.
- **Consequences.** Every command in every doc/script changed from `npm`/`npx` to
  `pnpm`/`pnpm exec`. No dependency version changed. `pnpm` does **not** make the deployed site
  faster — it only affects install/CI speed, never claimed otherwise (see `STATUS.md`). Verified:
  `pnpm install`, `pnpm install --frozen-lockfile`, `pnpm prisma:generate`, `pnpm typecheck`,
  `pnpm test` (92/92 at the time), `pnpm build`, `pnpm start`, `pnpm dev` all run clean.
- **Addendum (2026-09-16).** Installing a new dependency (`tailwindcss`, see ADR-005) surfaced a
  pnpm warning: `pnpm@10.34.5` no longer reads `pnpm.onlyBuiltDependencies` from `package.json` —
  it moved to a `pnpm-workspace.yaml` manifest. This had been silently inert since some point
  after the original migration was verified (a lockfile-only regression — `pnpm install` still
  worked, the setting just stopped doing anything). Fixed by creating `pnpm-workspace.yaml` with
  the same `onlyBuiltDependencies` list and removing the now-dead `pnpm` field from
  `package.json`. No workspace packages were declared — the file exists solely to hold this one
  setting, which pnpm permits.

## ADR-005: Design-system foundation is additive (Tailwind v4 + token layer), not a rewrite of existing pages

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` (Phase 2) calls for a real design system ahead of
  building any public-facing (discovery/booking) pages. The existing dashboard/admin pages
  (18+ screens) are functional, tested-against-indirectly (the app still needs to build and
  serve them), and 100% inline-styled against CSS custom properties in `app/globals.css`
  (`--indigo`, `--card`, `--ink`, etc.) with a small shared kit (`app/dashboard/ui.tsx`).
- **Decision.** Added Tailwind v4 (`@tailwindcss/postcss`, CSS-first config — no
  `tailwind.config.js`) via a `@theme` block in `app/globals.css` that maps Tailwind color
  tokens (`--color-indigo`, `--color-ink`, ...) to the **existing** raw CSS variables
  (`--color-indigo: var(--indigo);`), not new hardcoded values. This means: (1) the existing
  dark-mode override block (`@media (prefers-color-scheme: dark) { :root { ... } }`) keeps
  working unchanged and now also drives the new Tailwind utilities for free, and (2) no existing
  page's inline `style={{ color: "var(--indigo)" }}` usage needed to change. New shared
  components (`src/components/ui/*` — `Button`, `Card`, `Badge`, `Field`/`Input`/`Select`,
  `EmptyState`/`ErrorState`/`Skeleton`, `SearchBar`) are Tailwind-based and additive; the
  existing `app/dashboard/ui.tsx` kit is untouched.
- **Consequences.** New public-facing pages (Phase 5+) get a real component system from day
  one. Migrating the *existing* dashboard pages off inline styles onto the new components is
  explicitly deferred to a separate, later, page-by-page pass — not bundled into this change,
  to keep the diff reviewable and the risk near zero. Verified: `pnpm typecheck` clean,
  `pnpm build` clean (every existing route — dashboard, admin, API — still generates with no
  errors or warnings).

## ADR-006: Organization public-profile — "listed" and "verified" are separate, independent flags

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` (Phase 3) needs a way for a clinic to publish its
  profile for public discovery (a later phase), plus the plan's own §15 verification model
  (`DRAFT`/`PENDING_VERIFICATION`/`VERIFIED`/`REJECTED`/`SUSPENDED`). The audit found
  `Organization` already has a superadmin-controlled `isActive` boolean (suspend/reactivate) —
  a third, pre-existing on/off concept.
- **Decision.** Three independent concerns, not one status field: `Organization.isActive`
  (existing, superadmin suspend/reactivate — an inactive org can't be used at all),
  `Organization.isPubliclyListed` (new — whether the org appears in public discovery, set by the
  clinic admin via a "Publish" action, gated by `canPublishOrganization()`, a pure function
  requiring name/type/a description/contact info/≥1 location), and
  `Organization.verificationStatus` (new enum, default `DRAFT` — whether the platform has
  reviewed the org; **deliberately dropped `SUSPENDED` from the plan's proposed enum values**,
  since that would duplicate `isActive`'s job under a different name). A clinic can be publicly
  listed while still unverified — the profile page and (later) public discovery must render an
  honest "not verified yet" state, never fabricate a badge (per the plan's own §8 instruction:
  "Do not claim a doctor or hospital is 'verified' unless the system actually verifies them").
  The verification *review workflow* itself (an admin approving `PENDING_VERIFICATION →
  VERIFIED`) is deliberately not built yet — out of scope until Phase 10, per the plan's own
  "don't build a huge manual verification bureaucracy unless required, but make sure the
  architecture can support it."
- **Consequences.** Migration `20260916055537_organization_public_profile` is additive only —
  every existing `Organization` row is valid with no backfill (`verificationStatus` defaults
  `DRAFT`, `isPubliclyListed` defaults `false`, every new profile field is nullable). The
  publish-readiness check (`src/modules/clinics/publish.ts`) is a pure function, deliberately
  separated from the DB-touching service call, specifically so it's unit-testable without a
  database connection — 8 new tests, no integration/DB test suite run needed to verify this
  piece.

## ADR-007: Doctor public-profile edit reuses the existing self-edit authorization; no separate publish gate

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` (Phase 4) needs doctor-facing profile fields (photo,
  qualifications, experience, languages, consultation fee) and a way for a doctor to edit their
  own profile, not just a clinic admin. `doctors/service.ts`'s `updateDoctor` already had exactly
  this authorization shape: a doctor may edit their own `DoctorProfile` row, an admin may edit
  any, and only an admin may deactivate one — built for the existing availability/bio fields, and
  it required zero changes to extend to the new marketing fields.
- **Decision.** Added the new fields (`photoUrl`, `qualifications`, `yearsOfExperience`,
  `languages String[]`, `consultationFeeMinor`, `isPubliclyListed`) directly to
  `updateDoctorSchema`/`updateDoctor` rather than a parallel "doctor profile" model or a separate
  authorization path. **No `canPublishDoctor()` gate function** (unlike Organization's
  `canPublishOrganization()`, ADR-006) — `isPubliclyListed` is a plain checkbox on the same edit
  form. Reasoning: a doctor's public listing is only ever reachable through their *own*
  organization's public listing (Phase 5 discovery will nest doctors under their org), so an
  incomplete doctor profile within a published org is a display-quality concern for that later
  phase's UI, not a data-integrity concern worth a second blocking-validation system now.
  `specialty` stays freeform text (unchanged) rather than being promoted to a lookup/enum table —
  the plan flagged this as "recommended" for reliable discovery filtering, but that's additive
  work deferred to Phase 5 prep, not required to unblock this phase.
- **Consequences.** Migration `20260916060502_doctor_public_profile` is additive only, same
  pattern as ADR-006 (every field nullable/defaulted, zero backfill). New
  `/dashboard/:orgId/doctors/:doctorId/profile` page, reachable from the doctors list ("Profile"
  link, admin) and a new "My profile" sidebar link (doctor, own row only) — both hit the same
  page, which itself re-derives `canEdit` the same way the service layer does
  (`role === CLINIC_ADMIN || doctor.userId === ctx.userId`) for the UI-level redirect, while the
  service layer remains the actual enforcement point. `PATCH /api/orgs/:orgId/doctors/:doctorId`
  picked up the new fields automatically, same as ADR-006's org route.

## ADR-008: Public discovery module — unscoped `db` + named select-allowlist constants, not `tenantDb()`

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` (Phase 5) needs the platform's first genuinely
  unauthenticated, cross-tenant read surface: anyone, logged in or not, can browse published
  clinics and doctors. `tenantDb()` can't be used at all here — there is no `ctx.org` to scope
  by, because there's no session. This is a third instance of the "deliberate exception to
  tenant scoping" pattern, after ADR-001 (superadmin, trusted+re-checked) — but for the opposite
  reason: not "a trusted caller needs to see everything," but "nobody is authenticated, so the
  *query itself* must be the only thing standing between an anonymous caller and every
  organization's full row."
- **Decision.** `src/modules/public/service.ts` uses the base `db` client directly, and every
  function's `where` clause hardcodes `isActive: true, isPubliclyListed: true` (checked on the
  organization, and — for doctors — on both the doctor row and its parent organization; a
  doctor's own `isPubliclyListed` flag is necessary but not sufficient). Every `select` is a
  named, top-level, reviewable constant (`PUBLIC_ORG_SUMMARY_SELECT`,
  `PUBLIC_ORG_DETAIL_SELECT`, `PUBLIC_DOCTOR_SUMMARY_SELECT`, `PUBLIC_DOCTOR_DETAIL_SELECT`) —
  never an inline `select` built ad hoc per query — specifically so a future field added to
  `Organization`/`DoctorProfile` (e.g. something clinical, or an internal-only setting) doesn't
  silently become public just by existing on the model; it has to be deliberately added to one
  of these four lists. `getPublicOrganization`/`getPublicDoctor` both throw a plain `NOT_FOUND`
  for "doesn't exist" and "exists but isn't published" alike — never a distinguishable response,
  so an anonymous caller can't probe which org slugs exist but are unpublished.
- **Consequences.** No clinical model (`Consultation`/`Prescription`/`MedicalDocument`/
  `Medication`/`VitalReading`/`Patient`/`AuditLog`) is reachable from this module at all — not
  filtered out, structurally absent from every select. `ClinicLocation` has no
  `isPubliclyVisible` field yet (flagged as a "nice to have" in the plan's §6); every *active*
  location of a *publicly-listed* org is treated as public for now — a reasonable default,
  revisit if a clinic wants some locations hidden from discovery while still using others
  operationally. Also moved the old developer-facing homepage (API module status card) from `/`
  to `/status`, since `/` is now the patient-facing homepage — nothing was deleted, `/api/health`
  is unchanged and still linked from both.

## ADR-009: Patient self-booking — a new `patient-booking` orchestration module, a real `@@unique` constraint for idempotent self-registration, and a closed `getAppointment` ownership gap

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` Phase 6 needs a stranger who found a doctor via public
  discovery to book an appointment themselves. Investigating the existing `appointments.service.ts`
  found `bookAppointment` already fully supports a PATIENT booking themselves (self-book gate,
  `allowPatientSelfBooking`, `REQUESTED` vs `CONFIRMED` status) — it just has no caller that could
  ever reach it as a brand-new, unaffiliated user, because every existing path to a `PATIENT`
  role requires a `Membership` row, and the only thing that creates one for a patient is
  `patients.createPatient`, which is `RECEPTIONIST`/`CLINIC_ADMIN`-only. There was no self-service
  path from "logged-in stranger" to "PATIENT member with a Patient record" at all.
- **Decision 1 — a thin orchestration module, not new booking logic.** `src/modules/patient-booking/`
  sequences two existing things — `ensurePatientMembership` (new, find-or-create) then
  `bookAppointment` (existing, unmodified) — via a synthetic `OrgContext` built the same way
  `tenancy.createOrganization` already builds one for its own audit-log call (there's codebase
  precedent for this, not a new pattern). It never reimplements slot math, lead-time rules,
  double-booking protection, or the appointment state machine.
  - `ensurePatientMembership` only ever operates on an org that is `isActive: true, isPubliclyListed: true`
    — a caller can't use `organizationId` in the request body to quietly join a *private* clinic
    whose UUID they happened to know. This is the one place in the codebase `organizationId` is
    accepted from a request body at all (`MULTI_TENANCY.md`'s ":orgId path only" rule is about
    *selecting* an existing membership; here it can only ever *create the caller's own* PATIENT
    membership in a clinic that has explicitly opted into public visibility — never elevate,
    never touch another user's data).
  - Guest accounts are blocked, mirroring `createOrganization`'s own guest guard.
- **Decision 2 — a real `@@unique([organizationId, ownerUserId])` on `Patient`, not a racy
  find-then-create.** A first draft tried to look up an existing patient via a nonexistent
  `Membership.patientProfile` relation (`Patient` only relates to `User` via `ownerUserId`, never
  to `Membership` — caught by `tsc`, not shipped). The real fix: migration
  `20260916062902_patient_owner_unique_per_org` adds a genuine unique index on
  `(organizationId, ownerUserId)` — Postgres treats `NULL` as distinct per row, so this never
  restricts the many clinic-registered dependents that have no `ownerUserId` at all, only a
  genuine duplicate self-owned record for the same person at the same clinic. `ensurePatientMembership`
  now does a real `upsert` against that constraint (plus the existing `Membership_userId_organizationId_role_key`
  for the membership half), so a double-submitted booking request can't create two Patient rows
  — Postgres's `ON CONFLICT` serializes it, the same category of guarantee the appointment
  `EXCLUDE` constraint already gives booking itself. A cheap `findFirst`/`findUnique` pre-check
  skips the write (and the audit log entry) entirely on the overwhelmingly common repeat-visit
  case. **Applied via `prisma migrate deploy` on a hand-authored migration file, not `migrate
  dev`** — this environment's non-interactive shell can't answer `migrate dev`'s confirmation
  prompt for a unique-constraint-could-fail warning; matches the existing documented pattern for
  hand-written migrations (`DEPLOYMENT.md`, the original `EXCLUDE` constraint).
- **Decision 3 — closed a real, if low-severity, pre-existing gap in `getAppointment`.** Found
  while building the first real PATIENT-facing single-appointment read: `getAppointment` (used by
  every role) filtered only by `organizationId`, never by patient ownership — unlike
  `listAppointments`, which already correctly scoped a PATIENT caller to `where: { patient: {
  ownerUserId: ctx.userId } }`. A PATIENT could `GET` any appointment's detail within their own
  org by guessing/knowing another patient's appointment UUID. Low severity (UUIDs aren't
  guessable) but a real defense-in-depth gap, closed by mirroring `listAppointments`'s existing
  rule: a PATIENT whose `ownerUserId` doesn't match gets `NOT_FOUND`, not `FORBIDDEN` (same
  no-leak posture as every cross-tenant lookup elsewhere in the app). Verified live (see below) —
  the owning patient reads their appointment fine, a different patient (with their own,
  legitimate membership in the same clinic) gets a clean 404 on the same id.
- **Decision 4 — `?next=` redirect support added to `/login`/`/register`, guarded against
  open-redirect.** The booking flow's "log in to confirm" step needs to return the visitor to
  their in-progress booking after auth, and neither page had ever supported a redirect target
  before (both always landed on `/dashboard`). New `src/lib/safe-redirect.ts`'s `safeNextPath`
  only accepts a same-app relative path — rejects protocol-relative `//host` and any absolute
  URL — before it's ever passed to `redirect()`, so `?next=` can't be turned into an
  open-redirect vector. 5 unit tests.
- **Verification.** Live-tested end-to-end against the real dev database with disposable data
  (registered two real accounts via the actual API, created and published a real org + doctor,
  set real weekly availability, fetched real public slots, self-booked twice as the same brand-new
  patient — confirmed the *same* `patientId` both times, not a duplicate — confirmed a third
  concurrent-style double-booking attempt on the same slot correctly 409s, confirmed a booking
  attempt against an unpublished org 404s, and confirmed the `getAppointment` ownership fix live)
  — then deleted every row created for the test. Also wrote (but, per this project's standing
  "never run the DB-truncating integration suite against the shared dev database without being
  certain a disposable DB is configured" caution, did not execute) a full integration test file
  (`tests/integration/patient-booking.test.ts`) covering the same scenarios for whenever that
  suite's separate, already-flagged flakiness issue (see `STATUS.md`) is resolved. `pnpm typecheck`
  and `pnpm build` both clean throughout.

## ADR-010: Phases 7–8 (patient dashboard, doctor workspace) are role-specific overview components, not new backend

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` Phase 7 and Phase 8 both call for turning the generic
  `/dashboard/:orgId` stat-card grid (identical layout for every role, just different numbers)
  into something that actually answers "what should I do next," per-role — for a patient, their
  next appointment; for a doctor, who's waiting right now. Both are explicitly scoped as
  presentation work in the plan ("no new backend").
- **Decision.** New `PatientOverview.tsx`/`DoctorOverview.tsx`, swapped in by role at the top of
  `/dashboard/:orgId/page.tsx` (the CLINIC_ADMIN/RECEPTIONIST stat-grid view is untouched — out
  of scope for these two phases). Both are pure composition over existing, unmodified service
  functions — `DoctorOverview` calls `queue.getBoard()` (already orders by queue position, already
  distinguishes `IN_CONSULTATION`/`WAITING`) and `appointments.listAppointments()`; neither
  required a new query, a new field, or a new authorization rule. A DOCTOR-role membership with
  no linked `DoctorProfile` yet (an edge case — an invited account that hasn't completed setup)
  falls back to the old plain stat view rather than crashing, since `DoctorOverview` genuinely
  needs a `doctorId` to query against.
  - Also added the single-appointment detail page that was missing for *every* role
    (`/dashboard/:orgId/appointments/:appointmentId`) — reuses `getAppointment` (the function
    ADR-009 already made ownership-safe for PATIENT) and the *exact same* action functions the
    appointments list page already uses (`confirmAppointmentAction`, `cancelAppointmentAction`,
    etc.) — no duplicated business logic, just a second place to reach them from.
- **Consequences.** Zero schema/API changes for either phase. Verified live against the real
  database (not just build-clean): minted real cookie sessions for a patient and a doctor
  account, confirmed the patient overview correctly shows/hides the "next appointment" card,
  confirmed the appointment detail page renders and its actions are reachable, and confirmed the
  doctor overview correctly transitions from "nobody waiting" to "next patient" (with the real
  queue token) the moment a real check-in happens via the existing check-in endpoint — then
  deleted all of it. `pnpm typecheck`/`pnpm build` clean.

## ADR-011: Phase 9 (reception workspace) reuses `listAppointments` clinic-wide instead of per-doctor

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` Phase 9 wants reception's landing view to answer
  "what does the front desk need to know right now" — across *every* doctor in the clinic, unlike
  Phase 8's doctor view which is inherently one doctor's own queue.
- **Decision.** `ReceptionOverview.tsx` calls the same `appointments.listAppointments()` Phase 8
  uses, just without a `doctorId` filter — every existing tenant-isolation/role guarantee in that
  function applies unchanged. Counts (checked-in / waiting / in-consultation / no-shows) and an
  "Up next" list (soonest 8 non-terminal appointments across all doctors, each showing which
  doctor) are derived in the component, not a new query shape. The existing, already-functional
  live queue board (`/dashboard/:orgId/queue` — call/recall/skip/complete, auto-refresh) is
  deliberately left untouched and just linked to via an "Open queue board" button — Phase 9 is
  explicitly a landing-page improvement, not a rebuild of a tool that already works well.
- **Consequences.** No schema/API change. Verified live: invited a real RECEPTIONIST member,
  booked a same-day appointment, confirmed the overview's stat tiles and "Up next" list rendered
  correctly with real data — then deleted the test data. `pnpm typecheck`/`pnpm build` clean.

## ADR-012: Verification review queue — a request/decision pair mirroring the existing suspend/reactivate pattern, gated on the same readiness check as publishing

- **Context.** `Organization.verificationStatus` has existed since ADR-006 (Phase 3), defaulting
  `DRAFT`, but nothing ever transitioned it — there was no way for a clinic to ask for review and
  no way for a superadmin to decide. `PRODUCT_EVOLUTION_PLAN.md` Phase 10 asks for exactly this,
  explicitly modeled on the existing suspend/reactivate action rather than a new subsystem.
- **Decision.** Two new functions, one per side, both deliberately small:
  - `clinics.requestVerification(ctx)` (CLINIC_ADMIN) — `DRAFT|REJECTED → PENDING_VERIFICATION`,
    gated on the *exact same* `canPublishOrganization()` readiness check `publishOrganization`
    already uses (ADR-006) — a profile too incomplete to publish has nothing for a reviewer to
    verify either, so reusing the gate is correct, not a shortcut. Deliberately independent of
    `isPubliclyListed` — a clinic can request verification before or after publishing, or without
    ever publishing at all.
  - `superadmin.setOrganizationVerification(ctx, orgId, {status})` (SUPER_ADMIN) — only valid
    from `PENDING_VERIFICATION`; approving sets `VERIFIED`, rejecting sets `REJECTED` (which the
    clinic can then request again from, after fixing whatever prompted the rejection). Follows
    ADR-001's pattern exactly: unscoped `db`, `assertSuperAdmin` re-checked inside the function,
    `writeAudit` with an explicit `organizationId`.
  - `listOrganizations`' existing query schema gained one more independent filter
    (`verification: "pending"`, alongside the existing `status` filter) rather than a whole new
    list endpoint — backs a new `/admin/verification` queue page, which links into the *existing*
    `/admin/organizations/:orgId` detail page for the actual Approve/Reject decision (added there
    as two new buttons, visible only while `PENDING_VERIFICATION`) rather than building a second
    detail page.
  - Also shipped the CLINIC_ADMIN dashboard (`AdminOverview.tsx`) this same pass — the last
    org-scoped role still on the original plain stat grid (Phases 7–9 already covered
    PATIENT/DOCTOR/RECEPTIONIST). Same pattern as those: pure composition over
    `appointments.listAppointments()`, no new queries.
- **Consequences.** No schema migration — `verificationStatus` and its enum already existed. No
  route trusts a client-supplied "verified" claim anywhere; every place that shows a badge
  (public hospital profile, the clinic's own profile page, the new admin overview) reads the
  same DB column. Verified live end to end: filled a real profile, called
  `request-verification` (rejects a duplicate call while already pending, confirmed), listed it
  in a real superadmin's verification queue, approved it (rejects a duplicate approve once no
  longer pending, confirmed), and confirmed the "Verified" badge then appeared correctly in all
  three places that read it — then deleted the test data. `pnpm typecheck`/`pnpm build` clean.

## ADR-013: Dependent/family booking wired into the SERIALIZABLE booking path via the existing `PatientAccessGrant` primitive, not a new authorization system

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` Phase 11 is the last item touching the appointment
  booking transaction — the single highest-risk piece of code in the whole plan (SERIALIZABLE
  isolation, the `Appointment_org_doctor_no_overlap` EXCLUDE constraint). A guardian/family
  member managing a dependent's care (e.g. a parent booking for a child `Patient` record with no
  `ownerUserId`) had no way to book, view, reschedule, or cancel that dependent's appointments —
  `bookAppointment`'s PATIENT gate only ever checked `patient.ownerUserId === ctx.userId`. The
  authorization primitive already existed and was already used elsewhere: `PatientAccessGrant`
  (`AccessPermission` enum — `VIEW_APPOINTMENTS`, `MANAGE_APPOINTMENTS`, etc.) and
  `family.hasFamilyAccess(ctx, patientId, permission)`, but `appointments.service.ts` had never
  been wired to consult it.
- **Decision.** Extended every PATIENT-facing check in `appointments/service.ts` to also accept a
  live, non-revoked, non-expired grant, instead of building a parallel "family booking" code path:
  - `bookAppointment`'s self-booking gate (inside the `runSerializable` transaction) now allows a
    PATIENT who isn't the owner through if a `tx.patientAccessGrant` row exists for them on that
    patient with `MANAGE_APPOINTMENTS` — queried via `tx` directly (not the exported
    `hasFamilyAccess` helper) specifically to stay inside the same transaction snapshot the
    booking decision is being made under, matching the existing SERIALIZABLE discipline rather
    than adding a second, out-of-transaction check that could race against a grant revocation.
  - `getAppointment`/`listAppointments` extended to also match on `VIEW_APPOINTMENTS` grants (via
    the ordinary `hasFamilyAccess` helper / a `patientAccessGrant.findMany` respectively, both
    outside a transaction since these are plain reads).
  - `cancelAppointment`/`rescheduleAppointment` gained a shared `isFamilyManager(ctx, appt)`
    helper (checks `MANAGE_APPOINTMENTS`) used alongside the existing `isPatientOwner` check in
    both the authorization gate and, for cancellation, the same cancellation-window business rule
    the owner path already enforces — a family manager gets exactly the same rights and the same
    limits as the owner, not a superset or a separate ruleset.
  - Web UI: the appointments-list booking form now offers a patient picker ("(Myself)" plus any
    dependent with a `MANAGE_APPOINTMENTS` grant) only when the caller actually has at least one
    such grant — a patient with no dependents sees the exact same no-picker form as before. The
    appointment-detail page's Reschedule/Cancel buttons now also show for a `canManageAsFamily`
    caller, but the service layer remains the real enforcement point either way — the UI condition
    is purely a display decision, matching every other role's button-visibility pattern in that
    file (ADR-010).
- **Consequences.** No schema change — `PatientAccessGrant` and `hasFamilyAccess` already existed
  (built for the family module, not this phase). No new authorization concept introduced; a
  family manager's rights over an appointment are now defined as "identical to the owner's,
  wherever the owner is checked" rather than a separately-maintained rule that could drift out of
  sync. Verified live end to end against the real dev database: created a dependent `Patient` with
  no owner, granted a separate guardian account `VIEW_APPOINTMENTS`+`MANAGE_APPOINTMENTS`,
  confirmed booking for the dependent is `403` before the grant exists and succeeds after,
  confirmed the guardian can `GET` the appointment directly and see it in their own
  `listAppointments`, confirmed a cancel attempt correctly hits the ordinary
  `OUTSIDE_CANCELLATION_WINDOW` business rule (proving it passed the authorization gate and
  reached the same logic the owner path uses, not a bypass), confirmed a reschedule succeeds,
  and confirmed a *third*, unrelated in-tenant patient account (its own real membership, no grant)
  gets `404` on a direct `GET`, is excluded from its own `listAppointments`, and gets `403` on a
  book attempt for the dependent — then deleted all test data. `pnpm typecheck`/`pnpm build` clean
  throughout.

## ADR-014: Responsive/accessibility pass — a CSS-only mobile shell, not a client-side hamburger; global unlayered `:focus-visible`; one shared `Table`/`LinkButton` fix instead of per-page patches

- **Context.** `PRODUCT_EVOLUTION_PLAN.md` Phase 12 covers everything built in Phases 2–11. An
  audit found one launch-blocking bug and several smaller, systemic ones: (1) both sidebar
  layouts (`app/dashboard/:orgId/layout.tsx`, `app/admin/layout.tsx`) used a fixed 220px `<aside>`
  with zero media queries — on any phone-width viewport the dashboard was genuinely unusable, not
  just ugly; (2) `app/globals.css` had exactly one media query in the whole file
  (`prefers-color-scheme: dark`) — no responsive breakpoints existed anywhere; (3) the Tailwind
  kit's `Input`/`SearchBar` used `outline-none` with only a 1px border-color shift on focus — a
  weak-to-invisible keyboard focus indicator; (4) four dashboard overview components
  (`Patient`/`Doctor`/`Reception`/`AdminOverview.tsx`) nested a real `<button>` inside an `<a>`
  eleven times total (`<Link><Button>...</Button></Link>`) — invalid HTML, duplicate/confusing tab
  stops; (5) 15 pages still on the older `app/dashboard/ui.tsx` kit render data tables with
  `width: 100%` and no scroll fallback, which squeezes columns unreadably on a narrow screen
  instead of scrolling; (6) the queue page's doctor/date filter inputs and the verification
  queue's action column had no accessible name.
- **Decision 1 — CSS-only responsive shell, no new client JS.** Both sidebar layouts are Server
  Components with zero client-side state today; rather than convert them to add a hamburger
  toggle (a real feature, out of scope for a polish pass), added `.dashboard-shell`/
  `-sidebar`/`-nav`/`-main` classes to `globals.css` with one `@media (max-width: 768px)` block
  that stacks the shell vertically and lets the nav wrap horizontally — the sidebar becomes a top
  bar instead of disappearing or clipping. Zero new interactivity, pure layout.
- **Decision 2 — one global, unlayered `:focus-visible` rule, not per-component overrides.**
  Tailwind v4's `@import "tailwindcss"` places all its generated utilities (including
  `outline-none`) inside `@layer utilities`; a plain, unlayered CSS rule always wins the cascade
  over anything in a `@layer` regardless of source order, so a single `:focus-visible { outline: 2px
  solid var(--focus-ring); outline-offset: 2px; }` at the bottom of `globals.css` guarantees a
  visible keyboard focus ring on *every* interactive element in the app — including the older
  `app/dashboard/ui.tsx` kit, which styles everything via inline `style` objects and structurally
  cannot express `:focus-visible` itself. Also gave `Input`/`Select`/`SearchBar` an explicit
  `focus-visible:outline-focus` (a new `--color-focus` token) for a branded ring rather than
  relying solely on the cascade-layer fallback, since relying only on implicit layer-ordering
  behavior for a load-bearing a11y guarantee is fragile to reason about later.
- **Decision 3 — `LinkButton` (shares `Button`'s exact class-generation logic) replaces every
  `<Link><Button></Button></Link>`, not a one-off fix per file.** Extracted `buttonClasses()` in
  `button.tsx` and added `LinkButton` (a `next/link` styled identically to `Button`) so a
  navigation action renders as one real `<a>`, never a `<button>` nested inside one. Swapped all
  11 occurrences across the four overview components.
- **Decision 4 — a shared `Table` component wraps the old kit's `table`/`th`/`td` exports in a
  scrolling container, applied to all 15 pages that use them, not just the highest-traffic ones.**
  `app/dashboard/ui.tsx` exports `Table` (renders `<div className="table-scroll"><table
  style={table}>{children}</table></div>`); the `table` constant itself gained `minWidth: 560` so
  columns keep a readable width and the wrapper scrolls horizontally on a narrow screen instead of
  squeezing text unreadably. Every one of the 15 call sites (appointments, queue, patients,
  settings ×2, staff, doctors, availability ×2, consultation, family, audit ×2, admin
  organizations ×2, admin verification) was mechanically swapped from `<table style={table}>` to
  `<Table>` — a single component fix, not 15 divergent patches.
- **Decision 5 — a reusable `.sr-only` class, and `NavLink` (a small client component) for
  `aria-current`.** Added `.sr-only` to `globals.css` for controls with no visible label (the
  queue page's doctor/date filter, the verification queue's action column) instead of inlining the
  clip-rect hack per callsite. Added `src/components/nav-link.tsx` (`"use client"`, wraps
  `next/link` with `usePathname()`) so both sidebar layouts' nav links get a real `aria-current="page"`
  on the active route — the layouts themselves stay Server Components; only the leaf link needed
  client-side route awareness.
- **Decision 6 — `CardTitle` gained an `as` prop instead of forcing every usage to be an `<h3>`.**
  Two pages (`doctors/:id`, `doctors/:id/book`) put a `CardTitle` directly under an `<h1>` with no
  intervening `<h2>`, and in both cases the title wasn't really a page-outline heading at all — a
  link label / summary line inside a card. Rather than renumber the whole page's heading levels,
  changed both call sites to `<CardTitle as="p">`, since demoting to a non-heading element is the
  actually-correct fix when the text was never a section heading to begin with.
- **Consequences.** No schema/API changes — this phase touched only presentation. Verified live
  against the real dev database (not just build-checked): rendered the dashboard/queue/appointments
  pages via a minted cookie session and confirmed in the actual served HTML that
  `.dashboard-shell`/`.skip-link`/`.table-scroll`/`.sr-only` all appear, that the active nav link
  carries `aria-current="page"`, and that the queue filter's `sr-only` labels render — then
  deleted all test data. `pnpm typecheck`, `pnpm build` (every route generates clean), and
  `pnpm test:unit` (34/34) all clean. The DB-truncating integration suite was not run, per the
  project's standing caution (see `STATUS.md`'s still-open test-stability item).

## ADR-015: Phase 13 (final) — full suite ran green with no reproduction of the earlier flakiness; one real stored-XSS found and fixed at the validation boundary

- **Context.** Phase 13 is the plan's last item: "full existing test suite must stay green
  throughout every phase above, not just at the end" plus a security pass. `STATUS.md` had an
  open item since early in this project's work: a prior full test run had hit a worker crash
  after a cascading failure in the queue tests, and `consultations.test.ts`/`family.test.ts` had
  reportedly collected 0 tests — never root-caused, twice explicitly deferred at the user's
  direction to keep momentum on the functional phases. Running the real DB-truncating integration
  suite (`ALLOW_DB_TESTS=1 pnpm test`) requires pointing `DATABASE_URL` at a database that gets
  every app table `TRUNCATE`d — this project's standing rule is to never do that against the
  shared dev Neon instance without explicit, in-the-moment confirmation, which was asked for and
  given for this run specifically.
- **Decision 1 — ran the full suite for real, rather than continuing to reason about the
  flakiness from source alone.** Static review of `queue.test.ts` and the shared `beforeAll`/
  `truncateAll()` pattern across every integration file didn't surface a deterministic bug (no
  `.only`/`.skip`, availability rules cover all 7 ISO weekdays so no day-of-week-dependent
  flakiness, no shared mutable state between files). Rather than keep guessing, ran the real
  suite: **19/19 test files, 113/113 tests passed, no crash, no 0-test files, exit code 0.** The
  `prisma:error` lines visible in the log are Prisma's own verbose logging of two *intentionally*
  triggered failures the tests assert against (a double-booking's exclusion-constraint violation,
  a queue-action-on-a-stale-entry lookup) — both correctly caught and asserted as 409/404
  responses, not test failures. The previously-reported instability did not reproduce; no specific
  bug was found to have caused it (most likely a transient environment issue from whatever
  produced that original report), and this ADR records that honestly rather than claiming a fix
  for a bug that was never actually located.
- **Decision 2 — the security pass found one real, fixable vulnerability: `javascript:`/`data:`
  URIs accepted by every profile URL field, then rendered unescaped as `<a href>` on a public,
  unauthenticated page.** `updateOrgSchema.website`/`logoUrl`/`coverImageUrl` and
  `updateDoctorSchema.photoUrl` all validated with plain `z.string().url()`, which delegates to
  the WHATWG `URL` parser and accepts *any* scheme it recognizes, including `javascript:` —
  verified directly (`new URL("javascript:alert(1)").protocol` returns `"javascript:"`, and Zod's
  `.url()` accepts it). `website` flows from the profile edit form → `updateOrganization` →
  stored on `Organization.website` → returned by `getPublicOrganization` (the same function
  ADR-008 built specifically for anonymous, cross-tenant reads) → rendered directly as `<a
  href={org.website}>` on `/hospitals/:slug`, a page anyone can reach with no login. A
  `CLINIC_ADMIN` — the legitimate owner of that field, or an attacker who compromises one such
  account — could set it to a `javascript:` URI, publish their org, and any visitor who clicks the
  link executes attacker JS in the platform's origin. React does not protect against this: its
  auto-escaping guards against markup injection into the DOM tree, not against a dangerous
  *scheme* in a `href`/`src` attribute value it's told to render verbatim.
- **Decision 3 — fixed at the validation boundary with a shared `httpUrlSchema()` helper, not a
  render-time escape.** There's nothing to "escape" here — the value is already a syntactically
  valid URL, the danger is entirely in which scheme it uses. Added `httpUrlSchema(maxLength)` to
  `src/lib/validation.ts` (same module `parseBody`/`parseQuery` already live in), which requires
  the value to match `/^https?:\/\//i` in addition to passing `.url()`. Applied to all four
  affected fields (`website`, `logoUrl`, `coverImageUrl`, `photoUrl`) — `logoUrl`/`coverImageUrl`/
  `photoUrl` aren't actually rendered as `src`/`href` by any page in this codebase yet, but share
  the exact same field shape and the same eventual destination, so fixing all four now is
  cheaper and more honest than fixing only the one currently-exploitable field and leaving a
  known-dangerous pattern in the other three for whichever future page renders them first.
- **Consequences.** No schema/API breaking change for legitimate use — every real clinic website/
  logo/photo URL in practice already used http(s). New `tests/unit/http-url-schema.test.ts` (6
  tests) locks the fix in as a permanent regression test, matching this project's established
  pattern of DB-free unit tests for pure validators (ADR-006's `canPublishOrganization`, ADR-009's
  `safeNextPath`). Verified: the schema change rejects `javascript:`/`data:` URIs and still
  accepts plain `http://`/`https://` values (checked directly against the parser, not just
  inferred), `pnpm typecheck`, `pnpm build` (every route), and `pnpm test:unit` (40/40, including
  the 6 new tests) all clean. This closes the plan's final phase — all 13 phases of
  `PRODUCT_EVOLUTION_PLAN.md` are now done.

## ADR-016: Modern dashboard redesign + a real in-app notification center — outside the original 13-phase plan, requested directly by the user after it shipped

- **Context.** With `PRODUCT_EVOLUTION_PLAN.md` complete, the user asked for something the plan
  never scoped: a visually modern dashboard for every role, backed by a genuinely working
  notification system and booking flow, not just a restyle. Design direction was worked out first
  as a standalone HTML mockup (published as a Claude.ai artifact, iterated on live with the user —
  theme, layout, spacing — before any app code changed), then ported into the real Next.js app.
  The mockup file itself was never committed; it was a throwaway design surface, not a deliverable.
- **Decision 1 — a real notification center, not a decorative bell.** The `Notification` model
  and its dispatcher already existed (built early in this project for reminders/queue updates) but
  had no user-facing read surface at all — no list endpoint, no read/unread concept. Added
  `Notification.readAt DateTime?` (migration `20260917084237_notification_read_at`, additive/
  nullable, no backfill) and a new `src/modules/notifications/` module:
  `listMyNotifications(ctx)` (tenant-scoped, `channel: "IN_APP"`, returns both `PENDING` and
  `SENT` rows — `status` tracks the delivery/retry pipeline, not whether the row is worth showing,
  and IN_APP rows are meant to appear immediately, not wait for the next dispatch tick) and
  `markNotificationsRead(ctx, {ids?})`. The event→human-message mapping
  (`APPOINTMENT_BOOKED` → "An appointment was booked.", etc.) lives server-side in the service,
  not duplicated in the client component, so it evolves with the backend that defines the events.
  New routes `GET /api/orgs/:orgId/notifications`, `POST /api/orgs/:orgId/notifications/read`.
  `src/components/notification-bell.tsx` (client component) polls every 30s while mounted — this
  app has no realtime transport, and a 30s-stale unread count is a reasonable tradeoff against
  standing up one just for this.
- **Decision 2 — a mistake caught before it shipped: the mobile drawer.** The first pass at the
  new sidebar used `max-md:hidden` to remove it on narrow screens with no replacement, which would
  have silently reintroduced the exact "dashboard unusable on a phone" bug ADR-014/Phase 12 had
  just fixed — worse, actually, since the old CSS-collapse fallback would have been gone entirely.
  Caught on review, not by the user. Fixed with `src/components/mobile-nav.tsx`: a small client
  provider (`MobileNavProvider`/`MobileNavButton`/`MobileNavAside`) giving the sidebar a real
  slide-in drawer with a backdrop and a proper `<button aria-expanded>` toggle, auto-closing on
  route change via `usePathname()`. The layout itself (`app/dashboard/:orgId/layout.tsx`) stays a
  Server Component doing all the data fetching; only the open/closed state is client-side.
- **Decision 3 — new design tokens are additive, ported through `next/font/google` and the
  existing `@theme` layer, not a parallel styling system.** Sora (display), IBM Plex Sans (dashboard
  body), and IBM Plex Mono (tabular data) are self-hosted via `next/font` and exposed as
  `--nf-sora`/`--nf-plex-sans`/`--nf-plex-mono` on `<html>`, then wired into new `@theme` keys
  (`--font-display`, `--font-dash-body`, `--font-dash-mono`) in `globals.css` — deliberately two
  different variable names on each side of that link (a first attempt named both `--font-display`
  and created a silent self-referential custom-property collision between the `next/font` variable
  and the Tailwind theme token). `--warn` and `--surface-2` were added as new semantic tokens
  (light + dark), following the same "define once in `:root`, redefine under the dark-mode guard"
  pattern the file already used. None of this touches `--font-sans` or any existing page's
  rendering — Sora/Plex are opt-in via new utility classes only the new components use.
- **Decision 4 — two mixing-tone-classes-with-override-classes bugs caught before shipping.**
  The hero card's badges and buttons first used `tone="neutral"`/`variant="secondary"` plus a
  `className` override for the translucent-white look needed on a colored gradient background.
  Both `Badge` and `Button`/`LinkButton` build their class string by concatenating a tone/variant's
  classes with the caller's `className`, and two classes setting the same CSS property (the tone's
  `bg-surface` vs. the override's `bg-white/15`) are **not** guaranteed to resolve by source order
  in Tailwind's generated stylesheet — a real risk of the badge silently rendering grey-on-gradient
  in production. Fixed by adding real, mutually-exclusive variants instead of fighting the
  cascade: `Badge` gained `tone="glass"`, `Button`/`LinkButton` gained `variant="light"` and
  `variant="glass"`.
- **Decision 5 — the booking widget UI changed, the booking mechanics didn't.** `BookForm.tsx`
  still submits through the exact same `<input type="hidden" name="doctorId">` /
  `name="scheduledStart">` contract and the same server action
  (`bookAppointmentAction`/`rescheduleAppointmentAction`) as before — only the picker became a
  doctor-chip row, a 14-day date strip, and a real slot grid (still backed by the same
  `GET /api/orgs/:orgId/doctors/:doctorId/slots` fetch) with a sticky live-updating summary card,
  in place of three native `<select>`s. `src/components/ui/hero.tsx`, `stat-tile.tsx`, and
  `avatar.tsx` (a deterministic colored-initials avatar, same color per name every time) are new,
  reusable additions to the Tailwind kit — built once and shared across all four role dashboards
  (`Patient`/`Doctor`/`Reception`/`AdminOverview.tsx`), not copy-pasted per component.
- **Scope note.** This redesign covers the four role-overview landing pages
  (`app/dashboard/:orgId` per role), the dashboard shell (sidebar/topbar), the notification
  center, and the appointment booking widget — the pieces the user specifically asked for.
  The appointments *table*, older list pages (patients/settings/queue board), and the separate
  `/admin` superadmin console were deliberately left on their existing (already Phase-12
  responsive/accessible) styling — a full visual migration of those is a larger, separate piece of
  work, not bundled in here.
- **Consequences.** Verified live against the real dev database, not just build-checked: booked a
  real appointment, confirmed the resulting `APPOINTMENT_BOOKED` notification is real, correctly
  addressed to the doctor (not the booking admin), appears via `GET .../notifications` with the
  right `unreadCount`, and that `POST .../notifications/read` actually clears it — then rendered
  the real Admin and Doctor dashboards and the appointments/reschedule pages over HTTP with minted
  sessions and confirmed the new markup (fonts, hero cards, doctor chips) is present, before
  deleting all test data. `pnpm typecheck`, `pnpm build` (every route including the two new
  notification endpoints), and `pnpm test:unit` (40/40) all clean.

## ADR-017: Finished the visual migration ADR-016 deliberately deferred — appointments list, patients, doctors, staff, settings, queue board

- **Context.** ADR-016 explicitly scoped itself to the four role dashboards, the shell, the
  notification center, and the booking widget, and named what it left behind: "the appointments
  *table*, older list pages (patients/settings/queue board)... a larger, separate piece of work."
  The user asked to continue, so this pass finishes that named list — six pages in total
  (appointments, patients, doctors, staff, settings, queue board) — onto the same design language
  (Tailwind kit, `InitialsAvatar`, `Badge` tones, hero-style stat displays) rather than leaving the
  app visually split between two eras indefinitely.
- **Decision 1 — every raw `<table>` list became a card-row list, not a styled table.** Matches
  what ADR-016 already established for "up next"/queue-style lists (`InitialsAvatar` + name/sub +
  trailing badge or value), rather than introducing a second list pattern (a "modern" HTML table)
  alongside the card-row one. Actions that used to sit in a table's dedicated actions column now
  sit in a second row within each card, below a border — deliberately not making the whole card a
  `<Link>`, since a `<form>` or `<button>` inside an `<a>` is the same invalid-nesting bug fixed
  twice already this project (ADR-012's Phase 12 audit, and the `LinkButton` component it
  produced). Only genuinely non-interactive parts of a row are ever wrapped in a link.
- **Decision 2 — a new shared `Notice` component replaces the old kit's `ErrorNote` (which these
  pages no longer import) and stops three pages from hand-writing the same inline banner div.**
  `ErrorState` (the existing new-kit component) is sized for an empty section, not a one-line
  form-submission result — using it for "Email already registered" would look oversized. `Notice`
  (`src/components/ui/states.tsx`) is the lighter equivalent: one line, two tones (`ok`/`down`),
  reused across the appointments, patients, staff, doctors, and queue pages instead of each
  re-deriving the same `rounded-2xl border ... px-4 py-3 text-sm` div.
- **Decision 3 — form mechanics are completely unchanged; only the field-rendering changed.**
  Every server action (`createPatientAction`, `createStaffAction`, `createDoctorAction`,
  `saveSettingsAction`, `addLocationAction`, `addAppointmentTypeAction`, `queueAction`) is called
  exactly as before with the same field names. The only change is swapping the old kit's combined
  `<Field label name>` (label+input in one component) for the new kit's separated
  `<Field label><Input name /></Field>` — a mechanical conversion, not a logic change. The queue
  filter's native `<select>`/`<input type=date>` became the new kit's `Select`/`Input`, keeping
  the same `name` attributes the page's own query-string redirect already depends on.
- **Consequences.** No schema/API changes. Verified live against the real database: rendered all
  six pages over HTTP with a minted session and confirmed real data (a real doctor, patient, and
  checked-in queue entry) appears correctly on each; exercised one real mutation through the new
  UI's form fields (adding a clinic location via the settings page) and confirmed both the API
  call and the page's post-submission re-render show the new location — then deleted all test
  data. `pnpm typecheck`, `pnpm build` (every route), and `pnpm test:unit` (40/40) all clean.
  With this, every screen in `app/dashboard/:orgId/*` uses the current design system except the
  separate `/admin` super-admin console, which remains an explicitly out-of-scope, separate piece
  of work.

## ADR-018: Admin console migrated to the same design system — the one piece ADR-017 left out, plus one deliberate exception

- **Context.** ADR-017 named the `/admin` super-admin console (platform-owner only, not clinic
  staff) as the one remaining screen still on the old inline-style kit. The user asked to
  continue, so this pass covers it: `admin/layout.tsx`, `admin/page.tsx` (platform overview),
  `admin/organizations/page.tsx` (clinic list), `admin/organizations/:orgId/page.tsx` (clinic
  detail), `admin/verification/page.tsx`, `admin/audit/page.tsx`.
- **Decision 1 — the shell reuses the exact same `MobileNavProvider`/`MobileNavAside`/
  `MobileNavButton` components ADR-016 built for the org dashboard, not a parallel admin-specific
  shell.** Same mobile-drawer behavior, same icon-nav pattern (`navIconFor`, extended with two new
  label mappings — "Clinics" → `BuildingIcon`, "Verification" → `CheckIcon`). No notification
  bell here — there's no superadmin-relevant notification event defined anywhere in the system, so
  adding one would be inventing a feature, not reusing an existing one. The admin topbar is
  otherwise minimal (just the mobile menu button and a title on narrow screens); it doesn't need
  the org dashboard's search bar either, since nothing on these pages is fielded to search yet.
- **Decision 2 — the audit log stayed a real `<table>`, not a card-row list.** Every other list in
  ADR-017 became a card-row list (`InitialsAvatar` + name/sub + trailing badge), but a 150-row
  audit trail is genuinely tabular data meant to be scanned like a log, not a list of entities —
  forcing it into the card pattern would make it harder to read, not more modern. Restyled with
  current tokens (rounded card container, `Badge` for the action column, tabular alignment) rather
  than reused as-is from the old kit.
- **Decision 3 — `Badge`'s old `"muted"` tone (used throughout the pre-migration admin pages)
  doesn't exist in the new kit; every occurrence became `"neutral"`,** the new kit's equivalent
  (same visual role — a plain, low-emphasis tone for "not verified"/"draft"/"not listed" states).
- **Consequences.** No schema/API changes. Verified live against the real database with a real
  superadmin session: rendered all four admin pages, created a real clinic and confirmed it
  appears correctly in the organizations list, the clinic detail page, and the audit log; then
  exercised a real mutation through the actual API the detail page's "Suspend this clinic" button
  calls and confirmed the page's badge/button state updates correctly on re-render — then deleted
  all test data. `pnpm typecheck`, `pnpm build` (every route), and `pnpm test:unit` (40/40) all
  clean. This closes the visual migration entirely — every screen in the app, clinic-side and
  platform-admin-side, now uses the current design system.
