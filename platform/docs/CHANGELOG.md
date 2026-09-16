# DoseWise Platform — Changelog

Dated log of what actually shipped, newest first. Each entry says what changed, why, and what
was verified. See [DECISIONS.md](DECISIONS.md) for the reasoning behind non-obvious choices, and
[STATUS.md](STATUS.md) for the current plain-English state.

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
