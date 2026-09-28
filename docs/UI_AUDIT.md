# DoseWise — UI/UX Audit (Phase UI-1)

Read-only audit performed before any code changes. Inventory of what exists, what is
inconsistent, and what needs work, per the UI-1 contract. Findings feed phases UI-2…UI-10.

---

## 1. Web platform inventory

### Route tree (`platform/app/**`)
| Area | Routes |
| --- | --- |
| Public | `/`, `/hospitals`, `/hospitals/[slug]`, `/doctors`, `/doctors/[doctorId]`, `/doctors/[doctorId]/book`, `/login`, `/register`, `/status` |
| Org picker | `/dashboard`, `/dashboard/new` |
| Patient | `/dashboard/[orgId]` (PatientOverview), `/appointments`, `/appointments/[id]`, `/appointments/[id]/reschedule`, `/family` |
| Reception | Overview (ReceptionOverview), `/patients`, `/appointments`, `/queue` |
| Doctor | Overview (DoctorOverview), `/appointments`, `/queue`, `/doctors/[id]/availability`, `/doctors/[id]/profile`, consultation page |
| Clinic admin | Overview (AdminOverview), `/profile`, `/doctors`, `/staff`, `/team`, `/settings`, `/audit` |
| Super admin | `/admin`, `/admin/organizations`, `/admin/organizations/[orgId]`, `/admin/verification`, `/admin/audit` |

### Design systems in the repo (two generations + one straggler)
1. **Token system (target)** — `app/globals.css` (`:root` vars + Tailwind v4 `@theme`) and
   `src/components/ui/*`: `Button`/`LinkButton` (primary/secondary/ghost/danger/light/glass),
   `Card`/`CardTitle`/`CardSubtitle`, `Badge` (neutral/ok/down/indigo/warn/coral/glass),
   `Field`/`Input`/`Select`/`Textarea`, `EmptyState`/`ErrorState`/`Notice`/`Skeleton`,
   `SearchBar`, `Hero` kit, `StatTile`, `InitialsAvatar`. Global `:focus-visible` ring,
   `.sr-only`, skip link, `.table-scroll`. Used by all public, dashboard and admin pages.
2. **Legacy inline-style kit** — `app/dashboard/ui.tsx` (own Card/Badge/Button/Field/Select/
   ErrorNote/EmptyState/table). Still used by: `/login`, `/register`, `/dashboard`,
   `/dashboard/new`, and the fallback stats grid in `/dashboard/[orgId]`.
3. **`/status` page** — fully hand-rolled inline styles (third visual voice).

Fonts: Sora (display), IBM Plex Sans/Mono via `next/font`, opt-in utilities. Light theme only,
deliberately (`color-scheme: light`) — per spec §46, no dark mode to introduce or audit.

### Real defects found (web)
- **`--ink-faint` is used but never defined.** `text-ink-faint` appears in 26 places
  (StatTile, Hero `SideStat`, queue "Now serving", all overviews, BookForm, admin lists,
  audit tables, family/patients lists, dashboard header). `@theme` has no
  `--color-ink-faint`, so the utility never generates and those elements inherit full-ink
  color — the intended faint text hierarchy silently does not exist.
- **No destructive-action confirmations.** Cancel appointment (list + detail), Remove team
  member, and Sign & complete (consultation, which locks the record) all submit instantly.
- **`Skeleton` and `ErrorState` components exist but are used nowhere**; there are no
  `loading.tsx`/`error.tsx`/`not-found.tsx` route files. `force-dynamic` pages show a blank
  wait and Next's default error screen on throw.
- **Status→badge tone maps are per-page and disagree.** `REQUESTED` is `coral` on the
  appointments list, `neutral` on the detail page, `neutral` in DoctorOverview;
  `IN_CONSULTATION` is `coral` on the list, `indigo` in DoctorOverview; CANCELLED is
  `neutral` in one map, `down` in another. Same status, different colors per page.
- **Pagination drops filters.** `/hospitals` pagination keeps `q` but loses `city`;
  `/doctors` keeps `q` but loses `specialty`.
- **Search inputs have no accessible name** (placeholder-only) on `/hospitals`, `/doctors`,
  `/patients`, and the dashboard header search is fine (has aria-label).
- **Date chips on the public doctor page are color-only selected state** (background swap,
  no `aria-pressed`/`aria-current`), unlike BookForm which does it correctly.
- **Buttons have no loading/pending feedback** for server actions (double-submit possible).
- **Field component has no error/invalid affordance** (`aria-invalid`, error text slot);
  form errors only appear via redirect `?error=` Notice.

### Public-experience gaps vs spec (§8–§15)
- Hospital/doctor cards: no verification indicator, no photo/avatar, no fee, no "Book"
  affordance — **all data already exists** in the public API selects (`verificationStatus`,
  `photoUrl`, `logoUrl`, `consultationFeeMinor`, `organization.name`).
- Hospital profile: `coverImageUrl`/`logoUrl` are fetched but never rendered; no identity
  header. Doctor profile: photo never rendered; fee badge exists; date chips lack a11y state.
- Booking: single review+details page (works, mobile-friendly). Spec's guided steps can be
  satisfied with a lightweight step indicator on the existing page rather than a wizard
  rewrite (booking mechanics are a server action over hidden inputs — preserve).
- Login/register: on the legacy kit; Google sign-in exists in the backend
  (`/api/auth/google/start`, `googleOAuthConfigured`) but has **no button on the login page**.
  No password confirm on register (acceptable, hint exists).
- Homepage: communicates the product and has search + both primary CTAs; no "Book
  appointment" entry, but `/doctors` IS the booking entry — acceptable; keep hero calm.
- `/status` page is an engineering page — fine, but visually its own thing; low priority.

### What is already good (do not touch)
PublicHeader, Hero dashboard kit, StatTile, InitialsAvatar, NotificationBell (polling,
aria-expanded, unread count in label), MobileNav (aria-expanded, closes on route change),
NavLink (`aria-current`), skip links, queue board (AutoRefresh, role-gated actions,
token prominence), Consultation page structure (SOAP + prescription + signed → disabled
inputs), empty states on essentially every list, `.table-scroll` on wide tables,
responsive shell collapse at 768px, contrast-paired badge text+tint (never color-only).

---

## 2. Flutter inventory

### Structure
- Tokens: `lib/core/theme/design_tokens.dart` — `AppSpacing` (4/8/12/16/20/24/32/40),
  `AppRadius` (10/14/18/24/pill + getters), `AppSizes` (button 60, field 60, tapTarget 52,
  navBar 76, icons 18/22/26/32, avatar 48, maxContentWidth 560), `AppMotion` (150/220/320),
  `AppPalette` ThemeExtension (success/warning/info containers, cardBorder, heroSurface,
  missed, accent). `app_theme.dart` styles `cardTheme` (cardRadius, 1px cardBorder, elevation 0).
- Component library (`lib/features/widgets/`): `AppButton` (primary/secondary/danger/quiet/
  onColor, busy, 60pt, elder-friendly), `AppIconButton`, `AppCard`, `AppDialogs`,
  `AppScaffold`, `EmptyState`/`ErrorState`/`SkeletonList`/`SkeletonBox`, `DoseStatusBadge`
  (icon + word + tint — never color-only), `AppPill`, `AppTimePicker`, `MedicineTile`,
  `ReminderCard`, `DoseListTile`, `AdherenceCard`.
- Nav (just redesigned + verified): 4 tabs Home · Medicines · History · Family; Settings from
  header avatar; Profile from Settings → Account group. Healthcare (`HomeCareSection`) embedded
  on Home.

### Healthcare screens (`lib/features/healthcare/`, 12 files)
- States: every screen has loading skeleton / error-with-retry / empty states via `Hc*`
  widgets (`HcSkeletonList`, `HcErrorView.fromException`, `HcEmptyView`) — good.
- Booking flow: slot → review+details → confirmation, signed-in gate, slot-taken recovery
  dialog, prefilled patient details, form validators — functionally strong.
- **Debt:** raw `EdgeInsets`/`SizedBox` throughout the 10 screens (44 raw EdgeInsets, 82 raw
  SizedBox heights — e.g. `fromLTRB(20, 8, 20, 40)` repeated) instead of `AppSpacing`;
  booking screen uses bare `FilledButton` + manual busy `CircularProgressIndicator` instead
  of `AppButton(busy:)`; `Hc*` widgets parallel the `app_*` library (deliberate: shared,
  already tokenized — keep, but screens should sit on tokens).

### Spec §29–§39 items — considered and decided
- **5-tab nav (add Appointments/Profile): rejected.** The elderly-focused 4-tab shell +
  Settings/Profile entry was just redesigned and verified (91/91 tests); Appointments is
  reachable from Home care section + healthcare app bar. Restructuring nav now would churn a
  fresh, tested design for marginal gain. Documented decision, not an oversight.
- Medicines: visual hierarchy already rebuilt around `MedicineTile`/`DoseStatusBadge`;
  no functional changes (alarm/snooze/skip/missed untouched).
- Family: permission-scoped actions already reflect backend grants.
- Queue: patient queue view exists in appointment detail (token/status); receptionist
  controls correctly absent.

### Known constraints
- Do **not** run `dart format` (63/107 lib files are pre-unformatted; would create a huge
  unrelated diff).
- Pre-existing lint infos to leave alone: 3× `pill_photo_service.dart` string interps;
  2× `use_build_context_synchronously` (adherence_report L263, family_sync L477).
- 91/91 tests green; `flutter analyze` 0 errors/0 warnings — keep both true.

---

## 3. Phase plan derived from this audit

- **UI-2 (foundation, web):** define `--ink-faint`; centralize status→tone/label mapping
  (`src/components/ui/status.ts`) used by every page; add `ConfirmSubmit` client component
  (native confirm dialog) for Cancel / Remove / Sign & complete; add root `error.tsx`,
  `not-found.tsx`, and `loading.tsx` skeletons for dashboard + public sections; `Field`
  gains error/invalid affordance; `SearchBar` gets an accessible name; add pending state to
  `Button` via a small client wrapper where a form submits.
- **UI-3 (public web):** org/doctor cards gain verification badge, avatar, fee, Book CTA from
  existing API fields; hospital profile identity header (logo/cover); doctor page date-chip
  a11y + photo; booking page step indicator; login page Google button (conditional on
  `googleOAuthConfigured`); pagination preserves filters; migrate login/register off the
  legacy kit.
- **UI-4 (patient web):** unify appointment list/detail statuses via shared map; empty-state
  actions (Book) on patient lists.
- **UI-5 (reception):** inherits UI-2 badges/confirms; queue page untouched (already good).
- **UI-6 (doctor):** consultation gets "Signed — record locked" banner + confirm on Sign &
  complete; dashboard hero copy fix ("Today's pace" placeholder sub).
- **UI-7 (clinic admin):** inherits UI-2; settings/doctors/staff/team/forms get Field errors
  + confirms.
- **UI-8 (super admin):** audit tables get the shared status/badge treatment; organization
  detail review actions get confirms.
- **UI-9 (Flutter):** tokenize the 10 healthcare screens' raw paddings onto `AppSpacing`;
  booking screen `FilledButton` → `AppButton(busy:)`; no nav/logic changes.
- **UI-10 (QA):** `pnpm build` + `flutter analyze` + `flutter test` (91), responsive spot
  checks 320/375/768/1280, final report per the required format.

## 4. Components to reuse (never duplicate)
Web: `src/components/ui/*` is the single system; delete-by-migration the legacy
`app/dashboard/ui.tsx` kit (login/register/dashboard/dashboard-new/fallback-stats) rather
than styling anything new with it. Flutter: `lib/features/widgets/*` + `Hc*` shared widgets
are the single system.

---

## 5. Outcome (post UI-2…UI-10)

### Web — changed
- **Tokens**: `--ink-faint` defined (was used in 26 places but never generated); semantic
  `statusLabel`/`statusTone` map (`src/components/ui/status.tsx`) — REQUESTED is now warn
  (attention), IN_CONSULTATION coral (active), CANCELLED/NO_SHOW down everywhere.
- **New components**: `ConfirmSubmit` (destructive-action confirm), discovery cards
  (`HospitalCard`/`DoctorCard`/`HospitalDoctorCard` + verification badge), `Field.error` +
  `invalid` input affordances, sized `InitialsAvatar`, booking step indicator.
- **States**: root `error.tsx` + `not-found.tsx`; dashboard/admin/hospitals/doctors
  `loading.tsx` skeletons.
- **Pages rebuilt on the shared system**: homepage, /hospitals, /doctors (filter-preserving
  pagination), hospital profile (identity header, verification, fee on doctor cards), doctor
  profile (a11y `aria-current` date chips), booking (steps, autofill attributes), login
  (Google button when `googleOAuthConfigured`, autocomplete) and register (migrated off the
  legacy `dashboard/ui.tsx` kit; `minLength={10}` aligned with the platform rule).
- **Destructive actions now confirm**: cancel appointment (list + detail), remove team
  member, suspend clinic, reject verification, Sign & complete consultation (+ "signed —
  record locked" banner). Consultation signed state shows disabled inputs as before.
- **Doctor overview**: fake "Today's pace" stat replaced with real Completed-today count.
- Patient overview empty state now offers "Find a doctor" action.

### Flutter — changed (visual only)
- 7 healthcare screens (home, org profile, doctor profile, slot picker, booking,
  booking confirmation, sign-in) + appointment list/detail re-tokenized onto `AppSpacing`/
  `AppRadius`/`AppSizes`; hardcoded success/warn colors on booking confirmation replaced with
  `AppPalette` containers; bare `FilledButton`s with manual spinners replaced by the shared
  `AppButton(busy:)`; booking gate CTA now uses `AppButton`.
- No navigation, state-machine, alarm, or repository changes; elderly 4-tab shell untouched
  (deliberate — see §2).

### Functionality preserved
- All booking/cancel/reschedule/queue/consultation flows submit the same server actions;
  only the confirm step and presentation changed. Family permission logic, RBAC, double-
  booking protection untouched. No fake data introduced — every newly displayed field
  (verification, fee, doctor count) already existed in the public API selects.

### Verification
- Web: `tsc --noEmit` clean; `next build` ✓ (all routes); live smoke: 200s on public routes,
  no horizontal overflow at 390px, `--ink-faint` resolves, 404 + empty states render, login
  fields expose proper labels/autocomplete.
- Flutter: `flutter analyze` 0 errors/0 warnings (only the 5 pre-existing infos);
  `flutter test` 91/91 pass.
- Known gaps: live visual review of dashboard/admin screens not performed (auth roles not
  exercised in this session); Google button renders only when OAuth env vars are set;
  demo seed clinic remains unlisted in the dev DB so directory grids render their empty
  states (correct behavior).
