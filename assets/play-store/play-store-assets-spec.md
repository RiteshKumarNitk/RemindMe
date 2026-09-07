# Google Play Store — Asset Specifications

> Reference for all visual assets required when publishing on Google Play.

---

## 📱 App Icon

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Dimensions** | 512 px × 512 px |
| **Max file size** | 1 MB |
| **Status** | ✅ `app-icon/app-icon-512x512.png` ready |

### Notes
- Must meet Google's [design specifications](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)
- Must comply with Google's [metadata policy](https://play.google.com/about/developer-content-policy/#misrepresentation)
- Used as the app icon on Google Play and on the device

---

## 🖼️ Feature Graphic

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Dimensions** | 1,024 px × 500 px |
| **Max file size** | 15 MB |
| **Status** | ⏳ Need to create |

### Notes
- Used when you choose to feature your app
- Recommended: include app name/branding prominently
- Keep text within the center safe zone for different display sizes

---

## 📸 Phone Screenshots

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Count** | 2–8 screenshots required |
| **Max file size** | 8 MB each |
| **Aspect ratio** | 16:9 or 9:16 |
| **Dimensions** | Each side between 320 px and 3,840 px |
| **Status** | ⏳ Need to create |

### Promotion Eligibility
To be eligible for promotion on Google Play:
- **Minimum 4 screenshots**
- **Minimum 1080 px on each side**

### Recommended Sizes
| Orientation | Resolution | Aspect Ratio |
|-------------|------------|--------------|
| Landscape | 1920 × 1080 | 16:9 |
| Portrait | 1080 × 1920 | 9:16 |

### Best Practices
1. First screenshot is most important — it's the first thing users see
2. Show key features and value proposition
3. Use consistent styling across all screenshots
4. Include device frames/mockups for polish
5. Avoid excessive text — let the visuals speak
6. Test how they look on both light and dark mode

---

## 📋 Tablet Screenshots

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Count** | 2–8 screenshots required |
| **Max file size** | 8 MB each |
| **Aspect ratio** | 16:9 or 9:16 |
| **Dimensions** | Each side between 320 px and 3,840 px |
| **Status** | ⏳ Optional but recommended |

### Recommended Sizes
| Orientation | Resolution | Aspect Ratio |
|-------------|------------|--------------|
| Landscape (7") | 1920 × 1200 | 16:10 |
| Landscape (10") | 2560 × 1600 | 16:10 |
| Portrait (7") | 1200 × 1920 | 10:16 |
| Portrait (10") | 1600 × 2560 | 10:16 |

---

## ⌚ Wear Screenshots

| Property | Value |
|----------|-------|
| **Format** | PNG or JPEG |
| **Count** | 2–8 screenshots required |
| **Max file size** | 8 MB each |
| **Aspect ratio** | 1:1 (square) |
| **Dimensions** | 384 × 384 px recommended |
| **Status** | ⏳ Optional |

---

## 🎬 Video

| Property | Value |
|----------|-------|
| **Format** | YouTube URL |
| **Visibility** | Public or Unlisted |
| **Ads** | Must be turned off |
| **Age restriction** | Must not be age restricted |
| **Status** | ⏳ Need to create/upload |

---

## 📂 Directory Structure

```
assets/play-store/
├── play-store-assets-spec.md    ← This file
├── app-icon/
│   └── app-icon-512x512.png     ✅ Created
├── feature-graphic/              ⏳ Place 1024×500 images here
├── phone-screenshots/            ⏳ Place phone screenshots here
├── tablet-screenshots/           ⏳ Place tablet screenshots here
└── wear-screenshots/             ⏳ Place Wear OS screenshots here
```

---

## 🚀 Next Steps

1. **Feature Graphic**: Create a 1,024 × 500 px branded graphic with app name and tagline
2. **Phone Screenshots**: Capture at least 4 screenshots at 1080 × 1920 px (portrait) or 1920 × 1080 px (landscape)
3. **Video** (optional): Record a demo video, upload to YouTube as unlisted
4. **Tablet Screenshots** (optional): Capture tablet-optimized views
