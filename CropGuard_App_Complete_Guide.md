# CropGuard — Complete App Design & Development Guide
**AI-Based Crop Disease Detection | Android Mobile Application**
*Software Engineering Project — Guided by Sommerville (9th Edition)*

---

## Table of Contents

1. [App Overview](#1-app-overview)
2. [App Name, Branding & Identity](#2-app-name-branding--identity)
3. [Screen Inventory — All 9 Screens](#3-screen-inventory--all-9-screens)
4. [Screen-by-Screen Breakdown](#4-screen-by-screen-breakdown)
5. [User Flow & Navigation](#5-user-flow--navigation)
6. [UI Design System & Specifications](#6-ui-design-system--specifications)
7. [UX Principles for This App](#7-ux-principles-for-this-app)
8. [Component Library](#8-component-library)
9. [Functionality & Features](#9-functionality--features)
10. [Android Implementation Guide](#10-android-implementation-guide)
11. [AI Model Integration](#11-ai-model-integration)
12. [Software Engineering Checklist (Sommerville)](#12-software-engineering-checklist-sommerville)
13. [Requirements Specification](#13-requirements-specification)
14. [Testing Plan](#14-testing-plan)
15. [Prompts to Give Your AI (Vibe Coding Guide)](#15-prompts-to-give-your-ai-vibe-coding-guide)

---

## 1. App Overview

| Field | Detail |
|---|---|
| **App name** | CropGuard |
| **Platform** | Android (API 26+, Android 8.0 and above) |
| **Primary user** | Smallholder farmers (maize, tomato, potato) |
| **Core function** | Photograph a crop leaf → AI detects disease → show result + treatment |
| **AI model** | CNN with MobileNetV2 transfer learning, exported as TFLite |
| **Connectivity** | Fully offline — no internet required after installation |
| **Language** | English (simple, plain language — no technical jargon) |
| **Target region** | Ghana / Sub-Saharan Africa |
| **Min device spec** | 2GB RAM, Android 8.0, any camera |

---

## 2. App Name, Branding & Identity

### Name
**CropGuard** — short, memorable, tells the farmer exactly what it does.

### Tagline
> *"Detect crop diseases instantly. Works without internet."*

### Brand Colors

| Role | Color | Hex |
|---|---|---|
| Primary brand | Dark green | `#2d6a1f` |
| Healthy result | Medium green | `#639922` |
| Healthy background | Light green | `#f0f9eb` |
| Disease result | Red | `#E24B4A` |
| Disease background | Light red | `#fff0f0` |
| Low confidence | Amber | `#EF9F27` |
| Low conf. background | Light amber | `#fdf5e4` |
| Toolbar background | Dark green | `#1a3d0a` |
| Surface / card | White | `#ffffff` |
| Secondary surface | Light grey | system `background_secondary` |

### Logo
- Square with rounded corners (18dp radius)
- Dark green background (`#2d6a1f`)
- White leaf icon centered
- Sizes: 48×48dp (launcher), 36×36dp (toolbar), 192×192px (Play Store)

### Color Meaning (Never Break This Rule)
- **Green = healthy / safe / positive**
- **Red = disease found / danger**
- **Amber = uncertain / needs attention**

A farmer who cannot read English must still understand the result from color alone.

---

## 3. Screen Inventory — All 9 Screens

| # | Screen | Purpose | Navigation trigger |
|---|---|---|---|
| 1 | Splash / Onboarding | First-time welcome, 3 slides | App launch (first install only) |
| 2 | Home Dashboard | Central hub, quick scan CTA, recent results | App launch (returning user) |
| 3 | Camera / Scan | Live camera view, capture or gallery | "Scan a leaf" button or Scan tab |
| 4 | Analysing (Loading) | AI processing feedback | After image captured |
| 5 | Result — Disease found | Red theme, disease info, treatment steps | After analysis (diseased) |
| 6 | Result — Healthy leaf | Green theme, healthy confirmation, tips | After analysis (healthy) |
| 7 | Result — Low confidence | Amber theme, retry prompt | Confidence < 60% |
| 8 | History | All past detections, filterable | History tab in bottom nav |
| 9 | Settings | Display preferences, model info, about | Settings tab in bottom nav |

---

## 4. Screen-by-Screen Breakdown

---

### Screen 1 — Splash / Onboarding

**When shown:** Only on first install. Never again after user completes it.

**Layout — 3 slides (swipeable):**

#### Slide 1
- Large leaf logo centered (80×80dp)
- Title: `CropGuard`
- Subtitle: `Detect crop diseases instantly. Works without internet.`
- Dot indicators at bottom (3 dots)
- Button: `Get started` (primary, full width)

#### Slide 2
- Illustration: phone pointing at a leaf
- Title: `Take a photo of your crop leaf`
- Body: `Point your phone at any sick leaf. CropGuard will tell you what disease it has and what to do.`

#### Slide 3
- Illustration: result card graphic
- Title: `Get instant results`
- Body: `See the disease name, how sure the AI is, and exactly what treatment to apply.`
- Button: `Start using CropGuard` (primary, full width)

**UX notes:**
- Skip button top-right on slides 1 and 2
- Swipe gesture supported
- Onboarding state saved in SharedPreferences — never shown twice
- No login or account creation required

---

### Screen 2 — Home Dashboard

**Toolbar:**
- App icon (left)
- Title: `CropGuard`
- Subtitle: `Good morning, [Name]` or just `Welcome`
- No overflow menu needed

**Body content (scrollable, top to bottom):**

1. **Tip card** (green tinted, full width)
   - Label: `Today's tip`
   - Body: Rotating agricultural tip (stored locally, e.g. "Check maize leaves for grey spots — early blight season.")

2. **Primary action section**
   - Label: `What do you want to do?`
   - Large primary button: `Scan a leaf now` (full width, 56dp tall, camera icon)
   - Below it, two half-width secondary buttons side by side: `Gallery` | `History`

3. **Recent scans section**
   - Label: `Recent scans`
   - Last 3 detection history items (same row format as History screen)
   - Link text at bottom: `See all history →`

**Bottom navigation bar** (persistent across all main screens):
- Home | Scan | History | Settings
- Active tab: Home (highlighted green)

---

### Screen 3 — Camera / Scan Screen

**Toolbar:**
- Back arrow (left)
- Title: `Scan crop leaf`
- Subtitle: `Hold phone 20–30 cm from leaf`

**Body (top to bottom):**

1. **Camera viewfinder** (fills top ~50% of screen)
   - Live camera preview
   - Overlay guide frame (rounded rectangle, dashed border) to help farmer center the leaf
   - Corner brackets to indicate target area

2. **Slide indicator** (two dots — showing camera mode is active vs. gallery mode)

3. **Scan tips card** (compact)
   - Label: `Tips for a good scan`
   - Tips:
     - Place leaf flat with good lighting
     - Capture the whole leaf in frame
     - Avoid blurry or dark photos

4. **Shutter area**
   - Large circular shutter button (60dp diameter, green border, filled green center)
   - Below shutter: `Choose from gallery instead` (outline button, full width)

**Permissions handling:**
- If camera permission not granted: show rationale dialog before requesting
- Dialog text: `CropGuard needs camera access to scan your crop leaves. Your photos stay on your phone.`
- Buttons: `Allow` | `Not now`
- If denied twice: show message directing user to phone Settings

---

### Screen 4 — Analysing (Loading)

**Toolbar:**
- Title: `Analysing...`
- Subtitle: `Do not move the phone`

**Body (centered vertically):**

1. Dimmed preview of the captured image (full width, 150dp tall, 50% opacity)
2. Title text: `Running AI analysis`
3. Subtitle: `This takes about 2–3 seconds`
4. Progress bar (indeterminate or animated from 0→100%)
5. Status text: `Processing image...` (updates to `Almost done...`)

**UX notes:**
- No back button during analysis (disable it while inference runs)
- If inference takes longer than 5 seconds: show `Taking a little longer...`
- If inference fails: navigate to error screen with `Something went wrong. Please try again.`

---

### Screen 5 — Result: Disease Found

**Toolbar (dark red background `#7B1C1C`):**
- Title: `Disease detected`
- Subtitle: Disease name (e.g. `Maize Northern Leaf Blight`)

**Body (scrollable):**

1. **Leaf thumbnail** (full width, 90dp tall, captured image)

2. **Disease result card** (red tinted background `#fff0f0`, red border)
   - Disease name: bold, 14sp, dark red
   - Badge top-right: `Diseased` (red badge)
   - Cause: 12sp, red, e.g. `Caused by Exserohilum turcicum fungus`
   - Confidence section:
     - Label: `AI confidence`
     - Horizontal bar (red fill)
     - Percentage (e.g. `91%`)

3. **Treatment section**
   - Section label: `What to do`
   - Numbered treatment steps (3–5 steps), e.g.:
     1. Remove and burn infected leaves immediately
     2. Apply mancozeb or chlorothalonil fungicide
     3. Consult an agronomist if spread is large
   - Each step: numbered circle (green) + instruction text (13sp)

4. **Disclaimer** (small, grey)
   - `This is an AI suggestion. Consult an agronomist for serious outbreaks.`

5. **Action buttons** (side by side)
   - `Save result` (primary green)
   - `Scan again` (secondary)

---

### Screen 6 — Result: Healthy Leaf

**Toolbar (dark green background `#1a3d0a`):**
- Title: `Leaf looks healthy!`
- Subtitle: Crop type (e.g. `Tomato — Early Growth`)

**Body (scrollable):**

1. **Leaf thumbnail** (full width, 90dp tall)

2. **Healthy result card** (green tinted `#f0f9eb`, green border)
   - Label: `No disease found`
   - Badge: `Healthy` (green)
   - Body: `Your crop leaf appears to be in good condition.`
   - Confidence bar (green fill) + percentage (e.g. `97%`)

3. **Maintenance tips card** (white card)
   - Section label: `Keep your crop healthy`
   - Numbered tips:
     1. Continue regular watering schedule
     2. Monitor weekly for any new spots or yellowing
     3. Apply preventative fertiliser as needed

4. **Action buttons**
   - `Save result` (primary green)
   - `Scan another` (secondary)

---

### Screen 7 — Result: Low Confidence / Unclear Image

**Toolbar (dark amber background `#5a3d00`):**
- Title: `Could not identify clearly`
- Subtitle: `Image unclear`

**Body (centered):**

1. Dimmed/blurred image preview (full width, 120dp, low opacity)

2. **Amber warning card**
   - Title: `Could not identify clearly`
   - Body: `The AI is only [X]% confident. This may not be a crop leaf, or the photo is blurry or too dark.`
   - Confidence bar (amber fill) + percentage

3. **Guidance text**
   - `Make sure the leaf fills the frame, is in focus, and there is enough light.`

4. **Action buttons** (stacked)
   - `Try again` (primary green, full width)
   - `Choose from gallery` (secondary, full width)

**Trigger condition:** Confidence score < 60% OR no class scores above threshold.

---

### Screen 8 — History

**Toolbar:**
- Title: `Scan history`
- Subtitle: `All your past detections`

**Filter tabs (below toolbar):**
- `All` | `Diseased` | `Healthy`
- Active tab underlined in green

**List body (scrollable):**

Each history row contains:
- Thumbnail (36×36dp, rounded corners, leaf image or placeholder)
- Disease/crop name (13sp, bold)
- Date and time + confidence (10sp, grey)
- Status badge (right-aligned): `Diseased` (red) or `Healthy` (green)
- Tap row → opens full result detail (same layout as Screen 5 or 6)

**Empty state** (when no scans yet):
- Illustration: empty leaf graphic
- Text: `No scans yet. Scan your first crop leaf to get started.`
- Button: `Scan a leaf` (primary)

**Bottom navigation:** History tab active.

---

### Screen 9 — Settings

**Toolbar:**
- Title: `Settings`
- Subtitle: `App preferences`

**Sections:**

#### Display
| Setting | Type | Default |
|---|---|---|
| Large text mode | Toggle | Off |
| Show confidence score | Toggle | On |

#### Model & Data
| Setting | Type | Info |
|---|---|---|
| Model version | Info row | `MobileNetV2 — v1.2.0` + green "Up to date" badge |
| Supported crops | Info row | `Maize, Tomato, Potato` + "View all" link |
| Clear scan history | Destructive action | Red "Clear" text, confirmation dialog before deleting |

#### About
| Setting | Type | Info |
|---|---|---|
| About CropGuard | Info row | `Version 1.0 · Built for farmers` |
| How to use | Link | Opens simple user guide |
| Disclaimer | Info | AI suggestion only, not a replacement for agronomist |

**Bottom navigation:** Settings tab active.

---

## 5. User Flow & Navigation

### Happy Path (primary journey)

```
Open app
  └─ First install? → Onboarding (3 slides) → Home
  └─ Returning?     → Home directly

Home
  └─ Tap "Scan a leaf now"
       └─ Camera permission granted? 
            └─ Yes → Camera / Scan screen
            └─ No  → Permission dialog → Allow → Camera screen
                                       → Deny  → Gallery fallback

Camera / Scan
  └─ Capture photo (shutter) OR choose from gallery
       └─ Analysing screen (2–3 seconds, background thread)
            └─ Confidence ≥ 60%?
                 └─ Diseased → Result: Disease screen
                 └─ Healthy  → Result: Healthy screen
            └─ Confidence < 60% → Low Confidence screen
                 └─ Try again → Camera screen
                 └─ Gallery   → Gallery picker

Result screen (Disease or Healthy)
  └─ Save result → saved to Room DB → shown in History
  └─ Scan again  → back to Camera screen
```

### Error / Edge Case Flows

```
Non-plant image scanned
  └─ Low confidence screen (amber) → Retry

Camera permission permanently denied
  └─ Dialog: "Go to Settings to allow camera access"
  └─ Button opens Android app settings page

Inference failure (model crash / memory error)
  └─ Toast: "Something went wrong. Please try again."
  └─ Return to Camera screen

History item tapped
  └─ Opens read-only result detail screen (same layout as result screens)
```

### Navigation Structure

```
Bottom Navigation Bar (4 tabs, always visible on main screens)
├── Home       → Dashboard
├── Scan       → Camera screen (skips history, goes direct)
├── History    → Scan history list
└── Settings   → App settings
```

**Back button behaviour:**
- Result screen → Camera screen (not Home)
- Camera screen → Home
- Onboarding → Exit app (first slide only)
- Loading screen → Back disabled during inference

---

## 6. UI Design System & Specifications

### Typography Scale

| Role | Size | Weight | Usage |
|---|---|---|---|
| Screen title (toolbar) | 16sp | 500 | All toolbar titles |
| Subtitle (toolbar) | 10sp | 400 | Toolbar subtitles |
| Section labels | 11sp | 500, UPPERCASE | Category headers |
| Disease name / headline | 14sp | 500 | Result card title |
| Body text | 13sp | 400 | Cards, descriptions |
| Tips / secondary | 11–12sp | 400 | Hints, tips, captions |
| Badges / tags | 10sp | 500 | Status labels |
| **Minimum (outdoor mode)** | **16sp** | 400 | Large text mode toggle |

> **Rule:** Never use px. Always use sp for text, dp for everything else.

### Spacing System

| Token | Value | Usage |
|---|---|---|
| xs | 4dp | Tight gaps (icon-to-label) |
| sm | 8dp | Between related elements |
| md | 12dp | Card internal padding |
| lg | 16dp | Screen edge margins |
| xl | 24dp | Section spacing |

### Component Dimensions

| Component | Size |
|---|---|
| Primary button | Full width, 48dp height, 10dp corner radius |
| Secondary button | Full width or 50%, 44dp height |
| Camera shutter button | 60dp diameter circle |
| Navigation bar | 48dp height |
| Toolbar / App bar | 56dp height |
| History list row | Min 56dp height |
| Touch targets (all) | Minimum 48×48dp |
| Confidence progress bar | 6dp height, full width |
| Card corner radius | 10dp |
| Thumbnail (history) | 36×36dp, 6dp radius |
| Badge | 10sp text, 2dp top/bottom, 7dp left/right padding, pill radius |

### Elevation & Depth

- No drop shadows on cards (flat design)
- Toolbar: slight elevation (4dp) to separate from content
- Bottom nav: 8dp elevation
- Cards: 0dp elevation, 0.5dp border instead

---

## 7. UX Principles for This App

### Designed for farmers — not developers

These UX rules must be followed throughout the entire app:

1. **Plain language only.** No words like "CNN", "inference", "tensor", "confidence interval", "model". Use "AI check", "how sure the AI is", "result".

2. **Color communicates everything.** Green = good. Red = bad. Amber = unsure. Any farmer should understand the result screen in under 3 seconds without reading.

3. **Large, tappable buttons.** All buttons minimum 48dp tall. Primary actions are full-width. Never place two important actions right next to each other.

4. **Outdoor readability.** Default font at least 13sp. Large text mode bumps to 16sp+. High contrast — never light grey text on white background.

5. **Works offline.** No spinner that depends on internet. Model loaded from assets. History stored locally. Tips stored locally.

6. **Fail gracefully.** Every error has a message and a recovery action. Never show a blank screen or a raw exception.

7. **One action per screen.** The camera screen's only job is capturing a photo. The result screen's only job is showing the result. Don't crowd screens.

8. **Loading always visible.** Never run AI inference silently. Always show Screen 4 (Analysing) so the farmer knows the app is working.

9. **Confidence score always shown.** Never display just a disease label. Always pair it with a confidence bar and percentage.

10. **Disclaimer always present.** Every result screen includes: *"This is an AI suggestion. Consult an agronomist for serious outbreaks."*

---

## 8. Component Library

### Primary Button
```
Background:  #2d6a1f
Text:        White, 14sp, weight 500
Height:      48dp
Width:       Match parent (full width)
Radius:      10dp
State pressed: darken to #1a4a0f
```

### Secondary Button
```
Background:  Surface secondary (light grey)
Text:        Primary text color, 13sp
Height:      44dp
Border:      0.5dp, border secondary color
Radius:      10dp
```

### Outline Button
```
Background:  Transparent
Text:        #2d6a1f, 13sp, weight 500
Border:      1.5dp solid #2d6a1f
Height:      44dp
Radius:      10dp
```

### Disease Result Card
```
Background:  #fff0f0
Border:      0.5dp solid #f09595
Radius:      10dp
Padding:     10dp all sides
```

### Healthy Result Card
```
Background:  #f0f9eb
Border:      0.5dp solid #97c459
Radius:      10dp
Padding:     10dp all sides
```

### Low Confidence Card
```
Background:  #fdf5e4
Border:      0.5dp solid #fac775
Radius:      10dp
Padding:     10dp all sides
```

### Status Badge
```
Diseased:  Background #FCEBEB, Text #A32D2D
Healthy:   Background #EAF3DE, Text #3B6D11
Uncertain: Background #FAEEDA, Text #854F0B
Radius:    99dp (pill)
Padding:   2dp top/bottom, 7dp left/right
Font:      10sp, weight 500
```

### History Row Item
```
Height:       Min 56dp
Thumbnail:    36×36dp, radius 6dp
Title:        13sp, weight 500
Subtitle:     10sp, secondary color
Badge:        Right-aligned
Divider:      0.5dp bottom border
Tap state:    Light green background highlight
```

### Confidence Progress Bar
```
Track:     Height 6dp, background #e0e0e0, radius 99dp
Fill:      Diseased → #E24B4A | Healthy → #639922 | Low → #EF9F27
Animation: Animate from 0 to actual value over 600ms
```

### Bottom Navigation Bar
```
Height:        48dp
Background:    Surface secondary
Border top:    0.5dp, border tertiary
Active icon:   #2d6a1f, filled
Active label:  #2d6a1f, 9sp, weight 500
Inactive:      Grey, 9sp
Active bg:     Subtle green tint pill around icon
```

---

## 9. Functionality & Features

### Core Features (Must Have)

| Feature | Description |
|---|---|
| Camera scan | Open camera, display viewfinder with guide frame, capture on shutter tap |
| Gallery upload | Open Android photo picker, select existing image |
| Image preprocessing | Resize to 224×224dp, normalize pixels to match training preprocessing |
| TFLite inference | Run MobileNetV2 model on background thread, return class + confidence |
| Disease result display | Show disease name, confidence bar, cause, and numbered treatment steps |
| Healthy result display | Show healthy confirmation, confidence bar, maintenance tips |
| Low confidence fallback | Show amber warning when confidence < 60%, prompt retry |
| Detection history | Save result to Room database, display in History tab |
| Offline operation | All features work with no internet connection |
| Settings | Large text toggle, model info, clear history |

### Secondary Features (Should Have)

| Feature | Description |
|---|---|
| Onboarding | 3-screen first-launch walkthrough |
| Daily crop tips | Rotating local tips shown on Home screen |
| History filtering | Filter by All / Diseased / Healthy |
| Result sharing | Share screenshot of result (Android share sheet) |
| About screen | App version, disclaimer, model info |

### Out of Scope (Version 1)

- User accounts or login
- Cloud/server-side inference
- Weather integration
- Multilingual support (future version)
- Cassava, yam, or other crops beyond Maize / Tomato / Potato

---

## 10. Android Implementation Guide

### Project Structure

```
app/
├── src/main/
│   ├── java/com/cropguard/
│   │   ├── ui/
│   │   │   ├── onboarding/     OnboardingActivity.kt
│   │   │   ├── home/           HomeFragment.kt
│   │   │   ├── scan/           ScanFragment.kt
│   │   │   ├── result/         ResultFragment.kt
│   │   │   ├── history/        HistoryFragment.kt
│   │   │   └── settings/       SettingsFragment.kt
│   │   ├── ml/
│   │   │   ├── DiseaseClassifier.kt
│   │   │   └── ImagePreprocessor.kt
│   │   ├── data/
│   │   │   ├── db/             AppDatabase.kt
│   │   │   ├── model/          DetectionEntity.kt
│   │   │   └── repository/     DetectionRepository.kt
│   │   └── MainActivity.kt
│   ├── assets/
│   │   └── crop_disease_model.tflite
│   └── res/
│       ├── layout/             XML layouts for each screen
│       ├── drawable/           Icons, leaf illustrations
│       └── values/             colors.xml, strings.xml, dimens.xml
```

### Key Classes and Their Responsibilities

**`DiseaseClassifier.kt`**
- Load `.tflite` model from `assets/` folder
- Accept a `Bitmap` as input
- Run inference on background thread (coroutine `Dispatchers.IO`)
- Return `data class Result(label: String, confidence: Float)`
- Must NOT contain any UI code

**`ImagePreprocessor.kt`**
- Resize `Bitmap` to 224×224
- Convert to `ByteBuffer` with correct normalization
- For MobileNetV2: normalize to `[-1, 1]` (not `[0, 1]`)
- Formula: `(pixelValue / 127.5f) - 1.0f`

**`DetectionRepository.kt`**
- Insert detection record to Room database
- Query all detections, query filtered by status
- Delete all records (clear history)

**`DetectionEntity.kt` (Room Entity)**
```kotlin
@Entity(tableName = "detections")
data class DetectionEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val imagePath: String,
    val diseaseLabel: String,
    val confidence: Float,
    val isHealthy: Boolean,
    val timestamp: Long = System.currentTimeMillis()
)
```

### AndroidManifest.xml Permissions
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

### Gradle Dependencies
```gradle
// TensorFlow Lite
implementation 'org.tensorflow:tensorflow-lite:2.13.0'
implementation 'org.tensorflow:tensorflow-lite-support:0.4.4'

// Room database
implementation 'androidx.room:room-runtime:2.6.1'
implementation 'androidx.room:room-ktx:2.6.1'
kapt 'androidx.room:room-compiler:2.6.1'

// CameraX
implementation 'androidx.camera:camera-camera2:1.3.1'
implementation 'androidx.camera:camera-lifecycle:1.3.1'
implementation 'androidx.camera:camera-view:1.3.1'

// Navigation Component
implementation 'androidx.navigation:navigation-fragment-ktx:2.7.6'
implementation 'androidx.navigation:navigation-ui-ktx:2.7.6'

// Coroutines
implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
```

### Critical Implementation Rules

1. **Never run inference on the main thread.** Use `viewModelScope.launch(Dispatchers.IO)`.
2. **Load model once.** Initialise `Interpreter` in `DiseaseClassifier` constructor, reuse it.
3. **Normalization must match training.** Verify this before integration testing.
4. **Confidence threshold = 0.60f.** If `max(outputArray) < 0.60`, navigate to Low Confidence screen.
5. **Model in `assets/`.** Never download it at runtime.
6. **Image path, not Bitmap, stored in Room.** Save the file path; load image from path when needed.

---

## 11. AI Model Integration

### Model Details

| Field | Value |
|---|---|
| Base model | MobileNetV2 (pretrained on ImageNet) |
| Transfer learning | Final layers replaced and retrained on PlantVillage dataset |
| Input shape | 224 × 224 × 3 (RGB) |
| Input dtype | float32 |
| Normalization | [-1, 1] (MobileNetV2 standard) |
| Output shape | [1, N] where N = number of disease classes |
| Output dtype | float32 (softmax probabilities) |
| Export format | TensorFlow Lite (.tflite) |
| Quantization | Post-training quantization (DEFAULT) — reduces size ~4× |
| Target file size | < 20MB |

### Disease Classes Supported (PlantVillage subset)

| Crop | Disease | Class label |
|---|---|---|
| Maize | Northern Leaf Blight | `Corn_Northern_Leaf_Blight` |
| Maize | Common Rust | `Corn_Common_Rust` |
| Maize | Gray Leaf Spot | `Corn_Gray_Leaf_Spot` |
| Maize | Healthy | `Corn_Healthy` |
| Tomato | Bacterial Spot | `Tomato_Bacterial_Spot` |
| Tomato | Early Blight | `Tomato_Early_Blight` |
| Tomato | Late Blight | `Tomato_Late_Blight` |
| Tomato | Leaf Mold | `Tomato_Leaf_Mold` |
| Tomato | Healthy | `Tomato_Healthy` |
| Potato | Early Blight | `Potato_Early_Blight` |
| Potato | Late Blight | `Potato_Late_Blight` |
| Potato | Healthy | `Potato_Healthy` |

### Confidence Threshold Logic

```kotlin
val maxConfidence = outputArray.max()
val predictedClass = outputArray.indexOfMax()

when {
    maxConfidence < 0.60f -> navigateTo(LowConfidenceScreen)
    isHealthyClass(predictedClass) -> navigateTo(HealthyResultScreen)
    else -> navigateTo(DiseaseResultScreen)
}
```

### Python Model Export (Training side)
```python
# After training your model:
converter = tf.lite.TFLiteConverter.from_saved_model('saved_model_dir')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open('crop_disease_model.tflite', 'wb') as f:
    f.write(tflite_model)
```

---

## 12. Software Engineering Checklist (Sommerville)

### Requirements Engineering — Ch. 4–5
- [ ] Functional requirements documented (FR1–FR7)
- [ ] Non-functional requirements documented (NFR1–NFR6)
- [ ] Use cases / user stories written from farmer's perspective
- [ ] System constraints documented (offline, low-end device, Android-only)
- [ ] Disease and crop scope boundary defined in writing
- [ ] Requirements validated with a real stakeholder (agronomist, lecturer, or farmer)

### Architecture & Design — Ch. 6–7
- [ ] Architectural diagram drawn (camera → preprocessing → model → UI)
- [ ] Architecture decision recorded: on-device vs server-side, with trade-offs
- [ ] Data flow documented: image → tensor → output → display
- [ ] Separation of concerns: ML, UI, and data in separate classes
- [ ] Component interfaces defined (input/output types, tensor shape)

### AI / Model
- [ ] Pretrained model selected and justified (MobileNetV2)
- [ ] Dataset split: 70/15/15 train/validation/test, no leakage
- [ ] Dataset source cited (PlantVillage — Hughes & Salathé, 2015)
- [ ] Data augmentation applied (rotation, flip, brightness, zoom)
- [ ] Accuracy ≥ 85% on test set
- [ ] Precision, recall, F1 reported per class
- [ ] Confusion matrix generated and reviewed
- [ ] Model exported as TFLite with quantization
- [ ] Model file size ≤ 20MB
- [ ] Inference ≤ 3 seconds on 2GB RAM device

### Android App
- [ ] Camera permission requested at runtime with rationale
- [ ] Camera + gallery both supported
- [ ] Preprocessing matches training normalization exactly
- [ ] Model loaded from assets (not downloaded at runtime)
- [ ] Inference on background thread (no UI freezing)
- [ ] Confidence score always displayed with result
- [ ] Low confidence fallback screen implemented (< 60%)
- [ ] Detection history saved to Room database
- [ ] App fully functional offline
- [ ] Text minimum 16sp in large text mode
- [ ] No ML jargon in UI — plain farmer-friendly language

### Testing — Ch. 8
- [ ] Unit test: image preprocessing (tensor shape, normalization values)
- [ ] Integration test: end-to-end camera → model → result
- [ ] Accuracy tested on real phone photos (not training data)
- [ ] Tested on 2+ physical Android devices
- [ ] Poor image quality test (blurry, dark, partial)
- [ ] Acceptance test with non-technical user
- [ ] Non-plant image edge case tested
- [ ] Low-end device test (2GB RAM)

### Maintenance & Evolution — Ch. 9
- [ ] Code modular: model can be swapped without rewriting app
- [ ] Version number in manifest matches report version
- [ ] Known limitations documented
- [ ] Future work section written

### Documentation
- [ ] SRS document written
- [ ] Architecture diagram in report
- [ ] Model training process documented (hyperparameters, accuracy curves)
- [ ] Test plan and results table
- [ ] User manual (plain language, with screenshots)
- [ ] Ethical considerations addressed
- [ ] References cited correctly

---

## 13. Requirements Specification

### Functional Requirements

| ID | Requirement |
|---|---|
| FR1 | The app shall allow a user to capture a crop leaf image using the device camera |
| FR2 | The app shall allow a user to select an existing image from the device gallery |
| FR3 | The app shall classify the leaf image and return a disease label and confidence score |
| FR4 | If confidence is below 60%, the app shall prompt the user to retake the image |
| FR5 | The app shall display a disease description and recommended treatment for each result |
| FR6 | The app shall store detection history locally (image path, result, timestamp) |
| FR7 | The app shall function without an internet connection after installation |
| FR8 | The app shall display a confidence score alongside every result |
| FR9 | The app shall show a disclaimer recommending agronomist consultation |

### Non-Functional Requirements

| ID | Requirement | Measure |
|---|---|---|
| NFR1 | Classification accuracy | ≥ 85% on test set |
| NFR2 | Inference time | ≤ 3 seconds on 2GB RAM device |
| NFR3 | App cold start time | ≤ 4 seconds |
| NFR4 | Model file size | ≤ 20MB |
| NFR5 | Minimum Android version | API 26 (Android 8.0) |
| NFR6 | Touch target size | Minimum 48×48dp |
| NFR7 | Body text size | Minimum 13sp (16sp in large text mode) |
| NFR8 | Offline support | 100% core features work without internet |

### System Constraints

- Android platform only (no iOS in v1)
- Must run on devices with as little as 2GB RAM
- Farmers may have no mobile data in the field
- Target users may have low literacy — UI must not rely on reading alone
- No backend server — all computation on-device

---

## 14. Testing Plan

### Test Cases

| ID | Test | Type | Expected result | Pass/Fail |
|---|---|---|---|---|
| T01 | Preprocess 224×224 image, check tensor shape | Unit | Shape: [1, 224, 224, 3] | |
| T02 | Preprocess image, check pixel range | Unit | All values in [-1.0, 1.0] | |
| T03 | Run model on healthy tomato leaf | Integration | Label: Healthy, conf ≥ 80% | |
| T04 | Run model on diseased maize leaf | Integration | Correct disease, conf ≥ 75% | |
| T05 | Submit blurry image | Robustness | Low confidence screen shown | |
| T06 | Submit non-plant image (face) | Edge case | Low confidence screen shown | |
| T07 | Scroll history list 50+ items | Performance | No jank, smooth 60fps | |
| T08 | Run on 2GB RAM device | Performance | No crash, inference ≤ 3s | |
| T09 | Deny camera permission | Edge case | Rationale shown, gallery offered | |
| T10 | Complete scan without internet | Functional | Full result shown offline | |
| T11 | Non-technical user completes scan | Acceptance | Success without assistance | |
| T12 | Save result and view in history | Functional | Appears in history correctly | |
| T13 | Clear history in settings | Functional | All records deleted | |
| T14 | Toggle large text mode | Functional | Text size increases throughout | |

---

## 15. Prompts to Give Your AI (Vibe Coding Guide)

Use these exact prompts with your AI to build each part of the app:

---

### Architecture setup
```
Create an Android project in Kotlin with:
- Package name: com.cropguard
- Min SDK: 26, Target SDK: 34
- Dependencies: TensorFlow Lite 2.13, CameraX 1.3.1, Room 2.6.1, Navigation Component 2.7.6, Coroutines 1.7.3
- Project structure: ui/, ml/, data/ packages
- MainActivity with bottom navigation bar linking to HomeFragment, ScanFragment, HistoryFragment, SettingsFragment
- Brand color #2d6a1f as primaryColor in colors.xml
```

### Model integration
```
Create a DiseaseClassifier.kt class that:
- Loads a TFLite model from assets/crop_disease_model.tflite
- Accepts a Bitmap as input
- Resizes to 224x224 and normalizes pixels to [-1, 1] (MobileNetV2 standard)
- Runs inference using TensorFlow Lite Interpreter
- Returns a data class Result(label: String, confidence: Float)
- Runs on Dispatchers.IO coroutine context
- If max confidence < 0.6f, returns Result("LOW_CONFIDENCE", maxConfidence)
```

### Result screen
```
Create a ResultFragment.kt that:
- Receives disease label, confidence (Float), and image URI as navigation arguments
- If label is "Healthy": shows green theme toolbar (#1a3d0a), green result card (#f0f9eb), green confidence bar
- If label is disease: shows red theme toolbar (#7B1C1C), red result card (#fff0f0), red confidence bar
- Shows numbered treatment steps from a local map of disease → treatments
- Shows confidence as both a percentage text and an animated horizontal progress bar
- Has "Save result" button that calls DetectionRepository.insert()
- Has "Scan again" button that navigates back to ScanFragment
- Includes disclaimer: "This is an AI suggestion. Consult an agronomist for serious outbreaks."
```

### History screen
```
Create a HistoryFragment.kt with:
- RecyclerView showing all DetectionEntity records from Room database
- Each row: 36x36dp thumbnail, disease name (13sp bold), date+confidence (10sp grey), status badge
- Status badge: red "Diseased" or green "Healthy"
- Filter tabs at top: All | Diseased | Healthy
- Empty state: illustration + "No scans yet. Scan your first crop leaf." + primary button
- Tap row → navigate to result detail screen
- Data loaded via ViewModel + LiveData from DetectionRepository
```

### Low confidence screen
```
Create a LowConfidenceFragment.kt that:
- Shows amber toolbar background (#5a3d00)
- Displays the captured image at 50% opacity
- Shows amber warning card with confidence percentage and bar (amber fill #EF9F27)
- Message: "The AI is only [X]% confident. This may not be a crop leaf, or the photo is blurry or too dark."
- Guidance text: "Make sure the leaf fills the frame, is in focus, and there is enough light."
- Primary button: "Try again" → navigate back to ScanFragment
- Secondary button: "Choose from gallery" → open photo picker
```

### Room database
```
Set up Room database for CropGuard:
- DetectionEntity with fields: id (autoGenerate), imagePath (String), diseaseLabel (String), confidence (Float), isHealthy (Boolean), timestamp (Long)
- DetectionDao with: insertDetection(), getAllDetections() as LiveData<List<DetectionEntity>>, getDiseasedDetections(), getHealthyDetections(), deleteAll()
- AppDatabase singleton
- DetectionRepository wrapping the DAO
- AppDatabase initialized in Application class
```

---

*Document version: 1.0 | Project: CropGuard | Author: Software Engineering Student | Reference: Sommerville, I. (2016). Software Engineering, 9th Edition.*
