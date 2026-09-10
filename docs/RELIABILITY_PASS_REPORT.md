# Reliability pass — final report

Branch: `fix/reliability-pass-notifications` · 4 commits on top of `1aef0dd`.
`flutter analyze`: 0 errors / 0 warnings (5 pre-existing info lints).
`flutter test`: **58 / 58 pass** (was 47 pass + 1 fail before this pass).

> **Important context:** the brief assumed 18 unfixed bugs with specific
> line numbers. A prior pass had already landed fixes for ~14 of them
> (under junk commit messages). This pass **audited every one against the
> current code**, closed the genuine remaining gaps, fixed one regression
> that prior pass introduced, and did the notification + family work.

---

## 1. Root cause of the notification failure

No single code defect was found that would stop delivery. The pipeline is
architecturally complete and correct (local `AlarmManager` via
`flutter_local_notifications`, `alarmClock`-first scheduling that needs no
exact-alarm grant and fires in Doze, boot receiver, resume reconcile,
background-isolate actions, all six manifest permissions, MAX-importance
channel with a bundled WAV on the alarm stream + `fullScreenIntent`). The
historically likely culprits (channel-config caching, exact-alarm
fallback, `flutter_timezone` API, missing boot receiver) were **already
fixed** by the prior pass.

The realistic remaining causes are **device/OEM-level and only visible on
a real device run**:

1. `POST_NOTIFICATIONS` denied (Android 13+).
2. App **force-stopped** (user or OEM task killer) — Android drops all
   alarms until the app is reopened.
3. Battery optimisation not "Unrestricted" — Doze defers inexact alarms
   (mitigated by `alarmClock` mode; surfaced as `AppState.batteryUnrestricted`).
4. `SCHEDULE_EXACT_ALARM` revoked *and* the OEM also blocking
   `setAlarmClock` (rare) — degrades to inexact.
5. Full-screen-intent permission not granted (Android 14+) — the alarm
   still posts, but as a heads-up, not a lock-screen takeover.

This pass added **structured per-dose diagnostic logging** so the on-device
acceptance test pinpoints which of these it is. See §12.

## 2. Exact files changed

**Data layer**
- `lib/data/repositories/dose_repository.dart` — atomic `deletePendingFrom`
  (#16); `applyRemoteDose` skips doses whose parent medicine isn't local
  (FK-regression fix); `setSnoozedUntil` clears terminal timestamps (#2
  hardening); `import sqflite show ConflictAlgorithm`.
- `lib/state/app_state.dart` — `undoLastAction` retains state until refresh
  succeeds, `lastUndoFailed` getter (#17).
- `lib/services/sync/sync_service.dart` — clock-jump-safe checkpoint (#9);
  per-row-isolated remote-apply loops.
- `lib/data/database/app_database.dart` — schema **v7 → v8**; orphan-purge
  migration (#3).

**Notifications**
- `lib/services/dose_scheduler.dart` — `_audit()` structured `DoseAudit`
  records per scheduling decision.
- `lib/core/notifications/notification_background.dart`,
  `lib/main.dart` — `DOSE_FIRE` records on tap/action (fg / bg-isolate /
  cold-start).

**Family sync**
- `lib/services/sync/invitation_service.dart` — rewritten: transactional
  `acceptInvitation`, membership records, `FamilyRole`, `FamilyPermissions`.
- `lib/services/sync/firebase_backend.dart` — collision-safe
  `createHousehold`; `joinHousehold` verifies-only; member-subcollection
  push token.
- `firestore.rules` — rewritten for members-only + invitation-gated joins.
- `lib/features/settings/family_sync_screen.dart` — manual-code entry
  removed (with its leaked controller, #15); scanner wired; owner/member
  labels.
- `lib/features/settings/family_qr_scan_screen.dart`,
  `family_qr_show_screen.dart`, `family_connection_confirm_screen.dart` —
  API rename `householdCode → householdId`; `withOpacity` → `withValues`.
- `lib/data/models/app_settings.dart`,
  `lib/data/repositories/settings_repository.dart` — `syncRole` default
  `primary → owner`.

**Backup**
- `lib/features/settings/backup_screen.dart` — inline error state + Retry (#14).

**Tests / docs**
- `test/reliability_fixes_test.dart`, `test/family_invitation_test.dart` (new).
- `docs/NOTIFICATION_AUDIT.md`, `docs/FAMILY_SYNC.md`, this file (new).

## 3. Database migrations added

**v8** (`onUpgrade`, `oldVersion < 8`):
```sql
DELETE FROM medicine_doses      WHERE medicine_id NOT IN (SELECT id FROM medicines);
DELETE FROM medicine_schedules  WHERE medicine_id NOT IN (SELECT id FROM medicines);
```
One-time purge of rows orphaned on databases that predate the
`medicine_doses` FK+CASCADE (or where a delete raced the constraint).
Strictly scoped to genuinely orphaned rows; `sync_dose_tombstones` is left
intact (a tombstone legitimately outlives its medicine). Non-destructive
to valid data. Fresh installs run `onCreate` (already has the FK) and skip
all upgrades.

> v7 (already present) recreates `medicine_doses` with
> `FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE`,
> copying existing rows. `onConfigure` runs `PRAGMA foreign_keys = ON`.

## 4. Notification architecture (after)

```
Medicine saved ─▶ AppState.refresh ─▶ DoseScheduler.sync
   │                                     ├─ ensureDose() for each occurrence in the 7-day window
   │                                     ├─ _notificationTime(): snoozedUntil ?? scheduledAt
   │                                     │                       (or now+1s if overdue within grace)
   │                                     ├─ NotificationService.scheduleDoseReminder()
   │                                     │     zonedSchedule, mode = alarmClock
   │                                     │        → exactAllowWhileIdle → inexactAllowWhileIdle
   │                                     │     each verified against pendingNotificationRequests()
   │                                     ├─ scheduleAdvanceAlarm() × advanceMinutes (id = doseId*1000+offset)
   │                                     └─ cancel() anything pending that's no longer desired
   │
Reconciled on: cold start (deferred), every resume (didChangeAppLifecycleState),
               after every save / dose action, device reboot (ScheduledNotificationBootReceiver)
Delivery: OS AlarmManager → notification on the sound channel (MAX, bundled WAV,
          bypassDnd, insistent flag, fullScreenIntent) → DoseAlarmScreen / heads-up
Actions:  TAKEN / SNOOZE / SKIP → DoseActionHandler (foreground via onResponse,
          terminated via notificationBackgroundHandler isolate)
```
**Not** FCM. FCM is only used for family missed-dose *watcher* alerts, never
for the user's own medication reminders.

## 5. Exact alarm handling

`scheduleDoseReminder` tries, in order, and keeps the first that the OS
confirms in its pending list:
1. `AndroidScheduleMode.alarmClock` — `setAlarmClock()`, exact, fires in
   Doze, **needs no `SCHEDULE_EXACT_ALARM` grant**. Primary path.
2. `exactAllowWhileIdle` — only if `canScheduleExactNotifications()`.
3. `inexactAllowWhileIdle` — last resort; may be deferred by Doze (logged
   as such).
`canScheduleExact()` is pessimistic on null/error (reports "not granted"
and prompts) rather than claiming success.

## 6. Full-screen-intent handling

`USE_FULL_SCREEN_INTENT` in the manifest; `fullScreenIntent: true` on every
reminder + advance notification; `requestFullScreenIntentPermission()`
called in `main._postLaunch` (Android 14+ no longer auto-grants it to
non-call apps). When granted, the reminder takes over the lock screen via
`DoseAlarmScreen`; when not, it degrades to a heads-up notification (still
sounds and vibrates).

## 7. Notification permission handling

`main._postLaunch`, each step guarded and time-boxed, after first frame:
`areNotificationsEnabled()` → `requestPermission()` if not →
`requestExactAlarmPermission()` → `requestFullScreenIntentPermission()` →
`refreshPermissionStatus()`. Also requested in onboarding. Live state
(`notificationsEnabled`, `exactAlarmsEnabled`, `batteryUnrestricted`)
is surfaced in Settings with deep-links to the system screens.

## 8. Family QR architecture

Full detail in `docs/FAMILY_SYNC.md`. Summary:
- **Show QR** → `InvitationService.createInvitation` → 256-bit
  `Random.secure()` token, stored SHA-256-hashed at `invitations/{hash}`,
  `used:false`, 24h expiry. QR payload = `{type, token, v}` — **token only**,
  no id/uid/email/name/medical data (unit-tested).
- **Scan** → parse → `validateInvitation` (exists, unexpired, unused,
  not-self, not-already-member) → **Family Connection Request** screen
  (Cancel / Connect) → `acceptInvitation` = one **Firestore transaction**
  (re-validate + consume token + write membership) → duplicate/racing
  joins impossible.
- **Create Family** → `createHousehold` = transaction, writes only if the
  id is free, retries on clash — never a bare `set()`.

## 9. Multi-member family architecture

- `households/{id}/members/{uid}` **subcollection of records**:
  `{ userId, householdId, name, role, permissions, createdAt, fcmToken? }`.
  Not a two-party link — A/B/C/D each hold a record.
- Roles: **`owner`** (creator, exactly one) and **`member`**.
  `FamilyRole.normalize` maps legacy `primary`/`watcher`/`admin` on read.
- `SyncService` / `AppSettings` default role is now `owner`; the confirm
  screen joins as `member`.

## 10. Privacy / access-control behavior

- `FamilyPermissions` = `{shareMedicines:false, shareMissedAlerts:false}`
  by default. Joining exposes **no** medication data until the member opts
  in (`updateMyPermissions`).
- `firestore.rules`: households + all subcollections **members-only**; a
  `members` doc can only be created for yourself, and only as `member`
  when the `inviteHash` invitation was consumed by you for that household
  in the **same commit** (`getAfter`), or as `owner` if you are the
  household `ownerUid`.
- **Self-invite** blocked (client checks `creatorUid == currentUid`; also
  you'd need someone else's token).
- **Unauthorized removal** blocked — only the owner deletes another
  member; the owner's record can never be deleted; a member may only
  self-leave.
- **Access after removal** — deleting `members/{uid}` makes every
  subsequent medicine/dose request fail `isMember` → the ex-member's sync
  starts returning `permission-denied`.
- **Duplicate membership** blocked by the transactional accept.

## 11. All 18 bugs — disposition

| # | Disposition |
|---|-------------|
| 1 medicine id null from join | already fixed (`m.id AS med_id`) — verified |
| 2 `_setStatus` opposite status | already fixed; **+ hardened** `setSnoozedUntil` this pass |
| 3 delete leaves orphans | already fixed (txn + FK CASCADE); **+ v8 orphan-purge migration** this pass |
| 4 DB getter race | already fixed (`_opening` future) — verified |
| 5 no FK on `medicine_doses` | already fixed (FK + v7 migration + `PRAGMA foreign_keys=ON`) — verified |
| 6 escalation base time | already fixed (`snoozedUntil ?? scheduledAt`) — verified |
| 7 widget ignores snooze | already fixed (`snoozedUntil ?? scheduledAt`) — verified |
| 8 household code collision | **fixed this pass** — collision-safe `createHousehold`, transactional accept, members-only rules, QR-token identity |
| 9 checkpoint advances on stale pull | **fixed this pass** — never past `now`, never rewound; test added |
| 10 voice default mismatch | already fixed (`true` in all 3 layers) — verified |
| 11 missing `mounted` after pickers | already fixed (all 3 picker paths) — verified |
| 12 hardcoded English in alarm | already fixed (`l10n.elapsed*`, en+hi) — verified |
| 13 `copyWith` can't null fields | already fixed (sentinel pattern, both models) — verified |
| 14 backup screen no error handling | already partial; **+ inline error state + Retry** this pass |
| 15 `TextEditingController` leak | fixed — the leaking `_askCode` dialog was **removed** this pass |
| 16 tombstone + delete not atomic | **fixed this pass** — single `db.transaction`; test added |
| 17 undo state cleared too early | **fixed this pass** — retained until refresh succeeds; `lastUndoFailed`; test added |
| 18 `onComplete` after dispose | already fixed (`if (!mounted) return;` both paths) — verified |

**Bonus regression fixed:** the prior pass's FK work made `applyRemoteDose`
throw `FOREIGN KEY constraint failed` and abort the *entire* sync (incl.
the missed-dose alert check) whenever a dose arrived before its parent
medicine. `applyRemoteDose` now skips such rows; the remote-apply loops
are per-row isolated. This is why the suite went from 47+1-fail to 58 pass.

## 12. Tests performed and results

- `flutter analyze` — 0 errors, 0 warnings (5 pre-existing info lints).
- `flutter test` — **58/58 pass**. New: `reliability_fixes_test.dart`
  (#16 atomicity, #17 undo retention + recovery, #9 clock-jump safety ×2,
  FK cascade), `family_invitation_test.dart` (`FamilyRole.normalize`,
  `FamilyPermissions` privacy default + round-trip, QR payload carries no
  PII / rejects junk).
- **Not run** (cannot, from this environment):
  - the on-device notification acceptance test — protocol in
    `docs/NOTIFICATION_AUDIT.md`, now instrumented with `DoseAudit` logs.
  - Firestore rules + transactions — need the emulator or a real project;
    checklist in `docs/FAMILY_SYNC.md`.

## 13. Remaining warnings / issues

- **On-device notification test is unverified** — must be run by a human on
  real Android per §12 / `docs/NOTIFICATION_AUDIT.md`. Acceptance is
  functional ("fires at the selected time"), not compilation.
- **Firestore rules unverified** — deploy + emulator-test per
  `docs/FAMILY_SYNC.md` before shipping family sync. A rules bug here could
  expose medical data or lock members out.
- **Legacy households** created with the old `members` map: `getFamilyMembers`
  has a read-time fallback, but such households have no `members`
  subcollection, so the new rules' `isMember` (which checks the
  subcollection) will deny them. A migration (copy map → subcollection
  records) is needed if any production households predate this change.
- Pre-existing info lints untouched: `adherence_report_screen.dart:262`,
  `family_sync_screen.dart:453` (context-across-async-gap, both guarded),
  `pill_photo_service.dart` ×3 (brace-in-interpolation).
- `advanceMinutes` notification ids are `doseId*1000+offset` — overflows
  32-bit at `doseId ≈ 2.1M` (not reachable with a 7-day window; noted).
- An overdue-but-pending dose re-schedules its reminder to `now+1s` on
  every app resume (nag-until-actioned). Intended, but noticeable.

---

# Round 2 — notification + FCM follow-up

Commits `c67f9f1` (sound) and `00d799f` (FCM). `flutter analyze` 0/0,
`flutter test` 58/58, `node --check functions/index.js` OK.

## 1. Root cause — background notification unreliable
No single code defect. Local pipeline is complete and `alarmClock`-first
(kill-resistant, Doze-proof, no exact-alarm grant needed). The failures
are **device-state**: `POST_NOTIFICATIONS` denied, app **force-stopped**
(Android drops alarms until reopen), OEM deep-sleep allowlists, battery
not "Unrestricted". Now each is logged (`DOSE_PERMS`) and the FCM backup
covers the force-stop / dropped-alarm gap.

## 2. Root cause — no notification sound
The reminder channel + details never set `audioAttributesUsage`, so it
defaulted to `USAGE_NOTIFICATION`. The WAV played on the **notification
stream** — inaudible when ring/notification volume is low (common), while
stream-independent vibration kept working. **Fixed:** `audioAttributesUsage:
AudioAttributesUsage.alarm` everywhere sound is configured; channel
`v9 → v10` so Android adopts it.

## 3. Root cause — Firebase reminder never fired on time
There was **no server-side scheduler** — only a missed-dose Firestore
trigger. FCM can't schedule, and a client timer dies with the process.
**Fixed:** `functions/sendScheduledReminders`, Cloud Scheduler every minute.

## 4. Files changed (round 2)
`lib/core/notifications/notification_service.dart` (alarm audio attrs, v10,
`showDoseNow`, `DOSE_TZ` log), `lib/services/dose_scheduler.dart`
(`rescheduled`/`schedule_failed`/`DOSE_CANCEL`), `lib/state/app_state.dart`
(`DOSE_PERMS`), `lib/core/notifications/notification_background.dart` +
`lib/main.dart` (push wiring + `DOSE_FIRE`), **new**
`lib/services/push_messaging_service.dart`,
`lib/services/sync/firebase_backend.dart` (token + timezone on member doc),
**new** `functions/index.js` rewrite, `functions/package.json`, **new**
`firebase.json`, **new** `firestore.indexes.json`, `firestore.rules`
(`fcm_delivery_log` deny-all), `docs/NOTIFICATION_AUDIT.md`.

## 5. Local alarm architecture
`AlarmManager` via `flutter_local_notifications`, id = `doseId`
(advance = `doseId*1000+offset`) — unique/stable, no cross-medicine
collisions. `alarmClock → exactAllowWhileIdle → inexactAllowWhileIdle`,
each verified in the OS pending list. Reconciled on cold start, every
resume, every save/action, and reboot (`ScheduledNotificationBootReceiver`
re-registers persisted schedules; none duplicated, none in the past).
Edit → `deletePendingFrom` drops stale doses → their notifications
cancelled + new ones scheduled. Delete → FK-cascade removes doses → same.
Independent of the Flutter UI isolate; background actions run in
`notificationBackgroundHandler`.

## 6. Firebase architecture
`Cloud Scheduler (every 1 min) → sendScheduledReminders → collectionGroup
'doses' where status==pending and scheduled_at ∈ [now-3m, now+30s] → per
household, read members subcollection FCM tokens → sendEachForMulticast →
stamp dose.reminder_sent_at → write fcm_delivery_log`. `scheduled_at` is an
absolute UTC instant so no timezone math; the member IANA `timezone` is
logged only. `onDoseMissed` (ported to v2 + members subcollection) still
sends caregiver alerts.

## 7. Android permissions required
`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`+`USE_EXACT_ALARM`,
`USE_FULL_SCREEN_INTENT`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `WAKE_LOCK`,
`ACCESS_NOTIFICATION_POLICY` — all in the manifest, the first three
requested at runtime in `main._postLaunch` + onboarding, live state shown
in Settings and logged (`DOSE_PERMS`).

## 8. Channel id / name / sound
`medicine_reminders_v10` — "Medicine Reminders", `Importance.max`,
`playSound: true`, `sound: RawResourceAndroidNotificationSound('medicine_alarm')`
(res/raw/medicine_alarm.wav), `audioAttributesUsage:
AudioAttributesUsage.alarm`, vibration pattern, LED, `bypassDnd: true`.
Silent variant `medicine_reminders_silent_v10` (vibration only).
`family_alerts_v10` for caregiver/refill alerts. Reset procedure documented
in `docs/NOTIFICATION_AUDIT.md`.

## 9. Duplicate prevention (local + FCM)
Both post with **notification id = `doseId`** → Android shows exactly one;
the later arrival updates in place. Server also stamps `reminder_sent_at`
so it sends at most one FCM per dose. The device re-checks local dose
status before showing the FCM one and suppresses if already
taken/skipped/missed. No timestamp-based guessing.

## 10. Device testing results
**Not performed — no Android device/emulator available to this session.**
Instrumented protocol (13-row matrix, app-open / minimized / swiped /
locked / offline / reboot / multi-medicine / tap / Taken / Snooze / Skip)
in `docs/NOTIFICATION_AUDIT.md`. `flutter test` (58) and `flutter analyze`
(clean) are green; `node --check` on the function passes. This does **not**
constitute acceptance — the notification must be observed firing on real
hardware with sound + vibration.

## 11. Exact scheduled time vs actual delivery
Cannot measure without a device. The `DOSE_TZ` log line prints the
user-selected wall clock + zone, the exact local wall clock the OS alarm is
set for, and both UTC instants — so the on-device run proves there is no
UTC shift (`20:30 Asia/Kolkata` in ⇒ `20:30 Asia/Kolkata` scheduled).

## 12. Android / OEM limitations
`alarmClock` mode is the most kill-resistant API Android offers and is used
first, but cannot survive a user **Force-stop** or aggressive OEM
deep-sleep allowlists (MIUI Autostart, Samsung "Deep sleeping apps",
OnePlus). Battery-optimisation state is surfaced (`isIgnoringBatteryOptimizations`)
but not made a hard requirement. The FCM backup is what covers a dropped
local alarm. Background TTS is unreliable on Android by design, so voice is
best-effort and never the only alert — sound + vibration + full-screen are
the guaranteed channel.

## Still requires human / project verification
- On-device notification acceptance test (§10–11).
- Firestore rules on the emulator (`docs/FAMILY_SYNC.md`).

---

# Round 3 — Spark-only: server-side scheduler removed

The Round-2 Cloud Function / Cloud Scheduler approach needs Firebase Blaze.
Reverted. The medicine reminder is now **local-only** again, which is what
the working `alarmClock`-first implementation already was.

### 1. Files changed
- **Reverted** (`00d799f` undone surgically): `functions/index.js` +
  `functions/package.json` restored to their pre-existing caregiver-alert
  form; `firebase.json` and `firestore.indexes.json` deleted;
  `lib/services/push_messaging_service.dart` deleted;
  `NotificationService.showDoseNow` removed; `main.dart` push wiring
  removed; `FirebaseBackend.attachPushToken` back to `{fcmToken}` only;
  `firestore.rules` `fcm_delivery_log` block removed.
- **Kept / adjusted** (local logging + delivery quality):
  `lib/core/notifications/notification_service.dart` — RC-1 sound fix
  (`audioAttributesUsage: alarm`, channel `v10`), reminder `category`
  `reminder → alarm` + `priority max`, `DOSE_TZ` (renamed fields:
  `deviceTimezone / deviceNow / scheduledLocal / scheduledUtc /
  effectiveLocal / effectiveUtc / alarmId`), new `DOSE_NOTIFICATION` line.
  `lib/services/dose_scheduler.dart` — tags `DOSE_ALARM_SCHEDULE` /
  `DOSE_ALARM_SCHEDULE_ADVANCE` / `DOSE_CANCEL`.
  `lib/state/app_state.dart` — `DOSE_PERMS` every reconcile
  (`notifications / batteryOptimization / alarmCapability`).
  `lib/main.dart`, `lib/core/notifications/notification_background.dart` —
  `DOSE_ALARM_FIRE`.
  `docs/NOTIFICATION_AUDIT.md` rewritten local-only.

### 2. Exact root cause found
- **Sound:** channel + details never set `audioAttributesUsage` → default
  `USAGE_NOTIFICATION` → WAV on the notification stream → inaudible with the
  ringer down (vibration is stream-independent, hence it worked).
- **Background/closed unreliability:** no code defect; it is device-state
  (permission denied / force-stop / OEM deep-sleep / Doze on the inexact
  fallback). Now logged.
- **"Firebase never fires on time":** expected — FCM can't schedule and the
  reminder now deliberately does not use it.

### 3. Exact fix applied
`audioAttributesUsage: AudioAttributesUsage.alarm` on both sound channels
and every reminder `AndroidNotificationDetails`; channel id `v9 → v10` so
Android adopts it; `CATEGORY_ALARM` + `PRIORITY_MAX` on the reminder.
Structured `DoseAudit` logging per the requested vocabulary. No scheduling
mechanism changed — `alarmClock → exactAllowWhileIdle →
inexactAllowWhileIdle`, each verified against the OS pending list.

### 4. Notification channel id
`medicine_reminders_v10` ("Medicine Reminders"). Silent variant
`medicine_reminders_silent_v10`. Family `family_alerts_v10`.

### 5. Sound configuration
`playSound: true`, `sound: RawResourceAndroidNotificationSound('medicine_alarm')`
(`android/app/src/main/res/raw/medicine_alarm.wav`, present),
`audioAttributesUsage: AudioAttributesUsage.alarm` on the channel **and**
the details, `Importance.max`, `FLAG_INSISTENT` loop, vibration pattern,
LED, `fullScreenIntent: true`, `bypassDnd: true`, `CATEGORY_ALARM`.

### 6. Alarm scheduling method
`flutter_local_notifications` `zonedSchedule` with
`AndroidScheduleMode.alarmClock` first (`AlarmManager.setAlarmClock()` —
exact, Doze-exempt, no `SCHEDULE_EXACT_ALARM` grant needed), then
`exactAllowWhileIdle`, then `inexactAllowWhileIdle`; each accepted only if
it appears in `pendingNotificationRequests()`.

### 7. Permissions used
`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT`,
`SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` (fallback path only), `VIBRATE`,
`WAKE_LOCK`, `ACCESS_NOTIFICATION_POLICY`. Manifest unchanged this round.

### 8. How background/closed alarms work
`AlarmManager.setAlarmClock` registers the alarm in the OS, independent of
the app process. At fire time the OS invokes the plugin's native
`ScheduledNotificationReceiver` (no Flutter UI required) which posts the
notification. Actions route to `notificationBackgroundHandler`, a
`@pragma('vm:entry-point')` isolate that rebuilds the DB + plugin and
applies TAKEN/SNOOZE/SKIP. The app is reconciled on every open/resume so
missed windows self-heal.

### 9. How reboot recovery works
`ScheduledNotificationBootReceiver` (`BOOT_COMPLETED` /
`MY_PACKAGE_REPLACED` / QUICKBOOT) re-registers every persisted
`zonedSchedule` with AlarmManager — no duplicates, nothing in the past.
On the next app open, `DoseScheduler.sync` reconciles the OS alarm set
against the database (creates missing, cancels stale).

### 10. How to test on a real Android device
See `docs/NOTIFICATION_AUDIT.md` — 13-row matrix (open / minimized /
swiped / locked / Doze / airplane / reboot / multi-medicine / tap / Taken /
Taken-before / Snooze / Skip) with the `adb logcat | grep DoseAudit`
trace. **Not run here** — no device available to this session. `flutter
analyze` 0/0, `flutter test` 58/58.

### 11. Any Firebase Blaze feature added?
**No.** None. Cloud Functions / Cloud Scheduler removed. The project runs
entirely on the free Spark plan (Auth, Firestore, FCM token registration,
Family Sync unchanged). The pre-existing `functions/index.js` caregiver
missed-dose trigger is left exactly as it was — it is optional, would need
Blaze to *deploy*, and is unrelated to the medicine-reminder path (note: it
still reads the old `members` map and channel `family_alerts`, both changed
by the family rework — update or drop it if you ever deploy functions).

---

# Round 4 — background/closed alarm debug (`cbXXXXX`)

`flutter analyze` 0/0, `flutter test` 58/58. **Local-only, Spark, no
background service.**

### 1. Exact reason the alarm wasn't firing
Two things, both fixed:
- **RC-4 (new):** `scheduleDoseReminder` scheduled via `alarmClock`
  (exact, Doze-exempt) then re-queried `pendingNotificationRequests()`; if
  the id wasn't echoed back it **fell through and re-scheduled the same id
  with `inexactAllowWhileIdle`**, replacing the good alarm with one Doze
  holds through the idle window. Many OEMs don't list `setAlarmClock`
  alarms in that query → a locked, idle 2-minute test never fired.
  **Fixed:** `alarmClock`, once accepted, is trusted; the fallback chain
  runs only if it *threw*.
- **RC-1 (round 3):** sound was on the notification stream, not the alarm
  stream — inaudible with the ringer down. Fixed via
  `audioAttributesUsage: alarm` + channel `v10`.
Everything else (`app closed` fundamentals) is device-state: force-stop /
OEM deep-sleep / denied `POST_NOTIFICATIONS`, all now logged.

### 2. AlarmManager API currently used
`flutter_local_notifications` `zonedSchedule` →
`AndroidScheduleMode.alarmClock` → **`AlarmManager.setAlarmClock(AlarmClockInfo,
operationPendingIntent)`**. Fallbacks (only if that throws):
`exactAllowWhileIdle` → `setExactAndAllowWhileIdle`;
`inexactAllowWhileIdle` → `setAndAllowWhileIdle`.

### 3. Is AlarmClockInfo valid?
Yes — the plugin builds `new AlarmManager.AlarmClockInfo(triggerAtMillis,
showIntent)` where `triggerAtMillis` is `scheduledDate.millisecondsSinceEpoch`
(absolute; timezone of `tz.local` does not affect *when* it fires — the
`DOSE_TZ` log proves `scheduledLocal == effectiveLocal`). `showIntent` is
the plugin's launch PendingIntent for MainActivity.

### 4. PendingIntent action
The plugin uses an **explicit** PendingIntent targeting
`com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
(component set, no action string) with extra `notification_id`. Delivery
does not rely on an intent-filter.

### 5. Alarm requestCode
= the **notification id** = `doseId` for the main reminder,
`doseId*1000+offset` for advance alarms. Stable and unique per dose, so
one medicine's reschedule never overwrites another's PendingIntent. Logged
as `alarmId=` / `notificationId=`.

### 6. BroadcastReceiver class
`com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
(shipped in the plugin's `android/src/main/java/...`). Also
`ScheduledNotificationBootReceiver` and `ActionBroadcastReceiver`.

### 7. Manifest registration
All three declared in `android/app/src/main/AndroidManifest.xml`,
`android:exported="false"`, boot receiver with the `BOOT_COMPLETED` /
`MY_PACKAGE_REPLACED` / QUICKBOOT intent-filter. Plugin v20's library
manifest ships **only** permissions, so the app declaring the receivers is
**required** and correct. **No manifest change made** (verified sufficient).

### 8. Does the receiver work with the app process killed?
Yes — `ScheduledNotificationReceiver` is native Java. On fire it reads the
payload persisted at `zonedSchedule` time, re-creates the channel
(`channelAction=createIfNotExists`), and calls `NotificationManager.notify()`.
**No Flutter engine / Dart / MainActivity required** for the notification.
Action buttons (TAKEN/SNOOZE/SKIP) do spin up the
`notificationBackgroundHandler` isolate for the DB write, but the alert
itself does not.

### 9. Notification channel id
`medicine_reminders_v10` (silent variant `medicine_reminders_silent_v10`,
family `family_alerts_v10`). Logged every schedule as
`DOSE_NOTIFICATION channelId=`.

### 10. Sound resource
`android/app/src/main/res/raw/medicine_alarm.wav` (present, 258 KB, valid
lowercase resource name). `RawResourceAndroidNotificationSound('medicine_alarm')`
on the channel **and** the details, `audioAttributesUsage: alarm`.

### 11. Notification permission status handling
`areNotificationsEnabled()` checked at boot (`_postLaunch`), before the
in-app test, and now **at schedule time** — a denial logs
`DOSE_ERROR stage=permission`. `DOSE_PERMS` (every reconcile) reports
`notifications / batteryOptimization / alarmCapability`. Settings shows a
live status card + deep links.

### 12. Boot recovery
Plugin's `ScheduledNotificationBootReceiver` re-registers every persisted
`zonedSchedule` with AlarmManager on `BOOT_COMPLETED` — natively, no Dart.
On next app open `DoseScheduler.sync` reconciles against the DB and logs
`DOSE_BOOT_RESTORE osPendingAlarmIds=[…] count= desiredThisWindow=`. No
duplicates (id = `doseId`), nothing scheduled in the past
(`_notificationTime` guards).

### 13. Battery / OEM handling
`isIgnoringBatteryOptimizations()` (MethodChannel to `PowerManager`)
surfaced in Settings and in `DOSE_PERMS`. `alarmClock` mode is the
kill-resistant path. No foreground service, no `Timer.periodic`, no
polling, no keep-alive — none added, none present. Aggressive OEMs
(MIUI/Samsung/OnePlus) and explicit Force-Stop are documented as
out-of-reach; the log identifies them.

### 14. Exact files changed (round 4)
`lib/core/notifications/notification_service.dart` — trust `alarmClock`
(no downgrade), `medicineId` param, `_auditSchedule` emits the canonical
`DOSE_ALARM_SCHEDULE` with `scheduleMethod` + `osQueueVerified`,
`DOSE_ERROR` at every failure, self-test emits `DOSE_ALARM_SCHEDULE`.
`lib/services/dose_scheduler.dart` — pass `medicineId`, drop the now-duplicate
`_audit`, add `DOSE_BOOT_RESTORE`.
`lib/services/dose_action_handler.dart`, `lib/state/app_state.dart` — pass
`medicineId` through the snooze reschedule.
`lib/features/settings/settings_screen.dart` — "Test scheduled alarm" (60 s,
same code path as a dose) is now visible in release, not just debug.
`test/test_helpers.dart` — `FakeScheduler` signature.
`docs/NOTIFICATION_AUDIT.md` — RC-4, log vocabulary, receiver verification,
decision tree, A/B/C test split, Windows `findstr` ADB.

### 15. Exact ADB commands (Windows)
```
adb devices
adb logcat -c
adb logcat | findstr "DOSE_"
```
Doze: `adb shell dumpsys deviceidle force-idle` … test …
`adb shell dumpsys deviceidle unforce`.
Interpretation: `DOSE_ALARM_SCHEDULE` but no `DOSE_ALARM_FIRE` →
AlarmManager/OS/force-stop (check `scheduleMethod`; if `inexact*`, fix
battery/exact-alarm); `DOSE_ALARM_FIRE` but nothing visible →
permission/channel/DnD.

**Not run here** — no Android device in this environment. `flutter analyze`
0/0, `flutter test` 58/58 is *not* acceptance; A + B on real hardware is.
