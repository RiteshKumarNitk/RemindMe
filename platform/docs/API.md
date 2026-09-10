# API Design

REST-style JSON over HTTPS. Next.js App Router route handlers under
`app/api/**`. This document is the catalogue the Flutter developer works
against; an OpenAPI document is generated alongside it (see end).

## Conventions

- **Base**: `/api`. Tenant-scoped routes are nested under
  `/api/orgs/:orgId/...`. The `:orgId` **path segment is the only tenant
  selector** — it is resolved against the caller's `ACTIVE` memberships; no
  match ⇒ `404`. There is **no `X-Org-Id` header**; `organizationId` in a
  body/query/header is never trusted as tenant context (a body value that
  contradicts `:orgId` ⇒ `422`).
- **Auth**: `Authorization: Bearer <accessToken>` (app) or the `dw_session`
  cookie (web). `X-Client: web|app` selects login response style.
- **Content type**: `application/json`. `snake_case` is **not** used — request
  and response bodies are `camelCase`.
- **IDs**: UUID strings.
- **Timestamps**: RFC 3339 / ISO 8601 UTC (`2026-09-10T09:30:00Z`) for
  instants. Medication dose times carry a separate `timezone` (IANA) and a
  local wall-clock string.
- **Pagination**: `?limit=` (default 25, max 100) + `?cursor=` (opaque).
  Responses: `{ data: [...], nextCursor: string | null }`.
- **Validation**: Zod at the boundary. A validation failure is `422` with
  `details` listing field errors.
- **Idempotency**: mutation endpoints that a client may retry (booking, sync)
  accept `Idempotency-Key`.

## Error envelope (spec §23, §24)

```json
{ "error": { "code": "APPOINTMENT_SLOT_TAKEN",
             "message": "That slot is no longer available.",
             "details": null } }
```

| HTTP | `code` examples |
|---|---|
| 400 | `MALFORMED_REQUEST` |
| 401 | `NOT_AUTHENTICATED`, `TOKEN_EXPIRED`, `REFRESH_REUSE_DETECTED` |
| 403 | `FORBIDDEN_ROLE`, `OUTSIDE_CANCELLATION_WINDOW` |
| 404 | `NOT_FOUND` (also returned for cross-tenant access — no leak) |
| 409 | `APPOINTMENT_SLOT_TAKEN`, `INVALID_STATUS_TRANSITION`, `TOKEN_ALREADY_USED` |
| 422 | `VALIDATION_FAILED` (+ `details`) |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL` (generic; real cause logged server-side only) |

Raw Prisma / Postgres error text is never returned.

## Endpoint catalogue (MVP)

### Auth & identity
See [AUTHENTICATION.md](AUTHENTICATION.md). `POST /api/auth/{register,login,refresh,logout,logout-all,forgot-password,reset-password,verify-email}`, `GET /api/auth/google/{start,callback}`, `GET /api/me`.
`POST /api/auth/guest` — mints a short-lived, refresh-token-less session bound to the seeded **demo org** only (see [GUEST_ACCESS.md](GUEST_ACCESS.md)); disabled by an env flag; shares the `/api/auth/*` rate budget.

### Organizations / tenancy
| Method | Path | Role | Notes |
|---|---|---|---|
| `POST` | `/api/orgs` | any authenticated | create clinic; caller becomes `CLINIC_ADMIN` |
| `GET` | `/api/orgs/:orgId` | member | clinic profile + settings |
| `PATCH` | `/api/orgs/:orgId` | CLINIC_ADMIN | name, timezone |
| `GET`/`PATCH` | `/api/orgs/:orgId/settings` | CLINIC_ADMIN | `ClinicSettings` |
| `GET`/`POST` | `/api/orgs/:orgId/locations` | member / CLINIC_ADMIN | |
| `GET`/`POST` | `/api/orgs/:orgId/members` | CLINIC_ADMIN | list / invite staff |
| `PATCH`/`DELETE` | `/api/orgs/:orgId/members/:membershipId` | CLINIC_ADMIN | role / status |
| `PUT` | `/api/orgs/:orgId/members/:membershipId/capabilities` | CLINIC_ADMIN | grant/revoke `MembershipCapability[]` (e.g. `CLINICAL_RECORD_READ`); audited (`MEMBER_CAPABILITY_GRANTED/REVOKED`). **Separation of duties:** the acting admin **cannot target their own membership** (`:membershipId` ≠ the caller's membership) — `403 CANNOT_SELF_GRANT_CAPABILITY`. A `CLINICAL_RECORD_*` capability can only be granted by a *different* authorized `CLINIC_ADMIN`. A clinic with a single admin therefore cannot self-enable clinical access — add a second admin. |

### Invitations
| Method | Path | Role | Notes |
|---|---|---|---|
| `POST` | `/api/orgs/:orgId/invitations` | CLINIC_ADMIN | scope `CLINIC_STAFF`/`CLINIC_PATIENT`; returns raw token once |
| `POST` | `/api/invitations/:token/validate` | authenticated | preview (no consume) |
| `POST` | `/api/invitations/:token/accept` | authenticated | consume atomically |
| `POST` | `/api/orgs/:orgId/invitations/:id/revoke` | CLINIC_ADMIN | |

### Doctors & availability
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET`/`POST` | `/api/orgs/:orgId/doctors` | member / CLINIC_ADMIN | |
| `GET`/`PATCH` | `/api/orgs/:orgId/doctors/:id` | member / self+admin | |
| `GET`/`PUT` | `/api/orgs/:orgId/doctors/:id/availability` | member / self+admin | `AvailabilityRule[]` |
| `GET`/`POST`/`DELETE` | `/api/orgs/:orgId/doctors/:id/availability/exceptions` | self+admin | leave / holiday / extra hours |
| `GET` | `/api/orgs/:orgId/doctors/:id/slots?date=YYYY-MM-DD&typeId=` | member | **computed** free slots (see APPOINTMENT_WORKFLOW.md) |

### Patients & family
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET`/`POST` | `/api/orgs/:orgId/patients` | RECEPTIONIST+ | search by name/phone/mrn |
| `GET`/`PATCH` | `/api/orgs/:orgId/patients/:id` | authorized | demographics; clinical fields gated |
| `GET` | `/api/orgs/:orgId/patients/:id/appointments` | authorized | |
| `GET` | `/api/orgs/:orgId/patients/:id/medications` | authorized (`VIEW_MEDICATIONS`) | |
| `GET` | `/api/orgs/:orgId/patients/:id/documents` | authorized (`VIEW_DOCUMENTS`) | metadata list |
| `GET` | `/api/orgs/:orgId/patients/:id/history` | DOCTOR (authorized) / CLINIC_ADMIN* | consultations + prescriptions |
| `GET`/`POST` | `/api/me/family` | PATIENT | dependents |
| `POST` | `/api/me/family/:patientId/grants` | PATIENT (owner) | create `PatientAccessGrant` |
| `DELETE` | `/api/orgs/:orgId/patients/:id/grants/:grantId` | owner / CLINIC_ADMIN | revoke |

### Appointments
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/orgs/:orgId/appointments?from=&to=&doctorId=&patientId=&status=` | member (scoped) | |
| `POST` | `/api/orgs/:orgId/appointments` | PATIENT (self) / RECEPTIONIST+ | body: `patientId, doctorId, start, appointmentTypeId?, reason?` → validated + double-booking-safe |
| `GET` | `/api/orgs/:orgId/appointments/:id` | authorized | includes `events[]` |
| `PATCH` | `/api/orgs/:orgId/appointments/:id` | RECEPTIONIST+ / DOCTOR (own) | reason/notes/type |
| `POST` | `/api/orgs/:orgId/appointments/:id/confirm` | RECEPTIONIST+ | `REQUESTED → CONFIRMED` |
| `POST` | `/api/orgs/:orgId/appointments/:id/reschedule` | patient† / RECEPTIONIST+ | creates a new appointment, links lineage, old → `RESCHEDULED` |
| `POST` | `/api/orgs/:orgId/appointments/:id/cancel` | patient† / RECEPTIONIST+ | body: `reason` |
| `POST` | `/api/orgs/:orgId/appointments/:id/check-in` | RECEPTIONIST+ | → `CHECKED_IN`, creates `QueueEntry` |
| `POST` | `/api/orgs/:orgId/appointments/:id/no-show` | RECEPTIONIST+ / DOCTOR | `CONFIRMED → NO_SHOW` |
| `POST` | `/api/orgs/:orgId/appointments/:id/start` | DOCTOR (own) | → `IN_CONSULTATION` |
| `POST` | `/api/orgs/:orgId/appointments/:id/complete` | DOCTOR (own) | → `COMPLETED` |

### Queue
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/orgs/:orgId/queue?doctorId=&date=` | member | live board |
| `POST` | `/api/orgs/:orgId/queue/:entryId/call` | DOCTOR (own) / RECEPTIONIST | `WAITING → CALLED` |
| `POST` | `/api/orgs/:orgId/queue/:entryId/recall` | same | re-announce, `recallCount++` |
| `POST` | `/api/orgs/:orgId/queue/:entryId/skip` | same | `→ SKIPPED` |
| `POST` | `/api/orgs/:orgId/queue/:entryId/start` | DOCTOR (own) | `→ IN_CONSULTATION` |
| `POST` | `/api/orgs/:orgId/queue/:entryId/complete` | DOCTOR (own) | `→ COMPLETED` |

### Consultations & prescriptions
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET`/`POST`/`PATCH` | `/api/orgs/:orgId/consultations` (+`/:id`) | DOCTOR (own appointment) | SOAP fields, follow-up |
| `POST` | `/api/orgs/:orgId/consultations/:id/sign` | DOCTOR (own) | sets `signedAt`, locks edits |
| `GET`/`POST` | `/api/orgs/:orgId/prescriptions` (+`/:id`) | DOCTOR (own) | items inline |

### Documents
| Method | Path | Role | Notes |
|---|---|---|---|
| `POST` | `/api/orgs/:orgId/patients/:id/documents` | authorized | Phase 0: metadata + `local-dev` key. Later: pre-signed upload URL. |
| `GET` | `/api/orgs/:orgId/documents/:id` | authorized (`VIEW_DOCUMENTS`) | metadata; download URL is short-lived |

### Medications (DoseWise sync target)
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/orgs/:orgId/patients/:id/medications` | authorized | full list + schedules |
| `POST` | `/api/sync/medications` | PATIENT (self) | offline-first batch: `{ medications[], doses[], deletions[], since }` → `{ applied, serverChanges, checkpoint }`. Mirrors the app's outbox model; last-writer-wins on `updatedAt`. |
| `GET` | `/api/orgs/:orgId/patients/:id/adherence?from=&to=` | authorized | computed `AdherenceStats` |

### Notifications
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/me/notifications` | authenticated | in-app feed |
| `POST` | `/api/me/devices` | authenticated | register FCM token (stored hashed-at-rest reference, never in audit) |
| `POST` | `/api/internal/notifications/dispatch` | **`X-Cron-Key` secret** (no user auth); miss → `404` | claims + sends due `Notification` rows; idempotent; concurrency-safe; returns `{ claimed, sent, failed, requeued, reaped }`; no PHI. Invoked every 60s by an external cron (see [DEPLOYMENT.md](DEPLOYMENT.md) / [NOTIFICATION_ARCHITECTURE.md](NOTIFICATION_ARCHITECTURE.md)). |

### Reports & export
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/orgs/:orgId/reports/appointments?from=&to=` | CLINIC_ADMIN / DOCTOR (own) | counts by status, no-show rate |
| `GET` | `/api/orgs/:orgId/patients/:id/export?format=json\|csv` | authorized | adherence + appointment history |

### Audit
| Method | Path | Role | Notes |
|---|---|---|---|
| `GET` | `/api/orgs/:orgId/audit?entityType=&entityId=&from=&to=` | CLINIC_ADMIN | own-org only |

\* `CLINIC_ADMIN` reaches clinical bodies **only** with the
`CLINICAL_RECORD_READ` capability on their membership (absent by default;
granting and every use is audited). A `DOCTOR` additionally needs an
appointment/grant link to the patient. See [RBAC.md](RBAC.md) /
[MEDICAL_DATA_SECURITY.md](MEDICAL_DATA_SECURITY.md).
† subject to `ClinicSettings.cancellationWindowHours` / `bookingLeadTimeMinutes`.

## Per-endpoint documentation shape (spec §24)

Each endpoint in the generated OpenAPI carries: method, path, auth
requirement, required role, tenant scope, request schema, response schema,
error codes, and validation rules — derived from the Zod schemas in
`src/modules/<domain>/schema.ts` so docs cannot drift from code.

## OpenAPI (spec §25)

`@asteasolutions/zod-to-openapi` builds `docs/openapi.yaml` from the module
schemas at build time; a `GET /api/openapi.json` route serves it in dev. Written
after the modules exist (post Phase-0 sign-off).
