# Google Play Store — Asset Specifications for DoseWise

> Reference for all visual assets required when publishing on Google Play.

---

## 📱 App Icon ✅ READY

| Property | Value |
|----------|-------|
| **File** | `app-icon/app-icon-512x512.png` |
| **Format** | PNG |
| **Dimensions** | 512 px × 512 px |
| **File size** | 206.6 KB (limit: 1 MB) |

---

## 🖼️ Feature Graphic ✅ READY

| Property | Value |
|----------|-------|
| **File** | `feature-graphic/feature-graphic-1024x500.png` |
| **Format** | PNG |
| **Dimensions** | 1,024 px × 500 px |
| **File size** | 98.3 KB (limit: 15 MB) |

> ⚠️ This is an auto-generated placeholder. Replace with a professionally designed graphic before publishing.

---

## 📸 Phone Screenshots ⏳ NEEDS SCREENSHOTS

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Count** | 2–8 required (4 minimum for promotion) |
| **Max file size** | 8 MB each |
| **Aspect ratio** | 16:9 or 9:16 |
| **Dimensions** | Each side between 320 px and 3,840 px |

### Promotion Eligibility
- **Minimum 4 screenshots** at **minimum 1080 px** on each side

### Recommended Sizes
| Orientation | Resolution | Aspect Ratio |
|-------------|------------|--------------|
| Landscape | 1920 × 1080 | 16:9 |
| Portrait | 1080 × 1920 | 9:16 |

### Suggested Screenshots to Capture
1. **Home Screen** — Today's schedule with medicine list
2. **Add Medicine** — The medicine creation form
3. **Medicine List** — Full list of medications
4. **History/Adherence** — Adherence report with calendar view
5. **Profile/Settings** — User preferences screen
6. **Vitals Log** — Vital signs tracking (if applicable)
7. **Doctor Report** — Exported report preview

### How to Capture
1. Run the app on a phone emulator or physical device
2. Navigate to each screen
3. Take a screenshot (volume down + power on Android)
4. Place files in `phone-screenshots/` directory

---

## 📋 Tablet Screenshots ⏳ OPTIONAL

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Count** | 2–8 required |
| **Max file size** | 8 MB each |
| **Aspect ratio** | 16:9 or 9:16 |

### Recommended Sizes
| Orientation | Resolution | Aspect Ratio |
|-------------|------------|--------------|
| Landscape (7") | 1920 × 1200 | 16:10 |
| Landscape (10") | 2560 × 1600 | 16:10 |
| Portrait (7") | 1200 × 1920 | 10:16 |
| Portrait (10") | 1600 × 2560 | 10:16 |

---

## 🎬 Video ⏳ OPTIONAL

| Property | Value |
|----------|-------|
| **Format** | YouTube URL |
| **Visibility** | Public or Unlisted |
| **Ads** | Must be turned off |
| **Age restriction** | Must not be age restricted |

---

## 📂 Directory Structure

```
assets/play-store/
├── play-store-assets-spec.md         ← This file
├── app-icon/
│   └── app-icon-512x512.png          ✅ Created (206 KB)
├── feature-graphic/
│   └── feature-graphic-1024x500.png  ✅ Created (98 KB)
├── phone-screenshots/                 ⏳ Place phone screenshots here
├── tablet-screenshots/                ⏳ Place tablet screenshots here
└── wear-screenshots/                  ⏳ Place Wear OS screenshots here
```

---

## 🚀 Next Steps

1. ✅ ~~App icon~~ — Done
2. ✅ ~~Feature graphic~~ — Placeholder created, replace with professional design
3. ⏳ **Capture 4+ phone screenshots** from the running app
4. ⏳ **(Optional)** Create a demo video and upload to YouTube
5. ⏳ **(Optional)** Capture tablet screenshots
