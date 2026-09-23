# Healthcare discovery & booking in the DoseWise app

DoseWise is two interfaces over **one** backend: the Next.js platform
(`platform/`) where clinics, doctors and reception staff work, and this
Flutter app, where patients discover those clinics and manage their own
appointments. There is no second source of truth — the app reads and writes
the platform's REST API and shows exactly what it returns.

```
Web/Admin → Organization → Locations → Doctors → Availability → Public listing
                                   ↓
                         REST API (/api/public/…, /api/orgs/…, /api/patient/…)
                                   ↓
        Flutter: discovery → organization → branch → doctor → date → real slots
                                   ↓
                     booking → appointment → queue → reschedule/cancel
```

Nothing in the medicine-reminder product changed behaviour: reminders,
exact alarms, Taken/Snooze/Skip, history, adherence, voice, SQLite, offline
use and family sync are untouched. The healthcare block is additive.

---

## 1. Audit

### Existing (reused, not rebuilt)

| Concern | What already existed |
|---|---|
| Foundations | `provider` DI, `flutter_localizations` (en/hi), `AppTheme` (Material 3, large touch targets), `intl`, `timezone` (+ `flutter_timezone`), shared card/ListTile idiom |
| Medicine product | SQLite repositories, dose scheduler, notification service, family sync, account deletion |
| Config precedent | `SharedPreferences` for user settings; `--dart-define` for build-time values |

### Backend available (used as-is — no new endpoints invented)

All of these already existed on the platform; the app is the first mobile
consumer.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/public/organizations` | none | Published clinics: `q`, `city`, `orgType`, `page`, `pageSize` |
| GET | `/api/public/organizations/{slug}` | none | Public profile + locations + bookable doctors |
| GET | `/api/public/doctors` | none | Public doctors: `q`, `specialty`, `organizationSlug` |
| GET | `/api/public/doctors/{doctorId}` | none | Public doctor profile + clinic + its locations |
| GET | `/api/public/doctors/{doctorId}/slots?date=YYYY-MM-DD` | none | Real open slots, the clinic's timezone and duration |
| POST | `/api/auth/register` | none | Create a platform account |
| POST | `/api/auth/login` | none | `X-Client: app` → `{accessToken, refreshToken}` in the body |
| POST | `/api/auth/refresh` | none | Rotates the refresh token |
| POST | `/api/auth/logout` | bearer | Best-effort server-side sign-out |
| GET | `/api/me` | bearer | Profile (name/phone prefill) |
| GET | `/api/orgs` | bearer | Clinics this account belongs to (with role) |
| GET | `/api/orgs/{orgId}/appointments` | bearer | This patient's own rows (server-side ownership filter) |
| GET | `/api/orgs/{orgId}/appointments/{id}` | bearer | Detail incl. `queueEntry` |
| POST | `/api/patient/appointments` | bearer | Self-booking (`organizationId`, `doctorId`, `scheduledStart`, `locationId?`, `reason?`, `patient{…}`) |
| POST | `/api/orgs/{orgId}/appointments/{id}/cancel` | bearer | Cancellation (clinic's own window enforced server-side) |
| POST | `/api/orgs/{orgId}/appointments/{id}/reschedule` | bearer | Creates the replacement appointment, marks the old one RESCHEDULED |

The visibility rule is the backend's: `isActive AND isPubliclyListed` (on
both the organization and the doctor). The app never fetches “all
organizations” and never re-implements that filter.

### Flutter missing (added by this work)

An HTTP/JSON layer, platform session (bearer + rotating refresh token),
organization/doctor/slot/appointment models, three repositories, the
discovery → booking → appointment screens, and empty/loading/error states.

### Backend gaps found (not faked in the app)

1. **Patient-facing queue counter.** A patient can read their own ticket
   (`tokenNumber`, `state`, `position`) from their appointment, but
   `GET /api/orgs/{orgId}/queue` is a **staff** board (it exposes other
   patients' names) and is not patient-callable, so the app shows the
   patient's own token, state and people-ahead derived from `position` —
   not “now serving”.
2. **Patient self check-in.** `…/check-in` asserts `RECEPTIONIST` /
   `CLINIC_ADMIN`. Check-in stays reception-driven; the app explains that
   and shows the ticket once the clinic adds the patient to the queue.
3. **Booking for a dependent.** The API accepts `patientId` for a patient
   the caller holds a grant on, but there is no HTTP endpoint that lists
   *my* dependents in a clinic (the web page calls the service directly),
   so the app books for the account holder only.
4. **Booking policy is not published.** `allowPatientSelfBooking`,
   `bookingLeadTimeMinutes`, `cancellationWindowHours` and
   `maxAdvanceBookingDays` live in `ClinicSettings`, which has no public
   projection, so the app cannot pre-empt those rules — it surfaces the
   backend's own error (`CONFLICT`, `OUTSIDE_CANCELLATION_WINDOW`,
   `FORBIDDEN`) with the server's message.
5. **Doctor ↔ location association is not public.** The app lets the
   patient pick the branch they will visit (recorded on the appointment as
   `locationId`) but cannot claim a doctor works only at one branch.
6. **Appointment type catalogue is not public.** `/api/orgs/{orgId}/appointment-types`
   needs a membership, so bookings omit `appointmentTypeId` and inherit the
   clinic's default duration — the same default `computeSlots` used to
   compute the slots that were shown.

---

## 2. What was added in the app

```
lib/core/config/platform_api_config.dart      base URL (dart-define + QA override)
lib/data/api/api_client.dart                  bearer, X-Client: app, refresh-retry, envelope → ApiException
lib/data/api/api_exception.dart               typed failures (+ network/timeout/malformed)
lib/data/api/token_store.dart                 token pair + in-memory store
lib/data/api/secure_token_store.dart          OS keystore (EncryptedSharedPreferences)
lib/data/models/healthcare/*.dart             organization, location, doctor, availability,
                                              appointment, queue, page, me/orgs
lib/data/repositories/healthcare_repository.dart   public discovery + short-lived detail cache
lib/data/repositories/appointment_repository.dart  booking, my appointments, cancel, reschedule
lib/services/platform_auth_service.dart       platform session (separate from Firebase auth)
lib/features/healthcare/
  healthcare_home_screen.dart                 search + provider types + city filter + paging
  organization_profile_screen.dart            cover/logo/about/contact/locations/doctors + CTA
  doctor_profile_screen.dart                  public doctor profile + booking CTA
  slot_picker_screen.dart                     date strip + real slots (also reschedules)
  booking_screen.dart                         patient details → confirm
  booking_confirmation_screen.dart            backend-confirmed result + reference
  appointments_screen.dart                    Upcoming / Past / Cancelled
  appointment_detail_screen.dart              details + queue ticket + cancel/reschedule
  platform_sign_in_screen.dart                sign in / create account
  widgets/healthcare_widgets.dart             section header, skeleton, empty, error, status chip,
                                              organization/doctor cards, HcAsyncView
  widgets/home_care_section.dart              the home-screen “Care” block
  healthcare_format.dart                      clinic-timezone date/time, fees, status labels
```

### Data flow

```
Screen → repository → ApiClient → REST API → platform service → PostgreSQL
```

No widget builds a URL, and no HTTP call exists outside `ApiClient`.
`X-Client: app` is always sent so the API answers with tokens instead of a
web session cookie. A 401 triggers **one** single-flight refresh (refresh
tokens rotate on use, so parallel refreshes would destroy the session) and a
single retry; a refused refresh clears the session and the UI asks the user
to sign in again.

### Responsibilities kept on the server

* which organizations/doctors are visible (`isPubliclyListed`, `isActive`)
* which slots exist (lead time, availability rules, exceptions, booked rows)
* double-booking (serializable transaction inside `bookAppointment`)
* whether the caller may read/cancel/reschedule *this* appointment
* the clinic's cancellation window
* the appointment's status and queue state

The app never invents a slot, a fee, a rating, a doctor count, a distance or
an availability flag. Fields the API does not publish are simply hidden.

---

## 3. UX decisions

* **Medicine stays first.** Home keeps the “next medicine → today's schedule
  → progress” order; the healthcare block is a clearly separate “Care”
  section with one way in (“Find healthcare”) plus, only when it exists, the
  next real appointment. No fifth bottom-navigation tab.
* **Browse without an account.** Discovery, profiles and slots are public;
  the sign-in wall appears only where the API requires it (confirming a
  booking, viewing appointments) and explains why.
* **Few choices at a time.** Organization → branch (only when there is more
  than one) → doctor → date → time → details → confirm, one decision per
  screen, with large buttons (primary actions are full-width, height ≥ 54).
* **Clinic time, not phone time.** All times and dates are rendered in the
  clinic's IANA zone from the API payload, with a one-line note telling the
  patient so.
* **States are designed, not defaulted.** Skeletons instead of spinners,
  empty states that explain what to do next, error states that use
  `ApiException` to distinguish “you are offline” from “this clinic is no
  longer listed”, each with a retry.
* **Status is never colour-only.** Every status is a chip with a word
  (`Requested`, `Confirmed`, `Waiting`, `Cancelled`, …).

---

## 4. Tests

* `test/healthcare_api_test.dart` — client headers/bearer, fail-fast without
  a session, error-envelope mapping, refresh-then-retry, session cleared on a
  refused refresh, transport failure mapping; organization/doctor/slot
  parsing and query passthrough; appointment merge across clinics, booking
  payload shape, slot-taken error, reschedule replacement, queue ticket;
  sign-in / register→sign-in / wrong password / dead stored session.
* `test/healthcare_widget_test.dart` — discovery list, empty state, error +
  retry, slots rendered in clinic time, no-slots state, appointments
  sign-in gate, appointment rows from the patient's clinics, home care
  section signed in/out.
* `test/healthcare_test_helpers.dart` — fake platform API that records every
  request, so assertions are on real URLs/headers/bodies.
* `test/home_widget_test.dart` — updated to provide the healthcare providers,
  proving the medicine dashboard still renders with the clinic API failing.

---

## 5. Configuration

```bash
# point the app at a clinic platform deployment
flutter run --dart-define=PLATFORM_API_BASE_URL=https://<host>/api
```

The compiled default is `http://10.0.2.2:3000/api` (a Next.js dev server on
the developer's machine, seen from the Android emulator). Debug builds can
override the address at runtime from the healthcare screen's overflow menu →
“Clinic server (QA)”; release builds use the compiled value only.

---

## 6. Known limitations / open items

* Queue “now serving” is not patient-visible (backend gap 1).
* Check-in remains reception-driven (backend gap 2).
* Booking for a dependent is not implemented in the app (backend gap 3).
* Booking rules (lead time, cancellation window, self-booking toggle) are
  enforced only by the backend, surfaced as errors (backend gap 4).
* No Google sign-in for the platform account on mobile — the platform's
  Google flow is a browser redirect that returns a session cookie, so the
  app uses email + password (`X-Client: app`).
* Appointment photos/consultation summaries/prescriptions are not surfaced;
  the patient-facing endpoints for those do not exist yet.
* `flutter build apk --release` in this checkout additionally requires
  `android/app/google-services.json`, which is deliberately untracked.
