# Notification pipeline — audit & architecture (local-only, Firebase Spark)

**The medicine reminder is 100% local.** Android `AlarmManager` (exact,
`setAlarmClock`) via `flutter_local_notifications`. It works with the app
open, minimized, swiped away, the screen locked, the phone in Doze, and
**offline**. It does **not** depend on the Flutter UI isolate, on FCM, or
on any Cloud Function / Cloud Scheduler. **No Firebase Blaze feature is
used or required.**

FCM stays in the project only for what it already did — family-sync token
registration and the caregiver missed-dose push (`functions/index.js`, a
Firestore trigger; optional, unchanged). It is never an exact-time
scheduler.

---

## Root causes

### RC-1 — Notification sound silent (vibration worked)

`NotificationService` created the reminder channel and every
`AndroidNotificationDetails` **without `audioAttributesUsage`**, so it
defaulted to `AudioAttributesUsage.notification`. The bundled
`medicine_alarm.wav` played on the **NOTIFICATION audio stream** — silent
whenever ring/notification volume is low (common; people keep the alarm and
media volume up but silence the ringer). Vibration is stream-independent,
so it kept working. The `_v9` channel doc even *claimed* alarm attributes,
but the parameter was never passed.

**Fix:** `audioAttributesUsage: AudioAttributesUsage.alarm` on the sound +
family channels and on every reminder/advance/missed/refill/test
`AndroidNotificationDetails`. `USAGE_ALARM` → alarm stream: louder,
survives ringer-mute, honours `bypassDnd`. Channel version **`v9 → v10`**
(Android caches channel config; a live channel id will not adopt new
attributes — a fresh id is required). The `v9` ids are added to the
delete-on-startup list; only DoseWise's own `medicine_reminders*` /
`family_alerts*` channels are touched.

Also `category: AndroidNotificationCategory.reminder → alarm` and
`priority: high → max` on the reminder — a dose *is* an alarm; Android
14/15 then rank it above heads-up, keep the full-screen intent, and pass
DnD more readily.

### RC-2 — Reminder unreliable when app backgrounded / closed

No code defect was found. The pipeline is complete and `alarmClock`-first
(`AlarmManager.setAlarmClock()` — exact, survives process death, fires in
Doze, needs **no** `SCHEDULE_EXACT_ALARM` grant). Boot receiver,
resume/cold-start reconcile, and the background-isolate action handler are
all present and correct.

The realistic causes are **device-state**, now logged (`DOSE_PERMS` every
reconcile):
- `POST_NOTIFICATIONS` denied (Android 13+) → nothing shows.
- App **force-stopped** (user, or an aggressive OEM task killer) → Android
  cancels every alarm until the app is next opened. Not recoverable from
  code (documented, not "claimed fixed").
- Battery not "Unrestricted" → Doze can defer an *inexact* alarm
  (mitigated: `alarmClock` is exempt; state in `DOSE_PERMS
  batteryOptimization=`).
- OEM deep-sleep allowlists (MIUI Autostart, Samsung "Deep sleeping apps",
  OnePlus) — same class as force-stop.

### RC-3 — "Firebase notification never arrived at the scheduled time"

Correct — and it never will, because FCM has no client-side "deliver at
20:30" primitive and a scheduled Cloud Function needs Blaze. **This is
by design now:** the reminder does not use FCM at all. The local alarm is
the single source of truth. Any earlier server-side-scheduler scaffold has
been removed.

### RC-4 — A good exact alarm was being silently downgraded to inexact

`scheduleDoseReminder` scheduled via `AndroidScheduleMode.alarmClock`
(exact, Doze-exempt), then **re-queried `pendingNotificationRequests()`
and, if the id wasn't echoed back, fell through and re-scheduled the same
id with `inexactAllowWhileIdle`** — replacing the reliable alarm with one
Android's Doze/App-Standby can hold for the entire idle window. Many OEMs
simply don't list `setAlarmClock` alarms in that query, so on a locked,
idle phone a 2-minute test frequently never fired.

**Fix:** if `alarmClock` is accepted (no exception) it is **trusted** — a
missing pending-list echo logs a warning but does **not** trigger a
downgrade. Fallback to `exactAllowWhileIdle` → `inexactAllowWhileIdle`
happens only when `alarmClock` itself throws. Same fix in
`scheduleAdvanceAlarm` and `scheduleSelfTest`. The landed mode is now in
every `DOSE_ALARM_SCHEDULE` line (`scheduleMethod=` / `osQueueVerified=`).

---

## Flow

```
Medicine saved / edited / deleted ─▶ AppState.refresh ─▶ DoseScheduler.sync
  ├─ ensureDose() per occurrence in the 7-day window
  ├─ _notificationTime(): snoozedUntil ?? scheduledAt   (now+1s if overdue in grace)
  ├─ edit  → deletePendingFrom() drops stale doses; DoseScheduler cancels their alarms
  ├─ delete→ FK ON DELETE CASCADE removes doses; alarms cancelled the same way
  ├─ NotificationService.scheduleDoseReminder(id = doseId)
  │     TZDateTime.from(when, tz.local)            ← preserves the absolute instant
  │     zonedSchedule, androidScheduleMode:
  │        alarmClock → exactAllowWhileIdle → inexactAllowWhileIdle
  │     each verified against pendingNotificationRequests() before accepting
  ├─ scheduleAdvanceAlarm(id = doseId*1000+offset) × advanceMinutes
  └─ cancel() every pending id no longer desired
Reconciled on:  cold start (deferred), every resume
                (_MainShellState.didChangeAppLifecycleState),
                after every save / dose action,
                device reboot — ScheduledNotificationBootReceiver re-registers
                every persisted zonedSchedule (no duplicates, none in the past;
                DoseScheduler.sync then reconciles against the DB)
Deliver:  AlarmManager → notification on medicine_reminders_v10
          (MAX importance, WAV on the ALARM stream, bypassDnd, FLAG_INSISTENT
          loop, fullScreenIntent, CATEGORY_ALARM, lock-screen visible)
          → full-screen DoseAlarmScreen where the FSI permission is granted,
            otherwise a heads-up notification (still sounds + vibrates)
Actions:  TAKEN / SNOOZE / SKIP
          foreground:  onResponse → DoseActionHandler
          terminated:  notificationBackgroundHandler isolate → DoseActionHandler
                       (rebuilds DB + plugin; no UI isolate needed)
Tap:      payload "dose:<id>" → handleNotificationTap → the dose context.
          Never creates a new reminder.
```

`alarmId` / notification id = `doseId` (main) or `doseId*1000+offset`
(advance) — unique and stable per dose, so rescheduling one medicine's
alarm never disturbs another's, and re-showing collapses instead of
duplicating. **SNOOZE:** `DoseActionHandler` sets `snoozedUntil`, cancels
`doseId`, and re-schedules `doseId` for the snoozed time; escalation and
the widget already use `snoozedUntil ?? scheduledAt`. **TAKEN / SKIP:**
marks the dose, cancels `doseId`; `_notificationTime` returns null for a
non-pending dose so `DoseScheduler.sync` won't re-create it.

---

## Structured logs

Every line is `developer.log(..., name: 'DoseAudit')` → shows in logcat
tagged `DoseAudit` (or `flutter`).

```
DOSE_TZ               doseId deviceTimezone deviceNow scheduledLocal scheduledUtc
                      effectiveLocal effectiveUtc alarmId
DOSE_NOTIFICATION     doseId channelId sound=medicine_alarm.wav audioUsage=alarm
                      importance=MAX fullScreenIntent=true category=alarm insistent=true
DOSE_ALARM_SCHEDULE   medicineId doseId notificationId alarmId scheduledLocal effectiveLocal
                      scheduleMethod=alarmClock|exactAllowWhileIdle|inexactAllowWhileIdle|none
                      osQueueVerified=true|false timezone
                      result=scheduled|scheduled_inexact|schedule_failed
DOSE_ALARM_SCHEDULE_ADVANCE  … (same shape, id = doseId*1000+offset)
DOSE_ALARM_FIRE       source=foreground|background|cold-start actionId payload
DOSE_CANCEL           notificationId alarmId result=cancelled reason=…
DOSE_BOOT_RESTORE     osPendingAlarmIds=[…] count= desiredThisWindow=
DOSE_PERMS            result=ok|permission_denied notifications=
                      batteryOptimization=unrestricted|restricted alarmCapability=
DOSE_ERROR            stage=schedule|permission|zonedSchedule doseId= mode= error=
```

Trace one dose: `DOSE_TZ` (no UTC shift ⇒ `scheduledLocal == effectiveLocal`;
`scheduledUtc` is the absolute instant) → `DOSE_NOTIFICATION` (channel +
sound) → `DOSE_ALARM_SCHEDULE scheduleMethod=alarmClock result=scheduled`
→ at fire time / on tap / on action, `DOSE_ALARM_FIRE`.

**Decision tree (point 17):**
- No `DOSE_ALARM_SCHEDULE` at all → `DoseScheduler.sync` didn't run for this
  dose (check the medicine is active, the time is in the 7-day window).
- `DOSE_ERROR stage=zonedSchedule` for every mode + `result=schedule_failed`
  → the OS rejected scheduling (rare — usually a bad `tz.local` zone id or a
  plugin/desugaring problem).
- `scheduleMethod=inexactAllowWhileIdle` → the only mode that landed; Doze
  **will** delay it on a locked/idle phone. Grant exact alarms, or set the
  app to "Unrestricted" battery.
- `scheduleMethod=alarmClock result=scheduled` **and still no notification
  at fire time** → not a scheduling problem. Either the app was
  **force-stopped** (Android cancels all alarms until reopen), an OEM
  deep-sleep list is killing it, or `POST_NOTIFICATIONS` is denied — check
  `DOSE_PERMS` and `DOSE_ERROR stage=permission`.
- `DOSE_ALARM_FIRE` present but no visible notification → permission /
  channel / device DnD. Check the channel isn't disabled in system
  settings.

> **Limitation:** Android exposes no Dart callback for "the OS displayed
> this scheduled notification" — that is the native
> `ScheduledNotificationReceiver` inside the plugin. `DOSE_ALARM_FIRE` is
> emitted on tap/action, not on display; delivery is otherwise inferred
> from the `pendingNotificationRequests()` verification at schedule time.
> Adding a display-time hook would mean patching the plugin (out of scope).

---

## Notification channels

| id | importance | sound | audio usage | vibration | bypass DnD | lock screen |
|---|---|---|---|---|---|---|
| `medicine_reminders_v10` | MAX | `medicine_alarm.wav` | **alarm** | pattern | yes | visible |
| `medicine_reminders_silent_v10` | MAX | none | — | pattern | no | visible |
| `family_alerts_v10` | MAX | `medicine_alarm.wav` | **alarm** | pattern | yes | visible |

`RawResourceAndroidNotificationSound('medicine_alarm')` →
`android/app/src/main/res/raw/medicine_alarm.wav` (present, 258 KB,
packaged by the default Android resource pipeline).

**Reset a channel during testing** (Android keeps channel config + any user
override for the life of a channel id):
- bump `_v` in `notification_service.dart` — old ids are auto-deleted on
  next launch; or
- on device: *Settings → Apps → DoseWise → Notifications →* the channel
  *→ Reset*; or
- clear app data.

Migration is safe: `_createChannels()` deletes only the DoseWise ids it
owns (`medicine_reminders*`, `medicine_reminders_silent*`,
`family_alerts*`, v1–v10) and recreates the current ones. No other app's
or the system's channels are affected.

---

## Android permissions (`AndroidManifest.xml`, unchanged this round)

| Permission | Why | Runtime |
|---|---|---|
| `POST_NOTIFICATIONS` | show anything on Android 13+ | requested in `_postLaunch` + onboarding |
| `RECEIVE_BOOT_COMPLETED` | reschedule alarms after reboot | n/a |
| `USE_FULL_SCREEN_INTENT` | lock-screen takeover (Android 14+) | `requestFullScreenIntentPermission()` |
| `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` | the `exactAllowWhileIdle` fallback path | `requestExactAlarmPermission()`; the primary `alarmClock` mode does **not** need it |
| `VIBRATE`, `WAKE_LOCK`, `ACCESS_NOTIFICATION_POLICY` | vibration / wake / DnD bypass | n/a |

### Receivers — verified (`android/app/src/main/AndroidManifest.xml`)

`flutter_local_notifications` 20.1.0's **library** manifest declares only
`VIBRATE` + `POST_NOTIFICATIONS` — it does **not** ship the receivers, so
the **app manifest must declare them**, and it does:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

- Class names match the plugin's shipped classes
  (`.../flutterlocalnotifications/{ActionBroadcastReceiver,
  ScheduledNotificationReceiver, ScheduledNotificationBootReceiver}.java`).
- `ScheduledNotificationReceiver` needs **no** `intent-filter`: AlarmManager
  delivers an **explicit** PendingIntent (component set), and it runs
  **without a Flutter engine** — the notification is built and posted by the
  plugin's native Java from the payload persisted at `zonedSchedule` time
  (which also re-creates the channel via `channelAction=createIfNotExists`).
- `android:exported="false"` is correct for all three (same-app / OS
  delivery of the app's own PendingIntents); Android 12+ `exported`
  requirement satisfied.
- The boot receiver is declared without `android:enabled="false"` (the
  plugin's example disables it and flips it on at runtime) — here it is
  simply enabled from install, which is fine.

**No manifest change was needed or made this round.**

`AndroidActionBroadcastReceiver` (TAKEN/SNOOZE/SKIP) hands off to the
Dart `notificationBackgroundHandler` isolate (`@pragma('vm:entry-point')`)
for the action logic only — the notification itself never needs Dart.

---

## On-device acceptance test — MUST be run on real Android

### ADB (Windows PowerShell / cmd)

```
adb devices
adb logcat -c
adb logcat | findstr "DOSE_"
```
(macOS/Linux: `adb logcat | grep -E "DOSE_|DoseAudit"`.)

### Quick isolation — the "Test scheduled alarm" button

Settings → **Test scheduled alarm** (visible in release now). It schedules a
real AlarmManager alarm 60 s out through the *same* code path as a dose,
then shows the landed `mode`, whether the OS kept it, the fire time and the
timezone. Press it, read `DOSE_ALARM_SCHEDULE doseId=99998 (SELF-TEST)`,
**close + lock the phone**, wait 60–90 s. This proves the native pipeline
without touching the medicine UI.

### Full test

Medicine **Test Medicine**, reminder = **now + 2 min**. Confirm in the log:
`DOSE_TZ` (`scheduledLocal` == your pick, `== effectiveLocal`),
`DOSE_NOTIFICATION channelId=medicine_reminders_v10 sound=medicine_alarm.wav`,
`DOSE_ALARM_SCHEDULE scheduleMethod=alarmClock result=scheduled`.

| # | State (schedule reminder, then…) | Expect at T |
|---|---|---|
| A | press **Home** | notification + **sound** + vibration (+ voice) — **required** |
| B | **swipe away from Recents** | notification + sound + vibration — **required** |
| C | Settings → Apps → DoseWise → **Force Stop** | *may* not fire — Android cancels alarms after an explicit force-stop until the app is reopened. **Not an acceptance case.** |
| 4 | screen locked | + full-screen `DoseAlarmScreen` where FSI granted |
| 5 | Doze: `adb shell dumpsys deviceidle force-idle` (then `unforce` after) | still fires (`alarmClock` is Doze-exempt) |
| 6 | **airplane mode / wifi+data off** | still fires (no network involved) |
| 7 | reboot before T, do **not** open the app | still fires — check `DOSE_BOOT_RESTORE` on next open |
| 8 | 2 medicines, same minute | both fire independently (distinct `doseId`) |
| 9 | tap the notification | DoseWise opens on the dose; no new reminder |
| 10 | action **Taken** | dose = Taken; notification gone; `taken_at` set, others NULL; no re-fire |
| 11 | **Taken in-app before T** | reminder does **not** fire (`_notificationTime` → null → alarm cancelled) |
| 12 | action **Snooze** | new `DOSE_ALARM_SCHEDULE` for `snoozedUntil`; fires then; no early escalation |
| 13 | action **Skip** / Skip in-app | alarm cancelled; no further notification for that dose |

Acceptance = **A and B** pass (sound + vibration + notification, app not
running). C is explicitly out of scope. If A/B fail, the log pins it — see
the decision tree above.

**Firebase:** unchanged. `flutter run` against the free Spark project — Auth,
Google/guest sign-in, Firestore, FCM token registration, and Family Sync
all keep working. No Blaze prompt.
