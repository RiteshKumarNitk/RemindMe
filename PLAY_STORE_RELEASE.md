# DoseWise — Play Store release guide

Everything you need to publish DoseWise to Google Play. Work top to bottom.

---

## 0. Build artifact (done)

- **File:** `build/app/outputs/bundle/release/app-release.aab` (~47.7 MB)
- **Signed with:** upload key `CN=DoseWise` — `jarsigner -verify` → *jar verified*
- **Keystore:** `C:\Users\RiteshKumar\keystores\dosewise-upload.jks` (alias `upload`,
  store/key password `DoseWise@2026!`, valid to 2054)
- **Package name (permanent):** `com.family.medireminder`
- **Version:** `1.0.0` (versionCode 1) — from `pubspec.yaml` `version: 1.0.0+1`

> **Back up the `.jks` file and its password now, in two places.** Losing it means you can
> never update the app (only a Play key reset, if you enrol in Play App Signing).

**Bump for every future upload:** change `version:` in `pubspec.yaml` — e.g. `1.0.1+2`,
then `1.1.0+3`. The number after `+` (versionCode) must always increase.

---

## 1. Firebase — required for Sign-in / Family Sync to work in the released app

1. **Firestore rules** — Firebase console → project `remind-me-b7830` → Firestore → **Rules**
   → paste `firestore.rules` from this repo → **Publish**.
2. **Auth providers** — Authentication → Sign-in method → enable **Anonymous** and **Google**.
3. **SHA fingerprints** — Project settings → your Android app (`com.family.medireminder`) →
   *Add fingerprint*, add **all** of these:
   - **Upload key SHA-1:** `10:2A:02:35:F3:47:CA:11:9D:9D:3E:32:3B:BA:54:3E:56:A2:84:32`
   - **Upload key SHA-256:** `31:8E:38:AE:2E:A8:93:AF:D0:A0:59:BC:94:F3:2C:E7:10:76:75:9F:D0:6C:77:BC:48:9E:41:66:CF:88:14:ED`
   - **Play App Signing SHA-1 + SHA-256** — after your first upload, get these from
     Play Console → *Test and release → Setup → App signing*, and add both here too.
   Then **download the updated `google-services.json`**, replace
   `android/app/google-services.json`, and rebuild the AAB.

Without step 3, **Google Sign-In fails for users who install from Play.**

---

## 2. Hosting the legal pages

Play requires a public **Privacy Policy URL**. Files are in `docs/`:
`privacy-policy.html`, `terms-of-service.html`, `index.html`.

Fill in the `[PUBLISHER]`, `[CONTACT EMAIL]`, `[COUNTRY/STATE]` placeholders in all three,
then host them. Easiest: **GitHub Pages**
(repo → Settings → Pages → Source: `main` / `/docs`). Your URLs become:

- Privacy: `https://<user>.github.io/<repo>/privacy-policy.html`
- Terms:   `https://<user>.github.io/<repo>/terms-of-service.html`

---

## 3. Play Console — create the app

Console → **Create app**:

| Field | Value |
|---|---|
| App name | DoseWise |
| Default language | English (or your market) |
| App or game | App |
| Free or paid | Free |
| Category | **Medical** |

Accept the Developer Program Policies and US export declaration.

---

## 4. Store listing copy

**App name (30 chars):** `DoseWise — Medicine Reminder`

**Short description (80 chars):**
`Simple, reliable pill reminders with dose history and optional family alerts.`

**Full description (paste as-is):**

```
DoseWise helps you take the right medicine at the right time — and helps your
family keep an eye out when it matters.

WHY DOSEWISE
• One clear question on the home screen: "which medicine do I take now?"
• Big buttons, high contrast, and a spoken reminder option — easy for older users.
• Works fully offline. Your data stays on your phone unless you choose to share it.

REMINDERS THAT ACTUALLY REACH YOU
• Exact-time alarms with a loud, repeating alert tone and long vibration.
• Advance alarms in the minutes before a dose.
• Full-screen reminder on the lock screen.
• Reminders reschedule themselves after a restart.

TRACK EVERY DOSE
• Mark doses Taken, Skipped or Snoozed — right from the notification.
• Daily progress and an adherence percentage.
• History with per-day breakdown, filters, and CSV export.
• Optional pill-stock tracking with refill reminders.

FAMILY SYNC (optional)
• Share a 6-letter code so family can view your medicines and dose history.
• They get an alert if a dose is missed.
• Everyone can both manage their own medicines and help watch a relative.

PRIVACY
• No ads. No data selling. No analytics.
• Cloud sharing is off by default and limited to the family members you invite.

DoseWise is a reminder tool, not a medical device. It does not give medical advice —
always follow your doctor or pharmacist.
```

**Graphics you must supply (Play won't accept the app without these):**

| Asset | Spec |
|---|---|
| App icon | 512×512 PNG (use the DoseWise icon; `web/icons/Icon-512.png` is a starting point) |
| Feature graphic | 1024×500 PNG/JPG |
| Phone screenshots | 2–8 images, PNG/JPG, 16:9 or 9:16, min 1080px on the short side |
| (optional) 7" & 10" tablet screenshots |

Take screenshots on a device/emulator: Home, Today's schedule, History, Family & Sync,
Add medicine.

---

## 5. Content rating

Fill the **Content rating** questionnaire. DoseWise: no violence, no sexual content, no
profanity, no gambling, no user-generated content shared publicly. Reference to
"medication management" → expect **Everyone / PEGI 3**.

---

## 6. Data safety form (App content → Data safety)

Declare the following. (Analytics was removed from the build, so there is none.)

**Does your app collect or share user data?** Yes.

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name | Yes | Yes | App functionality (family sync), Account management | Yes |
| Email address | Yes | Yes | App functionality, Account management | Yes |
| User IDs (Google/anonymous auth ID) | Yes | Yes | App functionality, Account management | Yes |
| Health info (medicines, schedules, dose history) | Yes | Yes | App functionality (reminders & family sharing) | Yes — only if Family Sync is on |
| App activity — other (adherence/dose events) | Yes | Yes | App functionality | Yes |
| Device or other IDs (FCM push token) | Yes | No | App functionality (missed-dose alerts) | Yes |

- **Encrypted in transit:** Yes.
- **Users can request data deletion:** Yes — provide your support email; users turn off
  Family Sync and email you to delete the household.
- All items above are **only** collected when the user signs in / enables Family Sync;
  mark them optional.
- If you do **not** enable Family Sync features for launch, you can instead answer
  "No, this app does not collect or share any user data" — but Google Sign-In on the
  Profile screen still collects account data, so keep the table above.

---

## 7. Permissions declarations (Play Console will ask)

- **`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`** — Console → App content → *Alarms & reminders*
  permission declaration. Justification: *"DoseWise is a medication-reminder app whose core
  purpose is alerting the user to take medicine at exact, user-set times. Inexact alarms are
  not acceptable for medical adherence."*
- **`USE_FULL_SCREEN_INTENT`** — declare it; justification: *"Full-screen dose reminder on the
  lock screen so a critical medication alert is not missed."*
- **`RECEIVE_BOOT_COMPLETED`** — used to re-register reminders after reboot; usually no
  separate declaration, mention in the permissions form if prompted.
- The app does **not** request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (it only links to
  system settings), so no battery declaration is needed.

---

## 8. App content checklist (App content section)

- Privacy policy URL → your hosted `privacy-policy.html`
- Ads → **No**
- App access → all functionality available without special access; if a reviewer needs a
  test account, provide a Google test account or note that sign-in is optional
- Content rating → completed (step 5)
- Target audience → 13+ (or 18+ if you prefer for a medical app); not designed for children
- News app → No
- COVID-19 contact tracing → No
- Data safety → completed (step 6)
- Government app → No
- Financial features → No
- Health apps → if shown, declare it's a **medication reminder / adherence** tool, not a
  medical device, no health claims

---

## 9. Release

1. **Test and release → Testing → Internal testing → Create new release.**
2. Upload `app-release.aab`.
3. Google prompts to **enrol in Play App Signing** — accept (recommended).
4. Release name: `1.0.0 (1)`. Release notes: `First release of DoseWise.`
5. Add your own email as an internal tester, roll out, install from the opt-in link, and
   **verify on a real device**: reminders fire when the app is closed, Google Sign-In works,
   Family Sync creates a code.
6. When happy: **Production → Create new release** → promote the same build → set rollout %
   → submit for review. First review typically takes a few days.

---

## 10. Before you hit "Send for review" — final checks

- [ ] Legal page placeholders filled in and pages are publicly reachable
- [ ] Firestore rules published; Anonymous + Google auth enabled
- [ ] Upload-key **and** Play-App-Signing SHA-1/256 added to Firebase; fresh
      `google-services.json` in the repo; AAB rebuilt
- [ ] Keystore + password backed up off-machine
- [ ] Screenshots, icon (512), feature graphic (1024×500) uploaded
- [ ] Data safety + content rating + alarms/full-screen declarations submitted
- [ ] Release build installed from an internal-testing link and sanity-tested on a real phone
```
