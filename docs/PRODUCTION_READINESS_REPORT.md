# DoseWise — Production Readiness Report

**Date:** 2026-09-15. **Method:** a code-verified audit of the live
repository (not old docs), run in this order: security/privacy → Firebase/
Firestore/FCM → notification reliability → data/sync integrity → Android
permissions/OEM behavior → error handling/logging → release signing/build →
Play Store readiness → elderly UX/accessibility. Every issue below was
confirmed against actual source before being classified or fixed. Companion:
[`TECHNICAL_DOCUMENTATION.md`](TECHNICAL_DOCUMENTATION.md) (architecture
reference), [`PROJECT_DOCUMENTATION.md`](PROJECT_DOCUMENTATION.md) (phase
history + verification ledger, updated alongside this report).

**Scope discipline honored**: no new features were added. Every fix below is
a hardening change to an existing system (closing a gap, removing a leaked
credential, adding a missing guardrail) — nothing was rewritten that was
already working, and the notification pipeline specifically was left
untouched per the project's own prior lesson ("stop changing notification
code until a device run proves or disproves it" — `PROJECT_DOCUMENTATION.md`
§6).

---

## ❌ 0. The one CRITICAL finding — fix this first, today

**`PLAY_STORE_RELEASE.md` had the real production upload-keystore
password committed to git in plaintext** (`store/key password
DoseWise@2026!`, matching exactly what's in the local, git-ignored
`android/key.properties`). This repo has a GitHub remote
(`RiteshKumarNitk/RemindMe`) and the branch was up to date with it, so this
password has very likely already left this machine.

The keystore **file** itself (the `.jks`) was never committed — confirmed via
`git log --all --full-history` for `*.jks`/`*.keystore`/`key.properties`,
all empty — so this is not "your signing key is gone," but the password
protecting it is exposed in git history regardless of what the file now
says (I redacted the current file, but history retains it).

**Fixed now**: the file's plaintext password is redacted, replaced with a
warning banner and rotation instructions.

**Not fixed, cannot safely be fixed by me**: the password itself is still
`DoseWise@2026!` on disk (`android/key.properties`) and the keystore was
never re-generated. This needs a decision only you can make:
1. Rotate the store/key password now: `keytool -storepasswd -keystore
   C:\Users\RiteshKumar\keystores\dosewise-upload.jks` and `keytool
   -keypasswd -keystore ... -alias upload`, then update
   `android/key.properties` locally. This keeps the same upload key
   (no impact on an already-published app) — just changes the password.
2. Decide whether to scrub git history (`git filter-repo`/BFG + force-push).
   This is destructive and rewrites shared history — I did not do this and
   won't without you explicitly asking for it, since it can break any other
   clone/fork and requires everyone to re-clone.

---

## 0a. Same-day follow-up (2026-09-15): account deletion + crash reporting

After this report's first pass, two of the §3 "deliberately not fixed"
items were explicitly requested and built as real features (not part of the
original hardening-only pass, so held to normal feature-development
scrutiny — design decisions explained, not just a checklist):

**In-app account & data deletion** — `lib/services/account_deletion_service.dart`,
wired into a new "Danger zone" section on the Profile screen.
- **Local data (always wiped, no account needed)**: cancels every pending OS
  notification, then `AppDatabase.wipeAllData()` clears `medicines` (which
  cascades to schedules/doses) plus the three sync tables not covered by
  that cascade, then `SharedPreferences.clear()` wipes settings, the vitals
  log, and the missed-alert dedup set in one shot — matching how
  `BackupService` already treats "every SharedPreferences key" as one blob.
- **Cloud data (best-effort, only if signed in)**: `RemoteBackend` gained a
  `deleteMyHouseholdPresence()` method. A plain household member's record is
  deleted outright; a household **owner** cannot self-delete their member
  doc — `firestore.rules` forbids it (would orphan the household) — so only
  the FCM token is cleared and the user is told this happened. Then
  `AuthService.deleteAccount()` calls Firebase Auth's `user.delete()`; a
  `requires-recent-login` failure (Firebase's own safeguard for sign-ins
  older than ~5 minutes) prompts a re-sign-in and retry rather than failing
  silently.
- **Ordering matters**: cloud steps run first and are best-effort (every
  failure is caught and reported, never thrown); the local wipe always runs
  regardless of how the cloud steps went, since it needs no account. The
  result type (`AccountDeletionResult`) carries enough detail for the UI to
  tell the user the honest outcome — "everything deleted" vs. "your device
  data is gone, some account cleanup didn't finish, try again online."
- **Confirmation UX**: a single confirm dialog (consistent with this app's
  existing pattern for destructive actions — sign-out, Pause All — not a
  typed-confirmation flow, which would be inconsistent elderly-user friction
  for no real safety gain here). After deletion, the app is rebuilt from a
  fresh `RootScreen` so it re-evaluates signed-in/onboarding state (both now
  false) and lands on Login, not a stale Home screen.
- **What this does NOT do**: revoke invitations the user created (they're
  single-use and expire in 24h regardless — not worth the added complexity),
  or handle a multi-household user (the app's data model only supports one
  joined household at a time, so there's only ever one to clean up).
- Tests: `AppDatabase.wipeAllData()` (direct), the signed-out/local-only
  path end-to-end (the path every offline-only user — the app's default —
  actually takes), and `FakeBackend.deleteMyHouseholdPresence()`'s
  owner-vs-member branching (mirrors `FirebaseBackend`'s real rule). The
  signed-in cloud-delete path itself is **not** unit-testable in this
  environment (no live Firebase project reachable from a plain `flutter
  test` run — `AuthService.isSignedIn` is always false here) — ⚠️ needs a
  real signed-in device test before release, both as a plain member and,
  separately, as a household owner (to confirm the "FCM token cleared, not
  fully removed" messaging is accurate on the real backend, not just the
  fake).
- **Play Store impact**: this was flagged as a likely submission blocker in
  §3 of the original pass — built now, should no longer block submission,
  though the existing `docs/delete-account.html` web page should still be
  reviewed/updated to describe the in-app flow rather than standing alone.

**Crash reporting** — `firebase_crashlytics: ^5.4.0` added. Adding it forced
`firebase_core` up to `4.15.0`, which in turn was incompatible with the
previously-pinned `firebase_auth 6.5.7` at the native Android layer (a
`FlutterFirebaseCorePlugin.customAuthDomain` symbol firebase_auth's Java
code expected didn't exist — a classic FlutterFire plugin-version-skew
issue, not something wrong in this app's own code) — resolved by upgrading
`firebase_auth`/`cloud_firestore`/`firebase_messaging` together to a
mutually-compatible set (`flutter pub upgrade --major-versions`), landing
on `firebase_auth 6.7.0`, `cloud_firestore 6.10.0`, `firebase_messaging
16.7.0`. Wiring:
- `main.dart`: `FlutterError.onError`, `PlatformDispatcher.instance.onError`,
  and the top-level `runZonedGuarded` catch all now forward to
  `FirebaseCrashlytics.instance` **in addition to** the existing
  `developer.log` calls from the earlier hardening pass — local visibility
  and remote reporting, not one or the other.
  Collection is disabled in debug builds (`!kDebugMode`) and only enabled
  once Firebase itself has initialized successfully — on a device where
  Firebase is unreachable/unconfigured, this degrades to local-only logging
  exactly like every other Firebase-touching path in the app.
- `android/build.gradle.kts`/`settings.gradle.kts`: added the Crashlytics
  Gradle plugin (`com.google.firebase.crashlytics:3.0.3`) and the
  `firebase-crashlytics` native dependency.
- **Not yet done (Console-side, can't be done from here)**: Crashlytics
  must be *enabled* for the `remind-me-b7830` Firebase project in the
  Firebase Console before any report actually appears there — the code
  sends reports regardless, but they go nowhere until that's on. Also:
  Crashlytics collects crash/device diagnostic data, which **must be added
  to the Play "Data safety" form** before release (flagged in
  `build.gradle.kts` and `PLAY_STORE_RELEASE.md`) — the app's prior "we
  collect no analytics" simplicity claim is no longer fully accurate.

Verified via `flutter analyze` (clean), `flutter test` (**63/63**, up from
58 — 5 new tests), and `flutter build apk --release` (succeeds, 82.7 MB, up
from 82.0 MB — Crashlytics' added weight).

---

## ✅ 1. Verified — code-level, confirmed correct or now fixed

| Area | Finding |
|---|---|
| Sync conflict resolution | `applyRemoteMedicine`/`applyRemoteDose`'s last-writer-wins logic is correct and has no resurrection or infinite-loop bug — remote applies never re-enqueue to the outbox (verified by reading both methods in full), so a pull can never echo back as a push. A tie on `updatedAt` deterministically keeps the local value (documented, not a bug). |
| Invitation token security | 256-bit `Random.secure()` token, SHA-256-hashed doc id, raw token never stored, 24h TTL, single-use enforced by an atomic Firestore transaction that flips `used` and writes membership together — matches `docs/FAMILY_SYNC.md`'s claims exactly. |
| Secrets scan | Repo-wide grep for API-key/password/secret patterns is clean outside the two expected files (`google-services.json`'s client API key, which is not secret by Firebase's own design; `key.properties`, git-ignored) — and the one real leak found (§0) is now redacted. |
| Keystore file exposure | `.jks`/`.keystore`/`key.properties` never appear in git history (all 4 history-search commands returned empty). |
| Firestore rules — household/member integrity | Immutable household doc after creation; a member can only create their own record, as owner (if `households/{id}.ownerUid` matches) or as member (only with same-transaction proof the invitation was consumed by them); no self-promotion of `role`; owner can't be removed. This is sound. |
| PII-in-logs | Fixed: `auth_service.dart` no longer logs the signed-in user's raw email to `developer.log` (was logged on every Google sign-in, twice). FCM tokens and raw invitation tokens were checked and confirmed never logged. |
| Android Auto Backup of health data | Fixed: `android:allowBackup="false"` added — the local SQLite DB (medicine names, dose/adherence history) is no longer implicitly eligible for Android's Auto Backup to Google Drive. |
| Uncaught framework errors | Fixed: `FlutterError.onError` + `PlatformDispatcher.instance.onError` now log structurally (`developer.log`, tag `FlutterError`) instead of framework build/layout errors being invisible and the existing zone guard only doing a stripped-in-release `debugPrint`. |
| Firebase deploy determinism | Fixed: `.firebaserc` (pins `remind-me-b7830`) and `firebase.json` (points at `firestore.rules`/`functions/`) added — previously no committed default project existed for `firebase deploy`. |
| Release-build R8 landmine | Mitigated (not activated): `android/app/proguard-rules.pro` added with keep rules for `flutter_local_notifications`/Firebase/Google Sign-In, wired into `build.gradle.kts`, but `isMinifyEnabled` is left `false` — see §2, this needs a device retest before flipping on. |
| One accessibility gap | Fixed: the medicines-list search-clear icon button had no accessible label; now has a localized `tooltip` (en/hi). |
| Release signing (current claim) | Confirmed accurate as of this audit: with `android/key.properties` present, `flutter build apk --release` actually signs with the real upload keystore (verified by a successful release build in this pass), not the debug key — but rotate the password per §0 regardless. |
| App icon | Real, custom, per-density launcher icons exist (not the default Flutter icon) — confirmed by rendering the xxxhdpi asset. |
| Account-security basics | No hardcoded credentials, no plaintext-password auth (Firebase handles credentials), Google Sign-In error handling maps to actionable messages without leaking internals to the user. |

Build/test verification after every change in this pass: `flutter analyze`
→ clean (same 5 pre-existing info lints, 0 new), `flutter test` → **58/58
passed**, `flutter build apk --release` → **succeeds**, 82.0 MB, real
upload-keystore signature.

---

## ⚠️ 2. Requires device or cloud verification (code looks right, unproven)

These were true before this pass and remain true — nothing here regressed,
and nothing here can be verified without a real phone or Firebase Console
access, which this environment doesn't have:

- **Cloud Function deployment status** — `functions/index.js`'s
  `onDoseWrite` is correct in the repo (queries the `members` subcollection
  correctly, matching the client's write path) but there is no way to
  confirm from here whether it's actually deployed to `remind-me-b7830`.
  Run `firebase deploy --only functions` (now safe to run unqualified —
  `.firebaserc` pins the project) and then trigger a real missed dose to
  confirm the push arrives.
- **Notification sound/vibration/full-screen alarm on a real device** —
  the `alarmClock`-first scheduling, `audioAttributesUsage.alarm`, channel
  v10 config is all correct in code (re-confirmed, untouched in this pass)
  but has never been proven on hardware per `PROJECT_DOCUMENTATION.md` §5.
- **Overnight/reboot alarm survival** — architecturally sound
  (`ScheduledNotificationBootReceiver` + `DOSE_BOOT_RESTORE` reconcile), not
  device-tested.
- **Home-screen widget rendering** — Kotlin provider + layout reviewed only.
- **Google Sign-In end-to-end from a Play-installed build** —
  `PLAY_STORE_RELEASE.md` §1 explicitly notes this needs the Play App
  Signing SHA-1/SHA-256 fingerprint added to the Firebase project and a
  fresh `google-services.json` — not done yet.
- **R8/minification** — keep rules are now prepared
  (`proguard-rules.pro`) but `isMinifyEnabled` was deliberately left off in
  this pass; turning it on requires a full on-device notification-reliability
  retest (schedule → fire → action buttons → boot survival), since R8
  stripping a reflection-used class would silently break delivery, and
  that's a strictly worse failure mode for a medicine reminder app than a
  larger APK.
- **`shareMissedAlerts`/`shareMedicines` server-side enforcement** —
  investigated in depth, deliberately **not** fixed this pass. The Cloud
  Function currently notifies every household member with an FCM token,
  regardless of a member's own `shareMissedAlerts` flag. Fixing it correctly
  requires answering a data-model question this audit surfaced but can't
  answer alone: the `households/{code}/doses/{id}` documents aren't tagged
  with which member's device the dose came from, so it isn't obvious *whose*
  `shareMissedAlerts` the function should check for a given dose. This needs
  a product/data-model decision, not a guess — see next actions below.

---

## 🟡 3. Real issues found, deliberately not fixed (with reasoning)

| Issue | Severity | Why not fixed now |
|---|---|---|
| ~~No in-app account/data deletion flow~~ | — | **Built 2026-09-15 (same day, follow-up)** — see §0a. No longer a gap. |
| ~~No crash reporting~~ | — | **Built 2026-09-15 (same day, follow-up)** — Firebase Crashlytics wired in. See §0a. |
| `shareMissedAlerts` not enforced server-side | MEDIUM (privacy-model gap, not a security hole — non-members still see nothing) | See §2 — needs a data-model decision first. |
| `PLAY_STORE_RELEASE.md`'s build artifact section referenced a stale `1.0.0+1` build | LOW (docs accuracy) | Fixed as part of this pass — flagged as stale, rebuild instruction added. |
| No CI pipeline | MEDIUM (process gap, not a code defect) | Setting up CI is infrastructure work (choosing a runner, secrets management for a future signed build), not a code hardening fix; flagged for follow-up. |
| No adaptive icon (`mipmap-anydpi-v26`) | LOW (cosmetic) | Needs actual design assets (foreground/background layers) I don't have; not fixable via code alone. |
| `sync_tombstones` table has no unique constraint (unlike the other two sync tables) | LOW | Harmless in practice (worst case: a redundant tombstone push); not worth a schema migration for this pass. |
| Firestore rules leave `permissions` unconstrained on a member's own doc | LOW (a user can only change their own sharing prefs on their own record — not a privilege escalation, since the flat `medicines`/`doses` rule already grants full household member access regardless of `permissions`) | Working as designed — each member should be able to set their own sharing preference. Not a bug. |
| ~9 of ~20 icon-only `IconButton`s repo-wide lack a `tooltip`/semantic label | LOW–MEDIUM (accessibility) | Fixed the one flagged in the requested audit scope (medicines search-clear); a full accessibility pass across every icon button is a larger, separate effort better done deliberately with a TalkBack device test, not mixed into this hardening pass. |

---

## Fixes made in this pass (file list)

1. `lib/services/auth_service.dart` — stopped logging the user's raw email in `developer.log` (kept in the debug-only UI diagnostic string, which is fine).
2. `android/app/src/main/AndroidManifest.xml` — `android:allowBackup="false"`.
3. `lib/main.dart` — added `FlutterError.onError` + `PlatformDispatcher.instance.onError` structured logging.
4. `.firebaserc`, `firebase.json` — new, pin the Firebase project and deploy targets.
5. `android/app/proguard-rules.pro` — new, prepared keep rules (inert — minification still off).
6. `android/app/build.gradle.kts` — wired `proguardFiles(...)`, explicit `isMinifyEnabled = false` / `isShrinkResources = false` (unchanged behavior, now explicit and documented rather than implicit).
7. `lib/features/medicines/medicines_screen.dart` + `lib/core/localization/app_en.arb` + `app_hi.arb` — added a `tooltip` to the search-clear icon button (new `medSearchClear` string, both languages).
8. `PLAY_STORE_RELEASE.md` — redacted the leaked keystore password; added a rotation warning; corrected the stale `1.0.0+1` build-artifact claim.
9. `docs/TECHNICAL_DOCUMENTATION.md` — added a "Production hardening pass" section (§12a) and updated §13's Firestore-config gap note.
10. `docs/PROJECT_DOCUMENTATION.md` — hardening pass recorded (see that file's new §2 subsection and updated verification ledger).

Verification after all changes: `flutter analyze` clean, `flutter test`
58/58, `flutter build apk --release` succeeds (82.0 MB, real signing).

---

## Exact next 5 actions before release

1. **Rotate the exposed keystore password** (§0) — `keytool -storepasswd` /
   `-keypasswd` on `dosewise-upload.jks`, update `android/key.properties`.
   Decide separately whether to scrub git history. Do this before anything
   else; everything downstream assumes the signing key is still trustworthy.
2. **Device-test account deletion** (§0a) — as a plain household member
   (full cloud cleanup expected) and separately as a household **owner**
   (only partial cleanup is possible — confirm the "some cleanup didn't
   finish" messaging shows correctly), plus the `requires-recent-login`
   retry path. This is now built but has never run against a live Firebase
   project.
3. **Enable Crashlytics in the Firebase Console** for `remind-me-b7830`,
   and add it to the Play "Data safety" form (§0a) — the code reports
   regardless, but nothing appears in the dashboard until the Console side
   is turned on, and the data-collection disclosure is a Play requirement.
4. **Finish `PLAY_STORE_RELEASE.md`'s Firebase step** — add the Play App
   Signing SHA-1/SHA-256 fingerprint to the Firebase project, download a
   fresh `google-services.json`, rebuild — otherwise Google Sign-In will
   fail for every user who installs from Play.
5. **Run the on-device acceptance checklist** from
   `PROJECT_DOCUMENTATION.md` §5/§7 — sound test, overnight exact-alarm
   test, reboot test, QR family-join on two devices, widget add, and now
   also: confirm the app still restores correctly with `allowBackup=false`,
   confirm `firebase deploy --only functions` has been run against the
   now-pinned project, and item 2 above.

Beyond the top 5: decide the `shareMissedAlerts` semantics (§2 — is it
"notify others about my missed doses" or "let me receive others' missed-dose
alerts"? the current one-collection-per-household data model makes this
ambiguous to enforce server-side as-is). Everything else in §1 is done;
everything else in §2 was already a known, pre-existing gap and is
unchanged by this pass except where noted.
