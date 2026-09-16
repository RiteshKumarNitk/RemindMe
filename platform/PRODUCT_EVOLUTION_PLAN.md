# DoseWise Platform — Product Evolution Plan

**Audited against actual code, 2026-09-16.** This is a plan for evolving a working, tested
clinic-operations backend into a real two-sided healthcare product (public patient discovery +
booking, on top of the existing operational core). It does not propose rewriting anything that
already works — see §3/§4 for exactly what's missing versus what's already solid.

---

## 1. Current product capabilities

Everything below is implemented, tested, and working today:

- **Auth**: argon2id passwords, JWT access + rotating refresh tokens (reuse detection), Google
  OAuth, session cookies (web) + bearer tokens (native), a sandboxed guest mode.
- **Multi-tenancy**: one `User` identity can hold independent roles across multiple
  `Organization`s via `Membership`; tenant scope is enforced by a Prisma extension
  (`tenantDb()`) that force-scopes every query and throws on any cross-tenant attempt.
- **RBAC**: 5 roles (`PATIENT`/`DOCTOR`/`RECEPTIONIST`/`CLINIC_ADMIN`/`SUPER_ADMIN`) +
  4 fine-grained capabilities; role ≠ clinical access is a hard rule (no role, including admin,
  gets clinical-record access by default; no self-granting).
- **Clinic operations**: locations, doctors, staff, appointment types, recurring availability +
  exceptions, real slot computation, SERIALIZABLE-transaction booking with a DB-level
  double-booking `EXCLUDE` constraint, a 6-state appointment lifecycle, a 5-state front-desk
  queue with token allocation, SOAP-note consultations, prescriptions, patient records, a family/
  guardian access-grant system (partially wired — see §4), audit logging, and a notification
  dispatcher (now actually scheduled in production, see `STATUS.md`).
- **Superadmin console**: cross-tenant organization list/search, suspend/reactivate, audit feed,
  platform stats.
- **Web app**: every one of the above has a working (plain-styled) screen — dashboards for each
  role, a settings area, a queue board, a consultation editor. None of it is a placeholder stub.

## 2. Current web pages

| Page | State |
|---|---|
| `/` (homepage) | **Backend status page** — lists shipped API modules, links to `/api/health`. Explicitly says "no screens of its own yet beyond this." Not a marketing/discovery page. |
| `/login`, `/register` | Functional, minimal. |
| `/dashboard`, `/dashboard/new` | List my clinics / create a clinic. Functional. |
| `/dashboard/:orgId` (+ doctors/staff/team/settings/queue/appointments/patients/family/audit) | Full role-gated CRUD dashboards, all functional, all inline-styled. |
| `/dashboard/:orgId/appointments/:id/consultation` | Most-developed clinical screen — SOAP + prescription + sign flow. |
| `/admin`, `/admin/organizations(/:id)`, `/admin/audit` | Superadmin console, functional. |

**There is no public page anywhere** — no hospital list, no doctor list, no doctor/organization
profile, no booking flow reachable without already being a member of a clinic.

## 3. Current backend capabilities

Confirmed from the actual route table and service modules (12 modules, `src/modules/*`):
auth · tenancy · clinics (org/locations/settings/members) · doctors · staff · patients · family
(access grants) · availability (slot computation) · appointments (full lifecycle) · queue ·
consultations · prescriptions · audit · superadmin. Every route except `/api/health` and
`/api/auth/*` requires a session and an org membership resolved from the `:orgId` path segment —
**by design**, per `MULTI_TENANCY.md` (no `X-Org-Id` header, `organizationId` never trusted from
the client). This is correct for the operational side and is exactly what has to be selectively
opened up for public discovery, carefully, in §5.

## 4. Missing product capabilities

- **Public discovery** — no way for anyone to browse clinics or doctors without logging in.
- **Public organization/doctor profiles** — `Organization` has no branding/contact/about fields
  at all (just `name`/`slug`/`timezone`); `DoctorProfile` has no photo, qualifications,
  years-of-experience, languages, or consultation fee.
- **Patient-initiated booking from public discovery** — today, booking only happens from inside
  an authenticated clinic dashboard (staff-initiated). There's no "patient finds a doctor and
  books themselves from outside the org" flow.
- **Dependent/family booking** — `PatientAccessGrant` exists and `VIEW_PROFILE`/
  `VIEW_MEDICATIONS` are wired in, but **`VIEW_APPOINTMENTS`/`MANAGE_APPOINTMENTS` are not wired
  into the appointments module** (confirmed in current code, matching the earlier roadmap note).
  A guardian can't yet book or view a dependent's appointment through a grant.
- **Verification status** — no such concept exists on `Organization` or `DoctorProfile` at all.
- **Organization/doctor onboarding wizards** — org creation today is a single form
  (`/dashboard/new`); there's no multi-step "profile → locations → services → doctors → publish"
  flow, and no equivalent for a doctor completing their own professional profile.
- **Design system** — no Tailwind config, no token/variant system; a small, consistent-but-thin
  `app/dashboard/ui.tsx` kit is the only shared UI code today.

## 5. Missing APIs

All net-new (the existing route table has zero overlap with these):

- `GET /api/public/organizations` — search/filter (city, specialty, org type), paginated,
  returns only public fields.
- `GET /api/public/organizations/:slug` — public profile (about, locations, specialties,
  services, doctors list).
- `GET /api/public/doctors` — search/filter (name, specialty, city, language).
- `GET /api/public/doctors/:id` — public profile.
- `GET /api/public/doctors/:id/slots` — **reuses the existing `availability` module's
  `computeSlots` directly** — same authoritative slot math, exposed on a public, rate-limited,
  read-only route. No new booking-math code.
- `POST /api/public/appointments` (or an authenticated-patient equivalent) — patient-initiated
  booking, calling the *existing* `appointments.book()` service function — not a parallel
  booking path.
- `GET /api/me/appointments`, `GET /api/me/appointments/:id` — a patient's own appointment list/
  detail (today, appointment reads are all staff/clinic-scoped).
- Family-scoped equivalents of the above once `VIEW_APPOINTMENTS`/`MANAGE_APPOINTMENTS` are
  wired (§4).

Every one of these is a **read/write wrapper around existing service functions**, never new
booking/availability/tenant-isolation logic — that logic is already correct and tested and must
not be duplicated.

## 6. Missing database fields/models

Additive only, no destructive changes to any existing table:

- **`Organization`**: `description`/`about`, `logoUrl`, `coverImageUrl`, `orgType` (enum:
  HOSPITAL/CLINIC/DIAGNOSTIC_CENTER/POLYCLINIC/...), `publicPhone`, `publicEmail`, `website`,
  `verificationStatus` (enum: DRAFT/PENDING_VERIFICATION/VERIFIED/REJECTED/SUSPENDED, default
  DRAFT), `isPubliclyListed` (bool, default false — an org must opt in before appearing in
  discovery). Address stays on `ClinicLocation` as-is (a multi-location org has no single
  address).
- **`DoctorProfile`**: `photoUrl`, `qualifications` (string, or a small `DoctorQualification[]`
  relation if structure is wanted), `yearsOfExperience` (int), `languages` (string[]),
  `consultationFeeMinor` (int, currency-minor-units — nullable, not every clinic charges the same
  way), `isPubliclyListed` (bool, default false, independent of the org's own flag).
- **`ClinicLocation`**: `isPubliclyVisible` (bool) if a clinic wants some locations public and
  others not.
- **`Specialty`** (new, simple lookup table) and a `DoctorProfile ↔ Specialty` join, or — cheaper
  — promote `DoctorProfile.specialty` (currently freeform text) to reference a small seeded
  enum/table so discovery can actually filter by specialty reliably. Recommend the lookup-table
  approach since freeform text can't be filtered consistently.

None of this touches `Appointment`, `Queue`, `Consultation`, `Prescription`, or the tenancy/RBAC
tables — the clinical/operational core is untouched.

## 7. Patient journey

```
Discover (public, no login)
  → Search / browse hospitals or doctors
  → View hospital profile → its doctors
  → View doctor profile → real availability
Book (login required at this step, not before)
  → Pick a slot → pick self or a dependent → review → confirm
Manage
  → See upcoming/past appointments → cancel/reschedule
Visit
  → Check-in (staff-driven today; a patient-facing check-in confirmation screen is a nice-to-have,
    not required for MVP) → queue position visible → consultation happens (staff-side) →
    prescription visible to patient afterward
```

## 8. Doctor journey

```
Existing: staff-added DoctorProfile inside a clinic dashboard (unchanged, still the entry point —
clinics add their own doctors, doctors don't self-register into a random clinic)
  + NEW: doctor completes/edits their own public profile (photo, bio, qualifications,
    experience, languages) — reuses the existing DoctorProfile row, adds fields only
Daily use (already built, just needs a "what's next" landing instead of generic nav):
  Dashboard → today's appointments → next patient → start consultation → SOAP → prescription →
  sign → complete
```

## 9. Receptionist journey

Already fully built (queue board, check-in, call/recall/skip/complete, booking form) — this
phase's work here is presentation only: a faster booking entry point and clearer "what's next"
framing, not new backend capability.

## 10. Clinic/Hospital admin journey

```
Existing: create org → add locations/doctors/staff/appointment types/settings (all functional
today via /dashboard/new + /dashboard/:orgId/*)
  + NEW: a guided onboarding sequence over the same forms (basic info → profile/branding →
    locations → services/specialties → doctors → review → publish) instead of a single blank
    form, ending in a "how patients will see you" preview
  + NEW: a publish/verification toggle (isPubliclyListed) gated on required fields being filled
```

## 11. Platform/Super Admin journey

Already fully built (organization list/search/suspend/reactivate, cross-tenant audit, platform
stats). Adds one new concern once verification exists (§6): a verification review queue
(approve/reject a clinic's `PENDING_VERIFICATION` → `VERIFIED`), mirroring the existing
suspend/reactivate action pattern — not a new subsystem.

## 12. Information architecture

```
PATIENT               DOCTOR                  RECEPTIONIST          CLINIC ADMIN            SUPER ADMIN
Home                  Dashboard               Dashboard             Overview                Platform Dashboard
Find Doctors          Today's Appointments    Appointments          Appointments             Organizations
Find Hospitals        Patients                Patients              Doctors                  Users (future)
Appointments          Queue                   Queue                 Staff                    Audit
Family                Calendar (future)       Doctors                Patients                Verification (future)
Medicines (Flutter)   Consultations           Calendar (future)     Queue                    Platform Settings (future)
Profile               Prescriptions           —                     Services (future)
                      Availability                                  Locations
                      Profile                                       Availability
                                                                     Reports (future)
                                                                     Settings
                                                                     Audit
```

## 13. Navigation structure

- **Public site** (new): a thin marketing/discovery shell — homepage, `/hospitals`,
  `/hospitals/[slug]`, `/doctors`, `/doctors/[id]` — no clinic-role nav at all, just
  search + a login/signup entry point.
- **Authenticated app**: unchanged structure (`/dashboard/:orgId/...`), nav items filtered by
  role exactly as today — this plan adds pages under existing role sections, it doesn't
  restructure the existing nav.
- **Superadmin**: unchanged (`/admin/...`), plus a Verification entry once §6 lands.

## 14. Design-system plan

Current state (§12 of the audit): no Tailwind, inline styles, a small shared `ui.tsx` primitive
set (`Card`, `Badge`, `Button`, `Field`, `Select`, `ErrorNote`, `EmptyState`). This is a real gap
for a public-facing product but the existing dashboard pages work today and must not be broken
mid-migration.

**Plan**: introduce Tailwind + a token layer (`app/globals.css` `@theme`, indigo/coral palette
already established — keep it, formalize it) as the foundation for **new** public-facing pages
only, first. Do not do a big-bang rewrite of the existing dashboard pages' inline styles in the
same pass — that's a separate, lower-risk mechanical migration once the new pages prove the token
set. New shared components needed: doctor card, hospital card, appointment card, time-slot
picker, a search bar, empty/error/skeleton states matching the new token set. The existing
`ui.tsx` kit's components (`Card`/`Badge`/`Button`/etc.) get ported to the new token system
incrementally, page by page, not deleted and replaced in one commit.

## 15. Implementation phases

1. **This document** — done.
2. **Design-system foundation** — Tailwind + tokens + the handful of new shared components
   listed above. No schema/API changes. *(Starting this now, see below.)*
3. **Org onboarding wizard + profile fields** — schema additions from §6 (Organization only),
   guided multi-step form over existing `clinics` service functions, publish toggle.
4. **Doctor profile fields + self-editing** — schema additions from §6 (DoctorProfile only),
   profile edit screen.
5. **Public discovery** — homepage rebuild, `/hospitals`, `/hospitals/[slug]`, `/doctors`,
   `/doctors/[id]`, backed by the new `/api/public/*` routes (§5), each a thin wrapper over
   existing service reads with a public-field projection.
6. **Patient booking from discovery** — `/api/public/doctors/:id/slots` (wraps
   `computeSlots`) + `POST /api/public/appointments` (wraps `appointments.book()`), login gate
   only at the confirm step, full error handling for slot-taken/expired/conflict.
7. **Patient dashboard** — upcoming appointment, history, cancel/reschedule, using `GET
   /api/me/appointments*` (new, thin wrapper).
8. **Doctor workspace polish** — "what's next" landing reorganization of already-built pages;
   no new backend.
9. **Reception workspace polish** — same, presentation-only.
10. **Admin workspace polish + verification queue** — verification review UI once §6's
    `verificationStatus` field exists; reuses the existing suspend/reactivate action pattern.
11. **Dependent/family booking** — wire `VIEW_APPOINTMENTS`/`MANAGE_APPOINTMENTS` into the
    appointments module (the one place this plan touches the SERIALIZABLE booking path — done
    last, deliberately, and only with its own dedicated tests, per the existing family module's
    own documented caution about not touching booking logic casually).
12. **Responsive + accessibility pass** across everything built in 2–11.
13. **Security + regression pass** — full existing test suite must stay green throughout every
    phase above, not just at the end; new tests added per phase (see §21 of the original brief).

## 16. Dependencies between phases

- Phase 2 (design system) blocks every visual phase after it (5–10) — built first, deliberately.
- Phase 3 (org profile fields) and Phase 4 (doctor profile fields) are independent of each other
  and can run in parallel, but **both block Phase 5** (discovery needs real profile data to show).
- Phase 5 (discovery) blocks Phase 6 (booking needs a doctor to have been discovered/selected).
- Phase 6 blocks Phase 7 (a patient dashboard is only useful once patients can create bookings
  through it).
- Phase 11 (dependent booking) is deliberately isolated at the end — it's the only phase that
  touches the SERIALIZABLE booking transaction, and per the existing family module's own
  documented policy, that path only gets touched with dedicated test coverage, not as a
  side-effect of an unrelated UI phase.
- Phases 8–10 (workspace polish) have no dependency on 3–7 at all and could be pulled forward if
  wanted — they're presentation-only reorganizations of already-working, already-tested backend
  capability.

---

## Immediate next step

Starting **Phase 2** now: Tailwind + design tokens + the first batch of shared components, scoped
to not touch any existing page's rendering. Each subsequent phase will get its own verification
(typecheck + build + existing test suite green) before moving to the next, the same way every
other piece of work on this project has been done this session — not a single giant unreviewed
change spanning all 13 phases at once.
