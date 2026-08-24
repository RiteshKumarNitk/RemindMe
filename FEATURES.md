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

## 5. Platforms & data

- **Android-first** (minSdk 24); Material 3, large type, 72 px primary buttons,
  4-tab bottom navigation.
- **Local DB** — SQLite (v4): `medicines`, `medicine_schedules`,
  `medicine_doses` (with `updated_at`), `sync_tombstones`, `sync_outbox`.
  Every row carries `updatedAt`, so a cloud sync layer needed no rework.
- **Localization** — English + हिंदी via ARB (`app_en.arb`, `app_hi.arb`),
  generated with `flutter gen-l10n`.

---

## Changelog

Newest first. Format: `date — what changed (why)`.

- **2026-08-17 — Add-medicine form upgrade**: quick **Morning/Afternoon/Evening/Night**
  one-tap time-slot chips (toggle add/remove, chronological order) and one-tap
  **unit quick-picks** (`mg`, `ml`, `tablet`, `capsule`, `drop`, `spoon`) that
  fill the unit field, plus `FEATURES.md` introduced and linked from the README.
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
