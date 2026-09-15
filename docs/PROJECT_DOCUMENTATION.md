# DoseWise — Project Documentation

**Purpose:** a single, honest record of (1) everything built so far, (2) the
problems found along the way and how they were fixed, (3) what is *verified*
vs. what is *still unverified*, and (4) a direction assessment — are we going
in the right direction?

> **Maintained file.** Update it whenever a phase completes, a bug is fixed,
> or verification status changes. Companion docs:
> [`FEATURES.md`](../FEATURES.md) (feature inventory + changelog),
> [`docs/TECHNICAL_DOCUMENTATION.md`](TECHNICAL_DOCUMENTATION.md)
> (comprehensive, code-verified architecture/DB/notifications/Firebase/tests
> reference — the source of truth for *how* things work; this file is the
> source of truth for *what happened and why*),
> [`docs/NOTIFICATION_AUDIT.md`](NOTIFICATION_AUDIT.md) (notification root
> causes), [`docs/RELIABILITY_PASS_REPORT.md`](RELIABILITY_PASS_REPORT.md)
> (reliability pass), [`docs/PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md)
> (2026-09-15 security/privacy/build hardening audit — ✅/⚠️/❌ status +
> fixes + next actions), [`docs/FAMILY_SYNC.md`](FAMILY_SYNC.md) (family sync
> model), [`platform/docs/ROADMAP.md`](../platform/docs/ROADMAP.md) (clinic
> platform roadmap), [`.freebuff/run.md`](../.freebuff/run.md) (web preview).

---

## 1. Mission

Build a **production-ready medicine reminder app for an elderly user**
(Android-first) whose primary goal is **reliable reminders with minimum
interaction**. Everything else — cloud sync, caregiver alerts, the clinic
platform — exists in service of that goal.

---

## 2. What was built (phases, in order)

### Phase 1 — Core reminder MVP ✅ DONE

- Home dashboard: greeting, "Next Medicine" card with huge **TAKE MEDICINE**
  button, today's schedule, Taken / Remaining / Missed counters.
- Add/Edit medicine form: quick **Morning / Afternoon / Evening / Night**
  time-slot chips, unit quick-picks (mg, ml, tablet…), food instructions,
  frequency (daily / specific days / once / multiple times), notes.
- Local notifications with **TAKEN / SNOOZE / SKIP** action buttons; exact
  alarms via `setAlarmClock` (fires in Doze, survives reboot via boot
  receiver); snooze; missed-after grace period.
- History (Today / Week / All with adherence %), medicines list
  (pause/resume/edit/delete/duplicate), settings, EN + हिंदी localization,
  voice reminders (TTS).

### Phase 2 — Family sync & caregiver ✅ DONE

- Offline-first sync: local SQLite is the source of truth; persistent outbox
  queue (survives restarts/outages), retry with exponential backoff + jitter,
  connectivity-triggered retry, checkpoint reconcile, tombstones for deletes,
  `updatedAt`-based last-writer-wins conflicts.
- **QR invitations** (secure): 256-bit tokens stored SHA-256-hashed,
  single-use, 24 h expiry, atomic transactional join; multi-member households
  with owner/member roles. See [`FAMILY_SYNC.md`](FAMILY_SYNC.md).
- Caregiver dashboard: weekly adherence + today's household doses.
- Missed-dose alerts: local watcher + Firestore-triggered Cloud Function
  (`functions/index.js`) fanning out FCM push to household members.

### Phase 3 — Elderly UX & reliability hardening ✅ DONE

- Advance alarm (pre-dose looping alert 1–10 min before dose time).
- Notification sound root-cause fix (see §4.1): `audioAttributesUsage.alarm`
  on the **ALARM** stream, custom WAV, custom vibration, LED, full-screen
  intent, `bypassDnd`, `FLAG_INSISTENT` looping, channel version v10.
- Home-screen **Android widget**: urgency-colored (red/orange/teal/green),
  progress counter "3 / 6 done", 26sp medicine name, auto-refresh.
- History redesign: adherence ring, weekly bar chart (Mon–Sun stacked bars),
  color-coded tiles, prominent date headers.
- Stock/refill tracking (DB v6), schedule-conflict warning, undo (5 s),
  skip confirmation, batch mark-all, medicine search, pill photos
  (`image_picker`), splash + login screens.

### Auth & profile ✅ DONE (needs Firebase Console setup)

- Splash → Login (Continue with Google / Skip) → Onboarding → Main flow.
- Profile tab: photo, editable name + age, sign-in/out with confirmation,
  Firebase diagnostics card (debug builds).
- `Firebase.initializeApp()` before any Firebase usage; graceful offline
  fallback when Firebase is unconfigured.

### Production hardening pass ◐ DONE what code alone can fix (2026-09-15)

A full security/privacy → Firebase → notifications → sync → Android →
error-handling → build → Play Store → accessibility audit
(see [`PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) for
full detail). No new features — hardening only, notification internals left
untouched per the course-correction in §6. Highlights:

- **Found and fixed a real committed secret**: `PLAY_STORE_RELEASE.md` had
  the production upload-keystore password in plaintext in git. Redacted; the
  password itself still needs rotating (it's in git history regardless of
  the current file content) — **this is now the single highest-priority
  action**, ahead of anything else in §7.
- Stopped logging the signed-in user's raw email address (`auth_service.dart`,
  was logged on every Google sign-in).
- `android:allowBackup="false"` — the local DB (medicine names + dose
  history) was previously implicitly eligible for Android's Auto Backup to
  Google Drive by default (no exclusion rules existed).
- Added `FlutterError.onError`/`PlatformDispatcher.instance.onError`
  logging — framework-level errors were previously invisible in release
  (only async zone errors were caught, and only via a bare `debugPrint`).
- Added `.firebaserc`/`firebase.json` (pins the Firebase project for
  deploys) and `android/app/proguard-rules.pro` (prepared but inert —
  minification stays off pending a device retest, deliberately).
- One accessibility fix (missing tooltip on the medicines search-clear
  button).
- Investigated but deliberately did not fix: server-side enforcement of
  `shareMissedAlerts`/`shareMedicines` (needs a data-model decision, not a
  guess).

Verified via `flutter analyze` (clean), `flutter test` (58/58), and
`flutter build apk --release` (succeeds, 82.0 MB, real keystore signing).

### Account deletion & crash reporting ✅ DONE (2026-09-15, same day follow-up)

Two items the hardening pass above flagged as real gaps but deliberately
left unbuilt (account deletion: real feature with data-loss risk;
crash reporting: a new SDK) — built as explicit follow-up requests, not
part of the hardening-only scope:

- **`lib/services/account_deletion_service.dart`** + a "Danger zone" section
  on Profile. Local data (medicines/doses/settings/vitals) always wiped, no
  account needed. If signed in: best-effort household-presence cleanup
  (`RemoteBackend.deleteMyHouseholdPresence()` — a household **owner**
  can't self-delete their member doc per `firestore.rules`, only their FCM
  token is cleared, and the user is told) + Firebase Auth account deletion,
  with a `requires-recent-login` re-auth-and-retry path. Closes the likely
  Play Store submission blocker flagged in the hardening pass.
- **Firebase Crashlytics** wired into `main.dart`'s existing error handlers
  (`FlutterError.onError`/`PlatformDispatcher.onError`/the zone guard) —
  adds remote reporting on top of the `developer.log` calls the hardening
  pass added, doesn't replace them. Collection off in debug builds. Forced
  a Firebase package version bump (`firebase_auth` 6.5.7→6.7.0 and friends)
  to resolve a native Android plugin-version-skew build failure — unrelated
  to this app's own code, a known FlutterFire compatibility issue.
- Full detail, what's still unverified (needs a live device + Firebase
  project), and Console-side steps still needed (enable Crashlytics, update
  the Play Data Safety form) in
  [`PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) §0a.
- Verified via `flutter analyze` (clean), `flutter test` (**63/63**, +5),
  `flutter build apk --release` (succeeds, 82.7 MB).

### Platform (clinic side) — separate subproject ✅ Phases 0–4 done

`platform/` is a Next.js 15 + Prisma + Neon **clinic platform** (staff logins,
RBAC, tenancy, appointments, web dashboards) with its own test suite (51
passing at Phase 1) and roadmap in [`platform/docs/ROADMAP.md`](../platform/docs/ROADMAP.md).
It is a distinct track from the reminder app; don't mix its scope with the
app's.

---

## 3. Current verified status (checked 2026-09-15)

| Check | Result |
|---|---|
| `flutter analyze` | ✅ 0 errors / 0 warnings (5 info lints in `pill_photo_service.dart`) |
| `flutter test` | ✅ **63 / 63 pass** |
| Android manifest permissions | ✅ INTERNET, POST_NOTIFICATIONS, VIBRATE, WAKE_LOCK, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, USE_FULL_SCREEN_INTENT, ACCESS_NOTIFICATION_POLICY |
| Notification channel version | ✅ `v10` with old channels deleted on startup |
| Release APK | ✅ builds (82.7 MB as of 2026-09-15; minification still off, see hardening pass) |
| Crash reporting | ✅ Crashlytics wired in code; ⚠️ not yet enabled in Firebase Console, so no reports land anywhere yet |
| Account deletion | ✅ in-app, code-complete; ⚠️ never run against a live signed-in device |
| Committed secrets scan | ⚠️ one found & redacted 2026-09-15 (leaked keystore password in `PLAY_STORE_RELEASE.md`) — **password rotation still pending**, see §7 action 0 |

---

## 4. Problems found & fixed (the honest history)

The user reported **"no sound" repeatedly** and other failures. The root
causes, in the order they were discovered:

### 4.1 Notification sound — the real root cause

- **RC-1 (the actual bug):** every `AndroidNotificationDetails` was created
  **without `audioAttributesUsage`**, so the custom WAV played on the
  **NOTIFICATION stream** — silent whenever the ringer was muted (very
  common). Vibration is stream-independent, which is why it kept "working".
  Fix: `audioAttributesUsage: AudioAttributesUsage.alarm` everywhere + channel
  bump **v9 → v10** (Android caches channel config; a live channel id never
  adopts new attributes).
- **RC-4:** a good exact alarm was being **downgraded to inexact** by a
  re-query fallback in `scheduleDoseReminder` — many OEMs don't echo
  `setAlarmClock` alarms in `pendingNotificationRequests()`. Fixed by trusting
  `alarmClock` mode (commit `916f7ec`).
- Earlier attempts (custom WAV regeneration, channel v3/v5 bumping) treated
  symptoms; the stream-routing fix was the one that mattered. Full write-up:
  [`NOTIFICATION_AUDIT.md`](NOTIFICATION_AUDIT.md).

### 4.2 Sync correctness

- **Cloud Function read the wrong collection** for FCM tokens
  (`household.data().members` map instead of the `members` subcollection
  written by `InvitationService`) → missed-dose pushes silently never fired.
  Fixed (`functions/index.js`) to query the subcollection. **Not yet
  deployed.**
- Household creation used a bare `set()` that could overwrite another
  household — now collision-safe transactional create.
- Dose tombstone gap (edited medicines didn't propagate dose deletions),
  atomic dose deletion, clock-jump-safe checkpoints, orphan purge (DB v8).

### 4.3 App-flow bugs found by real testing

- `Firebase.initializeApp()` was never called → "Firebase not configured"
  everywhere despite a valid `google-services.json`. Fixed in `main.dart`.
- Snooze actions were hidden when sound was off (`withActions: _soundEnabled`)
  → now always shown.
- Login was skipped entirely when onboarding was done → now reachable from
  Profile.
- Battery-optimization nagging was removed from onboarding/settings —
  **deliberate product decision**: with `alarmClock`-first scheduling it is
  not required for correctness, and it confused the target user.

### 4.4 Production hardening pass findings (2026-09-15)

- **RC (root cause, not symptom): a real production credential was
  committed to git.** `PLAY_STORE_RELEASE.md` had documented the upload
  keystore's password in plaintext since it was first written — this
  wasn't a code bug, it was a docs-authoring mistake, but it's the most
  serious finding of the entire audit because it directly threatens the
  app's signing identity. Fixed by redacting the file; **the password
  itself is still the compromised one until manually rotated** (see §7).
- `auth_service.dart` logged the signed-in user's raw email address to
  `developer.log` on every Google sign-in — harmless in isolation, but
  unnecessary PII-in-logs exposure (logcat, bug reports). Fixed: the
  `developer.log` calls no longer interpolate the email; the existing
  debug-only `_debugInfo` UI string (shown only in `kDebugMode` and only
  when signed out) still carries it for the diagnostics card, which is
  fine since it's gated correctly.
- No `android:allowBackup` attribute existed, so Android's default
  (`true`, no exclusion rules) applied — meaning the SQLite DB (medicine
  names, dose/adherence history) was implicitly eligible for Android Auto
  Backup to the user's Google Drive account. Fixed: `allowBackup="false"`;
  the app already has its own explicit export/backup flow as the
  supported cross-device path.
- Framework-level Flutter errors (widget build/layout exceptions) had no
  handler at all — only async errors escaping a zone were caught, and even
  those only reached a `debugPrint` (stripped in some release configs).
  Fixed with `FlutterError.onError`/`PlatformDispatcher.instance.onError`
  → `developer.log`. This does not add crash reporting (no SDK was added,
  deliberately, to stay in scope) — it just makes errors loggable/visible
  locally instead of silently vanishing.

### 4.5 Known-remaining device-level risks (not code bugs)

These are documented in the reliability report and only diagnosable on a real
phone: OEM task killers / force-stop (drops all alarms), MIUI Autostart /
Samsung deep-sleep allowlists, full-screen-intent permission (Android 14+),
denied `POST_NOTIFICATIONS`. Structured per-dose diagnostic logging
(`DOSE_PERMS`, `DOSE_FIRE`) was added to pinpoint which on-device.

---

## 5. Verification ledger — what is proven vs. assumed

| Claim | Status | How verified |
|---|---|---|
| Analyzer clean, 58/58 tests pass | ✅ **Proven** | Run on 2026-09-15 (see §3) |
| Notification sound fix (alarm stream, v10) | ⚠️ **Code-proven, device-unverified** | Static audit; needs the Settings "Test notification" button on a real phone |
| Google Sign-In end-to-end | ⚠️ **Blocked on Console setup** | Code + config verified; needs Google provider enabled + SHA-1 registered + fresh `google-services.json` |
| Missed-dose FCM push | ⚠️ **Not verified** | Function fixed in repo but **never deployed**; `.firebaserc`/`firebase.json` added 2026-09-15 so `firebase deploy --only functions` now targets the right project without an explicit `--project` flag |
| Upload keystore integrity | ❌ **Compromised, unrotated** | Password was committed to git in plaintext (`PLAY_STORE_RELEASE.md`, found & redacted 2026-09-15); the password itself must still be rotated via `keytool` before this keystore should be trusted for a real Play upload |
| Family QR join flow | ⚠️ **Unit-tested, not device-tested** | `test/family_invitation_test.dart` covers token security; real two-device flow untested |
| Home-screen widget rendering | ⚠️ **Not verified** | Kotlin provider + layout reviewed only; needs manual widget add on device |
| Reminders fire in Doze / after reboot | ⚠️ **Not verified** | Architecture complete (`alarmClock`, boot receiver) but needs an overnight device test |
| Clinic platform (`platform/`) | ✅ 51 tests at Phase 1 | `platform/docs/ROADMAP.md` checkpoints |

**The single biggest honesty gap: everything cloud/notification-critical is
still unproven on a real Android device.** The code audits pass; the phone
is the referee.

---

## 6. Direction assessment — are we going the right way?

**Verdict: yes, the direction is right, with two course corrections.**

### What is right ✅

1. **Offline-first was the correct foundation.** An elderly user's medicine
   reminders must never depend on network, Firebase, or a logged-in account.
   Every cloud feature we layered on top is optional. This decision has paid
   off repeatedly (web preview works, Firebase misconfigurations never break
   reminders).
2. **Local exact alarms, not FCM, for reminders.** We correctly reverted an
   FCM server-side scheduler (commit `cdf1ddf`) — FCM cannot deliver at an
   exact time on the free Spark plan, and the local `AlarmManager` pipeline
   is strictly more reliable.
3. **Root-cause debugging over symptom patching** (§4.1): the alarm-stream
   discovery explained why four earlier "fixes" hadn't worked.
4. **Elderly-first UX iteration** (big buttons, quick slots, 12-hour clock,
   simplified onboarding, removing the battery nag) matches the stated
   product goal.

### Course corrections needed ⚠️

1. **Too many consecutive rewrites of the notification layer** (custom WAV →
   channel v3 → v5 → URI sound → v10). Each rewrite churned the same file.
   The lesson is already captured in [`NOTIFICATION_AUDIT.md`](NOTIFICATION_AUDIT.md):
   **stop changing notification code until a device run proves or disproves
   it** — the remaining suspects are device-state, not code.
2. **Verification debt is compounding.** We keep building (widget, QR,
   dashboard, platform) faster than we validate on hardware. The right next
   pass is **one structured on-device acceptance run** (sound test, overnight
   alarm test, reboot test, QR join, widget add), not more features.

### Where NOT to go next ❌

- No more notification-channel versions or sound rewrites.
- No new big features (wearables, drug-info DBs) until the on-device
  acceptance checklist in §5 is green.
- Don't entangle the reminder app with the `platform/` clinic track — they
  share nothing at runtime.

---

## 7. Next actions (priority order)

0. **Rotate the exposed upload-keystore password** (§4.4, §5) — found
   committed to git in plaintext on 2026-09-15. Do this before anything
   else touches the release build: `keytool -storepasswd`/`-keypasswd` on
   `dosewise-upload.jks`, update `android/key.properties`, decide whether
   git history needs scrubbing.
1. **Deploy the Cloud Function** — `firebase deploy --only functions` (fix
   already written, §4.2; `.firebaserc` now pins the project so this is
   safe to run without `--project`).
2. **Firebase Console**: enable Google provider, verify SHA-1
   (`B4:63:…:16:80`) **and add the Play App Signing fingerprint**, then
   re-download `google-services.json` and rebuild. Also **enable
   Crashlytics** for the project while there (§2 "Account deletion & crash
   reporting") — the code reports
   regardless, nothing shows up until this is on.
3. **Device-test account deletion** (§2 "Account deletion & crash
   reporting") — as a plain household member and
   separately as an owner (only partial cleanup is possible for an owner —
   confirm that's communicated correctly), plus the `requires-recent-login`
   retry path. Built but never run against a live Firebase project.
4. **On-device acceptance run** against §5's unverified rows:
   sound test → exact-alarm overnight test → reboot test → QR join (2
   devices) → widget add → Google Sign-In → confirm `allowBackup=false`
   didn't break the in-app export/restore path.
5. Fix the 5 info lints in `pill_photo_service.dart` (trivial).
6. Only after 0–4 are green: pick up the feature backlog
   (adherence streaks, per-medicine breakdown, wearables) or the deferred
   items (CI, `shareMissedAlerts` server-side enforcement, Play Data Safety
   form update for Crashlytics — see `PRODUCTION_READINESS_REPORT.md`).

---

## 8. Maintaining this document

- **After each work session:** update §3 (status table) and §5 (ledger) with
  real command output — never from memory.
- **After each bug fix:** add a §4 entry with root cause, not symptoms.
- **After each phase:** add a §2 subsection and keep
  [`FEATURES.md`](../FEATURES.md)'s changelog in sync.
- Keep the "Course corrections" list honest; it exists to stop us repeating
  expensive mistakes.
