# Notification pipeline — end-to-end audit

Scope: why a medicine reminder might not fire at the user's selected time,
and what the code now guarantees. Reminders are **local** (Android
`AlarmManager` via `flutter_local_notifications`), never FCM — they work
with the app closed and offline.

## Flow, stage by stage

| # | Stage | Where | Status |
|---|-------|-------|--------|
| 1 | Medicine + schedule saved | `MedicineRepository.insert/update` (txn) | OK |
| 2 | Dose rows generated for the window (7 days) | `DoseScheduler._occurrences` → `DoseRepository.ensureDose` | OK |
| 3 | Effective fire time chosen (`snoozedUntil ?? scheduledAt`, or "now+1s" if overdue within grace) | `DoseScheduler._notificationTime` | OK |
| 4 | OS alarm scheduled | `NotificationService.scheduleDoseReminder` → `zonedSchedule` | OK, now audited |
| 5 | Timezone resolution | `NotificationService.initTimeZone` (`flutter_timezone` 5.1 → `.identifier`; falls back to `UTC`) | OK — `TZDateTime.from` preserves the absolute instant even if the zone name is wrong |
| 6 | Schedule mode | `alarmClock` → `exactAllowWhileIdle` → `inexactAllowWhileIdle`, each verified against `pendingNotificationRequests()` | OK — `alarmClock` needs no `SCHEDULE_EXACT_ALARM` grant and fires in Doze |
| 7 | Reconcile on every app open / resume | `AppState.refresh` → `DoseScheduler.sync`; also `_MainShellState.didChangeAppLifecycleState` | OK |
| 8 | Reschedule after reboot / app update | `ScheduledNotificationBootReceiver` (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, QUICKBOOT) | OK — plugin re-registers every persisted `zonedSchedule` |
| 9 | Action buttons while terminated | `notificationBackgroundHandler` isolate → `DoseActionHandler` | OK |
| 10 | Cold start from a notification | `main._postLaunch` → `getNotificationAppLaunchDetails` | OK |

### Permissions (`AndroidManifest.xml`, all present)

`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM`,
`USE_FULL_SCREEN_INTENT`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`,
`WAKE_LOCK`, `ACCESS_NOTIFICATION_POLICY`. Requested at runtime in
`main._postLaunch` (notifications, exact alarm, full-screen intent) and in
onboarding.

### Channels (`NotificationService._createChannels`)

`Importance.max`, bundled `res/raw/medicine_alarm.wav` on the **alarm**
audio stream, `bypassDnd: true`, custom vibration pattern, LED, and
`fullScreenIntent: true` per notification. Channel id is version-suffixed
(`_v9`) and old ids are deleted first, because Android ignores channel
config changes after first creation.

## Root-cause assessment

Static analysis found **no defect that would stop delivery**. The prior
pass had already fixed the historically likely culprits (channel config
caching, exact-alarm fallback, resume reconcile, boot receiver, timezone
API). The realistic remaining causes are **device/OEM-level**, which only
an on-device run surfaces:

1. `POST_NOTIFICATIONS` denied (Android 13+) — nothing shows.
2. App **force-stopped** by the user or an aggressive OEM task killer —
   Android cancels all alarms until the app is next opened.
3. Battery optimization not "Unrestricted" — Doze can defer an inexact
   alarm indefinitely (mitigated by `alarmClock` mode, surfaced by
   `AppState.batteryUnrestricted`).
4. `SCHEDULE_EXACT_ALARM` revoked on Android 14+ AND the OEM also blocks
   `setAlarmClock` (rare) — degrades to inexact.
5. Full-screen intent permission not granted on Android 14+ — the alarm
   still posts as a heads-up, but does not take over the lock screen.

## Diagnostic logging (added in this pass)

One structured line per scheduling decision, tag `DoseAudit`:

```
DOSE_SCHEDULE medicineId=<id> doseId=<id> scheduledAt=<iso> effectiveAt=<iso> \
  timezone=<zone> notificationId=<id> alarmId=<id> result=scheduled|FAILED
DOSE_SCHEDULE_ADVANCE ... notificationId=<doseId*1000+offset> ...
```

`notificationId == alarmId`: `flutter_local_notifications` uses the
notification id as the `AlarmManager` request code. `NotificationService`
emits a correlated second line with the landed schedule **mode** and
whether it was **verified** in the OS pending list.

On fire / tap / action, tag `DoseAudit`:

```
DOSE_FIRE source=foreground|background|cold-start actionId=<id> payload=dose:<doseId>
```

> Limitation: Android gives no Dart callback for "notification was
> displayed" (that is the OS's `ScheduledNotificationReceiver`, native
> plugin code). "Fired" is therefore observed via the tap/action log plus
> the `pendingNotificationRequests()` verification at schedule time. A
> native hook would require patching the plugin.

## On-device acceptance test (must be run by a human on real Android)

```
adb logcat -c
adb logcat | grep -E "DoseAudit|Notif|flutter"
```

1. Open the app, grant every permission it asks for. In Settings, confirm
   the notification self-test rings (sound + vibration).
2. Add medicine **Paracetamol**, reminder = **now + 2 min**. Save.
3. Confirm a `DOSE_SCHEDULE ... result=scheduled` line for it, with
   `effectiveAt` ≈ your target time and `timezone` = your actual zone.
4. **Close the app** (swipe from recents — do NOT "Force stop").
5. **Lock the phone.** Wait for the target time.
6. Expect: full-screen alarm on the lock screen, alarm sound looping,
   vibration. Log shows the notification and, on tap, `DOSE_FIRE`.
7. Tap **Taken**. Reopen app → dose shows Taken in Home + History;
   `next dose` advances. DB: `taken_at` set, `skipped_at`/`snoozed_until`
   NULL.
8. Repeat with **Snooze** (fires again after the snooze minutes; widget +
   next-dose use the snoozed time) and **Skip** (`skipped_at` set, others
   NULL).
9. Reboot the phone, do NOT open the app, schedule another reminder before
   reboot → it still fires (boot receiver).
10. Add a second medicine at the same time → both fire independently.

If step 6 fails, the log tells you which stage: no `DOSE_SCHEDULE` line =
reconcile didn't run; `result=FAILED` = the OS rejected all modes; line
present but no fire = permission denied, force-stopped, or Doze — check
`areNotificationsEnabled`, `canScheduleExactNotifications`, and battery
optimisation state (all surfaced in Settings).
