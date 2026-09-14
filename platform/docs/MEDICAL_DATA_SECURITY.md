# Medical Data Security

Design target: **HIPAA-aware foundation** (no BAA process yet — decision on
record). Build every control HIPAA would expect; don't block on legal.

## What counts as sensitive (PHI)

`Patient` demographics · `Consultation` (all SOAP fields) · `Prescription` /
`PrescriptionItem` · `MedicalDocument` (metadata **and** bytes) ·
`Medication*` · `VitalReading` · anything in `AuditLog.before/after` that
copies the above.

## Access model

> **A membership role is never sufficient on its own to read a clinical record
> body.** Access comes from one of: being the assigned doctor, holding an
> explicit `Membership.capabilities` grant, or a family `PatientAccessGrant`.

Access to a patient's **clinical** PHR (`Consultation` bodies,
`Prescription*` contents, `MedicalDocument` contents, `Medication*`,
`VitalReading`) requires an `ACTIVE` `Membership` in the patient's
`organizationId`, **plus one of**:

1. **`DOCTOR`** with an **assignment link** to the patient — an appointment
   with that patient, or a `PatientAccessGrant` naming that doctor. Writes
   (`Consultation`/`Prescription`) are further restricted to the doctor's
   **own** appointment. "All doctors see all patients" is **not** the
   default; a doctor needs no separate capability for their own patients —
   the assignment is the credential.
2. **`CLINICAL_RECORD_READ`** (or `_WRITE`) on the membership — **absent by
   default for every role**, including `CLINIC_ADMIN` and `DOCTOR`. For
   `CLINIC_ADMIN` this is the *only* path in. For `DOCTOR` it's an optional
   override that extends *read* beyond their assigned patients (e.g.
   covering a colleague) — it never extends write to another doctor's chart.
3. The caller **is the patient** (own record only).
4. A guardian/family user with a non-expired, non-revoked
   `PatientAccessGrant` whose `permissions` include the needed one.

Access to patient **demographics / contact / appointment / queue** data
requires only (1) + a role permitted for that class (see the [RBAC.md](RBAC.md)
matrix) — `RECEPTIONIST` and `CLINIC_ADMIN` qualify; clinical bodies do not
travel on those responses.

Every check is server-side and re-verified in the service layer, not just at
the route. Cross-tenant ⇒ `404` (no existence leak). In-tenant denial ⇒ `403`.
Where an endpoint returns a mix, the service applies **field-level
projection**: clinical fields are removed for a caller without clinical read.

## CLINIC_ADMIN ≠ unrestricted clinical access

`CLINIC_ADMIN` is an **operations** role. By default a clinic admin can manage
doctors, staff, schedules, patients (registration/demographics), appointments,
queue, settings, invitations, and the operational audit log — and **cannot**
open a consultation note, a prescription body, a document, a medication list,
or a vitals log.

To give a specific admin clinical visibility, another admin grants
`CLINICAL_RECORD_READ` (and, rarely, `CLINICAL_RECORD_WRITE`) on that admin's
membership. That grant:

- **must be performed by a *different*, authorized `CLINIC_ADMIN`** — the
  `PUT /members/:membershipId/capabilities` endpoint rejects a request where
  `:membershipId` is the caller's own membership for these two capabilities
  (`403 CANNOT_SELF_GRANT_CAPABILITY`). Separation of duties: no admin can
  unilaterally give themselves access to PHR;
- is itself audited (`MEMBER_CAPABILITY_GRANTED` / `_REVOKED`, with actor and
  target);
- makes **every** subsequent clinical read by that admin an audited event
  (`CLINICAL_RECORD_VIEWED`);
- is revocable with immediate effect.

Consequence: a clinic with a **single** admin cannot enable clinical access for
that admin at all — it must add a second admin first. A clinic can also run
indefinitely with admins who never see PHR — the schema and policy default to
that.

## Receptionist limits (spec §13)

`RECEPTIONIST` may read/write patient **demographics, contact info, and
appointment/queue data only**. There is **no capability** that grants a
receptionist clinical access — it cannot be enabled. They can never read:

- `Consultation` bodies (`subjective/objective/assessment/plan/instructions`)
- `Prescription` / `PrescriptionItem` contents
- `MedicalDocument` contents
- `Medication*` / `VitalReading`

Endpoints that would return these fields strip them for a RECEPTIONIST caller
(field-level projection in the service), or `403` if the endpoint is wholly
clinical.

## SUPER_ADMIN — no routine clinical access

`SUPER_ADMIN` (`User.isPlatformAdmin`) holds **no `Membership`** in any clinic,
so the tenant-scoped client returns nothing clinical for them. They manage
tenants and platform health only. The single sanctioned path to clinical data
is a future `SUPPORT_ACCESS` flow: explicitly initiated, reason-required,
time-boxed, clinic-notified, and fully audited. It does not exist in MVP.

## Family / dependents (spec §15)

- A family link (`FamilyRelationship`) grants **nothing** by itself.
- Access is the explicit permission set on `PatientAccessGrant`:
  `VIEW_PROFILE`, `VIEW_APPOINTMENTS`, `MANAGE_APPOINTMENTS`,
  `VIEW_MEDICATIONS`, `MANAGE_MEDICATIONS`, `VIEW_DOCUMENTS`.
- Grants are created only by the patient (if self-owned) or `CLINIC_ADMIN`,
  can carry `expiresAt`, and are revocable (`revokedAt`) with immediate effect.
- This preserves DoseWise's default-private posture
  (`shareMedicines`/`shareMissedAlerts` default false).

## Invitation / join tokens (spec §16)

Carried over from DoseWise's proven model:

- The raw token appears **only** in the link / QR / email — never stored.
- `sha256(token)` is the stored `Invitation.hashedToken` (unique).
- `expiresAt` (short, e.g. 24–72 h), single-use (`usedAt`), revocable
  (`revokedAt`), scoped (`scope` + `organizationId` + optional `role` /
  `patientId` / `permissions`).
- `accept` consumes the token and creates the membership / grant **atomically**
  in one transaction (a double-scan or race cannot double-apply).
- A QR/link never contains passwords, PHI, full patient data, or long-lived
  secrets.

## Audit logging (spec §22)

Recorded for every clinical mutation and every PHI read that is not the
patient's own routine self-access:

`actorUserId`, `actorRole`, `action`, `entityType`, `entityId`,
`organizationId`, `before`, `after`, `ip`, `userAgent`, `requestId`, `at`.

Action vocabulary includes: `APPOINTMENT_CREATED/CONFIRMED/RESCHEDULED/
CANCELLED/NO_SHOW/CHECKED_IN/COMPLETED`, `PATIENT_CREATED/UPDATED`,
`CONSULTATION_CREATED/UPDATED/SIGNED`, `PRESCRIPTION_CREATED`,
`PRESCRIPTION_ITEM_ADDED/REMOVED`, `DOCUMENT_UPLOADED/
DOWNLOADED`, `ACCESS_GRANT_CREATED/REVOKED`, `MEMBER_ADDED/REMOVED/ROLE_CHANGED`,
`MEMBER_CAPABILITY_GRANTED/REVOKED`, `CLINICAL_RECORD_VIEWED` (capability-gated
reads by staff), `INVITATION_CREATED/ACCEPTED/REVOKED`, `MEDICATION_IMPORTED`,
`SUPPORT_ACCESS` (platform admin).

**Never logged**: passwords, password hashes, session/refresh/reset tokens,
FCM/device tokens, OAuth secrets, full document bytes, or medical free-text
beyond what a diff strictly needs (truncate large text; store a hash + length
where the full value isn't required).

## Data at rest & in transit

- Neon encrypts data at rest by default; TLS required for all connections
  (`sslmode=require`).
- All API traffic HTTPS only; HSTS on.
- Object storage (documents, later) uses server-side encryption + short-lived
  pre-signed URLs; no public buckets.
- Backups follow Neon's managed backups; a documented restore drill is in
  [DEPLOYMENT.md](DEPLOYMENT.md).

## Retention & deletion (foundation)

- Soft-delete for patients/organizations; hard-delete is an audited
  platform-admin operation.
- A patient data-export endpoint exists (`/patients/:id/export`).
- Full "right to erasure" workflow is post-MVP but the schema supports it
  (cascade rules + `AuditLog` retained as the tombstone of record).

## Error hygiene (spec §23)

No raw DB errors, stack traces, or Prisma messages to clients. `500` bodies are
`{ error: { code: "INTERNAL", message: "Something went wrong." } }`; the real
error (with `requestId`) is logged server-side only. 404 is used for
cross-tenant lookups so an attacker cannot map another clinic's id space.
