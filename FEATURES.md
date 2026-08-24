# Features — Medicine Reminder (RemindMe)

**Maintained file.** Every time a feature is added, changed, or removed, update
this document (add a line to the [Changelog](#changelog) and adjust the relevant
section below). Keep the changelog newest-first.

Companion docs: [`README.md`](README.md) (setup, database, permissions,
deployment) and `.freebuff/run.md` (how to run the web preview).

---

## 1. Core reminders (Phase 1 — MVP)

- **Home dashboard** — greeting, "Next Medicine" card with a huge **TAKE
  MEDICINE** button, today's schedule, and Taken / Remaining / Missed counters.
- **Add / Edit medicine form** — designed for one-handed elderly use: large
  fields, big chips, no hidden options.
- **Local notifications** with **TAKEN / SNOOZE / SKIP** action buttons; work
  with the app closed, backgrounded, or the phone locked; re-armed after reboot
  by the boot receiver.
- **Snooze** — reschedules the reminder for a configurable duration (default 10
  min).
- **History** — Today / This Week / All, with per-status counts and adherence %.
- **Medicines list** — pause / resume / edit / delete (with confirmation).
- **Settings** — language (English / हिंदी), notification sound, voice reminder
  (TTS), snooze duration, "missed after" grace period, dark mode, permission
  shortcuts, about/disclaimer.
- **Voice reminder** — optional spoken reminder plus a speaker button on the
  home card; works while the app is running (Android foreground only).

### Medicine form fields

| Field | Details |
| --- | --- |
| Name | required, free text |
| Dose | number (e.g. "1") |
| Unit | free text **plus one-tap quick picks**: `mg`, `ml`, `tablet`, `capsule`, `drop`, `spoon` |
| Food instruction | No special instruction / Before food / After food / With food |
| Frequency | Every day / Specific days / Once / Multiple times a day |
| Days | weekday chips (shown when "Specific days") |
| Once date | date picker (shown when "Once") |
| Reminder times | add / edit / delete times via time picker |
| **Quick time slots** | one-tap **Morning (8:00) / Afternoon (13:00) / Evening (18:00) / Night (21:00)** chips — tap to add, tap again to remove; times kept in chronological order |
| Notes | optional free text |

## 2. Reliability engineering

- **Dose scheduler** — pre-generates a rolling 14-day window of dose rows and
  schedules **one exact-alarm notification per dose** (`exactAllowWhileIdle`,
  falling back to inexact when the exact-alarm permission is missing).
- **Self-healing schedule** — every app start/resume re-syncs the OS
  notification schedule against the database, so edits, deletes, pauses,
  snoozes and permission changes self-correct.
- **Missed tracking** — ignored doses become **Missed** automatically after the
  configurable grace period.

## 3. Family sync & caregiver (Phase 2)

- **Offline-first sync** — local SQLite DB stays the source of truth; sync is
  best-effort background work on top.
- **Backend abstraction** — `RemoteBackend` interface with a Firebase
  implementation (Auth anonymous sign-in + Firestore); swappable later.
- **Households** — create a family (6-char code) or join by code; roles:
  primary (takes medicines) and watcher (family).
- **Conflict resolution** — merge by `updatedAt` (newest wins); tombstones so
  deletes propagate instead of being resurrected; remote applies never echo
  back into the outbox.
- **Persistent outbox queue** — every local mutation is enqueued at write time
  and removed only after the backend confirms the upload; survives network
  outages, app restarts and clock jumps.
- **Checkpoint reconcile** — on start/enable, anything changed since the last
  successful sync is re-queued (idempotent safety net for upgrades or a lost
  outbox).
- **Retry with backoff** — failed syncs keep the queue and retry with
  exponential backoff + jitter (30 s → … → 10 min cap); resets on success.
- **Connectivity-triggered retry** — `connectivity_plus` fires a sync
  immediately when the network returns after being offline.
- **Missed-dose alerts** — a 24 h-recency watcher raises a local
  "⚠️ Missed medicine" notification for watchers; a Firestore-triggered Cloud
  Function (`functions/index.js`) fans out **FCM push alerts** to all household
  members when a dose flips to `missed` (24 h TTL so history syncs don't spam).
- **Family Dashboard (watcher view)** — weekly adherence card (adherence %,
  Taken / Missed / Skipped) and today's household dose list with status chips;
  reads through the synced local mirror (works offline, no blank screen).
- **Security** — `firestore.rules` restrict every household read/write to
  authenticated members.

## 4. Web preview support

- The app runs in a browser via the Flutter **web** build (`web/` platform
  dir added; `sqflite_common_ffi_web` provides in-browser SQLite WASM).
- Android-only features (notifications, TTS, exact alarms) no-op gracefully on
  web; Firebase sync stays disabled without a config (app still fully usable).
- **Fixes that web support required**: lazy Firestore/Auth handles in
  `FirebaseBackend` (eager `.instance` access crashed startup on web and on
  Android without auto-init), guarded notification init, conditional-import DB
  factory (`database_factory_stub.dart` for IO), and generated `web/sqflite_sw.js`
  + `web/sqlite3.wasm` binaries (regenerate with `dart run sqflite_common_ffi_web:setup`).

## 5. UX enhancements

- **Undo** — 5-second SnackBar with Undo button after marking a dose Taken or
  Skipped; reverts the status change locally and re-syncs.
- **Skip confirmation** — tapping Skip shows a confirmation dialog to prevent
  accidental skips.
- **Daily progress bar** — linear bar showing "3 / 6 doses done" with a %
  label; green when 100%; hidden when no doses exist.
- **Urgency indicator** — when the next dose is due now (within 10 min), the
  Next Medicine card switches to an error-colored background with a pulsing
  bell icon; a countdown badge shows "in 2h", "5 min late", etc.
- **Medicine search** — search bar on the My Medicines screen filters by name
  with a clear button.
- **Batch mark-all** — "Mark all as taken" button below the dose list when
  any pending doses remain.
- **All-done badge** — green banner with 🔥 when every dose for today is
  resolved with zero misses.
- **Schedule summary overflow** — medicine card schedule text wraps instead of
  overflowing on narrow screens.

## 6. Medicine form enhancements

- **Quick time slots** — one-tap Morning / Afternoon / Evening / Night chips
  that add or remove pre-set times (8:00, 13:00, 18:00, 21:00).
- **Unit quick-picks** — one-tap mg / ml / tablet / capsule / drop / spoon
  chips that fill the unit field.
- **Weekday / Weekend presets** — "Weekdays" (Mon–Fri) and "Weekends"
  (Sat–Sun) one-tap presets in the Specific Days picker.

## 7. Batch & convenience

- **Pause All Medicines** — Settings tile that pauses every active medicine and
  cancels its pending notifications; resumable per-medicine.
- **Quick Duplicate** — copy button on each medicine card creates a duplicate
  with "(copy)" suffix, same schedules, ready to edit.

## 8. Stock & refill tracking

- **Stock count / refill threshold** — optional fields on the medicine form
  ("Current pills" / "Remind at"). When the stock drops to or below the
  threshold, a refill reminder notification fires on every app open.
- **DB v6**: `medicines` table gains `stock_count INTEGER` and
  `refill_at INTEGER` columns.

## 9. Export & reporting

- **Export CSV** — button on the History screen generates a selectable CSV of
  all dose entries in the current date range (Date, Time, Medicine, Dose,
  Status). Shown in a dialog for copy-paste.
- **Export JSON backup** — Settings tile that serializes all medicines,
  schedules, and dose history (last 365 days) to a formatted JSON string
  shown in a dialog for copy-paste. Useful for backup/restore across devices.

## 10. Schedule conflict warning

- When saving a medicine whose reminder times overlap with another medicine,
  a confirmation dialog warns the user ("These medicines are already scheduled
  at the same time: X. Continue anyway?").

## 11. Adherence trend

- **Trend indicator** — on the History screen (This Week view), a colored
  trend badge shows "Adherence is looking good!" (>= 70%) or "Adherence
  needs improvement" (< 70%) with an up/down/flat icon.

## 12. Notification sound & reliability hardening

- **Custom alarm sound** — generated triple-beep WAV (880 Hz, 3×0.4s) at
  `android/app/src/main/res/raw/medicine_alarm.wav` used by all notification
  channels; loud and distinctive enough for elderly users.
- **Custom vibration pattern** — double-buzz pattern (300ms buzz → 200ms pause →
  400ms buzz) that is more noticeable than a single pulse through clothing.
- **LED lights** — green LED blinks on medicine reminders, orange on family
  alerts; `enableLights: true` on all channels.
- **fullScreenIntent** — scheduled dose reminders use `fullScreenIntent: true`
  so the notification behaves like an alarm on the lock screen.
- **Auto-permission request** — every app launch auto-checks and requests
  notification permission + exact alarm permission if not yet granted; the OS
  dialog only shows once; subsequent calls are silent.
- **Voice enabled by default** — `voiceEnabled` defaults to `true` so elderly
  users hear "Time to take [medicine]" without any configuration.
- **BigTextStyleInformation** — notification body text is rendered expanded
  (not collapsed) so the full medicine name and instructions are visible.

## 13. Platforms & data

- **Android-first** (minSdk 24); Material 3, large type, 72 px primary buttons,
  4-tab bottom navigation.
- **Local DB** — SQLite (v6): `medicines` (with `stock_count`, `refill_at`),
  `medicine_schedules`, `medicine_doses` (with `updated_at`),
  `sync_tombstones`, `sync_dose_tombstones`, `sync_outbox`.
  Every row carries `updatedAt`, so a cloud sync layer needed no rework.
- **Localization** — English + हिंदी via ARB (`app_en.arb`, `app_hi.arb`),
  generated with `flutter gen-l10n`.

---

## Changelog

Newest first. Format: `date — what changed (why)`.

- **2026-08-24 — Notification sound fixes (critical)**: versioned channel IDs
  (v2) to force Android to recreate channels with correct sound/vibration;
  louder triple-beep WAV (880 Hz + harmonic, 3s); `USE_FULL_SCREEN_INTENT`
  permission added; "Test Notification Sound" button in Settings; Hindi
  localization for test notification.
- **2026-08-24 — Advance alarm (pre-dose looping)**: configurable advance
  alarm that starts 1-10 minutes before dose time, re-firing every minute
  until taken; settings UI with chip selector (Off / 1 / 2 / 3 / 5 / 10 min);
  advance notifications use fullScreenIntent + alarm sound for maximum
  visibility on lock screen.
- **2026-08-24 — Notification sound & permission fixes**: custom triple-beep
  alarm WAV in `res/raw/medicine_alarm.wav`; custom double-buzz vibration
  pattern; LED lights; fullScreenIntent for lock-screen alarm; auto-request
  notification + exact-alarm permission on every launch; voice enabled by
  default; BigTextStyleInformation for expanded notification body.
- **2026-08-24 — Remaining Phase 3 features**: stock/refill tracking (DB v6,
  refill reminder notification), CSV export on History screen, schedule conflict
  warning in medicine form, adherence trend indicator (>= 70% good, < 70% needs
  work).
- **2026-08-24 — Export & tests**: JSON backup export in Settings, 11 new tests
  (48 total: medicine model stock fields, export service, dose repository
  extensions).
- **2026-08-17 — Add-medicine form upgrade**: quick **Morning/Afternoon/Evening/Night**
  one-tap time-slot chips (toggle add/remove, chronological order) and one-tap
  **unit quick-picks** (`mg`, `ml`, `tablet`, `capsule`, `drop`, `spoon`) that
  fill the unit field, plus `FEATURES.md` introduced and linked from the README.
- **2026-08-24 — Phase 3 features**: batch mark-all-as-taken, weekday/weekend
  presets, quick duplicate medicine, "All done today" streak badge, pause all
  medicines in settings.
- **2026-08-24 — UX overhaul (Phase 2)**: 5-second undo SnackBar after marking
  doses taken/skipped; skip confirmation dialog; daily progress bar
  ("3 / 6 doses done"); pulsing urgency indicator + countdown badge for due-now
  doses; medicine list search; history "All" capped at 90 days; schedule
  summary text overflow fix; voice feedback for skipped doses.
- **2026-08-24 — Critical bug fixes (Phase 1)**: dose tombstone gap (edited
  medicines now propagate dose deletions to cloud); _entryFromRow single-parsed;
  getAllUpdatedSince SQL-optimized; DoseScheduler N+1 query batched; connectivity
  deduped via `.distinct()`; dose tombstone sync to Firestore (DB v5).
- **2026-08-17 — Web preview enabled**: Flutter web build with in-browser SQLite
  (WASM); lazy Firebase handles + guarded notification init so startup never
  crashes when Firebase is unconfigured; generated SQLite web binaries.
- **2026-08-17 — Caregiver view**: Family Dashboard screen (weekly adherence +
  today's doses for watchers); shared `AdherenceCard`/`DoseListTile` extracted
  from History; fixed a "setState during build" crash on dashboard open.
- **2026-08-17 — SyncService hardening**: persistent outbox queue (DB v4),
  checkpoint reconcile safety net, exponential backoff with jitter, and
  connectivity-triggered retry; Family & Sync shows pending count + retry state.
- **2026-08-17 — Phase 2 (cloud sync)**: Firebase Auth (anonymous) + Firestore
  household sync, tombstones, missed-dose FCM alerts (Cloud Function), Family &
  Sync screen; DB migrated to v3 (`updated_at` on doses).
- **2026-08-17 — Phase 1 (MVP)**: core reminder app (scheduler, notifications,
  history, settings, EN/HI l10n, onboarding, permissions).
