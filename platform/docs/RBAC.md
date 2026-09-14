# Role-Based Access Control

## Roles

| Role | Scope | Summary |
|---|---|---|
| `PATIENT` | per membership | own record, own appointments, own/authorized dependents, own medications & documents |
| `DOCTOR` | per membership | own schedule, assigned appointments, **authorized** patients only, consultation notes, prescriptions, own queue |
| `RECEPTIONIST` | per membership | clinic appointments, patient registration, booking/reschedule/cancel, check-in, queue — **never clinical record bodies** |
| `CLINIC_ADMIN` | per membership | clinic **operations**: doctors, staff, schedules, appointment types, patient registration, appointments, settings, invitations, operational reports, audit log. **Not** clinical record bodies unless separately granted. |
| `SUPER_ADMIN` | platform (`User.isPlatformAdmin`) | tenant lifecycle, platform health, support — **no** routine clinical data access, ever; any access is a separate, audited, clinic-notified flow |

Roles are attached to a `Membership`, so the same person is `DOCTOR` in one
clinic and `PATIENT` in another with no leakage between them.

## Role ≠ clinical-data access

> **A role never, by itself, grants access to clinical record bodies**
> (`Consultation` notes, `Prescription`/`PrescriptionItem` contents,
> `MedicalDocument` contents, `Medication*`, `VitalReading`).

Clinical-record access requires either **an assignment to the patient**
(doctors, on their own patients) or **an explicit capability** on the
membership (everyone else it's ever extended to — chiefly `CLINIC_ADMIN`):

| Principal | What unlocks clinical **read** | What unlocks clinical **write** |
|---|---|---|
| `PATIENT` | it is their own record (or a dependent they own) | their own medications/documents; never consultation notes or prescriptions |
| guardian / family user | a non-expired `PatientAccessGrant` containing the matching `AccessPermission` (`VIEW_MEDICATIONS`, `VIEW_DOCUMENTS`, …) | `MANAGE_MEDICATIONS` / `MANAGE_APPOINTMENTS` in the grant |
| `DOCTOR` | an **assignment link** to the patient (an appointment they're the doctor on, or a `PatientAccessGrant` naming them) — no separate capability needed; that assignment *is* the credential for a doctor's own patients. "Every doctor sees every patient" is still not the default: an unassigned patient stays out of reach unless the doctor also holds `CLINICAL_RECORD_READ` (an optional clinic-wide override, granted like any other capability, for e.g. covering a colleague). | assignment link only — a doctor writes `Consultation`/`Prescription` **only for their own appointment**; `CLINICAL_RECORD_WRITE` does not extend this to other doctors' charts |
| `CLINIC_ADMIN` | **only** if `CLINICAL_RECORD_READ` is present in `Membership.capabilities`. Absent by default. It can be granted **only by a different, authorized `CLINIC_ADMIN`** — self-grant is rejected (`403 CANNOT_SELF_GRANT_CAPABILITY`). The grant is audited (`MEMBER_CAPABILITY_GRANTED`) and every subsequent read is audited (`CLINICAL_RECORD_VIEWED`). | `CLINICAL_RECORD_WRITE` capability — same no-self-grant rule; expected to be rare/never; admins are operations, not clinicians |
| `RECEPTIONIST` | **never.** No capability grants it. Endpoints that would return clinical bodies strip those fields for a receptionist or return `403`. | never |
| `SUPER_ADMIN` | **never** through normal endpoints. A separate `SUPPORT_ACCESS` flow (post-MVP), time-boxed, reason-required, clinic-notified, is the only path. | never |

`Membership.capabilities` (`MembershipCapability[]`, default `[]`):
`CLINICAL_RECORD_READ`, `CLINICAL_RECORD_WRITE`, `BILLING_MANAGE` (reserved),
`DATA_EXPORT`. Empty for **every role** on creation, including `CLINIC_ADMIN`.

**Separation of duties for `CLINICAL_RECORD_*`:** an admin can never add or
remove a `CLINICAL_RECORD_READ`/`WRITE` capability on **their own**
membership. `PUT /members/:membershipId/capabilities` rejects
`:membershipId == caller's membership` for those two capabilities with
`403 CANNOT_SELF_GRANT_CAPABILITY`. It therefore takes **two** distinct
`CLINIC_ADMIN`s for any admin to gain clinical visibility; a single-admin
clinic cannot self-enable it (add a second admin). `BILLING_MANAGE` /
`DATA_EXPORT` are operational and not subject to the no-self-grant rule.

## Where checks happen (spec §6, §23)

1. **Route pipeline** — `withApi(handler, { roles: [...] })` rejects a wrong
   role with 403 before the handler runs.
2. **Policy module** — `can(ctx, action, resource)` in `src/lib/rbac.ts` is the
   single table-driven source of truth. `ctx` carries `role` **and**
   `capabilities` **and** the resolved relationship facts (is-assigned-doctor,
   grant-permissions). Clinical actions check the capability + relationship,
   not just the role.
3. **Service ownership checks** — "is this patient in `ctx.organizationId`?",
   "is this appointment assigned to `ctx.doctorId`?", "does this grant include
   `VIEW_MEDICATIONS` and is it unexpired?" — always re-verified against the DB.
4. **Field-level projection** — services strip clinical fields from a response
   when the caller lacks clinical read (e.g. a RECEPTIONIST fetching a patient
   gets demographics only).

Frontend never decides authorization. It only hides controls it knows will be
rejected.

## Capability matrix (MVP)

`✓` allowed · `own` only their own / assigned / authorized · `cap` requires the
`CLINICAL_RECORD_*` capability (+ relationship) · `—` denied

| Action | PATIENT | DOCTOR | RECEPTIONIST | CLINIC_ADMIN | SUPER_ADMIN |
|---|:--:|:--:|:--:|:--:|:--:|
| View own user profile | ✓ | ✓ | ✓ | ✓ | ✓ |
| Manage clinic settings | — | — | — | ✓ | — |
| Invite / manage staff | — | — | — | ✓ | — |
| Grant/revoke `CLINICAL_RECORD_*` capability on **another** membership | — | — | — | ✓ (audited) | — |
| Grant/revoke `CLINICAL_RECORD_*` capability on **own** membership | — | — | — | **—** (`403 CANNOT_SELF_GRANT_CAPABILITY`) | — |
| Manage doctors & availability | — | own | — | ✓ | — |
| Register a patient | — | — | ✓ | ✓ | — |
| View patient demographics | own | assigned | ✓ (clinic) | ✓ | — |
| View consultation notes / clinical history | own | assigned (or `cap`) | **—** | `cap` | **—** |
| View patient medications | own | assigned (or `cap`) | **—** | `cap` | **—** |
| View patient documents | own | assigned (or `cap`) | **—** | `cap` | **—** |
| Book appointment | own | ✓ | ✓ | ✓ | — |
| Reschedule / cancel appointment | own† | ✓ | ✓ | ✓ | — |
| Change appointment status (lifecycle) | — | own | ✓ | ✓ | — |
| Mark NO_SHOW | — | own | ✓ | ✓ | — |
| Check-in a patient | — | — | ✓ | ✓ | — |
| Manage queue (call/recall/skip/complete) | — | own | ✓ | ✓ | — |
| Create / amend consultation notes | — | own appt only | — | `cap`-write (rare) | — |
| Create prescription | — | own appt only | — | — | — |
| Upload medical document | own | assigned (or `cap`) | — | `cap` | — |
| Manage family / dependents | own | — | — | — | — |
| Grant patient access to another user | own‡ | — | — | ✓ | — |
| View operational reports (appointments, no-show) | own | own | clinic (non-clinical) | ✓ | — |
| View adherence / clinical reports | own | assigned (or `cap`) | — | `cap` | — |
| Export data | own | own (`DATA_EXPORT` for clinic-wide) | — | `DATA_EXPORT` | — |
| Tenant lifecycle / platform health | — | — | — | — | ✓ |
| Read audit log | — | — | — | ✓ (own org) | ✓ (all, audited) |
| Break-glass clinical access | — | — | — | — | `SUPPORT_ACCESS` flow only (post-MVP) |

† Patient reschedule/cancel is bounded by `ClinicSettings.cancellationWindowHours`
and `bookingLeadTimeMinutes`.
‡ A patient can grant access to their own record and to dependents they own.

## Per-role: can / cannot (explicit)

### PATIENT
- **Can:** manage own profile; view/book/reschedule/cancel own appointments
  (within clinic rules); see own queue position; view own medical info,
  medications, documents, prescriptions issued to them; manage dependents they
  own and grant/revoke access to those records; export own data.
- **Cannot:** see any other patient's data; see clinic-wide lists; see a
  doctor's private notes beyond what is shared with them; change appointment
  lifecycle beyond request/cancel; act in a clinic where they hold no
  membership.

### DOCTOR
- **Can:** manage own availability; see assigned appointments and own queue;
  for a patient they're assigned to (an appointment, or a grant) — view
  history, medications, documents, and create/amend the `Consultation` and
  `Prescription` for their own appointment; set follow-ups. No separate
  capability grant needed for their own patients — the assignment is the
  credential. Optionally, `CLINICAL_RECORD_READ` extends *read* to patients
  they aren't assigned to (covering a colleague); nothing extends *write*
  beyond their own appointment.
- **Cannot:** view or write for a patient they are not assigned to and hold
  no grant/override for; manage staff, settings, or other doctors' schedules;
  access another clinic's data; change another doctor's appointments.

### RECEPTIONIST
- **Can:** register patients; edit patient **demographics/contact** only;
  book/reschedule/cancel/confirm appointments; mark no-show; check patients in;
  run the queue; view non-clinical operational reports.
- **Cannot:** read or write `Consultation` bodies, `Prescription`/
  `PrescriptionItem` contents, `MedicalDocument` contents, `Medication*`,
  `VitalReading` — no capability exists that grants a receptionist clinical
  access. Requests for clinical fields are stripped or `403`.

### CLINIC_ADMIN
- **Can:** everything operational for their own clinic — doctors, staff,
  schedules, appointment types, patient registration, appointments, queue,
  clinic settings, invitations, operational reports, the clinic's audit log;
  grant/revoke `CLINICAL_RECORD_*` capabilities on **other** members'
  memberships (audited).
- **Cannot:** grant/revoke a `CLINICAL_RECORD_*` capability on their **own**
  membership (`403 CANNOT_SELF_GRANT_CAPABILITY`) — clinical visibility for an
  admin must be conferred by a **different** authorized `CLINIC_ADMIN`.
- **Cannot (by default):** read or write clinical record bodies. That requires
  `CLINICAL_RECORD_READ`/`WRITE` on their own membership, granted by another
  admin as above — not implied by the admin role. A clinic can run with admins
  who never see a clinical note. Also cannot touch another clinic's data or
  platform-level functions.

### SUPER_ADMIN
- **Can:** create/suspend/inspect tenants; view platform health and
  aggregate/operational metrics; manage platform staff.
- **Cannot:** read patient clinical data through any normal endpoint;
  self-grant a clinic membership; act inside a clinic's clinical surface. Any
  genuine support need goes through a future `SUPPORT_ACCESS` flow that is
  time-boxed, reason-logged, clinic-notified, and fully audited.

## Family / dependent permissions

Separate from clinic roles. A guardian's access to a dependent patient is the
set on `PatientAccessGrant.permissions`:

`VIEW_PROFILE` · `VIEW_APPOINTMENTS` · `MANAGE_APPOINTMENTS` ·
`VIEW_MEDICATIONS` · `MANAGE_MEDICATIONS` · `VIEW_DOCUMENTS`

Grants can expire (`expiresAt`) and be revoked (`revokedAt`). No permission is
implied by the family link alone — joining a family exposes nothing until a
grant is created (carried over from DoseWise's default-private model).

## SUPER_ADMIN guard rails

- Not a `Membership` role; backed by `User.isPlatformAdmin`.
- Cannot read `Consultation`, `Prescription*`, `MedicalDocument`,
  `Medication*`, `VitalReading` bodies through normal endpoints — the
  tenant-scoped client returns nothing for an org where they hold no
  membership, and they hold none.
- The only path to clinical data is a dedicated, separately-audited,
  time-boxed `SUPPORT_ACCESS` flow (post-MVP) that notifies the clinic.
