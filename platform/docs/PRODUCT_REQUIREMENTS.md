# Product Requirements

## Problem

Small and mid-size clinics run appointments on paper, phone calls, and
WhatsApp. Patients don't know their queue position. Doctors lack a consolidated
view of a patient's history, medications, and documents. There is no
multi-clinic system that is affordable, respects patient-owned medication data,
and works for low-connectivity environments.

DoseWise already solves **personal medication adherence** (reminders, history,
family sync) very well. The platform extends that foundation into clinic
operations without discarding it.

## Target users

**Primary customers:** individual doctors, single- and multi-doctor clinics,
small healthcare practices.

**Users:**

| Role | Uses the platform to… |
|---|---|
| Patient | Book/cancel/reschedule appointments, see queue position, view own records, manage dependents, keep medication reminders (DoseWise) |
| Doctor | Manage schedule, see assigned appointments & authorized patient history, write consultation notes and prescriptions, run the consultation queue |
| Receptionist | Register patients, book/reschedule/cancel, check-in, manage the queue |
| Clinic admin | Manage doctors, staff, schedules, appointment types, settings, reports |
| Super admin | Platform administration: tenant lifecycle, health, support — **not** routine access to clinical data |

## Tenancy

A **tenant = one clinic / healthcare organization**. Tenants are fully isolated:
Clinic A can never read Clinic B's patients, appointments, queue, documents, or
audit logs. Isolation is enforced server-side, never by frontend filtering, and
`tenantId` is never accepted from the client — it is derived from the
authenticated membership.

## Core workflows (MVP)

1. **Clinic onboarding** — create organization, first CLINIC_ADMIN, at least
   one location, one doctor with availability.
2. **Patient registration** — by receptionist/admin, or patient self-signup
   then linked to the clinic.
3. **Booking** — patient app or reception picks doctor + slot; backend
   validates availability and rejects double-booking atomically.
4. **Reschedule / cancel** — within clinic rules (lead time, cancellation
   window); every change audited; reschedule keeps lineage.
5. **Check-in & queue** — reception checks a patient in; a token is issued;
   the queue orders `WAITING → CALLED → IN_CONSULTATION → COMPLETED` with
   recall and skip.
6. **Consultation** — doctor opens the appointment, sees authorized history +
   current medications + documents, records structured notes, issues a
   prescription, sets a follow-up.
7. **Medication adherence (DoseWise)** — unchanged for the patient; data
   eventually syncs to the platform so an authorized doctor can view it.
8. **Family / dependents** — a user manages authorized dependents with
   per-permission grants (`VIEW_PROFILE`, `VIEW_APPOINTMENTS`,
   `MANAGE_APPOINTMENTS`, `VIEW_MEDICATIONS`, `VIEW_DOCUMENTS`).
9. **Notifications** — appointment booked/confirmed/cancelled/rescheduled,
   check-in, queue updates, consultation complete, follow-up.
10. **Reports & export** — adherence and appointment reports; JSON/CSV export.

## Post-MVP

- Multi-location routing and resource (room) scheduling.
- Billing / invoicing / payments.
- Email / SMS / WhatsApp notification channels (MVP is push + in-app only).
- Object-storage-backed document upload UI and previews.
- Patient-facing web portal polish and clinic branding.
- Analytics dashboards, no-show prediction (non-clinical ML only).
- Postgres RLS as defense-in-depth on top of the app-layer isolation.

## Non-goals

- **No AI medical diagnosis, disease prediction, automated prescription or
  treatment recommendation, or drug-interaction engine** (spec §39). The
  existing DoseWise client-side `InteractionChecker` is left as-is and is
  **not** ported server-side without an explicit later decision.
- No autonomous clinical decision-making of any kind. This is a
  management/documentation system.
- No microservices, no Kafka/Redis/Elasticsearch/Kubernetes in MVP (spec §37).
- No "big bang" rewrite of the Flutter app (spec §30).

## Business model (placeholder)

Per-clinic subscription (tiered by doctor count / appointment volume). Patient
app stays free. Billing is out of scope for MVP.

## Security requirements (summary — see SECURITY.md)

Server-side authorization; tenant isolation; input validation (Zod); modern
password hashing (argon2id); secure session/token handling; rate limiting;
security headers; CORS allow-list; audit logging of clinical changes; no raw
DB errors to clients; no PHI / secrets / FCM tokens in logs.

## Technical constraints

- Database: Neon PostgreSQL. Prisma migrations only.
- Free / low-cost dev infra: no paid providers in MVP unless requested.
- Modular monolith in one Next.js project; the same domain/service layer
  serves both the Flutter app and the web app (no duplicated business logic).
- Flutter must keep working offline; the platform API is a sync target for
  medication data, not a hard runtime dependency for reminders.
- Appointment instants stored timezone-safe; medication reminder times stay
  local wall-clock.
