# DoseWise — Existing Functionality Inventory

Inventory of the current Flutter app (`/lib`, `/functions`, `/android`,
`firestore.rules`) as inspected for Phase 0. For each feature: current
implementation, storage, dependencies, reuse verdict, required changes, what
must stay untouched, and migration requirements.

**Global rule:** nothing in `lib/`, `android/`, `functions/`, `test/`,
`firestore.rules`, `pubspec.yaml`, or the ARB files is modified in Phase 0.
The app must keep building and its tests must stay green.

Legend for **Reuse**: ✅ reuse as-is · ♻️ reuse with a server port ·
🔒 keep client-only, untouched · ⚠️ needs a product decision.

---

## Reuse register (confirmed 2026-09-10)

Every item below is **kept and planned for reuse**. **None is modified,
removed, or rewritten in Phase 0.** The full analysis for each is in the
numbered sections that follow.

| Existing DoseWise capability | Reuse | Planned target | §  |
|---|:--:|---|:--:|
| Firebase Authentication | ♻️ | platform `/api/auth/*` (parallel run first) | 1 |
| Google Sign-In | ♻️ | platform Google OAuth, linked by `sub` | 1 |
| Guest access (offline, no account) | ✅ | stays offline-only; mapping deferred → [GUEST_ACCESS.md](GUEST_ACCESS.md) §2 | 3 |
| Medicine management | ♻️ | `Medication` / `MedicationSchedule` | 7, 8 |
| Medicine schedules | ♻️ | `MedicationSchedule` (identical shape) | 8 |
| Taken / Snooze / Skip (+ Missed) | ♻️ | `MedicationDose` + `/api/sync/medications` | 9 |
| Medicine history | ♻️ | derived from `MedicationDose` | 10 |
| Adherence | ♻️ | `AdherenceStats` recomputed server-side | 10 |
| Stock tracking | ♻️ | `Medication.stockCount` | 11 |
| Refill tracking | ♻️ | `Medication.refillAt` (+ client notification) | 11 |
| Family Sync | ♻️ | `FamilyRelationship` + `PatientAccessGrant` | 12 |
| QR functionality | ♻️ | platform `Invitation` (same hashed/single-use/TTL model) | 13 |
| Export | ♻️ | `/api/.../export?format=json\|csv` (JSON = importer input) | 14 |
| Voice (TTS) | 🔒 | client-only, untouched forever | 16 |
| English / Hindi localization | ✅ | ARB strings reused; server message catalogue mirrors them | 17 |
| Local database / offline behaviour | 🔒 | stays the app's offline store; mirrored, not replaced | 6 |
| Notification infrastructure | 🔒 | client-only; platform notifications are additive | 18 |
| Backup / restore | ♻️ | importer input (esp. vitals) | 15 |
| Home-screen widget | 🔒 | client-only, untouched | 20 |
| Drug interaction checker | ⚠️ | left exactly as-is; **not** ported (spec §39) | 21 |
| Vitals log | ♻️ | new `VitalReading` table (best-effort import) | 22 |

---

## 1. Firebase Authentication (Google Sign-In)

- **Implementation:** `lib/services/auth_service.dart` — `AuthService extends
  ChangeNotifier`; `GoogleSignIn` + `GoogleAuthProvider.credential` →
  `FirebaseAuth.signInWithCredential`. Degrades gracefully when Firebase is
  unconfigured (app fully usable offline). Used by `login_screen.dart`,
  `profile_screen.dart`.
- **Storage:** Firebase Auth (client SDK) — token cache on device. Display
  name / age also mirrored into SharedPreferences (`user_name`, `user_age`).
- **Dependencies:** `firebase_auth`, `firebase_core`, `google_sign_in`,
  `google-services.json` (project `remind-me-b7830`).
- **Reuse:** ♻️ — replace with platform `/api/auth/*` (email/password + Google
  OAuth, same Google `sub`).
- **Changes required:** new API client + token storage in Flutter (Phase 1);
  account-link Firebase Google user → platform `User`.
- **Untouched (Phase 0):** all of it.
- **Migration:** map Firebase `uid`/Google `sub` → `User` + `IdentityAccount`.
  See [AUTHENTICATION.md](AUTHENTICATION.md).

## 2. Anonymous auth (sync identity)

- **Implementation:** `lib/services/sync/firebase_backend.dart` →
  `signInAnonymously()`. This is the identity used for Firestore household
  sync — **separate** from the Google account.
- **Storage:** Firebase Auth anonymous credential on device.
- **Dependencies:** `firebase_auth`.
- **Reuse:** ♻️ / retire — replaced by an authenticated platform `User`.
- **Changes required:** Phase 3 prompts anonymous-only users to sign in to keep
  cloud sync; local data never lost.
- **Migration:** carry the anonymous household id on the client during the
  cutover so synced data can be re-homed to a `Patient` + `Medication` rows.

## 3. Guest / offline use

- **Implementation:** `LoginScreen(onSkip:)` — the whole app works with no
  auth; profile shows "Guest User" (`profileGuestUser`) when `user_name` is
  empty. No server, no Firebase, no data leaves the device in this state.
- **Storage:** none (local SQLite + SharedPreferences only).
- **Dependencies:** none.
- **Reuse:** ✅ concept — the Flutter app must keep working with **no platform
  account**. Platform features (appointments, clinic-visible sync) simply
  require sign-in; local functionality never does.
- **Untouched:** yes.
- **Not the same as platform "guest mode".** The platform's guest mode is a
  sandboxed demo-org session for previewing the product — see
  [GUEST_ACCESS.md](GUEST_ACCESS.md), which documents both and keeps them
  clearly separate.
- **Migration / mapping — DECISION DEFERRED:** how (or whether) a DoseWise
  offline "guest" becomes a platform account is an explicit open decision
  (candidates in [GUEST_ACCESS.md](GUEST_ACCESS.md) §2). Current assumption:
  stays offline-only; must register to sync. Nothing implemented in Phase 0.

## 4. User profile

- **Implementation:** `profile_screen.dart` + `SettingsController` — edit name
  and age, sign out.
- **Storage:** SharedPreferences (`user_name`, `user_age`) + Firebase Auth
  display name.
- **Dependencies:** `provider`, `shared_preferences`, `firebase_auth`.
- **Reuse:** ♻️ — becomes `User.fullName` + a self-owned `Patient` record.
- **Changes required:** profile edits call the API once signed in.
- **Migration:** `user_name` → `User.fullName`; `user_age` → derive/store on
  the self `Patient` (`dateOfBirth` unknown → keep `age` as a transitional
  note; not a schema field — capture DOB going forward).

## 5. Firestore (household sync store)

- **Implementation:** `firebase_backend.dart` implements the `RemoteBackend`
  interface. Layout: `households/{code}`, `.../members/{uid}`,
  `.../medicines/{id}`, `.../doses/{medId_ts}`, `invitations/{sha256(token)}`.
  Batched writes; `updated_at` (UTC ISO-8601) for lexical ordering.
- **Storage:** Cloud Firestore.
- **Dependencies:** `cloud_firestore`, `firebase_auth`, `firestore.rules`.
- **Reuse:** ♻️ — the **`RemoteBackend` abstraction is the migration seam**: a
  new `HttpBackend` implementing the same interface points sync at the platform
  API instead of Firestore.
- **Changes required:** new `RemoteBackend` implementation; endpoint
  `/api/sync/medications`.
- **Untouched (Phase 0):** yes.
- **Migration:** one-off script: `households/*` → `Family` links +
  `PatientAccessGrant`; `medicines`/`doses` → `Medication`/`MedicationDose`
  keyed by `(sourceDeviceId, legacyLocalId)` / `(medicationId,
  scheduledAtLocal)`. See [MEDICINE_DATA_MIGRATION.md](MEDICINE_DATA_MIGRATION.md).

## 6. Local database (SQLite)

- **Implementation:** `lib/data/database/app_database.dart` — sqflite, schema
  **v8**, migrations codified in `onUpgrade`. Tables: `medicines`,
  `medicine_schedules`, `medicine_doses`, `sync_tombstones`,
  `sync_dose_tombstones`, `sync_outbox`. FK + `ON DELETE CASCADE` on
  `medicine_doses` / `medicine_schedules`. Index `idx_doses_scheduled`.
- **Storage:** on-device SQLite (`medireminder.db`); web uses
  `sqflite_common_ffi_web` (WASM).
- **Dependencies:** `sqflite`, `sqflite_common_ffi_web`,
  `sqflite_common_ffi` (tests).
- **Reuse:** 🔒 stays as the app's offline store, unchanged. Its **schema is
  the source model** for the Postgres medication tables.
- **Changes required:** none to the local DB. Add a client-side "cloud id"
  column later only if needed for the HTTP backend (the app already keys doses
  by `(medicine_id, scheduled_at)`).
- **Migration:** structural mapping only — the local DB is not "migrated
  away", it is mirrored to the server.

## 7. Medicine management (CRUD)

- **Implementation:** `medicine_repository.dart`, `medicine_form_screen.dart`,
  `medicines_screen.dart`. Fields: name, dosage, dosage_unit, notes,
  `FoodInstruction`, `MedicineFrequency` (`daily`/`specificDays`/`once`/
  `multiple`), `selectedDays` (CSV weekday ints), `onceDate`, `active`,
  `stock_count`, `refill_at`. Insert/update in a transaction that also rewrites
  schedules; enqueues `sync_outbox`.
- **Storage:** SQLite `medicines` (+ `medicine_schedules`).
- **Dependencies:** `sqflite`, `provider`.
- **Reuse:** ♻️ model + rules → `Medication` / `MedicationSchedule`.
- **Changes required:** server CRUD via `/api/.../medications`; keep local CRUD
  for offline.
- **Untouched:** the Flutter screens/repos in Phase 0.
- **Migration:** field-for-field, see [MEDICINE_DATA_MIGRATION.md](MEDICINE_DATA_MIGRATION.md).

## 8. Medicine schedules (reminder times)

- **Implementation:** `MedicineSchedule` (`hour`, `minute`, `enabled`);
  replaced wholesale on medicine update.
- **Storage:** SQLite `medicine_schedules`.
- **Reuse:** ♻️ → `MedicationSchedule` (identical shape).
- **Migration:** direct copy per medication.

## 9. Dose occurrences + Taken / Snooze / Skip / Missed

- **Implementation:** `dose_repository.dart`, `dose_scheduler.dart`,
  `dose_action_handler.dart`, `app_state.dart`. `DoseStatus` =
  `pending|taken|skipped|missed`. `ensureDose(medicineId, scheduledAt)`
  materialises rows for a rolling **7-day** window; `sweepMissed(grace, now)`
  flips overdue pending → missed; snooze sets `snoozed_until`. Identity
  `(medicine_id, scheduled_at)`. Every change enqueues `sync_outbox`.
- **Storage:** SQLite `medicine_doses` (+ `sync_dose_tombstones`).
- **Dependencies:** `sqflite`, `flutter_local_notifications`, `timezone`.
- **Reuse:** ♻️ → `MedicationDose`. `scheduled_at` (naive local) →
  `scheduledAtLocal` + `timezone`.
- **Changes required:** server accepts dose deltas via `/api/sync/medications`;
  LWW on `updatedAt` (already the app's model).
- **Untouched:** the scheduler/handler logic (Phase 0).
- **Migration:** by `(medicationId, scheduledAtLocal)`; tombstones → `deletedAt`.

## 10. Medicine history + adherence

- **Implementation:** `history_screen.dart`, `adherence_report_screen.dart`,
  `doctor_report_screen.dart`; `AdherenceStats` (taken/missed/skipped/pending,
  `adherencePercent`); `DoseRepository.statsBetween(...)` uses the grace period
  for effective status.
- **Storage:** derived from SQLite `medicine_doses`.
- **Reuse:** ♻️ — `AdherenceStats` math re-implemented server-side for
  `/api/.../adherence`; the doctor report becomes an authorized clinic view.
- **Untouched:** the screens (Phase 0). UI later restyled to the DoseWise
  design language (indigo/coral) keeping all features.
- **Migration:** none beyond the dose data itself.

## 11. Medicine stock + refill tracking

- **Implementation:** optional `stock_count` / `refill_at` on `medicines`
  (DB v6). `AppState._checkRefillReminders()` fires `showRefillAlert` when
  `stock_count <= refill_at` on every refresh.
- **Storage:** SQLite `medicines.stock_count`, `medicines.refill_at`.
- **Reuse:** ♻️ → columns on `Medication` (`stockCount`, `refillAt`). Refill
  **notification** stays client-side.
- **Migration:** direct copy.

## 12. Family Sync (households, roles, permissions)

- **Implementation:** `invitation_service.dart`, `sync_service.dart`,
  `firebase_backend.dart`, family screens under `lib/features/settings/`.
  Roles `owner` / `member` (legacy `primary`/`watcher`/`admin` normalised).
  `FamilyPermissions { shareMedicines, shareMissedAlerts }` default **false**.
  Owner-only member removal; no self-promotion (enforced by `firestore.rules`).
- **Storage:** Firestore `households/{id}/members/{uid}`.
- **Dependencies:** `cloud_firestore`, `firebase_auth`, `crypto`.
- **Reuse:** ♻️ concept → `FamilyRelationship` + `PatientAccessGrant` with a
  richer permission enum. The security *guarantees* port to server RBAC + the
  cross-tenant/relationship test suite.
- **Changes required:** households are not clinic-aware today; the platform
  model separates "family access to a patient" from "clinic membership".
- **Untouched:** Firestore + rules in Phase 0.
- **Migration:** `members` → grants; default-private posture preserved.

## 13. QR functionality (family invitations)

- **Implementation:** `invitation_service.dart` (`createInvitation` /
  `validateInvitation` / `acceptInvitation` in a Firestore transaction;
  `cleanupExpired`); `family_qr_show_screen.dart` (`qr_flutter`),
  `family_qr_scan_screen.dart` (`mobile_scanner`). Token = 256-bit
  `Random.secure()`, `sha256` at rest, single-use, 24 h TTL. QR payload =
  `{"type":"dosewise_invite","token":<raw>,"v":1}` — token only, no PII.
- **Storage:** Firestore `invitations/{sha256(token)}`.
- **Dependencies:** `qr_flutter`, `mobile_scanner`, `crypto`, `cloud_firestore`.
- **Reuse:** ♻️ — the exact security model maps to the platform `Invitation`
  table (`hashedToken`, `scope`, `expiresAt`, `usedAt`, `revokedAt`), and is
  reused for clinic staff/patient joining too (spec §16).
- **Changes required:** payload gains a `scope` + points at a platform deep
  link; still token-only.
- **Untouched:** Phase 0.
- **Migration:** unconsumed invitations are not migrated (short TTL); regenerate.

## 14. Export

- **Implementation:** `export_service.dart` — `exportToJson()` (medicines +
  365-day dose history → pretty JSON in a dialog); CSV export on the History
  screen (`Date, Time, Medicine, Dose, Status`).
- **Storage:** none (generates a string; `share_plus` to share).
- **Dependencies:** `share_plus`.
- **Reuse:** ♻️ — becomes `/api/.../export?format=json|csv`; the JSON shape is
  also the **device-migration import format**.
- **Untouched:** Phase 0.
- **Migration:** the export JSON is a supported importer input.

## 15. Backup / restore

- **Implementation:** `backup_service.dart` — writes
  `dosewise_backup_<ts>.json` (medicines via `toMap()` + **all**
  SharedPreferences + metadata) to the app documents dir; `restoreBackup()`
  reads it back; `backup_screen.dart`.
- **Storage:** app documents directory (local file).
- **Dependencies:** `path_provider`, `shared_preferences`.
- **Reuse:** ♻️ — the backup JSON is the richest local snapshot and is the
  primary **import source for vitals** (which never synced). Cloud backup
  becomes server-side once signed in.
- **Untouched:** Phase 0.
- **Migration:** importer accepts this file; maps `medicines` + `vital_*` +
  relevant prefs.

## 16. Voice functionality (TTS)

- **Implementation:** `voice_service.dart` (`flutter_tts`, rate 0.45,
  `en-IN`/`hi-IN`); `AppState` auto-speak timer; `voice_mode_screen.dart`;
  spoken confirmations for taken/skipped/snoozed.
- **Storage:** none.
- **Dependencies:** `flutter_tts`.
- **Reuse:** 🔒 client-only. No backend involvement, ever.
- **Untouched:** entirely.
- **Migration:** none.

## 17. Localization (EN / HI)

- **Implementation:** `flutter gen-l10n` from `app_en.arb` + `app_hi.arb`
  (~370 keys), `l10n.yaml`, generated `AppLocalizations`. Locale in
  SharedPreferences; `Intl.defaultLocale` at boot.
- **Storage:** SharedPreferences (`locale`).
- **Dependencies:** `flutter_localizations`, `intl`.
- **Reuse:** ✅ strings reused. Server messages (notifications, emails) get a
  parallel `en`/`hi` message catalogue; `ClinicSettings.supportedLocales`
  defaults `["en","hi"]`; `User.locale`.
- **Untouched:** the ARB files (Phase 0).
- **Migration:** `locale` pref → `User.locale`.

## 18. Notification infrastructure

- **Implementation:** `notification_service.dart` (wraps
  `flutter_local_notifications`), `notification_background.dart`,
  `reminder_text.dart`, `dose_scheduler.dart`, `missed_dose_escalation.dart`.
  Versioned channels (**v10**): `medicine_reminders`,
  `medicine_reminders_silent`, `family_alerts`. Exact alarms (`alarmClock`),
  `fullScreenIntent`, ALARM audio stream, bundled WAV, insistent flag, custom
  vibration, LED. Boot receiver re-arms; scheduler reconciles OS alarms vs DB
  each app open. TAKEN/SNOOZE/SKIP handled from background + cold start.
- **Storage:** OS AlarmManager + the plugin's pending-notification store;
  channel config cached by Android.
- **Dependencies:** `flutter_local_notifications`, `flutter_timezone`,
  `timezone`; Android permissions in the manifest.
- **Reuse:** 🔒 stays fully client-side and unchanged. The platform's
  `NOTIFICATION_ARCHITECTURE` is **additive** (server events → push/email),
  and the core appointment system is **not** dependent on Android alarms
  (spec §19).
- **Untouched:** entirely, Phase 0 and beyond.
- **Migration:** none. FCM device token registration gains a platform endpoint
  (`POST /api/me/devices`).

## 19. Cloud Function (missed-dose FCM fan-out)

- **Implementation:** `functions/index.js` — `onDoseWrite` Firestore trigger:
  when a dose flips to `missed`, `sendEachForMulticast` to member FCM tokens.
  **Reads `household.data().members` as a map** — but membership is now a
  subcollection, so this is effectively stale/partially broken. Git history:
  a server-side scheduler was added (`00d799f`) then reverted (`cdf1ddf`) to
  stay on the free Spark plan.
- **Storage:** n/a (compute).
- **Dependencies:** `firebase-functions` ^5, `firebase-admin` ^12, Node 20.
- **Reuse:** ❌ — replaced by the platform `notifications` module.
- **Untouched:** Phase 0.
- **Migration:** REMOVE LATER (Phase 4).

## 20. Home-screen widget

- **Implementation:** `home_widget_service.dart` + native `DoseWidgetProvider`
  (RemoteViews). Data pushed via `home_widget` (SharedPreferences bridge).
- **Storage:** SharedPreferences (`widget_*` keys).
- **Dependencies:** `home_widget`; Android widget provider.
- **Reuse:** 🔒 client-only, untouched.
- **Migration:** none.

## 21. Drug interaction checker

- **Implementation:** `interaction_checker.dart` — a **static local** table of
  ~19 interaction groups; pure Dart; used in the medicine form / list.
- **Storage:** none (compile-time constants).
- **Dependencies:** none.
- **Reuse:** ⚠️ **conflicts with spec §39** ("no drug interaction engine").
  Verdict: leave the existing client-side feature exactly as-is; do **not**
  port it to the server or extend it without an explicit decision.
- **Untouched:** yes.
- **Migration:** none.

## 22. Vitals log

- **Implementation:** `vitals_log_screen.dart`, `vital_entry.dart` — BP /
  sugar / weight / temperature / heart rate with normal-range status.
- **Storage:** **SharedPreferences** (`vital_<id>` → `List<String>`).
  **Not in SQLite. Not synced anywhere.**
- **Dependencies:** `shared_preferences`.
- **Reuse:** ♻️ → new `VitalReading` table.
- **Changes required:** the app would need to write vitals to SQLite + outbox
  to sync them (currently it does not).
- **Migration:** best-effort only — from a device **backup JSON**, since
  there is no cloud copy today.

## 23. Onboarding / splash

- **Implementation:** `onboarding_screen.dart`, `splash_screen.dart`;
  `onboarding_done` flag.
- **Storage:** SharedPreferences (`onboarding_done`).
- **Reuse:** 🔒 client-only, untouched.
- **Migration:** none.

## 24. Settings

- **Implementation:** `settings_screen.dart` + `SettingsController` /
  `SettingsRepository`. Keys: `locale`, `sound_enabled`, `voice_enabled`,
  `snooze_minutes`, `grace_minutes`, `advance_minutes`, `theme_mode`,
  `user_name`, `user_age`, `onboarding_done`, `sync_enabled`,
  `household_code`, `sync_role`, `missed_alerts_enabled`, `last_sync_at`.
- **Storage:** SharedPreferences.
- **Reuse:** partial — device/notification prefs stay local; identity-ish
  prefs (`locale`, `user_name`, `user_age`) map to `User`; `household_code` /
  `sync_role` / `last_sync_at` are replaced by the platform sync state.
- **Untouched:** Phase 0.
- **Migration:** as noted per key above.

## 25. Existing tests

- **Implementation:** `test/` (~13 files) — dose repo/scheduler/handler,
  caregiver dashboard, export, family invitation (pure helpers only), sync
  service, home widget, medicine model/form, reliability fixes. Uses
  `sqflite_common_ffi` + `FakeScheduler` + a fake `RemoteBackend`.
- **Reuse:** ✅ — must keep passing throughout. The fake `RemoteBackend` is the
  template for testing the future `HttpBackend`.
- **Gap:** Firestore transactions/rules have **no** automated coverage — the
  platform must test the equivalent RBAC explicitly (spec §29).

---

## Must NOT be modified (Phase 0)

`lib/**`, `android/**`, `functions/**`, `test/**`, `firestore.rules`,
`pubspec.yaml`, `pubspec.lock`, `l10n.yaml`,
`lib/core/localization/app_en.arb`, `lib/core/localization/app_hi.arb`,
`assets/**`, `web/**`, the repo-root `docs/**`, `FEATURES.md`, `README.md`.
