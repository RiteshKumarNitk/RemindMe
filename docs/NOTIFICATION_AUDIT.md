# Notification pipeline — audit & architecture

Two responsibilities, both handled:

- **A. LOCAL medicine alarm** — Android `AlarmManager` via
  `flutter_local_notifications`. Primary. Fires with the app closed, the
  process dead, the screen locked, and **offline**. Never depends on the
  Flutter UI isolate or on FCM.
- **B. CLOUD reminder** — a **server-side** scheduled Cloud Function
  (`functions/sendScheduledReminders`) that sends FCM at the dose time.
  Backup for when the local alarm was dropped. **Not** a client-side timer.

---

## Root causes found

### 1. Notification sound did not play (vibration did)

`NotificationService` created the reminder channel and built the
notification details **without `audioAttributesUsage`**, so it defaulted to
`AudioAttributesUsage.notification`. The bundled `medicine_alarm.wav` played
on the **NOTIFICATION audio stream** — silent whenever the phone's ring /
notification volume is low (very common; people keep alarm & media volume
up but silence the ringer). Vibration is stream-independent, so it kept
working. The `_v9` channel doc even *claimed* alarm attributes, but the
parameter was never passed.

**Fix** (`fix(notifications): route reminder sound to the ALARM stream`):
`audioAttributesUsage: AudioAttributesUsage.alarm` on the sound + family
channels and on every reminder / advance / missed / refill / test
`AndroidNotificationDetails`. `USAGE_ALARM` → alarm stream: louder,
survives ringer-mute, honours `bypassDnd`. Channel version **v9 → v10**
(Android caches channel config — a live channel won't adopt the new
attributes without a fresh id); the v9 ids are added to the delete list.

### 2. Scheduled reminder unreliable when app closed / backgrounded

No single defect. The local pipeline is complete: `alarmClock`-first
scheduling (needs no `SCHEDULE_EXACT_ALARM`, fires in Doze), boot receiver,
resume reconcile, background-isolate actions, all six manifest permissions.
The realistic causes are **device-state**, now made visible by the
`DoseAudit` logs:

- `POST_NOTIFICATIONS` denied → `DOSE_PERMS result=permission_denied`.
- App **force-stopped** (user or OEM killer) → Android drops all alarms
  until the app is reopened. No log until reopen; the FCM backup covers this.
- Battery not "Unrestricted" → Doze defers inexact alarms (mitigated by
  `alarmClock`; state in `DOSE_PERMS ... battery=`).
- `SCHEDULE_EXACT_ALARM` revoked *and* OEM blocking `setAlarmClock` (rare).

### 3. Firebase reminder never arrived at the scheduled time

There was no server-side scheduler — only a Firestore **trigger** for
missed-dose caregiver alerts. FCM has no "deliver at 20:30" primitive, and
a client-side timer dies with the process. **Fix:** added
`functions/sendScheduledReminders` (Cloud Scheduler, every minute).

---

## Local alarm — flow

```
Medicine saved / edited / deleted ─▶ AppState.refresh ─▶ DoseScheduler.sync
  ├─ ensureDose() per occurrence in the 7-day window
  ├─ _notificationTime(): snoozedUntil ?? scheduledAt   (now+1s if overdue in grace)
  ├─ edit/delete → deletePendingFrom() drops stale doses → their notifications cancelled
  ├─ NotificationService.scheduleDoseReminder(id = doseId)
  │     tz.TZDateTime.from(when, tz.local)          ← preserves the absolute instant
  │     zonedSchedule, androidScheduleMode =
  │        alarmClock → exactAllowWhileIdle → inexactAllowWhileIdle
  │     each verified against pendingNotificationRequests()
  ├─ scheduleAdvanceAlarm(id = doseId*1000+offset) × advanceMinutes
  └─ cancel() every pending id no longer desired
Reconciled on: cold start (deferred), every resume, after every save/action,
               device reboot (ScheduledNotificationBootReceiver re-registers
               every persisted zonedSchedule — no duplicates, none in the past)
Deliver: AlarmManager → notification (sound channel v10: MAX, WAV on ALARM
         stream, bypassDnd, FLAG_INSISTENT, fullScreenIntent) → DoseAlarmScreen
Actions: TAKEN / SNOOZE / SKIP → DoseActionHandler
         foreground: onResponse   terminated: notificationBackgroundHandler isolate
```

`requestCode` / notification id = `doseId` (main) or `doseId*1000+offset`
(advance) — unique and stable per dose, so rescheduling one medicine never
touches another's alarm. Editing a medicine deletes its pending doses →
`DoseScheduler.sync` cancels their notifications and schedules the new
ones. Deleting a medicine cascades the doses away → same cancellation.

## Cloud reminder — architecture

```
Cloud Scheduler ── every 1 min ──▶ functions/sendScheduledReminders
                                     │
     collectionGroup('doses')        │ status == 'pending'
       .where scheduled_at in        │ [now-3min, now+30s]   (absolute UTC instants)
                                     ▼
     for each due dose (skip if reminder_sent_at already set  ← idempotency, Part 11)
       households/{id}/members → collect fcmToken[]
       admin.messaging().sendEachForMulticast({
         notification{ title:"DoseWise — Medicine Reminder", body },
         data{ type:"medicine_reminder", doseId, medicineId, scheduledAt,
               action:"open_dose" },                     ← no medical detail beyond the name
         android{ collapseKey:"dose_<id>", notification{ tag:"dose_<id>",
                  channelId:"medicine_reminders_v10", sound:"medicine_alarm" } }
       })
       dose.reminder_sent_at = serverTimestamp()
       fcm_delivery_log/{auto} ← { doseId, householdId, scheduledAt, timezone,
                                   serverExecutionTime, tokensTargeted,
                                   successCount, failureCount, messageIds, errors, result }
       prune tokens FCM reports as not-registered
```

- `scheduled_at` is written by the app as an **absolute UTC instant**
  (`d.scheduledAt.toUtc()`), so due-time math is timezone-independent. The
  member's IANA `timezone` (written by `attachPushToken`) is logged for
  debugging only.
- **Dedup with the local alarm (Part 11):** on the device, the FCM message
  is shown via `NotificationService.showDoseNow(id = doseId)` — the *same*
  id as the AlarmManager notification, so Android displays exactly one.
  Before showing, `PushMessagingService` re-checks the local DB and
  suppresses if the dose is already taken / skipped / missed
  (`DOSE_FIRE source=fcm result=suppressed`).
- FCM notification **tap** → payload `dose:<id>` → the existing
  `handleNotificationTap` opens the dose. Never creates a new reminder.

## Structured logging (`DoseAudit` tag)

```
DOSE_SCHEDULE         medicineId doseId scheduledAt effectiveAt timezone
                      notificationId alarmId result=scheduled|rescheduled|schedule_failed
DOSE_SCHEDULE_ADVANCE …                          result=scheduled|skipped
DOSE_TZ               doseId userSelected(<zone>) androidScheduled(<zone>)
                      instantUserUtc instantFireUtc          ← catches a UTC shift
DOSE_CANCEL           notificationId alarmId result=cancelled reason=…
DOSE_PERMS            result=permission_denied notifications= exactAlarms= battery=
DOSE_FIRE             source=foreground|background|cold-start|fcm
                      actionId payload  |  result=notification_displayed|suppressed
```
Server side: every send writes an `fcm_delivery_log` doc (see above) — so a
missing reminder is pinned to: server-never-ran / send-failed / delivered /
device-suppressed / channel-muted.

> Limitation: Android gives no Dart callback for "notification was
> displayed by the OS" (that is `ScheduledNotificationReceiver`, native
> plugin code). "Displayed" is inferred from the schedule verification +
> the tap/action logs. Background TTS (voice) is best-effort only — Android
> restricts audio from the background, so notification sound + vibration +
> full-screen are the reliable channel; voice plays when the app/alarm
> screen is foreground.

## Android permissions (manifest + runtime)

| Permission | Manifest | Runtime request |
|---|---|---|
| `POST_NOTIFICATIONS` | ✓ | `main._postLaunch`, onboarding |
| `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` | ✓ | `requestExactAlarmPermission()`; `alarmClock` mode works without it |
| `USE_FULL_SCREEN_INTENT` | ✓ | `requestFullScreenIntentPermission()` (Android 14+) |
| `RECEIVE_BOOT_COMPLETED` | ✓ | n/a |
| `VIBRATE`, `WAKE_LOCK`, `ACCESS_NOTIFICATION_POLICY` | ✓ | n/a |

Live state (`notificationsEnabled`, `exactAlarmsEnabled`,
`batteryUnrestricted`) is shown in Settings with deep-links to the system
screens; a `DOSE_PERMS` line is logged on every `refresh()` when anything
is missing.

## Notification channels

| id | importance | sound | audio usage | vibration | bypass DnD |
|---|---|---|---|---|---|
| `medicine_reminders_v10` | MAX | `medicine_alarm.wav` | **alarm** | pattern | yes |
| `medicine_reminders_silent_v10` | MAX | none | — | pattern | no |
| `family_alerts_v10` | MAX | `medicine_alarm.wav` | **alarm** | pattern | yes |

**Resetting a channel during testing:** Android keeps channel config (and
any user override) for the life of a channel id. To force-refresh, either
bump `_v` in `notification_service.dart` (old ids are auto-deleted on next
launch), or on the device: *Settings → Apps → DoseWise → Notifications →*
the channel *→ ⋮ → Reset*, or clear app data. The code never deletes a
user's *other* apps' or the system's notification settings — only
DoseWise's own `medicine_reminders*/family_alerts*` channels.

## OEM / battery notes (Part 16)

`alarmClock` mode (`AlarmManager.setAlarmClock`) is the most kill-resistant
option Android offers and is what this app uses first. It still cannot
survive a user **force-stop** or some OEM "deep sleep" allowlists
(Xiaomi/MIUI "Autostart", Samsung "Deep sleeping apps", OnePlus battery
optimisation). Mitigations in place: `isIgnoringBatteryOptimizations()`
check surfaced in Settings; the FCM cloud backup fills the gap when the
local alarm was dropped. Not made a hard dependency — the app works with
battery optimisation on where Android permits.

---

## On-device acceptance test (must be run by a human)

```
adb logcat -c && adb logcat | grep -E "DoseAudit|Notif|FCM"
```

Medicine **Test Medicine**, reminder = **now + 2 min**. Confirm the
`DOSE_SCHEDULE ... result=scheduled` and `DOSE_TZ` lines look right
(effective time = your target, both `instant*Utc` consistent).

| Test | State | Expect at T+2min |
|---|---|---|
| 1 | app open | notification + **sound** + vibration; voice |
| 2 | app minimized | same |
| 3 | app swiped from recents (not Force-stop) | notification + sound + vibration |
| 4 | screen locked | + full-screen alarm (if permission granted) |
| 5 | **internet off** | local alarm still fires (no FCM) |
| 6 | internet on | local alarm fires; independently, `fcm_delivery_log` gets a `result:"sent"` row for the same `doseId` |
| 7 | both fire | **one** visible notification (same id) |
| 8 | tap it | DoseWise opens on the dose; no new reminder created |
| 9 | Taken | dose = Taken, notification dismissed, `taken_at` set / others NULL |
| 10 | Snooze 5m | fires again at `snoozedUntil`; no early escalation |
| 11 | Skip | no further notification for that dose |
| 12 | reboot before T | reminder still fires (boot receiver) |
| 13 | 2 medicines same time | both fire independently |

**Firebase half** (needs the project + `firebase deploy --only functions,firestore:indexes`):
create the composite index, deploy, then watch
`firebase functions:log` and the `fcm_delivery_log` collection while a dose
comes due — confirm `serverExecutionTime`, `messageIds`, `successCount`,
and that the device receives it.
