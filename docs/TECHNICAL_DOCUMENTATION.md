# DoseWise — Technical Documentation

**Scope:** the Flutter app at the repo root (package name `medireminder`, Android
`applicationId com.family.medireminder`, display name "DoseWise", app version
`1.0.1+2`). The unrelated `platform/` subdirectory (a separate Next.js/Prisma
clinic backend) is out of scope — see [`platform/docs/ROADMAP.md`](../platform/docs/ROADMAP.md)
for that project.

**Method:** every fact in this document was verified directly against the
current source code (file-by-file, line-referenced where useful) on
2026-09-15, not copied from other docs. Where an existing doc's claim turned
out to be stale or inaccurate, it is called out explicitly in
[§11 Discrepancies vs. other docs](#11-discrepancies-vs-other-docs-flagged-during-this-audit)
rather than silently repeated.

Companion docs (narrower, still useful): [`README.md`](../README.md) (quick
start), [`FEATURES.md`](../FEATURES.md) (changelog-style feature list),
[`docs/PROJECT_DOCUMENTATION.md`](PROJECT_DOCUMENTATION.md) (phase history,
problems found/fixed, verification ledger, direction assessment),
[`docs/NOTIFICATION_AUDIT.md`](NOTIFICATION_AUDIT.md),
[`docs/FAMILY_SYNC.md`](FAMILY_SYNC.md).

---

## Contents

1. [Mission & product shape](#1-mission--product-shape)
2. [Architecture & project structure](#2-architecture--project-structure)
3. [Database](#3-database)
4. [Models](#4-models)
5. [Repositories (internal data API)](#5-repositories-internal-data-api)
6. [State management (`AppState`)](#6-state-management-appstate)
7. [Notifications & reminder engine](#7-notifications--reminder-engine)
8. [UI / screens](#8-ui--screens)
9. [Firebase, sync & auth](#9-firebase-sync--auth)
10. [Testing](#10-testing)
11. [Configuration & build](#11-configuration--build)
12. [Discrepancies vs. other docs (flagged during this audit)](#12-discrepancies-vs-other-docs-flagged-during-this-audit)
13. [Known gaps / dead code](#13-known-gaps--dead-code)

---

## 1. Mission & product shape

A medicine reminder app built primarily for an **elderly user**, Android-first,
**offline-first**: the local SQLite database is the source of truth for every
reminder; nothing about scheduling or delivering a reminder depends on
network or a signed-in account. An optional **Family & Sync** layer (Firebase
Auth + Firestore + Cloud Functions) lets a caregiver view adherence and get
push alerts when a dose is missed — entirely additive, never load-bearing for
the core reminder loop.

---

## 2. Architecture & project structure

```
lib/
  main.dart                     entry point: Firebase init, DB/services wiring,
                                 notification callback registration, cold-start
                                 notification-tap handling, guarded boot sequence
  app.dart                      provider tree, MaterialApp, RootScreen (Splash→
                                 Login→Onboarding→Main), MainShell (bottom-nav)
  core/
    constants/app_constants.dart      channel names, action ids, window size
    theme/app_theme.dart              Material 3 light/dark theme
    localization/                     app_en.arb, app_hi.arb + gen-l10n output
    notifications/
      notification_service.dart       flutter_local_notifications wrapper
      notification_background.dart    background-isolate notification-tap handler
      reminder_text.dart               localized notification strings
    utilities/date_utils.dart
  data/
    database/app_database.dart        sqflite schema + migrations (injectable)
    models/                           Medicine, MedicineSchedule, MedicineDose,
                                       DoseEntry, AdherenceStats, VitalEntry,
                                       AppSettings, enums
    repositories/                     Medicine/Dose/Settings/Sync repositories
  services/
    dose_scheduler.dart                generates doses + reconciles OS notifications
    dose_action_handler.dart           processes TAKEN/SNOOZE/SKIP
    settings_controller.dart           ChangeNotifier over SettingsRepository
    voice_service.dart                 flutter_tts wrapper
    auth_service.dart                  Google Sign-In (Firebase Auth), diagnostics
    home_widget_service.dart           pushes data to the Android home-screen widget
    backup_service.dart                generic SharedPreferences + DB backup/restore
    export_service.dart                JSON export of medicines + dose history
    pill_photo_service.dart            disk-based pill photo storage (currently unused — §13)
    sync/
      remote_backend.dart              abstract sync backend interface
      firebase_backend.dart            Firebase Auth (anonymous) + Firestore impl
      sync_service.dart                outbox, retry/backoff, checkpoint reconcile,
                                        tombstones, missed-dose watcher
      invitation_service.dart          QR/token household invitations
  state/app_state.dart                 the single ChangeNotifier screens depend on
  features/
    home/ medicines/ history/ settings/ onboarding/ login/ splash/
    profile/ caregiver/ widgets/
```

**Layering discipline**: repositories own all SQL; `NotificationService` is
the only thing that touches the OS notification API; `AppState` is the only
thing screens talk to for data/actions (screens also read `AppState.settings`
and `AppState.voice` directly, both public fields). No named-route/Navigator
2.0 layer exists — routing is plain imperative `Navigator.push`/`pop`, with a
hand-rolled stage switch (`RootScreen`) sitting above an `IndexedStack`
bottom-nav shell (`MainShell`).

**Provider tree** (`lib/app.dart`, `MultiProvider`, all `.value` providers
built once in `main.dart`'s `_bootstrap()`): `SettingsController`, `AppState`,
`SyncService`, `AuthService`.

**App-open flow**: `RootScreen` shows Splash for a hardcoded 1.5s, then:
`AuthService.isSignedIn || SettingsController.onboardingDone` → jump straight
to Main; otherwise → Login (skippable) → Onboarding → Main. Comment in the
file: `/// App root: Splash → Login → Onboarding → Main`.

**Bottom-nav shell** (`MainShell`, `IndexedStack`, 4 tabs in order): **Home**,
**Medicines**, **History**, **Profile** — a custom pill-style nav bar, not the
stock `NavigationBar`. A floating add button appears only on the Home tab.
`MainShell` also owns a full-screen in-app **dose alarm overlay**
(`DoseAlarmScreen` via non-dismissible `showGeneralDialog`) shown when a dose
is due within 10 minutes — independent of and in addition to the OS
notification.

---

## 3. Database

`lib/data/database/app_database.dart` — sqflite, DB file `medireminder.db`,
**schema version 8**, `PRAGMA foreign_keys = ON`. `AppDatabase` is injectable
(`AppDatabase({DatabaseFactory? factory, String? path})`) — tests construct it
with `sqflite_common_ffi` against a per-test temp file, never touching the
real app DB. The `database` getter is a lazy, concurrency-safe singleton
opener.

### Tables (current/v8 shape)

**`medicines`**

| column | type | notes |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| name | TEXT NOT NULL | |
| dosage | TEXT NOT NULL DEFAULT '' | |
| dosage_unit | TEXT NOT NULL DEFAULT '' | |
| notes | TEXT NOT NULL DEFAULT '' | |
| food_instruction | TEXT NOT NULL DEFAULT 'none' | enum name string |
| frequency | TEXT NOT NULL DEFAULT 'daily' | enum name string |
| selected_days | TEXT NOT NULL DEFAULT '' | comma-joined weekday ints, 1=Mon..7=Sun |
| once_date | TEXT | nullable, `yyyy-MM-dd` |
| active | INTEGER NOT NULL DEFAULT 1 | |
| created_at / updated_at | TEXT NOT NULL | ISO8601 |
| stock_count | INTEGER | nullable, added v5→v6 |
| refill_at | INTEGER | nullable, added v5→v6 |

**`medicine_schedules`**: `id` PK, `medicine_id` (FK → `medicines.id` ON
DELETE CASCADE), `hour`, `minute`, `enabled` (default 1).

**`medicine_doses`**: `id` PK, `medicine_id` (FK → `medicines.id` ON DELETE
CASCADE, added in the v6→v7 rebuild — see migrations below), `scheduled_at`
(ISO8601), `status` (`pending|taken|skipped|missed`, default `pending`),
`taken_at`/`skipped_at`/`snoozed_until` (nullable), `created_at`,
`updated_at` (added v1→v2). `UNIQUE (medicine_id, scheduled_at)`. Index
`idx_doses_scheduled(scheduled_at)`.

**`sync_tombstones`** (medicine deletions to propagate, added v2→v3): `id`
PK, `medicine_key` INTEGER NOT NULL, `updated_at` TEXT NOT NULL — **no unique
constraint** (can accumulate duplicate rows for the same medicine).

**`sync_outbox`** (pending local changes to push, added v3→v4): `id` PK,
`entity_type` (`'medicine'|'dose'`), `entity_id`, `updated_at`, `UNIQUE
(entity_type, entity_id)` — upserted via `ConflictAlgorithm.replace`.

**`sync_dose_tombstones`** (pending dose deletions, added v4→v5): `id` PK,
`medicine_id`, `scheduled_at`, `updated_at`, `UNIQUE (medicine_id,
scheduled_at)`.

No table backs `VitalEntry` — vitals are persisted ad hoc in
`SharedPreferences` (§4). No FTS/search table exists.

### Migrations (`onUpgrade`, cumulative `if (oldVersion < N)` blocks — a fresh install just runs `onCreate`)

| Step | Change |
|---|---|
| v1→v2 | `ALTER TABLE medicine_doses ADD COLUMN updated_at TEXT` |
| v2→v3 | create `sync_tombstones` |
| v3→v4 | create `sync_outbox` |
| v4→v5 | create `sync_dose_tombstones` |
| v5→v6 | `ALTER TABLE medicines ADD COLUMN stock_count INTEGER`; `... refill_at INTEGER` |
| v6→v7 | rebuild `medicine_doses` (SQLite can't `ALTER TABLE ADD CONSTRAINT`): disable FKs, create `medicine_doses_new` with the FK+CASCADE, copy all rows, drop old, rename, recreate the index, re-enable FKs |
| v7→v8 | one-time cleanup: delete orphaned `medicine_doses`/`medicine_schedules` rows predating the FK (does **not** touch `sync_dose_tombstones`, since tombstones legitimately outlive their medicine) |

### Other local persistence (`shared_preferences`, via `SettingsRepository` unless noted)

| key | type | default | meaning |
|---|---|---|---|
| `locale` | String | `'en'` | `en` or `hi` |
| `sound_enabled` | bool | `true` | |
| `voice_enabled` | bool | `true` | TTS on/off |
| `snooze_minutes` | int | `10` | |
| `grace_minutes` | int | `30` | "missed after" grace period |
| `advance_minutes` | int | `5` | pre-dose looping alert lead time (0 = off) |
| `theme_mode` | String | `'system'` | `system`\|`light`\|`dark` |
| `user_name` | String | `''` | |
| `user_age` | int? | — | removed from prefs if null |
| `onboarding_done` | bool | `false` | |
| `sync_enabled` | bool | `false` | |
| `household_code` | String | `''` | |
| `sync_role` | String | `'owner'` | `owner`\|`member` |
| `missed_alerts_enabled` | bool | `true` | |
| `last_sync_at` | String (ISO8601) | — | removed from prefs if null |

Outside `SettingsRepository`: `missed_alerts_notified` (`SyncService`, a
`StringList` of already-alerted dose ids, prevents re-notifying across
restarts); `vital_<epochMillis>` keys (`VitalsLogScreen`, one `StringList`
per logged vital — **not** routed through `VitalEntry.toMap()`/`fromMap()`,
which exist but are unused for persistence, see §13); `home_widget` plugin's
own key/value store (`widget_medicine_name`, `widget_all_done`,
`widget_dose_info`, `widget_dose_time`, `widget_status_text`,
`widget_progress`, `widget_bg_color`, `widget_done_count`,
`widget_total_count`, `widget_has_medicines` — written by
`HomeWidgetService.update()`).

`BackupService` iterates **every** `SharedPreferences` key generically
(typed by runtime value), so it captures all of the above — including
`vital_*` — without needing to know key names ahead of time, alongside a full
SQLite export.

---

## 4. Models

All under `lib/data/models/`.

- **`Medicine`** — `id, name, dosage, dosageUnit, notes, foodInstruction,
  frequency, selectedDays, onceDate, active, createdAt, updatedAt,
  stockCount, refillAt, schedules[]`. Computed: `hasStockTracking =
  stockCount != null`; `needsRefill = stockCount != null && refillAt != null
  && stockCount! <= refillAt!`; `doseLabel` joins dosage+unit (e.g. "1
  tablet").
- **`MedicineSchedule`** — `id, medicineId, hour, minute, enabled`. Computed
  `time` → `TimeOfDay`.
- **`MedicineDose`** — `id, medicineId, scheduledAt, status, takenAt,
  skippedAt, snoozedUntil, createdAt, updatedAt`. `updatedAt` drives sync
  last-writer-wins comparisons.
- **`DoseEntry`** — a UI-facing join of `dose` + `medicine`, not DB-backed.
  Computed `effectiveStatus(grace, now)`: returns the stored status as-is if
  it isn't `pending`; otherwise returns `missed` once `(snoozedUntil ??
  scheduledAt) + grace` has passed, else `pending`. This is a *derived
  display* status — `DoseRepository.sweepMissed()` is what actually
  persists `missed` to the DB.
- **`AdherenceStats`** — `taken, missed, skipped, pending` counters;
  computed `total`, `resolved = taken+missed+skipped`, `adherencePercent =
  round(taken*100/resolved)` (0 if nothing resolved).
- **`VitalEntry`** / **`VitalType`** (`bloodPressure, bloodSugar, weight,
  temperature, heartRate`, each with display name + unit) / **`VitalStatus`**
  (`normal, elevated, high`, computed from hardcoded per-type normal ranges).
  Has `toMap`/`fromMap` but they're unused — see §3 and §13.
- **`AppSettings`** — the in-memory shape of every `SettingsRepository` key
  above, plus computed `snoozeDuration`/`graceDuration` (`Duration`
  wrappers).

**Enums** (exact values): `DoseStatus {pending, taken, skipped, missed}`;
`MedicineFrequency {daily, specificDays, once, multiple}`;
`FoodInstruction {none, before, after, withFood}`. Each has a `.from(String)`
parser falling back to a safe default.

---

## 5. Repositories (internal data API)

No ORM/DAO layer — repositories issue sqflite queries directly. This is the
closest thing to an internal "API" that the app has.

**`MedicineRepository(AppDatabase, {SyncRepository? sync})`**: `getAll()`,
`getById(id)`, `getByName(name)`, `insert(medicine)` (medicine+schedules in
one transaction), `update(medicine)` (replaces all schedules), `delete(id)`,
`deleteIfExists(id)`, `getAllUpdatedSince(since)`,
`applyRemoteMedicine(remote)` (last-writer-wins merge), `setActive(id,
active)`. Every mutating method optionally enqueues a sync-outbox row via the
injected `SyncRepository` (omit it — e.g. in most unit tests — and syncing is
simply skipped).

**`DoseRepository(AppDatabase, {SyncRepository? sync})`**: `ensureDose(
medicineId, scheduledAt)` (get-or-create; returns null if a dose with a final
outcome already exists for that slot), `getDose(id)`, `getDoseEntry(id)`
(joined via raw SQL), `getEntriesBetween(start, end)`,
`getAllUpdatedSince(since)`, `applyRemoteDose(remote, {deleted})`,
`getPendingDosesForMedicine(id, from)`, `restorePreviousStatus(id, {status,
takenAt, skippedAt})` (undo), `getPendingBetween(start, end)`,
`markTaken/markSkipped/markMissed(id, at)`, `setSnoozedUntil(id, until)`,
`sweepMissed(grace, now)` (persists derived-missed doses, returns count),
`deletePendingFrom(medicineId, from)` (atomically tombstones + deletes in one
transaction), `deleteForMedicine(id)`, `statsBetween(start, end, {grace,
now})` → `AdherenceStats`.

**`SettingsRepository(SharedPreferences)`**: `load()` → `AppSettings`,
`save(settings)`.

**`SyncRepository(AppDatabase)`**: owns the three sync-only tables —
tombstone add/list/clear for both medicines and doses, outbox
enqueue/list/remove/prune/clear, `countPending()` (note: this count includes
`sync_outbox` + `sync_tombstones` but **not** `sync_dose_tombstones`, per the
code as written).

---

## 6. State management (`AppState`)

`lib/state/app_state.dart` — a single `ChangeNotifier`, constructed with
injected repositories/services, that every screen watches/reads. Public
surface grouped by concern:

- **Snapshot**: `loading`, `todayDoses`, `medicines`, `nextDose`,
  `todayStats`, `revision` (bumped every refresh so screens like History can
  detect staleness cheaply).
- **Permissions**: `notificationsEnabled`, `exactAlarmsEnabled`,
  `batteryUnrestricted`.
- **Undo**: `canUndo`, `lastUndoFailed`.
- **Lifecycle**: `init({deferScheduleSync})` (fast local load + backgrounded
  full reconcile so the splash never blocks on the notification-scheduling
  work), `refresh()` (sweeps missed doses → `DoseScheduler.sync()` reconciles
  OS notifications for the rolling window → reloads today's data → recomputes
  `nextDose` → checks refill reminders → pushes to the home-screen widget →
  bumps `revision`), `restartAutoSpeak()`, `refreshPermissionStatus()`.
- **Dose actions**: `markTaken/markSkipped/markSnoozed(entry)` (each saves
  undo state, speaks a voice confirmation if enabled, cancels the OS
  notification, refreshes, and fires `sync.syncNow()`), `undoLastAction()`,
  `handleNotificationTap({actionId, payload})` (delegates to
  `DoseActionHandler`), `historyFor(start, end)` → `(entries, stats)`.
- **Medicine management**: `saveMedicine(medicine)` (drops today's stale
  pending doses on update so they regenerate under the new schedule),
  `setMedicineActive(id, active)`, `deleteMedicine(id)` (deletes doses, then
  the medicine, then tombstones it).
- **Permission flows**: `requestAllPermissions()`, `requestExactAlarms()`.

`refresh()` call sites (every point OS notifications get reconciled): app
start (`main.dart`'s `_bootstrap`/`_postLaunch`), app resume
(`MainShell.didChangeAppLifecycleState`), every dose/medicine mutation
above, and a notification tap.

---

## 7. Notifications & reminder engine

### Channels (`lib/core/notifications/notification_service.dart`)

Channel-id version suffix **`v10`**. On init, `_createChannels()` explicitly
**deletes every historical channel id** (`v2`…`v9` + unversioned) before
creating the current three — necessary because Android caches a channel's
sound/importance/vibration config permanently once created, so any
config change requires a brand-new id. `v10` specifically fixed a bug where
`audioAttributesUsage: alarm` was intended but never actually passed, so the
custom sound was playing on the silence-prone NOTIFICATION stream instead of
the ALARM stream.

| Channel | resolved id | importance | sound | `audioAttributesUsage` | vibration | LED | `bypassDnd` |
|---|---|---|---|---|---|---|---|
| Sound | `medicine_reminders_v10` | max | `medicine_alarm.wav` (`res/raw/`) | `alarm` | multi-burst pattern (~6s) | green | **true** |
| Silent | `medicine_reminders_silent_v10` | max | none | — | same pattern | green | false |
| Family | `family_alerts_v10` | max | same WAV | `alarm` | same pattern | orange | **true** |

Every real reminder notification also sets: `FLAG_INSISTENT` (loops the
alarm sound until dismissed/actioned), `fullScreenIntent: true`, category
`AndroidNotificationCategory.alarm` (deliberately not `reminder`, to rank
above heads-up and preserve the full-screen intent on Android 14+/15).

**Action buttons**: `taken` / `snooze` / `skip` (exact ids in
`AppConstants`), each `showsUserInterface: false, cancelNotification: true`
— handled fully in the background, only on the main dose-reminder channel
(`withActions: true`), not on advance alarms or test/refill/missed alerts.

### Scheduling (`NotificationService.scheduleDoseReminder` /
`scheduleAdvanceAlarm`, via `zonedSchedule`)

Both try, in order: (1) `AndroidScheduleMode.alarmClock` — exact, survives
Doze, needs no runtime permission; if accepted, **trusted immediately and
never downgraded**, even if the OS's own pending-list query doesn't echo it
back (a deliberate fix — many OEMs don't echo `alarmClock` alarms, and
falling through used to silently downgrade a good exact alarm to an inexact
one); (2) `exactAllowWhileIdle` if the caller requested `exact: true`; (3)
`inexactAllowWhileIdle` as the last resort. Notification id = the dose's own
integer id; advance-alarm id = `doseId * 1000 + offset`. Payload:
`"dose:<id>"`. A dose already slightly in the past (within the reconcile's
30-minute window) is clamped to fire in 2 seconds rather than being skipped.

**Advance alarm**: `scheduleAdvanceAlarm()` schedules a separate looping
alert before the dose's main time — user-configurable `advance_minutes`
(0/1/2/3/5/10, 0 = off).

**Permissions**: `canScheduleExact()` defaults pessimistically to `false` on
error; `requestExactAlarmPermission()`/`requestFullScreenIntentPermission()`
open the relevant system screen. Because `alarmClock` mode needs neither
grant, exact scheduling works even without them — the `exact` param only
gates the `exactAllowWhileIdle` fallback tier. Battery-optimization state is
read via a custom `MethodChannel('com.family.medireminder/power')`
implemented in `MainActivity.kt`.

**Diagnostics**: `scheduleSelfTest()` (Settings → "Test Scheduled") schedules
a real short-delay test alarm and reports back which mode actually landed;
`showTestNotification()` fires an immediate test notification with a
"rich → plain fallback" attempt to isolate OEM WAV/style rejection;
`getHealthCheck()` reports init state, sound setting, channel version,
`notificationsEnabled`, `canScheduleExactNotifications`, pending count.

### Reconciliation (`lib/services/dose_scheduler.dart`)

`sync(days: AppConstants.windowDays = 7)`: generates/reconciles doses for a
rolling **7-day window**, re-run on every open/resume/mutation (kept small so
the reconcile finishes in ~1–2s per run). Steps: expand active
medicines×schedules into concrete occurrences → pre-load existing pending
doses in one query (avoids N+1) → `ensureDose()` any missing occurrence →
compute each dose's desired notification time (`null` if not pending; the
snoozed time if in the future; the scheduled time if in the future; if
overdue within a **hardcoded 30-minute window**, fire almost immediately;
else `null`) → diff against the OS's actual pending-id set: reschedule if
drifted, schedule if missing, cancel anything OS-pending that's no longer
desired (covers edits/pauses/deletes/taken-from-app). A separate pass cancels
stale advance-alarm ids. Logs the OS's pending-id set before reconciling
(`DOSE_BOOT_RESTORE`) as proof that reboot recovery worked without any Dart
code running.

> **Two distinct "30-minute" values, don't conflate them**: the scheduler's
> hardcoded 30-minute "still worth firing if overdue" window (scheduling
> decision) vs. the user-configurable `grace_minutes` setting (default 30,
> used by `DoseEntry.effectiveStatus()`/`sweepMissed()` to decide *missed*
> status). They happen to share a default value but are unrelated knobs.

### Action handling (`lib/services/dose_action_handler.dart`)

`handle({actionId, payload, now, speak})`: parses `"dose:<id>"`, looks up the
dose+medicine, then: `taken` → mark taken, cancel notification, speak if
`speak && voiceEnabled`; `skip` → mark skipped, cancel (no speech); `snooze`
→ compute `now + snoozeDuration`, cancel, reschedule for the new time with
`exact: true` (no speech here — snooze speech happens at the `AppState`
level for in-app taps). A plain body tap (`actionId == null`) is a no-op at
this layer.

Three call sites, each logging `DOSE_ALARM_FIRE` with a distinct `source`:
live foreground callback (`main.dart`'s `notifications.init(onResponse:
...)`, `speak: true`), background/terminated isolate
(`notification_background.dart`'s `@pragma('vm:entry-point')` handler —
opens its own `AppDatabase`/repositories, `speak: false` since there's no
audio session), cold start (`main.dart`'s `_postLaunch()` reading
`getNotificationAppLaunchDetails()`).

### Reboot handling

No custom Android boot-receiver code exists in this app. Reboot recovery is
delegated entirely to `flutter_local_notifications`' own
`ScheduledNotificationBootReceiver` (declared in the manifest, listening for
`BOOT_COMPLETED`/`MY_PACKAGE_REPLACED`/`QUICKBOOT_POWERON`). The app-side
confirmation is the `DOSE_BOOT_RESTORE` log described above.

### Android manifest — permissions & components

Permissions: `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`VIBRATE`, `WAKE_LOCK`, `ACCESS_NOTIFICATION_POLICY` (required for
`bypassDnd`), `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM`,
`USE_FULL_SCREEN_INTENT`.

Components (all `exported="false"` except the widget provider):
`ActionBroadcastReceiver`, `ScheduledNotificationReceiver`,
`ScheduledNotificationBootReceiver` (all from the plugin), plus
`.DoseWidgetProvider` (`exported="true"`, home-screen widget only, unrelated
to reminder delivery).

### Voice / TTS (`lib/services/voice_service.dart`)

`flutter_tts` wrapper, `awaitSpeakCompletion(true)`, speech rate `0.45`
("slow and clear for elderly users"). Locale mapping is binary: `hi` →
`hi-IN`, everything else → `en-IN`. All failures swallowed silently — TTS is
always best-effort, never load-bearing. Triggers: `AppState`'s dose-action
methods (in-app taken/skipped/snoozed confirmations), `DoseActionHandler`
(only the `taken` case, only foreground), and a periodic **30-second
auto-speak timer** in `AppState` that announces a due-or-soon dose, throttled
to once per 60 seconds. `VoiceModeScreen` is a separate dedicated
high-contrast, TTS-first manual screen for visually-impaired users.

### Structured diagnostic logging

All under `developer.log(..., name: 'DoseAudit')`, distinct from ordinary
debug `developer.log` calls elsewhere:

| Tag | Emitted from | Purpose |
|---|---|---|
| `DOSE_ALARM_SCHEDULE` | `scheduleDoseReminder` | every scheduling decision (mode tried, OS-queue verified, result) |
| `DOSE_ALARM_SCHEDULE_ADVANCE` | `scheduleAdvanceAlarm` | same, for pre-dose alarms |
| `DOSE_ALARM_FIRE` | 3 call sites (§ above) | `source=foreground\|background\|cold-start`, actionId, payload |
| `DOSE_TZ` | `scheduleDoseReminder` | local/UTC/effective/device-timezone sanity check |
| `DOSE_NOTIFICATION` | `scheduleDoseReminder` | delivery config actually used (channel, sound, audio usage, category, insistent) |
| `DOSE_ERROR` | failure paths | uninitialized service, denied `POST_NOTIFICATIONS`, `zonedSchedule` exceptions |
| `DOSE_CANCEL` | `DoseScheduler.sync()` | a stale OS-pending notification was cancelled, with reason |
| `DOSE_BOOT_RESTORE` | `DoseScheduler.sync()` | the OS's actual pending-alarm-id set, proving boot-receiver re-registration |
| `DOSE_PERMS` | `AppState.refresh()` | every reconcile cycle: notifications/battery/alarm-capability result |

(Older docs referenced a `DOSE_FIRE` tag — the real tag is `DOSE_ALARM_FIRE`;
see §12.)

---

## 8. UI / screens

### Home (`lib/features/home/home_screen.dart`)

Time-of-day greeting + user name; header with avatar and a permission-warning
bell; an "all done" streak banner (🔥) when nothing's missed/pending;
separate permission banners for notifications-off and exact-alarms-off;
an **"Upcoming Dose" hero card** — gradient card (pulses when due), medicine
name, dose/time/food/snoozed chips, a live countdown, a speaker button to
replay the TTS line, a **"Mark as Taken"** button, and Snooze/Skip ghost
buttons (falls back to an "all done" card when nothing's next); **Today's
Schedule** with a status filter (All/Pending/Taken/Missed) and time-slot
chips (Morning/Afternoon/Evening) over a tile list, plus a "log now" action
per pending row and a batch "mark all" button; a **Taken / Remaining /
Missed** counter row plus a circular adherence-% ring; a Quick Actions grid
linking to Weekly Calendar, Adherence Report, Doctor Report, Voice Mode, and
Vitals Log screens (all real, beyond the originally-described feature set);
empty states for "no medicines" and "nothing in this time slot."

### Medicines (`lib/features/medicines/`)

**Form**: name (required), dose amount + unit (with quick-pick chips: mg,
ml, tablet, capsule, drop, spoon), food instruction chips, frequency chips
(daily/specific days/once/multiple), weekday picker with "Weekdays"/
"Weekends" presets, a date picker for "once," reminder time chips (add/
edit/remove) plus four quick-slot presets (Morning 8:00, Afternoon 13:00,
Evening 18:00, Night 21:00, each color-coded), notes, optional stock-count +
refill-threshold fields, and a **schedule-conflict warning dialog** comparing
the chosen times against every other medicine before saving. It also runs an
(unlocalized, English-only) **drug-interaction check** on save, showing a
warning dialog for pairwise interactions — a real feature not originally
asked about. There is **no photo/camera field** wired into this form (see
§13 — `PillPhotoService` exists but is orphaned).

**List**: search by name, active/total count header, per-medicine card
(name, dose+food, active pill, schedule summary, stock-left line colored red
when refill is due, notes), row actions **Pause/Resume, Edit, Delete**
(confirmation dialog). **No Duplicate action exists.**

### History (`lib/features/history/history_screen.dart`)

Today / This Week / All (last 90 days) range tabs; an adherence ring
(green ≥80%, coral accent otherwise) with taken/missed/skipped counts; a
7-bar stacked weekly chart (Mon–Sun, status-colored segments, week view
only) with a trend indicator against a 70% baseline; a status filter chip
row (All/Taken/Missed/Skipped/Pending); a day-grouped tile list with
scheduled-vs-actual times and a colored status badge.

### Settings (`lib/features/settings/settings_screen.dart`)

In on-screen order: Family Sync entry point; Language (English/हिंदी only);
notification sound toggle; voice/TTS toggle; snooze duration chips
(5/10/15/20/30 min); grace-period chips (15/30/45/60/90/120 min); advance-
alarm chips (0/1/2/3/5/10 min, 0=off); a "Test notification" button + a
"Test Scheduled" self-test with inline diagnostics + a live pending-count
readout; "Pause All" (confirmation, deactivates every medicine); dark-mode
3-way segmented control (System/Light/Dark); a Permissions section (battery-
restriction warning card, notification/exact-alarm/battery-optimization
tiles each opening the right system screen, plus a "Fix All" button);
Backup & Restore entry point; an inline About card (`"DoseWise · v1.0.0"` +
body text — no separate disclaimer screen, just this string).

### Onboarding (`lib/features/onboarding/onboarding_screen.dart`)

Two steps: (1) welcome copy + a name text field (the only data collected);
(2) informational cards about notification/exact-alarm permissions (not
interactive toggles). Finishing saves the name and **actually requests**
notification + exact-alarm permissions from the OS, then marks onboarding
done. "Skip" is available throughout and sets onboarding-done immediately
without requesting anything.

### Profile, Login, Splash

`ProfileScreen`: avatar (Google photo or fallback icon), editable name+age
(local-only; name is additionally pushed to the Firebase Auth
`displayName` if signed in — age never leaves the device), sign-in/out
(sign-out behind a confirm dialog), a debug-build-only Firebase diagnostics
card (shown only when **not** signed in), and links to Settings + a static
About card. `LoginScreen`: a "Skip" button always available regardless of
Firebase state, and a Google Sign-In button shown only when Firebase is
available.

### Caregiver dashboard (`lib/features/caregiver/caregiver_dashboard_screen.dart`)

Read-only weekly-adherence + today's-dose-list view. Reads from the **local
SQLite mirror**, not Firestore directly — on open it fires a background
`SyncService.syncNow()` to pull fresh household data, then reactively
reloads when `AppState.revision` changes; also has a manual Refresh button.
Degrades to "last synced copy" when offline.

### Shared large-tap-target widgets (`lib/features/widgets/`)

`BigButton`/`BigTextButton` (56dp-tall primary/skip actions), `PermissionBanner`,
`DoseListTile` and `AdherenceCard` (both shared between History-adjacent
screens and the caregiver dashboard), `statusVisual()`/`StatusChip` (status
icon/color/pill helpers used across Home/History/tiles).

### Home-screen Android widget

Kotlin `AppWidgetProvider` (`DoseWidgetProvider.kt`) + XML layout, `minWidth
250dp × minHeight 110dp`, `updatePeriodMillis=1800000` (Android's documented
30-minute floor for OS-driven refresh). Shows title + a "N / M done" progress
counter, medicine name (26sp), dose info, time, and a status badge ("Due
now!"/"N min late"/"in N min"), with a background drawable that switches
between normal/urgent/late/done coloring. Tapping it launches the app.
`HomeWidgetService.update()` computes all of this and pushes it via
`HomeWidget.saveWidgetData(...)` + `HomeWidget.updateWidget(...)` from
`AppState.refresh()` — so it updates immediately on any in-app action, on top
of the OS's periodic floor.

### Theme & localization

Material 3 (`ColorScheme.fromSeed`, indigo `0xFF4F46E5` light / `0xFFB4B0F5`
dark), tuned for elderly users: 54dp minimum button height, 48×48 icon
buttons, 64×56 text buttons, a 72dp/26sp nav bar, 68dp settings tiles — font
sizes otherwise follow Material 3 defaults and scale with the system
accessibility setting. Semantic extension colors: accent (coral), dose
gradients, success/pending/missed. **Dark mode is fully implemented** (real
distinct `ColorScheme`, live-reactive `MaterialApp.themeMode` binding, a
working 3-way toggle) — not just a stated feature. **Localization**: exactly
two languages, `app_en.arb` / `app_hi.arb` (418 lines each), generated via
`flutter gen-l10n` into `lib/core/localization/generated/`.

---

## 9. Firebase, sync & auth

### `RemoteBackend` (abstract interface, `lib/services/sync/remote_backend.dart`)

`initialize()`, `signIn()`, `createHousehold()` → code, `joinHousehold(code)`,
`currentHousehold()`, `attachPushToken()`, `pushMedicines(items)`,
`pushDoses(items)`, `pullMedicines(since)`, `pullDoses(since)`,
`watchDoses()` → `Stream<List<RemoteDose>>`, `dispose()`. `RemoteMedicine`/
`RemoteDose` both carry a `deleted` (tombstone) flag; `RemoteDose`
denormalizes `medicineName` so a watching device can alert without resolving
the medicine separately.

### `FirebaseBackend` (`lib/services/sync/firebase_backend.dart`)

**Auth for sync**: Firebase **anonymous** sign-in only (`signInAnonymously()`
if no current user) — a device's sync identity does not require Google
sign-in.

**Firestore layout**:
```
households/{code}                        { createdAt, ownerUid }
households/{code}/members/{uid}          { userId, householdId, role, permissions, createdAt, fcmToken? }
households/{code}/medicines/{id}         medicine snapshot (+ deleted flag)
households/{code}/doses/{medId_ts}       dose snapshot (+ deleted flag), doc id = "<medicineId>_<scheduledAtEpochMs>"
invitations/{sha256(token)}              { householdId, creatorUid, creatorName, expiresAt, used }
```
Timestamps are UTC ISO-8601 strings (lexicographic range-query friendly).
Members are a **subcollection** (see §12 for the historical "map field"
confusion this replaced).

`createHousehold()`: 6-char code from a confusable-character-free alphabet
(`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`), `Random.secure()`, written inside a
collision-checked Firestore transaction (retried up to 5×), which also writes
the owner's member doc with default permissions `{shareMedicines: false,
shareMissedAlerts: false}`. `attachPushToken()`: fetches an FCM token
(12s timeout, returns null gracefully) and merges it into the member doc —
fully best-effort. `pushMedicines`/`pushDoses`: batched `set()` overwrites.
`pullMedicines`/`pullDoses`: single-field `updated_at > since` range queries
(auto-indexed by Firestore, no composite index file needed/present).
`watchDoses()`: a live `.snapshots()` stream on the doses subcollection.

### `SyncService` (`lib/services/sync/sync_service.dart`)

**Outbox**: every local mutation is queued into `sync_outbox` at write time
(via the repositories' optional `SyncRepository`) and only removed once the
backend confirms the push — survives restarts/outages.

**Retry/backoff**: periodic sync every 10 minutes; on failure, `30s ×
2^attempt` (attempt clamped to 8) capped at 10 minutes, with a **±20% jitter
multiplier** (`0.8 + 0.4*random()`) applied on top — so the real progression
is 30s→60s→120s→240s→480s→600s(capped)…, each jittered. An immediate retry
also fires on an offline→online connectivity transition
(`connectivity_plus`, deduped via `.distinct()`).

**Checkpoint reconcile**: on `init()` and on `enableSync()`, re-queries
everything locally changed since the last checkpoint and re-enqueues it — a
self-healing net against a lost/corrupted outbox. The checkpoint watermark
itself is computed carefully: it advances to the max `updatedAt` actually
fetched (capped at wall-clock now), or to wall-clock now only if that hasn't
rewound behind the previous checkpoint — explicitly designed to survive
device clock jumps without silently skipping data.

**Tombstones**: deletes are tracked as separate tombstone records (not just
outbox rows), pushed as a `deleted: true` remote item; on pull, a `deleted`
flag triggers a local delete rather than an upsert.

**Conflict resolution**: `sync_service.dart` itself applies whatever a pull
returns unconditionally — the actual last-writer-wins `updatedAt` comparison
lives inside `MedicineRepository.applyRemoteMedicine()` /
`DoseRepository.applyRemoteDose()` in the repository layer, not in
`SyncService`.

**Missed-dose watcher**: subscribes to `watchDoses()`; alerts (local
notification) for any dose that is `status == missed` and within the last
24h, gated by the user's own `missed_alerts_enabled` setting, deduped via a
persisted `missed_alerts_notified` set so restarts don't re-notify. Per an
explicit code comment, **there is no longer a single designated "watcher"
role** — any household member with the setting on gets alerted (see §12 on
the `FamilyRole` model).

**`enableSync()`**: `initialize()` → `signIn()` →
`joinHousehold`/`createHousehold`, wrapped in a 25s timeout with a friendly
error; push-token registration is fire-and-forget.

### Invitations (`lib/services/sync/invitation_service.dart`)

256-bit tokens (`Random.secure()`, 32 bytes, base64Url, unpadded), hashed
with **SHA-256** (`package:crypto`) as the Firestore document id — the raw
token itself is never stored, only embedded in the QR payload
(`{"type":"dosewise_invite","token":...,"v":1}` — no household id, uid, or
PII in the QR). `tokenTTL = 24h`. Single-use, enforced by an atomic Firestore
**transaction** that reads the invite, validates not-used/not-expired/
not-self/not-already-member, then in the same transaction flips
`used: true` on the invite **and** writes the new member doc (carrying the
consumed invite's hash so security rules can verify the two writes happened
together — see below). Roles: exactly **`owner`** and **`member`** — a
`FamilyRole.normalize()` step maps legacy strings (`'primary'`, `'admin'`)
to `owner` for backward compatibility with pre-refactor data, confirming an
older 3-tier role scheme has been collapsed to two. Permissions:
`{shareMedicines, shareMissedAlerts}`, both default `false` (opt-in), enforced
only client-side — not by Firestore rules or the Cloud Function (§12).
`getFamilyMembers()` reads the `members` subcollection and, if empty, falls
back to a legacy `members` map field on the household doc for pre-migration
data.

### `functions/index.js` (Cloud Functions)

Exactly one exported function: `onDoseWrite`, a Firestore trigger on
`households/{code}/doses/{doseId}`. Fires only when a dose **transitions
into** `missed` (not already missed before this write), skips doses older
than a 24h TTL. Queries the `households/{code}/members` **subcollection**
(current, correct state — matches the client's write path; the historical
"map field" bug this once had is fixed, see §12) to collect every member's
`fcmToken`, then sends a `sendEachForMulticast` push ("⚠️ Missed medicine…")
on the `family_alerts` channel. **Notifies every member with a stored token,
regardless of that member's own `shareMissedAlerts` setting** — the opt-in
flag is a client-side convention only, not enforced server-side (§12).

### `firestore.rules`

`households/{id}`: read requires membership; create requires
`ownerUid == auth.uid`; update/delete always false (immutable after
creation). `members/{uid}`: read requires membership; a member can only
create their *own* record, either as `owner` (if they created the household)
or as `member` **with a same-transaction proof** (`getAfter()`) that the
matching invitation doc was flipped to `used` by them; a member can update
only their own record and cannot self-promote its `role`; self-removal is
allowed (except the owner, who can never be removed, and can remove any
other non-owner). `medicines`/`doses` subcollections: flat
`allow read, write: if isMember(householdId)` — the per-member
`shareMedicines`/`shareMissedAlerts` flags are **not** a rules-level
boundary, only a client-side UX convention. `invitations/{tokenHash}`: `get`
allowed for any signed-in user (needed to validate a scanned code); `list`
always false (can't enumerate invitations); `create` requires
`creatorUid == auth.uid && used == false`; the consume `update` is a
tightly-constrained one-way `used:false → true` flip; `delete` only by the
original creator.

### Auth (`lib/services/auth_service.dart`)

Google Sign-In via `google_sign_in` + `FirebaseAuth.signInWithCredential`.
Constructor wraps `Firebase.app()` in try/catch — on failure it sets
`firebaseAvailable = false` and nulls out the auth/Google clients, which is
what lets Login's "Skip" path and the rest of the app work with Firebase
totally unconfigured. Maps common `FirebaseAuthException` codes to
actionable messages. `signOut()` signs out of both Google and Firebase Auth.
`runDiagnostics()` powers the Profile debug card (Firebase init / Auth
signed-in state / Google Sign-In plugin load, each ✅/⚠️/❌).

**Important**: `AuthService`'s Google identity and `FirebaseBackend`'s
anonymous sync identity both use the **same** `FirebaseAuth.instance`
session — so a user who signs in with Google via Profile *is* also the
current user for household sync (which only calls `signInAnonymously()` when
`currentUser == null`). They are conceptually separate flows that happen to
converge on one session, not two isolated identities (see §12).

`Firebase.initializeApp()` is called once, in `main.dart`, inside the app's
generic timeout-guarded boot-step wrapper — a failure there is caught and
logged, never crashes the app, and every downstream Firebase-touching class
(`AuthService`, `FirebaseBackend`) independently re-checks availability and
degrades to an error/disabled state rather than throwing into the UI. Net
effect: the reminder core (local DB, notifications, UI) works fully with
Firebase unreachable or unconfigured.

### Crash reporting (added 2026-09-15)

`firebase_crashlytics ^5.4.0`. Initialized in `main.dart`'s `_initCrashlytics()`
right after `Firebase.initializeApp()` succeeds — `setCrashlyticsCollectionEnabled(!kDebugMode)`
then a module-level `_crashlyticsReady` flag flips true. Every error handler
installed by `_installErrorHandlers()` (`FlutterError.onError`,
`PlatformDispatcher.instance.onError`) and the top-level `runZonedGuarded`
catch in `main()` checks that flag and, if true, also calls
`FirebaseCrashlytics.instance.recordFlutterError()`/`recordError()` —
**in addition to**, not instead of, the `developer.log` calls already there.
If Firebase never initializes (unconfigured/unreachable device), the flag
stays false forever and every error handler silently degrades to
local-only logging, matching every other Firebase-touching code path in
this app. Requires enabling Crashlytics for the project in the Firebase
Console before any report is visible there (code-level wiring alone doesn't
make that happen) — see `docs/PRODUCTION_READINESS_REPORT.md` §0a.

### Account & data deletion (added 2026-09-15)

`lib/services/account_deletion_service.dart` (`AccountDeletionService`,
provided via a plain `Provider<AccountDeletionService>.value`, not a
`ChangeNotifier`), triggered from a "Danger zone" section on
`ProfileScreen`.

- **`RemoteBackend` gained a new method**: `Future<bool> deleteMyHouseholdPresence()`.
  `FirebaseBackend`'s implementation reads the caller's own member doc; if
  `role == 'owner'` it clears only `fcmToken` (`firestore.rules` forbids an
  owner deleting their own member doc — it would orphan the household) and
  returns `false`; otherwise it deletes the doc outright and returns `true`.
  No household joined → `true` (nothing to do). `FakeBackend` in
  `test/test_helpers.dart` mirrors this exact branching for tests
  (`householdRole`/`householdPresenceDeleted`/`householdFcmCleared` fields).
- **`AuthService.deleteAccount()`**: calls `FirebaseAuth`'s
  `currentUser.delete()`, letting `FirebaseAuthException` propagate
  (unlike most `AuthService` methods, which swallow errors) — specifically
  so the caller can detect code `requires-recent-login` and prompt a
  re-sign-in + retry rather than reporting a bare failure.
- **`AppDatabase.wipeAllData()`**: one transaction, `DELETE FROM medicines`
  (cascades to `medicine_schedules`/`medicine_doses`) plus explicit deletes
  of the three sync tables (`sync_tombstones`, `sync_outbox`,
  `sync_dose_tombstones`), which have no FK to `medicines` and would
  otherwise survive.
- **`AccountDeletionService.deleteEverything()`**: if signed in, attempts
  `deleteMyHouseholdPresence()` then `AuthService.deleteAccount()`
  (both wrapped so a failure never blocks the next step); local data is
  **always** wiped last, regardless of how the cloud steps went —
  `notifications.cancelAllPending()` → `db.wipeAllData()` →
  `prefs.clear()` (the same "every key" treatment `BackupService` already
  uses). Returns an `AccountDeletionResult` (`localDataWiped`,
  `householdPresenceRemoved`, `firebaseAccountDeleted`,
  `requiresRecentLogin`, `cloudError`, computed `fullyCleaned`) so the UI
  can report the honest outcome instead of a blanket "done."
- **UI flow** (`ProfileScreen._confirmDeleteAccount`/`_runDeletion`): one
  confirm dialog (consistent with this app's existing destructive-action
  pattern — sign-out, Pause All — not typed confirmation) → a blocking
  spinner during deletion → on `requiresRecentLogin`, a re-auth dialog that
  calls `AuthService.signInWithGoogle()` then retries the whole deletion →
  otherwise a result dialog, then the in-memory `SettingsController`/
  `AppState` are reloaded from the now-empty disk state and the entire app
  is rebuilt from a fresh `RootScreen` (`pushAndRemoveUntil`), which
  re-evaluates signed-in/onboarding state (both now false) and lands on
  Login rather than a stale Home screen.
- Not handled: revoking invitations the user created (24h TTL makes this
  low-value) or multiple households (the app's data model only supports one
  joined household at a time).

---

## 10. Testing

`test/` — **13 test files + 1 shared helper, 63 total test cases** (56
`test()` + 7 `testWidgets()`), confirmed by both grep count and a live
`flutter test` run. `test/test_helpers.dart` builds a real, isolated
per-test SQLite DB via `sqflite_common_ffi` (not a mock), plus a
`FakeScheduler` (records scheduled/cancelled notifications instead of
touching the OS) and a `FakeBackend` (in-memory `RemoteBackend`, since
2026-09-15 also simulating the owner-can't-self-delete household rule for
`AccountDeletionService` tests).

| File | Cases | Covers |
|---|---|---|
| `medicine_model_test.dart` | 6 | stock-tracking fields, `needsRefill`, `copyWith`/`toMap`/`fromMap` round-trips |
| `dose_repository_test.dart` | 7 | medicine CRUD round-trips; `ensureDose` dedup; taken/skipped/missed persistence + stats; `sweepMissed`; snoozed-then-ignored → missed |
| `dose_repository_extensions_test.dart` | 3 | `restorePreviousStatus`, `getPendingBetween` windowing, `deletePendingFrom` tombstoning |
| `dose_action_handler_test.dart` | 4 | taken/skip/snooze handling; malformed/unknown payloads ignored safely |
| `dose_scheduler_test.dart` | 8 | daily/specificDays/once/multiple generation; inactive medicines produce nothing; notification cancel-on-taken; snooze reschedule; stale-notification cleanup on edit |
| `export_service_test.dart` | 2 | JSON export shape + dose history inclusion |
| `family_invitation_test.dart` | 5 | `FamilyRole.normalize`; `FamilyPermissions` defaults/round-trip; QR payload carries only `{type,token,v}`, rejects malformed/foreign payloads |
| `reliability_fixes_test.dart` | 5 | atomic tombstone+delete; FK `ON DELETE CASCADE` enforced; undo state retained on write failure; sync checkpoint clock-jump safety |
| `sync_service_test.dart` | 11 | end-to-end via `FakeBackend`: enable→push→checkpoint; watcher join receives data; remote edit/delete propagation; exactly-once missed-dose alerts (24h cutoff); graceful degradation unconfigured; outbox queuing pre-enable; retry/backoff growth + reset; init-time reconcile |
| `home_widget_test.dart` | 2 (`testWidgets`) | Home greeting + empty state; next-dose card + "Mark as Taken" after adding a medicine |
| `caregiver_dashboard_test.dart` | 1 (`testWidgets`) | dashboard renders week/adherence/refresh/medicine name once the DB load completes |
| `medicine_form_widget_test.dart` | 4 (`testWidgets`) | name-required validation; save persists via repository; quick time-slot toggle; unit quick-pick |
| `account_deletion_service_test.dart` | 5 | `AppDatabase.wipeAllData()` clears medicines + all 3 sync tables; the signed-out/local-only deletion path end-to-end; `FakeBackend.deleteMyHouseholdPresence()` owner-vs-member-vs-no-household branching |

**Verified run (2026-09-15)**: `flutter analyze` → **0 errors, 0 warnings, 5
info-level lints** (all `use_build_context_synchronously`/
`unnecessary_brace_in_string_interps` in
`adherence_report_screen.dart`/`family_sync_screen.dart`/
`pill_photo_service.dart`). `flutter test` → **63/63 passed**, 0 failures
(the only non-trivial-looking log line, a deliberate `Bad state: simulated
undo failure` stack trace inside `reliability_fixes_test.dart`, is the test
intentionally exercising the undo-retry failure path, not a real failure).

**No CI pipeline exists** — no `.github/workflows/`, no other CI config
anywhere in the repo. Testing/analysis is currently manual/local-only.

---

## 11. Configuration & build

**`pubspec.yaml`**: package `medireminder`, version **`1.0.1+2`**, Dart SDK
`^3.9.0`.

| Group | Packages |
|---|---|
| State | `provider ^6.1.5+1` |
| Database | `sqflite ^2.4.2`, `sqflite_common_ffi_web ^1.0.2`; dev: `sqflite_common_ffi ^2.3.7+1` |
| Notifications | `flutter_local_notifications ^20.1.0`, `flutter_timezone ^5.1.0`, `timezone ^0.10.1` |
| Firebase | `firebase_core ^4.13.0` (resolved 4.15.0), `firebase_auth ^6.5.7` (resolved 6.7.0), `cloud_firestore ^6.8.0` (resolved 6.10.0), `firebase_messaging ^16.5.0` (resolved 16.7.0), `firebase_crashlytics ^5.4.0` (added 2026-09-15 — forced the core/auth/firestore/messaging resolutions above, upgraded together via `flutter pub upgrade --major-versions` to resolve a native Android plugin-version-skew build failure), `google_sign_in ^6.2.1` |
| Localization | `flutter_localizations` (sdk), `intl 0.20.2` (pinned exact) |
| Utility | `app_settings ^9.0.0`, `connectivity_plus ^7.3.1`, `crypto ^3.0.3`, `flutter_tts ^4.2.5`, `home_widget ^0.9.2+1`, `image_picker ^1.1.2`, `mobile_scanner ^6.0.2`, `path_provider ^2.1.5`, `qr_flutter ^4.1.0`, `share_plus ^10.1.4`, `shared_preferences ^2.5.5` |
| Dev | `flutter_test` (sdk), `flutter_lints ^5.0.0`, `sqflite_common_ffi ^2.3.7+1` |

`flutter:` section: `uses-material-design: true`, `generate: true` (drives
`flutter gen-l10n`), one bundled asset (`assets/dosewise_logo.png`).

**Android**: `applicationId`/`namespace` = `com.family.medireminder`.
`minSdk`/`targetSdk`/`compileSdk` are inherited from the Flutter Gradle
plugin (not hardcoded) — resolving, for the installed Flutter 3.35.1
toolchain, to **compileSdk 36, minSdk 24, targetSdk 36**, `ndkVersion
27.0.12077973`. Java/Kotlin target 11, with core-library desugaring enabled
(`desugar_jdk_libs 2.1.4`, required by `flutter_local_notifications`' use of
`java.time`). Firebase native deps via BoM `firebase-bom:34.18.0` → auth,
firestore, messaging (analytics deliberately omitted, per an inline comment,
to keep the Play Data-safety declaration minimal). **No product flavors.**

**Release signing**: the build script falls back to the debug keystore if no
`android/key.properties` is present, but on a machine where that file
*is* present (it's git-ignored — a local, per-developer/CI credential, not
committed) release builds are signed with the real upload keystore it
points to. The "release APK uses the debug key" caveat found in older docs
is therefore **conditional on that file's presence**, not an absolute
current fact — see §12.

**Localization config** (`l10n.yaml`): `arb-dir: lib/core/localization`,
template `app_en.arb`, output class `AppLocalizations`, `nullable-getter:
false`. Exactly two `.arb` files exist: `app_en.arb`, `app_hi.arb` (418
lines each).

**Lint config**: `analysis_options.yaml` is a single line —
`include: package:flutter_lints/flutter.yaml` — no custom rule overrides.

**Firebase config**: `android/app/google-services.json` is present, **is
committed to git** (not gitignored, unlike `key.properties`), and is a real,
fully-populated project registration — `project_id: remind-me-b7830`,
`project_number: 883368917967`, `storage_bucket:
remind-me-b7830.firebasestorage.app`, package name matching the app's
`applicationId`. There is **no `firebase.json`/`.firebaserc`** anywhere in
the repo, so Cloud Functions/Firestore-rules deploys rely on the Firebase
CLI selecting a project ad hoc (interactively or via `--project`) rather
than a pinned default.

**CI/CD**: none (see §10).

---

## 12. Discrepancies vs. other docs (flagged during this audit)

These are places where an existing doc's claim did **not** match the current
code as of this audit. Listed so future edits to those docs can correct
them, and so this document isn't silently propagating the same drift.

1. **Household members storage** — `README.md` describes members as a
   `{ uid: { role, joinedAt, fcmToken } }` **map field** on the household
   document. The current code (`firebase_backend.dart`,
   `invitation_service.dart`, `functions/index.js`) uses a
   `households/{id}/members/{uid}` **subcollection**; the Cloud Function
   explicitly comments that it deliberately queries the subcollection, not a
   map — this was a real historical bug and is now fixed. A legacy map-field
   fallback read remains in `getFamilyMembers()` purely for old, pre-migration
   household docs — that fallback is almost certainly the origin of the
   README's claim, but it no longer describes current writes.
2. **"Watcher" role** — README's framing implies a designated watcher role;
   current code has collapsed the model to exactly `owner`/`member`
   (`FamilyRole`), with `'watcher'`/`'primary'`/`'admin'` normalized away as
   legacy strings, and the missed-dose watcher itself is explicitly
   per-member-opt-in now ("the app no longer forces a single 'watcher'
   role," per an in-code comment), not tied to a role.
3. **Two separate Firebase Auth usages share one session** — README doesn't
   clearly distinguish the Google Sign-In identity (`AuthService`, Profile
   tab) from the anonymous sync identity (`FirebaseBackend`, Family & Sync)
   — they're conceptually different flows that happen to resolve to the same
   `FirebaseAuth.instance` current user, which is worth being explicit about
   to avoid confusing "signed in for sync" with "signed in to your Google
   account."
4. **Retry backoff jitter** — README's "30s → 60s → … capped at 10 min" is
   accurate but omits that a ±20% jitter multiplier is applied on top of
   every computed delay.
5. **Release signing** — the "debug key" caveat in older docs is not an
   unconditional fact; it's the fallback path when no `key.properties` is
   present. On a machine with that file (git-ignored, per-developer/CI),
   release builds use the real upload keystore.
6. **`DOSE_FIRE` log tag** — some older notes reference a `DOSE_FIRE` tag;
   the actual tag in code is `DOSE_ALARM_FIRE`.
7. **Server-side enforcement of `shareMedicines`/`shareMissedAlerts`** — no
   existing doc claims this is enforced server-side, but it's worth stating
   plainly here since it could easily be assumed: Firestore rules grant all
   household members full read/write on `medicines`/`doses` regardless of
   these flags, and the Cloud Function pushes missed-dose alerts to every
   member with a stored token regardless of `shareMissedAlerts`. The opt-in
   model is a client-side UX convention only, not a security boundary. **Not
   fixed in the 2026-09-15 hardening pass** — see
   [`PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) for why
   (the data model doesn't tag a dose with which member's device it came
   from, so it's unclear whose `shareMissedAlerts` flag the function should
   even check; fixing this needs a data-model decision, not a guess).

---

## 12a. Production hardening pass (2026-09-15)

A security/privacy → Firebase → notifications → sync → Android → error
handling → build → Play Store → accessibility audit was run against this
document and the live code; results and fixes are recorded in
[`PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) (full
detail) — summary of what changed in the code as a result:

- `lib/services/auth_service.dart`: no longer logs the signed-in user's raw
  email address to `developer.log` (was logged twice, on every Google
  sign-in — §12 point 7's sibling issue, PII in logs, not a doc mismatch).
- `android/app/src/main/AndroidManifest.xml`: `android:allowBackup="false"`
  added (was unset → Android default `true` with no exclusion rules, which
  would let Android Auto Backup copy the local health-adjacent SQLite DB to
  the user's Google Drive).
- `lib/main.dart`: added a `FlutterError.onError` +
  `PlatformDispatcher.instance.onError` handler (structured `developer.log`,
  tag `FlutterError`) — framework-level errors were previously invisible in
  release builds (only the existing `runZonedGuarded` caught *async* errors,
  and even that only did a bare `debugPrint`, which is stripped in some
  release configurations).
- `.firebaserc` / `firebase.json` added at the repo root — pins the Firebase
  project (`remind-me-b7830`) and points at `firestore.rules`/`functions/`,
  so `firebase deploy` can't accidentally target the wrong project (there
  was no committed default before).
- `android/app/proguard-rules.pro` added with standard Flutter/Firebase/
  `flutter_local_notifications` keep rules, referenced from
  `build.gradle.kts`'s `proguardFiles(...)` — but **`isMinifyEnabled` is
  still explicitly `false`**, so this is inert prep, not a behavior change;
  see the file's own header comment for why it wasn't turned on in this
  pass.
- `lib/features/medicines/medicines_screen.dart` + both `.arb` files: the
  search-clear `IconButton` (previously icon-only, no accessible label) now
  has a localized `tooltip`.
- **`PLAY_STORE_RELEASE.md`**: this file had the real production
  upload-keystore password committed to git in plaintext. Redacted from the
  file; **the password itself must still be rotated** since it already
  exists in git history — see that file's new warning banner and
  `PRODUCTION_READINESS_REPORT.md`'s top finding.

All verified via `flutter analyze` (clean, same 5 pre-existing info lints),
`flutter test` (58/58), and `flutter build apk --release` (succeeds, 82.0 MB,
real upload-keystore signing).

**Same-day follow-up (still 2026-09-15)**: account deletion and crash
reporting — flagged above and in the readiness report as real gaps but
deliberately left unbuilt in the hardening-only pass — were then explicitly
requested and built as real features. See §9's "Crash reporting" / "Account
& data deletion" subsections for what was built, and
`PRODUCTION_READINESS_REPORT.md` §0a for the full writeup. Current totals:
**63/63 tests**, release APK **82.7 MB**.

---

## 13. Known gaps / dead code

- **`PillPhotoService`** (`lib/services/pill_photo_service.dart`) exists
  (disk-based pill-photo storage keyed by medicine id) but is **not
  referenced anywhere** in `medicine_form_screen.dart` or the `Medicine`
  model — it's orphaned code, not a wired-up feature, despite `image_picker`
  being a listed dependency.
- **`VitalEntry.toMap()`/`fromMap()`** are unused for persistence — the
  actual Vitals Log screen writes/reads `SharedPreferences` directly with
  its own ad hoc `vital_<id>` key scheme, not through these model methods or
  any repository/table.
- **No CI pipeline** — analysis and testing are run manually, not gated on
  push/PR.
- **No composite Firestore indexes** — fine today (only single-field queries
  exist), but any future compound Firestore query will need an explicit
  index file. (`firebase.json`/`.firebaserc` were added in the 2026-09-15
  hardening pass, so deploys are no longer ad hoc about *which* project.)
- **`sync_tombstones` has no unique constraint** — unlike the outbox and
  dose-tombstone tables, repeated calls could in principle insert duplicate
  tombstone rows for the same medicine (harmless — they'd just cause a
  redundant delete-tombstone push — but inconsistent with the other two
  tables' upsert design).
- Device-level verification status (does the sound actually play on a real
  phone, does the Cloud Function fire, does the widget render, does an
  overnight/reboot alarm survive) is tracked separately in
  [`docs/PROJECT_DOCUMENTATION.md`](PROJECT_DOCUMENTATION.md) §5 — this
  document only asserts what the *code* does, not what's been proven on
  hardware.
