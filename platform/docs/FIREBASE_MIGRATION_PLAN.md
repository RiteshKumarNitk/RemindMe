# Firebase Migration Plan

Firebase is **not** deleted immediately (spec §20). Each service is classified
`KEEP` / `MIGRATE` / `TEMPORARY` / `REMOVE LATER`, with a deliberate reason for
anything that stays.

Firebase project: `remind-me-b7830` · Android package `com.family.medireminder`.

## Service classification

| Firebase service | Used for | Class | Reason / target |
|---|---|---|---|
| **Auth — Google Sign-In** (`AuthService`) | interactive login, profile identity | **MIGRATE** | → platform `/api/auth/*` (email/password + Google OAuth via the same `sub`). Runs in parallel during Phase 1–2. |
| **Auth — Anonymous** (`FirebaseBackend.signIn`) | sync identity, separate from Google | **MIGRATE / REMOVE LATER** | replaced by an authenticated platform `User`. Anonymous-only users prompted once in Phase 3. |
| **Cloud Firestore** | household sync store (`households`, `members`, `medicines`, `doses`, `invitations`) | **MIGRATE** | → Postgres via `/api/sync/medications` + `Family`/`PatientAccessGrant`/`Invitation`. Frozen read-only, then removed in Phase 4. |
| **`firestore.rules`** | tenant/household isolation, single-use invites, owner-only removal | **MIGRATE** | re-implemented as server RBAC + the cross-tenant/relationship test suite. Removed with Firestore. |
| **Cloud Messaging (FCM)** | push transport for missed-dose alerts | **KEEP (as transport)** | the platform `notifications` module sends via FCM server credentials. No user-visible change. Device tokens re-registered via `POST /api/me/devices`. |
| **Cloud Functions** (`functions/onDoseWrite`) | FCM fan-out on missed dose (currently reads a legacy `members` map — likely already broken) | **REMOVE LATER** | superseded by the `notifications` module. Deleted in Phase 4. |
| **`google-services.json`** | Firebase SDK bootstrap on Android | **TEMPORARY** | required while any Firebase SDK is linked. Removed when `firebase_*` packages are dropped from `pubspec.yaml` (Phase 4). |
| **Firebase Hosting** (if any; `web/` + `docs/*.html`) | privacy policy / delete-account pages | **KEEP** | unrelated to the platform; leave as-is unless consolidated later. |

## Phase sequencing

### Phase 0 — backend foundation (now)
No Firebase change. Backend docs + schema only.

### Phase 1 — parallel run
- Flutter adds an optional platform API client + sign-in screen.
- Medication data **dual-writes**: the existing Firestore path stays; a new
  `RemoteBackend` implementation (`HttpBackend`) also posts to
  `/api/sync/medications`, behind a feature flag.
- Firebase Auth + Firestore untouched and fully functional.
- Exit criteria: platform sync verified against a pilot clinic; no data loss
  in dual-write for ≥ 2 weeks.

### Phase 2 — platform becomes primary for medication + family
- `HttpBackend` becomes the default `RemoteBackend`; Firestore writes stop.
- One-off importer runs: `households/*` → `FamilyRelationship` +
  `PatientAccessGrant`; `medicines`/`doses` → `Medication`/`MedicationDose`
  (see [MEDICINE_DATA_MIGRATION.md](MEDICINE_DATA_MIGRATION.md)).
- QR family invites switch to platform `Invitation` tokens (same security
  properties).
- Firestore set to read-only (rules tightened to deny writes) as a safety net.
- Exit criteria: all active households imported and reconciled; sync parity
  confirmed.

### Phase 3 — auth cutover
- Platform auth is the only auth in the app.
- Firebase Google users linked by `sub` on first platform sign-in.
- Anonymous-only users prompted once to sign in (Google or email) to retain
  cloud sync; local data untouched regardless.
- Firebase Auth usage stops.
- Exit criteria: < X% of MAU still unlinked; a grace window elapsed.

### Phase 4 — retire Firebase
- Delete `functions/`; remove the Firestore trigger.
- Remove `firestore.rules`.
- Drop `cloud_firestore`, `firebase_auth` from `pubspec.yaml`.
- Keep `firebase_messaging` + `firebase_core` **only if** FCM remains the push
  transport; otherwise remove those too and delete `google-services.json`.
- Archive the Firestore data export; decommission the Firebase project (or keep
  it solely for Hosting of the legal pages).

## Rollback posture

Each phase is reversible until Phase 4:
- Phase 1: disable the feature flag → pure Firebase behaviour.
- Phase 2: re-enable Firestore writes; the importer is idempotent and additive.
- Phase 3: re-enable the Firebase sign-in path (kept in the codebase until
  Phase 4).

## Risks specific to this migration

- **Two identities to reconcile** (Google + anonymous) — see AUTHENTICATION.md.
- **`onDoseWrite` legacy `members` map** — don't attempt to "fix forward";
  just replace.
- **FCM token handling** — tokens must never land in `AuditLog` or any log;
  stored only as an operational reference for the notifications module.
- **Free-tier constraint** — the reverted server-side scheduler (`cdf1ddf`)
  shows the intent to avoid Firebase Blaze costs; the platform's scheduler
  runs on Neon + the app host, not Firebase.
