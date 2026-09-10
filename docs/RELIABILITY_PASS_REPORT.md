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
