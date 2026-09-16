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
