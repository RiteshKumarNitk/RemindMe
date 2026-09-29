# DASHBOARD_AUDIT.md — Phase 1 (read-only audit)

Scope: the "Complete Dashboard UI/UX + Clinic Directory + Appointment Management" request.
Method: read schema, services, web app, and Flutter app; no code was modified for this document.
Prior work it builds on (not repeated): `docs/UI_AUDIT.md` and commit `77757a8` (design system,
states, a11y, destructive-action confirms, discovery cards, skeletons).

---

## 1. Data model as it exists (schema.prisma — source of truth)

**Organization** (public-profile fields already in place, all optional/defaulted):
`name, slug, timezone, isActive (superadmin suspend switch), orgType, tagline, about, logoUrl,
coverImageUrl, publicPhone, publicEmail, website, verificationStatus, isPubliclyListed`.

**OrganizationVerificationStatus enum**: `DRAFT → PENDING_VERIFICATION → VERIFIED | REJECTED`.
There is deliberately **no `READY` enum value** — "ready" is a *readiness predicate*
(`canPublishOrganization` in `src/modules/clinics/publish.ts`), not a stored state. Listing is the
independent boolean `isPubliclyListed`. Verified ≠ listed; listed ≠ verified. See §5 below.

**ClinicLocation**: `name, addressLine1/2, city, state, postalCode, country, phone, timezone,
isActive`. Multi-location is real (`Organization 1—N ClinicLocation`).

**DoctorProfile** (per org, linked to a User via Membership): `displayName, specialty,
registrationNumber, bio, consultationDurationMin, isAcceptingNewPatients, isActive` + public
fields `photoUrl, qualifications, yearsOfExperience, languages[], consultationFeeMinor,
isPubliclyListed` (independent of the org's listing flag).

**Appointment** — full ownership chain is already enforced by FKs:
`organizationId → locationId? → doctorId → patientId`, plus `appointmentTypeId?`,
`scheduledStart/End (timestamptz)`, `timezone` snapshot, `status` (9-state machine),
`bookingSource`, reschedule lineage (`rescheduledFromId`), `AppointmentEvent` history,
`QueueEntry?`, `Consultation?`. Double-booking is blocked by a Postgres EXCLUDE constraint
scoped `(organizationId, doctorId, time-range)`.

**Availability**: `AvailabilityRule` (weekday, start/end minute, slotMinutes, effective range,
optional `locationId`) + `AvailabilityException` (DAY_OFF/HOLIDAY/LEAVE/BREAK/EXTRA_HOURS).
Availability is **doctor-level**, optionally per location. There is **no location-level
"operating hours" model** — the spec's "operating hours if supported" is therefore *not
supported* at location level and must not be fabricated.

**AppointmentType** (per org): `name, durationMinutes, colorHex, isActive`.

**RBAC**: `Role` = PATIENT/DOCTOR/RECEPTIONIST/CLINIC_ADMIN/SUPER_ADMIN. `Membership.capabilities`
= `CLINICAL_RECORD_READ/WRITE, BILLING_MANAGE, DATA_EXPORT` — empty by default; a role never
implies clinical access (consultations additionally require assignment-or-capability in
`consultations/service.ts`). `resolveOrgContext` only accepts ACTIVE memberships in ACTIVE orgs;
`tenantDb` scopes every tenant query; `requireOrgContext` 404s non-members (no leak).
Queue: START/COMPLETE assigned-doctor-only; CALL/RECALL/SKIP staff-only.

**ClinicSettings**: `allowPatientSelfBooking, bookingLeadTimeMinutes, cancellationWindowHours,
maxAdvanceBookingDays, defaultAppointmentDurationMin` — enforced inside the booking transaction.

Fields the spec mentions that **do not exist** and will NOT be invented: legal/business name,
year established, secondary/emergency phone, location coordinates, location operating hours,
ratings/reviews, distance. (Spec §11/§12/§16 explicitly forbids fabrication.)

## 2. Backend services as they exist (all reused, none rewritten)

- `modules/tenancy`: `createOrganization` (org + settings + CLINIC_ADMIN membership + optional
  first location, one transaction, audited).
- `modules/clinics`: get/update org profile, `publishOrganization`/`unpublishOrganization`
  (readiness-gated), `requestVerification` (same gate, DRAFT/REJECTED only), settings
  get/update, **locations: list + create only** (no update/deactivate path yet — gap, see §7),
  members invite/update/remove, `setMemberCapabilities` (no self-grant of clinical caps).
- `modules/appointments`: book (policy + availability + family-grant checks + reminders, all in
  a serializable transaction, audited, notifies patient+doctor), list/get (patient rows filtered
  to own + VIEW_APPOINTMENTS dependents), confirm/check-in (creates QueueEntry + token)/no-show/
  start/complete/cancel (window-enforced for patients)/reschedule (new row + lineage).
- `modules/availability`: `computeSlots` (windows − exceptions − booked − lead time) and
  `assertWithinAvailability` — the single slot engine used by staff booking, patient
  self-booking, web and the public slots endpoint.
- `modules/patient-booking`: public slots (synthetic ctx, published orgs only) +
  `selfBookAppointment` (idempotent PATIENT membership + Patient upsert → `bookAppointment`).
- `modules/public`: strict allowlist selects; orgs require `isActive && isPubliclyListed`;
  doctors additionally require their org listed. Search by q/city/orgType (orgs) and
  q/specialty/organizationSlug (doctors). Detail select includes locations (address+phone) and
  public doctor summaries. **Not exposed:** appointment types, availability hours, services.
- `modules/superadmin`: list orgs (filters incl. verification=pending), org detail, suspend/
  reactivate, `setOrganizationVerification` (only from PENDING), platform audit list,
  `platformStats` (5 counters today).

## 3. Web app as it exists

- Design system `src/components/ui/*`: Button/LinkButton, Card, Badge, Field/Input/Select/
  Textarea, EmptyState/ErrorState/Notice/Skeleton, SearchBar, Hero kit, StatTile,
  InitialsAvatar, status map, ConfirmSubmit, discovery cards (HospitalCard/DoctorCard/
  HospitalDoctorCard/VerificationBadge). Legacy kit `app/dashboard/ui.tsx` remains only on
  /dashboard, /dashboard/new and fallback views.
- `/dashboard` = org picker. `/dashboard/new` = a **3-field form** (name/slug/timezone) →
  redirect to /profile. No guided flow, no progress (gap for Phase 7).
- `/dashboard/[orgId]` dispatches per-role overview components (Patient/Doctor/Reception/
  Admin) — all already on the shared kit with Hero/StatTile. Gaps vs spec:
  - **AdminOverview**: no "attention required" section, no profile-completion meter, no
    per-doctor appointment breakdown, no locations/verification alerting. It shows 8 stat
    tiles (spec §29 warns against exactly this).
  - **ReceptionOverview**: missing Completed-today count and token numbers in Up-next; no
    inline check-in.
  - **DoctorOverview**: closest to spec already (current consultation / next patient hero,
    waiting count, today's schedule). Minor polish only.
  - **PatientOverview**: good next-appointment hero; missing "Today's medicines / next dose"
    (data exists: MedicationDose) and a discovery entry point beyond the empty-state CTA.
- `/dashboard/[orgId]/profile`: org profile edit + publish gate + verification cards + a
  *static* preview card. Spec §13/§31 wants a real preview of the public page.
- `/dashboard/[orgId]/settings`: booking rules + locations (name/city only — address fields
  uncollected) + appointment types (add-only).
- `/dashboard/[orgId]/appointments`: list + inline role-gated actions + BookForm
  (doctor chips → date chips → live slots via `/api/orgs/:id/doctors/:id/slots`).
  **No appointment-type or location picker** (defaults used; backend supports both).
- Appointment detail: status-gated actions per role; shows patient/doctor/time/token/history;
  **does not show location or appointment type** (not in the `getAppointment` include).
- Public: `/hospitals`, `/hospitals/[slug]`, `/doctors`, `/doctors/[doctorId]` (+book flow:
  date chips → slots → details form → `selfBookAppointment` → redirect to appointment detail).
  No unified cross-type search page (§18); hospital detail shows locations/doctors/contact —
  no operating hours (correctly, none exist).
- `/admin`: 6 stat tiles only. Pending-verification queue exists at `/admin/verification`
  (approve/reject actions); orgs list + detail; audit page. Spec §9 wants a denser overview
  (verification counts, recent orgs, audit activity, appointments today/month).

## 4. Flutter app as it exists (12 files under lib/features/healthcare)

- `HealthcareRepository`: searchOrganizations (q/city/orgType/page), organizationBySlug,
  searchDoctors, doctorById, doctorAvailability — all unauthenticated public endpoints,
  5-min detail cache. `AppointmentRepository`: myOrganizations → per-org appointments merged
  + sorted, appointment detail (queue token), book (via `/patient/appointments`), cancel
  (reason), reschedule (SlotPicker with `reschedule:`), location labels resolved from the
  clinic's public profile.
- Screens: HealthcareHomeScreen (search + type chips + city filter sheet + org cards +
  pagination), OrganizationProfileScreen (logo/verified/type/about/locations/doctors), Doctor
  profile, SlotPicker (14-day chips → real slots only), Booking (sign-in gate, prefilled
  details, confirmation), BookingConfirmation, AppointmentDetail (token, cancel-with-reason,
  reschedule), AppointmentsScreen (upcoming/past/cancelled), PlatformSignIn.
- Gaps vs spec: directory has **no doctors-search surface** (repo method exists, unused in
  home); **no appointment-type step** (endpoint supports `appointmentTypeId`; types are not
  in the public org payload yet); booking passes `branch` but the org profile's location →
  booking link needs verifying during Phase 11.
- Flutter already consumes the SAME public APIs and creates the SAME backend appointments
  (verified: booking → `/patient/appointments` → `bookAppointment`). No second database
  anywhere. §37/§43 are satisfied architecturally.

## 5. Listing lifecycle (spec §15) — mapping without a second state machine

UI-level *composed* lifecycle label derived from existing fields
(`verificationStatus`, `isPubliclyListed`, `canPublishOrganization`):

| Composition                                   | Label shown            |
|-----------------------------------------------|------------------------|
| DRAFT + !ready                                | Draft — incomplete     |
| DRAFT + ready + !listed                       | Ready to publish       |
| PENDING_VERIFICATION                          | Pending verification   |
| VERIFIED + !listed                            | Verified — not listed  |
| VERIFIED + listed                             | Published              |
| REJECTED                                      | Rejected — fix & resubmit |
| isActive=false                                | Suspended (superadmin) |

A pure helper (`listingLifecycle`) will live next to `status.tsx`'s map so every surface
(dashboard, profile, admin) renders the same vocabulary. No DB change; publish/unpublish/
request-verification endpoints unchanged.

## 6. Profile completeness (spec §14) — honest, field-driven

New pure module `src/modules/clinics/completeness.ts` (mirrors `publish.ts` style, unit-testable):
weighted checklist over **real** fields: name (base), orgType, tagline/about, publicPhone/
publicEmail, website, logoUrl, coverImageUrl, ≥1 active location **with address+city**,
≥1 publicly-listed doctor, ≥1 appointment type, verification status. Output: `{ percent,
missing: [{key,label,href}] }`. Consumed by AdminOverview, /profile, onboarding checklist.
No arbitrary percentages — each item documented with its weight.

## 7. Gaps that require NEW (additive) backend surface — kept minimal

1. **Location update** service + dashboard action (schema already has the fields; only
   create exists today). Needed for location data quality (§12/§41).
2. **`completeness.ts`** (pure, §6 above) + availability-coverage query ("N active doctors
   have no active availability rules") for the attention section (§7).
3. **`platformStats` extension**: add verification counters, appointments-today/-month,
   patients/doctors counts (additive selects; page wiring in Phase 3/9 of this request).
4. **Public org detail: include active appointment types** (`id/name/durationMinutes` only,
   public-safe) so both web and Flutter can offer the spec'd "Appointment Type" step.
   Booking endpoints already accept `appointmentTypeId`.
5. **`getAppointment` include**: location + appointment type (display only, Phase 12).
6. **Unified search** (`/search`): composes existing `listPublicOrganizations` +
   `listPublicDoctors` (no new queries).

Everything else in the spec is achievable by re-composing existing services.

## 8. Phase-by-phase plan (implementation order per spec §44)

- **P2 Design system**: add `listingLifecycle`, `completeness` + `CompletionMeter`,
  `AttentionList`, `Stepper` (onboarding) to the shared kit; no duplicates of existing parts.
- **P3 Owner dashboard**: rebuild AdminOverview → verification/listing hero band + completion
  meter + attention list (incomplete profile, unverified, doctors w/o availability, no
  appointment types, location gaps) + per-doctor today counts + today stats + recent schedule.
- **P4 Reception**: add Completed-today, token numbers in Up-next, inline Check-in on the
  next rows, keep existing queue untouched.
- **P5 Doctor**: polish only (labels, current-consultation emphasis) — already near-spec.
- **P6 Patient**: add Today's medicines strip (next dose + done count) from MedicationDose;
  add Find-healthcare CTA card; keep priority order §4.
- **P7 Onboarding**: /dashboard/new becomes step 1 of a guided flow (basics + first location,
  org created immediately → progress is real data, nothing to lose); new
  `/dashboard/[orgId]/setup` checklist page (completion meter + per-task links +
  request-verification/publish at the end); location editing added; dark-launch nothing.
- **P8 Directory**: unified `/search` (grouped Doctors / Clinics); hospital/doctor pages keep
  existing cards; only-real-data rule enforced (no ratings/distance fabrication).
- **P9 Booking (web)**: appointment-type picker (from new public types payload) + location
  line on review; pass `appointmentTypeId`/`locationId` through the existing action.
- **P10 Flutter directory**: Doctors tab in Find Healthcare using `searchDoctors`; l10n via arb.
- **P11 Flutter booking**: appointment-type step (types from org detail), slot refetch with
  type; ensure branch selection flows into booking.
- **P12 Appointment mgmt**: detail shows org/location/type; owner per-doctor breakdown links;
  verify RBAC matrix unchanged (backend is the authority); audit trail already written by
  services — no changes.
- **P13 QA**: platform unit tests + tsc + next build; flutter analyze + flutter test; then
  drive the 31-step acceptance scenario (§45) end-to-end on the dev server, including the
  cross-tenant negative check (Clinic B user → Clinic A appointment ⇒ 404).

## 9. Risks / guardrails

- Dev DB is shared — QA writes go to the dev database (demo seed exists there); use clearly
  named QA entities and clean up created rows where feasible.
- Public selects: any new public payload addition must extend the named allowlist constants
  only — never widen to full models.
- Do not touch: auth/Google/guest, multi-tenancy, EXCLUDE constraint, queue state machine,
  consultation/prescription flows, family grants, notification dispatch, audit writes,
  Flutter offline medicine sync.
- Flutter: no restructure of the 4-tab nav; no `dart format`; keep `flutter analyze` at 0
  errors / the 5 known infos.
