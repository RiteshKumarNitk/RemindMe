# DoseWise Platform — Status

**Last updated: 2026-09-18.** This file is updated every time a piece of work
finishes — it's meant to be shown to non-technical stakeholders as-is, no
translation needed. If something below looks stale, ask and it'll be
refreshed before you rely on it.

## What this is, in one line

A backend + web app that lets a clinic or hospital manage doctors, staff,
appointments, queues, and patient records — built to eventually plug into the
existing DoseWise medicine-reminder app.

## The two sides of the product

```
PATIENT SIDE                    HEALTHCARE SIDE
Find a doctor/clinic            Register a clinic
Book an appointment             Add doctors & staff
Manage my appointments          Set availability/hours
See my visit history            Run the daily queue
                                 See consultation notes & prescriptions
```

Everything below is organized against these two sides, plus the shared
foundation underneath both.

---

## ✅ Done and verified

| Area | What it means for the business |
|---|---|
| **A modern design, top to bottom, and real notifications** | Every reachable screen in the app — the four clinic role dashboards, appointments, patients, doctors, staff, settings, the queue board, consultation notes, reschedule, doctor availability, family access, team, both audit logs, and the separate platform-owner admin console — has been visually rebuilt with a consistent design (hero cards, stat tiles, colored patient avatars), plus a working notification bell that shows real events (appointment booked, cancelled, rescheduled, reminders) and can be marked as read. The appointment booking/reschedule screens are now a doctor/date/time picker with a live summary instead of a plain form. Verified live against the real, seeded demo clinic: a real booking creates a real notification, addressed to the right person, that clears when marked read; every migrated page renders with real data through the new design. |
| **Accounts & login** | Clinics and staff can register and log in securely (industry-standard password hashing, session handling). |
| **Multi-clinic isolation** | One clinic can never see another clinic's data — tested and enforced, not just assumed. |
| **Roles & permissions** | Admin / Doctor / Receptionist / Patient each see only what their role should — including a rule that no admin can grant themselves extra medical-record access (must be a second admin). |
| **Clinic setup** | A clinic admin can register their organization, add locations, add doctors and staff. |
| **Organization & doctor public profiles** | A clinic admin can fill in a real public-facing clinic profile (type, description, branding, contact info) and publish/unpublish it; each doctor can fill in their own professional profile (photo, qualifications, experience, languages, fee) and choose to be listed. |
| **Public hospital & doctor search** | Anyone — no login needed — can search for hospitals and doctors and view their public profiles at `dosewise.example/hospitals` and `/doctors`. Nothing shows up in production yet simply because no clinic has clicked "Publish" — the pages themselves work, verified against the real database. |
| **Patient self-service booking** | A patient can find a doctor, pick a real available time slot, log in (or sign up), and book — with no clinic staff involved. Verified end-to-end against the real database: booking, double-booking prevention, and a patient only ever being able to see their own appointment all confirmed working for real. |
| **A real patient dashboard** | After logging in, a patient sees a greeting and their next appointment front and center (doctor, time, queue token if checked in) — not a plain staff-style table. Every appointment now also has its own detail page, with view/cancel/reschedule in one place. |
| **A real doctor "what's next" view** | A doctor logging in sees who's currently being seen or next in line, today's full schedule, and quick counts (waiting / completed / no-shows) — instead of a single generic number. Verified live: correctly updates the moment a patient is actually checked in. |
| **A real reception "what's next" view** | The front desk logging in sees today's clinic-wide numbers (checked-in, waiting, in-consultation, no-shows) and an at-a-glance "up next" list across every doctor — plus quick links to the existing queue board, patient search, and new-appointment form. Verified live with real data. |
| **A real clinic-admin dashboard** | The clinic owner/admin now sees the same kind of "what's next" view (doctor/staff counts, today's numbers by status, quick add-doctor/add-staff actions) instead of the old generic grid. |
| **Verification review** | A clinic admin can now formally request that DoseWise review and verify their clinic; we (the platform) have a real queue to approve or reject those requests, and the "Verified" badge shown to patients only ever reflects a real decision — never faked. Verified live end to end. |
| **Dependent / family booking** | A guardian who has been given access to a dependent's record (a child, an elderly parent, etc.) can now book, view, reschedule, and cancel that dependent's appointments — with the exact same rules and limits the patient themself would have, no more and no less. Verified live end to end, including confirming an unrelated patient at the same clinic still cannot see or touch that dependent's appointment. |
| **Works on a phone, and with a keyboard/screen reader** | Fixed the biggest gap: the dashboard was previously unusable on a phone screen (the side menu didn't adapt at all). Also added a visible outline for keyboard users tabbing through the site, fixed some invalid button/link markup, and made data tables scroll sideways on a narrow screen instead of squeezing unreadably. |
| **Full test suite + a security fix** | Ran every automated test (113 of them) against the real database — all passing, no crash. A security review of everything built this cycle found and fixed one real issue: a clinic's website link could have been used to run malicious code in a visitor's browser; that's now blocked at the point where the clinic saves their profile, so it can never be stored in the first place. |
| **Doctor scheduling** | Doctors set weekly availability + exceptions (holidays, leave); the system calculates real open slots automatically. |
| **Booking a real appointment** | A patient/staff can book, confirm, cancel, reschedule, or no-show an appointment — double-booking the same doctor at the same time is physically impossible (enforced at the database level, not just in app code). |
| **Front-desk queue** | Check-in issues a token, a live board shows who's waiting, staff can call/recall/skip, and starting/completing a visit is restricted to the assigned doctor. |
| **Consultation notes & prescriptions** | A doctor can write visit notes and add prescription items during a visit; once a note is signed, it locks against edits (a compliance requirement, not just a nice-to-have). |
| **Audit trail** | Every sensitive action (who changed what, when) is logged and reviewable by that clinic's admin. |
| **Family access** | A patient can grant a family member read access to their own records; nothing is shared without an explicit grant. |
| **Platform admin console** | We (the platform owner) have a super-admin panel to see all clinics, suspend/reactivate one if needed, and review a cross-clinic audit feed — without being able to silently self-grant medical-record access. |
| **Web app (functional)** | All of the above is usable today through a working website — login, dashboards per role, booking, queue board, notes, admin console. Every screen in the entire app, including the separate platform-owner admin console, now has real visual design. |

**In short: the operational core of "run a clinic's day-to-day" is built and
working.** What's missing now is mostly the polished patient-facing experience
and the doctor/clinic onboarding wizard.

## 🔄 In progress / needs attention before the next milestone

| Item | Status |
|---|---|
| Site response time in production | Root cause identified (a database configuration/region issue, not app code) — write-up in `DEPLOYMENT.md`; one code-level fix is ready but not yet deployed, and the infrastructure checks need someone with dashboard access to confirm. |
| Reminder/notification delivery in production | The scheduler that fires reminders was never actually turned on in production until this week; it's wired up now but needs two configuration values set before it's live. |

*Resolved this update:* the automated-test-stability item (a prior run had hit a worker crash and
some test files reporting 0 tests) — a full re-run came back clean, all 113 tests across every
module passing, no crash. Whatever caused the earlier failure didn't reproduce.

## ⛔ Not started yet

| Area | Notes |
|---|---|
| **Mobile-app integration (Flutter)** | The existing DoseWise app and this new backend aren't connected yet — planned as the final phase, deliberately last so the web product is solid first. |
| Document uploads, SMS/WhatsApp notifications, right-to-erasure workflow | Explicitly deferred, not required for MVP. |

---

## Full evolution plan

A detailed, phase-by-phase plan for turning this from a clinic-operations tool into a real
patient-facing product (public hospital/doctor discovery, self-service booking, guided
onboarding for clinics and doctors) now exists at
[`PRODUCT_EVOLUTION_PLAN.md`](../PRODUCT_EVOLUTION_PLAN.md), based on an audit of the actual
current code. **All 13 phases are now done** — design system, organization & doctor public
profiles, public discovery pages, patient self-service booking, role-specific "what's next" views
for every staff role, a real platform verification queue, dependent/family booking, a responsive/
accessibility pass, and a final regression + security pass. A stranger can find a doctor, see real
availability, log in, book, and land on a real dashboard; staff logging in immediately see what
needs attention; a clinic can request a "Verified" badge and the platform can actually grant one;
a guardian can manage a dependent's appointments with the same rules as the patient themself; the
whole thing works on a phone screen and with a keyboard; and the full automated test suite passes
end to end. All verified live against the real database, not just build-checked.

## Recommended next milestone

**The evolution plan is complete, and every screen in the app now has real modern design.**
What's left is outside the original 13 phases: connecting the existing Flutter mobile app to this
backend, and deciding when/how to commit and deploy this cycle's work — neither is started yet
and would need a fresh scoping conversation.

---

*For engineers: the detailed, phase-by-phase technical roadmap lives in
[ROADMAP.md](ROADMAP.md). This file is the plain-English summary of that one.*
