# DoseWise Platform — Status

**Last updated: 2026-09-16.** This file is updated every time a piece of work
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
| **Accounts & login** | Clinics and staff can register and log in securely (industry-standard password hashing, session handling). |
| **Multi-clinic isolation** | One clinic can never see another clinic's data — tested and enforced, not just assumed. |
| **Roles & permissions** | Admin / Doctor / Receptionist / Patient each see only what their role should — including a rule that no admin can grant themselves extra medical-record access (must be a second admin). |
| **Clinic setup** | A clinic admin can register their organization, add locations, add doctors and staff. |
| **Organization & doctor public profiles** | A clinic admin can fill in a real public-facing clinic profile (type, description, branding, contact info) and publish/unpublish it; each doctor can fill in their own professional profile (photo, qualifications, experience, languages, fee) and choose to be listed. |
| **Public hospital & doctor search** | Anyone — no login needed — can search for hospitals and doctors and view their public profiles at `dosewise.example/hospitals` and `/doctors`. Nothing shows up yet simply because no clinic has clicked "Publish" — the pages themselves work, verified against the real database. |
| **Doctor scheduling** | Doctors set weekly availability + exceptions (holidays, leave); the system calculates real open slots automatically. |
| **Booking a real appointment** | A patient/staff can book, confirm, cancel, reschedule, or no-show an appointment — double-booking the same doctor at the same time is physically impossible (enforced at the database level, not just in app code). |
| **Front-desk queue** | Check-in issues a token, a live board shows who's waiting, staff can call/recall/skip, and starting/completing a visit is restricted to the assigned doctor. |
| **Consultation notes & prescriptions** | A doctor can write visit notes and add prescription items during a visit; once a note is signed, it locks against edits (a compliance requirement, not just a nice-to-have). |
| **Audit trail** | Every sensitive action (who changed what, when) is logged and reviewable by that clinic's admin. |
| **Family access** | A patient can grant a family member read access to their own records; nothing is shared without an explicit grant. |
| **Platform admin console** | We (the platform owner) have a super-admin panel to see all clinics, suspend/reactivate one if needed, and review a cross-clinic audit feed — without being able to silently self-grant medical-record access. |
| **Web app (functional)** | All of the above is usable today through a working (plain-styled, not final visual design) website — login, dashboards per role, booking, queue board, notes, admin console. |

**In short: the operational core of "run a clinic's day-to-day" is built and
working.** What's missing now is mostly the polished patient-facing experience
and the doctor/clinic onboarding wizard.

## 🔄 In progress / needs attention before the next milestone

| Item | Status |
|---|---|
| Automated test stability for the queue/consultation/family modules | A recent full test run hit a worker crash after a cascading failure in the queue tests — needs a root-cause fix before we build more UI on top of those modules. Not a sign the features are broken in practice, but the safety net needs repair first. |
| Site response time in production | Root cause identified (a database configuration/region issue, not app code) — write-up in `DEPLOYMENT.md`; one code-level fix is ready but not yet deployed, and the infrastructure checks need someone with dashboard access to confirm. |
| Reminder/notification delivery in production | The scheduler that fires reminders was never actually turned on in production until this week; it's wired up now but needs two configuration values set before it's live. |

## ⛔ Not started yet

| Area | Notes |
|---|---|
| **Patient self-service booking** | A patient can find a doctor publicly but can't yet book an appointment from there — today, booking still requires staff inside the clinic's own dashboard. This is the next piece of work. |
| **Visual design pass** | Current UI is clean but generic — not yet matching DoseWise's actual brand look (the new public pages use a real component system now; the older dashboard screens still don't). |
| **Mobile-app integration (Flutter)** | The existing DoseWise app and this new backend aren't connected yet — planned as the final phase, deliberately last so the web product is solid first. |
| Document uploads, SMS/WhatsApp notifications, right-to-erasure workflow | Explicitly deferred, not required for MVP. |

---

## Full evolution plan

A detailed, phase-by-phase plan for turning this from a clinic-operations tool into a real
patient-facing product (public hospital/doctor discovery, self-service booking, guided
onboarding for clinics and doctors) now exists at
[`PRODUCT_EVOLUTION_PLAN.md`](../PRODUCT_EVOLUTION_PLAN.md), based on an audit of the actual
current code. **Phases 2–5 are done** — design system, organization & doctor public profiles,
and now real public discovery pages (homepage, hospital search + profile, doctor search +
profile). Nothing is visible there yet because no clinic has actually published its profile in
this database — that's expected, this feature only shipped today. Phase 6 (patient booking from
discovery) is next.

## Recommended next milestone

**Patient self-service booking (Phase 6)** — let a patient book directly from a doctor's public
profile instead of needing clinic staff to do it, closing the loop on "find → view → book" that
the last few days of work have been building toward. Worth fixing the test-stability issue above
first so this is built on solid ground.

---

*For engineers: the detailed, phase-by-phase technical roadmap lives in
[ROADMAP.md](ROADMAP.md). This file is the plain-English summary of that one.*
