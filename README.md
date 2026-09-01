# DoseWise

A simple, reliable medicine reminder app built for an elderly user (Android-first).
It answers one question on the home screen: **"Which medicine do I need to take now?"**

Reminders and tracking work **fully offline** — the local database is the source
of truth. Optional **Phase 2 cloud sync** (Firebase Auth + Firestore) lets a
caregiver view adherence and receive missed-dose push alerts.

> ⚠️ **Safety**: This app is a reminder and tracking tool only. It does not
> recommend medicines, change dosages, or give medical advice. Always follow
> the doctor's instructions.

---

## 1. Features

> 📋 A maintained, itemised feature inventory with changelog lives in
> [`FEATURES.md`](FEATURES.md) — keep it updated whenever features change.

- **Home dashboard** – greeting, "Next Medicine" card with a huge **TAKE MEDICINE**
  button, today's schedule, and Taken / Remaining / Missed counters.
- **Add / Edit medicine** – name, dose ("1 tablet"), reminder time(s), frequency
  (every day / specific days / once / multiple times a day), optional notes and
  food instruction.
- **Local notifications** with **TAKEN / SNOOZE / SKIP** action buttons. Work with
  the app closed, backgrounded, or the phone locked.
- **Snooze** – reschedules the reminder for a configurable duration (default 10 min).
- **History** – Today / This Week / All, with per-status counts and an adherence %.
- **Medicines list** – pause / resume / edit / delete (with confirmation).
- **Settings** – language (English / हिंदी), notification sound, voice reminder
  (text-to-speech), snooze duration, "missed after" grace period, dark mode,
  permission shortcuts, about/disclaimer.
- **Voice reminder** – optional spoken reminder ("दवा लेने का समय हो गया है") plus a
  speaker button on the home card; works while the app is running. Fully localised
  notification text.
- **Family & Sync (Phase 2)** – optional Firebase Auth sign-in. Syncs medicines
  and dose history to Firestore (offline-first: local DB stays the source of
  truth; `updatedAt`-based conflict resolution; tombstones for deletions). A
  caregiver can join the household by code and get **push alerts when a dose is
  missed** (via Cloud Function).

## 2. Technology

| Concern            | Choice                                                          |
| ------------------ | --------------------------------------------------------------- |
| Framework          | Flutter 3.35 / Dart 3.9, Material 3                             |
| State management   | `provider` + ChangeNotifier (single `AppState` controller)      |
| Database           | `sqflite` (local SQLite)                                        |
| Notifications      | `flutter_local_notifications` 20.1 + `timezone` + `flutter_timezone` |
| Settings           | `shared_preferences`                                            |
| Voice              | `flutter_tts`                                                    |
| Localization       | Flutter `gen_l10n` (ARB: English + Hindi, easily extendable)    |
| Tests              | `flutter_test` + `sqflite_common_ffi` (in-memory SQLite)        |
| Cloud sync (opt.)  | `firebase_core`, `firebase_auth`, `cloud_firestore`; Firebase Cloud Functions + FCM for caregiver alerts |

## 3. Project structure

```
lib/
  main.dart                     – entry point, service wiring, notification launch handling
  app.dart                      – providers, MaterialApp, bottom-nav shell (RootScreen / MainShell)
  core/
    constants/app_constants.dart
    theme/app_theme.dart        – Material 3, high contrast, large type
    localization/               – ARB files + generated AppLocalizations (en, hi)
    notifications/
      notification_service.dart – flutter_local_notifications wrapper (channels, exact alarms, actions)
      reminder_text.dart        – localized notification strings (no BuildContext needed)
    utilities/date_utils.dart
  data/
    database/app_database.dart  – sqflite schema (injectable for tests)
    models/                     – Medicine, MedicineSchedule, MedicineDose, DoseEntry, enums, stats
    repositories/               – medicine / dose / settings repositories (repository pattern)
  services/
    dose_scheduler.dart         – generates doses + reconciles OS notifications
    dose_action_handler.dart    – processes notification taps (taken / snooze / skip)
    settings_controller.dart    – settings ChangeNotifier
    voice_service.dart          – text-to-speech
    sync/
      remote_backend.dart       – abstract sync backend (interface)
      firebase_backend.dart     – Firebase Auth + Firestore implementation
      sync_service.dart         – push/pull merge, tombstones, missed-dose watch
  state/app_state.dart          – single app controller the UI watches
  features/
    home/ medicines/ history/ settings/ onboarding/
  features/widgets/             – shared large-tap-target widgets
```

The **data layer is separated from the UI**. `AppState` is the only entry point
screens talk to; repositories own all SQL; the notification service is the only
place that touches the OS notification API. A `ReminderScheduler` interface lets
the scheduler be unit-tested with a fake.

## 4. Database design

SQLite schema (version 3, foreign keys enabled) — three core tables plus a sync tombstone log:

```
medicines
  id, name, dosage, dosage_unit, notes, food_instruction,
  frequency (daily|specificDays|once|multiple),
  selected_days (CSV of 1..7), once_date (ISO), active (0/1),
  created_at, updated_at

medicine_schedules
  id, medicine_id (FK cascade), hour, minute, enabled

medicine_doses
  id, medicine_id, scheduled_at (ISO), status (pending|taken|skipped|missed),
  taken_at, skipped_at, snoozed_until, created_at, updated_at,
  UNIQUE (medicine_id, scheduled_at)

sync_tombstones          – deletions to propagate (v3)
  id, entity_type (medicine|dose), entity_id, deleted_at
```

### How reminders actually work (important)

- The `DoseScheduler` pre-generates a **rolling 14-day window** of `medicine_doses`
  rows from each medicine + schedule combination (respecting frequency and
  selected days).
- Each *future* pending dose gets **one individually scheduled notification**
  (`zonedSchedule`, notification id = dose id).
- On every app start / resume / data change, `sync()` reconciles:
  - schedules notifications that are missing,
  - cancels notifications whose dose was taken, skipped, deleted, paused or edited,
  - marks overdue pending doses as **missed** after the grace period.
- Statuses are **derived** (`effectiveStatus`) so a dose the user ignored becomes
  "Missed" automatically once `time + grace period` passes — even if the app was
  never opened.

### Notification reliability chain

1. **Exact alarms** (`exactAllowWhileIdle`) fire on time even in Doze / app closed.
   Falls back to inexact if the exact-alarm permission is missing or revoked.
2. **Boot receiver** (`ScheduledNotificationBootReceiver` from the plugin) re-arms
   all scheduled notifications after device reboot or app update.
3. **Start-up resync** self-heals anything else (edits, timezone changes, language
   changes, reinstalled schedules) whenever the app opens.
4. **Action buttons** (`TAKEN` / `SNOOZE` / `SKIP`) work both from the live
   callback and from a cold start (payload = `dose:<id>`; handled via
   `getNotificationAppLaunchDetails` in `main.dart`).

## 5. Android permissions

Declared in `AndroidManifest.xml`:

| Permission                    | Why                                                                 |
| ----------------------------- | -------------------------------------------------------------------- |
| `POST_NOTIFICATIONS`          | Show notifications (Android 13+; requested at runtime)               |
| `RECEIVE_BOOT_COMPLETED`      | Re-arm reminders after reboot                                        |
| `SCHEDULE_EXACT_ALARM`        | Exact delivery on Android 12 (requested at runtime via settings)     |
| `USE_EXACT_ALARM`             | Auto-granted for alarm apps on Android 13+                           |
| `VIBRATE` / `WAKE_LOCK`       | Vibration / wake for delivery                                        |

Runtime flows (also reachable from Settings → Permissions):
- **Notifications**: requested during onboarding and on demand; the home screen
  shows a banner when denied.
- **Exact alarms**: a friendly dialog opens the system "Allow exact alarms" page;
  a banner appears if reminders can't be exact.
- **Battery optimization**: Settings → Permissions → Battery opens the system
  battery-optimization screen so the user can exempt the app (recommended for
  OEMs that aggressively kill background alarms).

## 6. Building & running

```bash
flutter pub get
flutter gen-l10n          # regenerates AppLocalizations (also runs on build)
flutter analyze           # static analysis
flutter test              # unit + widget tests
flutter run               # on a connected Android device/emulator
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

Note: release builds are currently signed with the **debug key** (see
`android/app/build.gradle.kts`) — configure your own signing config before
distributing. The committed `android/app/google-services.json` is a documented
placeholder so the project builds without a Firebase project; replace it with
your own before enabling sync (see §9).

## 7. Manual test checklist for reminders

On a real device (this is the most important part of the app):

1. **Onboarding**: allow notifications and exact alarms.
2. **App closed / locked**: add a medicine 1–2 minutes in the future, lock the
   phone, close the app → notification fires on time with sound + vibration.
3. **Actions**: tap `TAKEN` (status becomes Taken), `SKIP` (Skipped),
   `SNOOZE` (fires again after the configured duration).
4. **Cold start from notification**: force-stop the app, let a reminder fire,
   tap an action → the app opens and the status is recorded.
5. **Reboot**: schedule a medicine for a few minutes ahead, reboot the phone,
   don't open the app → notification still fires (boot receiver).
6. **Do nothing**: let the reminder time pass; open the app after the grace
   period → the dose shows as Missed.
7. **Edit / delete**: change a medicine's time or delete it → no stale
   notifications fire; delete asks for confirmation.
8. **Same time / multiple doses**: two medicines at the same time produce two
   separate notifications.
9. **Permission denied**: deny notifications → home shows a banner; the app still
   works for tracking.
10. **Battery saver / optimization**: with battery saver on, exact alarms still
    fire; also exempt the app under Settings → Battery for worst-case OEMs.

## 8. Known Android limitations

- **Android 12+ exact alarms** need a one-time user grant (Settings screen). If
  denied, reminders fall back to inexact delivery (may be delayed a few minutes).
- **`USE_EXACT_ALARM`** is auto-granted but Play policy restricts it to apps whose
  core function is alarms — fine for a medicine reminder, worth keeping in mind
  for Play review.
- **Snoozed/background voice (TTS)** only speaks while the app process is alive;
  a full background voice reminder needs a foreground service (Phase 2).
- **Time zone / clock changes**: notifications are re-synced on every app open;
  a reminder already armed for an absolute time does not move if the user changes
  the time zone without opening the app afterwards.
- **DST edge case**: two identical local times on the same day can collide on the
  `UNIQUE(medicine_id, scheduled_at)` constraint (irrelevant in India; minor
  elsewhere).
- **Reboot rescheduling** depends on the plugin's own persisted schedule; our
  app-start resync is the safety net, so the first app open after a reboot
  re-arms everything definitively.
- OEM battery managers (MIUI, OnePlus, etc.) may kill the app; the Settings →
  Battery shortcut helps, exact alarms are the strongest available mechanism.

## 9. Phase 2 – Family & Caregiver sync (Firebase)

Optional cloud sync. **Nothing changes for users who never sign in** — the app
stays fully offline. When the primary phone signs in, medicines + dose history
sync to Firestore; a caregiver signs in on their phone, joins the same household
by code, sees adherence, and gets push alerts when a dose is missed.

### How it works

- **Offline-first**: the local SQLite DB remains the source of truth for
  reminders. Sync is best-effort background work on top of it.
- **Persistent pending-changes queue (outbox)**: every local change is queued
  into a `sync_outbox` table at write time and removed only after the backend
  confirms the upload. The queue survives network outages, app restarts and
  even clock jumps. A checkpoint reconcile on every app start re-queues
  anything changed since the last successful sync (upsert-based, so it is
  idempotent and safe) — the safety net for upgrades or a lost outbox.
- **Retry with backoff**: failed syncs keep the queue and retry automatically
  with exponential backoff + jitter (30s → 60s → … capped at 10 min), plus an
  immediate retry as soon as the network comes back (connectivity listener).
  The Family & Sync screen shows how many changes are waiting and when the
  next automatic retry happens.
- **Merge strategy**: every row carries `updatedAt`; the newest write wins.
  Deletes are recorded in `sync_tombstones` so a medicine removed on one phone is
  removed everywhere (not silently resurrected by an older copy).
- **Identity**: `households/{code}` Firestore docs; `members` map
  `{ uid: { role, joinedAt, fcmToken } }`. The primary phone creates a household
  (6-character code), caregivers join with the code. Cloud Function
  `onDoseWrite` fans out FCM push notifications when a dose flips to `missed`.
- **Missed-dose watch**: while the app runs, it subscribes to remote dose changes
  for the last 24h window and shows a local **Missed medicine** notification.
- **Caregiver dashboard**: in Family & Sync, a watcher can open **Family
  Dashboard** — the household's weekly adherence % (Taken/Missed/Skipped) and
  today's dose list. It pulls a fresh sync from Firestore on open and has a
  Refresh button; offline it shows the last synced copy.

### One-time Firebase setup (required before sync works)

1. Create a Firebase project (console.firebase.google.com) and add an **Android
   app** with your application id (`com.family.medireminder`).
2. Download `google-services.json` and replace
   `android/app/google-services.json` (the committed file is a documented
   placeholder — builds, but sync won't connect until replaced).
3. **Enable Authentication** → Sign-in method → **Anonymous** (no password flow
   for elderly users; account = the phone).
4. Create a **Cloud Firestore** database, then deploy the security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
5. **Cloud Messaging** — add an Android app if prompted, and deploy the missed-
   dose alert function:
   ```bash
   cd functions && npm install
   cd .. && firebase deploy --only functions
   ```
6. In the app: **Settings → Family & Sync → Sign in**. Primary phone: **Create
   household** and share the 6-character code. Caregiver: **Join** with the code.

### Firebase structure

```
households/{code}
  members: { uid: { role: "owner"|"caregiver", joinedAt, fcmToken } }
  medicines/{id}     – copy of the medicine row (synced on change)
  doses/{id}         – copy of the dose row incl. status/updatedAt
```

`firestore.rules` (deployed with step 4) restrict all reads/writes to
authenticated members of the household; `functions/index.js` sends the
missed-dose push using each member's FCM token.

### Notes & limitations

- Sync requires network; while offline everything still works locally and the
  outbox keeps every pending change until the next successful sync.
- Concurrent edits from two phones are resolved by push order (last push wins),
  not by clock: multi-writer households may overwrite each other's changes to
  the same medicine. The primary phone is the recommended writer.
- FCM tokens rotate; the app refreshes the token on each sync. The push alert
  only fires for doses that became missed while the function is deployed and the
  device is online.
- Push delivery on Android requires Google Play services and depends on the
  OEM's background policy; the in-app missed list is the reliable fallback.

## 10. Known Phase 1 limitations (unchanged)

See §8 for the full list — exact-alarm user grant on Android 12+, TTS only
while the app process is alive, timezone-change caveats, OEM battery managers.

## 11. Disclaimer

## 11. Disclaimer

Medicine Reminder is provided as-is for personal reminder use. It is not medical
software and must not be used to make dosing decisions. Always follow your
doctor's instructions.
