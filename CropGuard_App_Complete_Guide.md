# CropGuard — Complete App Design & Development Guide
**AI-Based Crop Disease Detection | Android Mobile Application**
*Software Engineering Project — Guided by Sommerville (9th Edition)*

---

## Table of Contents

1. [CURRENT] [App Overview](#1-app-overview) [CURRENT]
2. [CURRENT] [App Name, Branding & Identity](#2-app-name-branding--identity) [CURRENT]
3. [CURRENT] [Screen Inventory — All 9 Screens](#3-screen-inventory--all-9-screens) [CURRENT]
4. [CURRENT] [Screen-by-Screen Breakdown](#4-screen-by-screen-breakdown) [CURRENT]
5. [CURRENT] [User Flow & Navigation](#5-user-flow--navigation) [CURRENT]
6. [CURRENT] [UI Design System & Specifications](#6-ui-design-system--specifications) [CURRENT]
7. [CURRENT] [UX Principles for This App](#7-ux-principles-for-this-app) [CURRENT]
8. [CURRENT] [Component Library](#8-component-library) [CURRENT]
9. [CURRENT] [Functionality & Features](#9-functionality--features) [CURRENT]
10. [CURRENT] [Android Implementation Guide](#10-android-implementation-guide) [CURRENT]
11. [CURRENT] [AI Model Integration](#11-ai-model-integration) [CURRENT]
12. [CURRENT] [Software Engineering Checklist (Sommerville)](#12-software-engineering-checklist-sommerville) [CURRENT]
13. [CURRENT] [Requirements Specification](#13-requirements-specification) [CURRENT]
14. [CURRENT] [Testing Plan](#14-testing-plan) [CURRENT]
15. [CURRENT] [Prompts to Give Your AI (Vibe Coding Guide)](#15-prompts-to-give-your-ai-vibe-coding-guide) [CURRENT]

---

## 1. App Overview

| Field | Detail | [CURRENT]
|---|---| [CURRENT]
| **App name** | CropGuard | [CURRENT]
| **Platform** | Android (API 26+, Android 8.0 and above) | [CURRENT]
| **Primary user** | Smallholder farmers (maize, tomato, potato) | [HISTORICAL]
| **Core function** | Photograph a crop leaf → AI detects disease → show result + treatment | [CURRENT]
| **AI model** | CNN with MobileNetV2 transfer learning, exported as TFLite | [CURRENT]
| **Connectivity** | Fully offline — no internet required after installation | [CURRENT]
| **Language** | English (simple, plain language — no technical jargon) | [CURRENT]
| **Target region** | Ghana / Sub-Saharan Africa | [CURRENT]
| **Min device spec** | 2GB RAM, Android 8.0, any camera | [CURRENT]

---

## 2. App Name, Branding & Identity

### Name
**CropGuard** — short, memorable, tells the farmer exactly what it does.

### Tagline
> *"Detect crop diseases instantly. [CURRENT] Works without internet."* [CURRENT]

### Brand Colors

| Role | Color | Hex | [CURRENT]
|---|---|---| [CURRENT]
| Primary brand | Dark green | `#2d6a1f` | [CURRENT]
| Healthy result | Medium green | `#639922` | [CURRENT]
| Healthy background | Light green | `#f0f9eb` | [CURRENT]
| Disease result | Red | `#E24B4A` | [CURRENT]
| Disease background | Light red | `#fff0f0` | [CURRENT]
| Low confidence | Amber | `#EF9F27` | [CURRENT]
| Low conf. [CURRENT] background | Light amber | `#fdf5e4` | [CURRENT]
| Toolbar background | Dark green | `#1a3d0a` | [CURRENT]
| Surface / card | White | `#ffffff` | [CURRENT]
| Secondary surface | Light grey | system `background_secondary` | [CURRENT]

### Logo
- Square with rounded corners (18dp radius)
- Dark green background (`#2d6a1f`)
- White leaf icon centered
- Sizes: 48×48dp (launcher), 36×36dp (toolbar), 192×192px (Play Store)

### Color Meaning (Never Break This Rule)
- **Green = healthy / safe / positive**
- **Red = disease found / danger**
- **Amber = uncertain / needs attention**

A farmer who cannot read English must still understand the result from color alone. [CURRENT]

---

## 3. Screen Inventory — All 9 Screens

| # | Screen | Purpose | Navigation trigger | [CURRENT]
|---|---|---|---| [CURRENT]
| 1 | Splash / Onboarding | First-time welcome, 3 slides | App launch (first install only) | [CURRENT]
| 2 | Home Dashboard | Central hub, quick scan CTA, recent results | App launch (returning user) | [CURRENT]
| 3 | Camera / Scan | Live camera view, capture or gallery | "Scan a leaf" button or Scan tab | [CURRENT]
| 4 | Analysing (Loading) | AI processing feedback | After image captured | [CURRENT]
| 5 | Result — Disease found | Red theme, disease info, treatment steps | After analysis (diseased) | [CURRENT]
| 6 | Result — Healthy leaf | Green theme, healthy confirmation, tips | After analysis (healthy) | [CURRENT]
| 7 | Result — Low confidence | Amber theme, retry prompt | Confidence < 60% | [CURRENT]
| 8 | History | All past detections, filterable | History tab in bottom nav | [CURRENT]
| 9 | Settings | Display preferences, model info, about | Settings tab in bottom nav | [CURRENT]

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

1. [CURRENT] **Tip card** (green tinted, full width) [CURRENT]
   - Label: `Today's tip`
   - Body: Rotating agricultural tip (stored locally, e.g. "Check maize leaves for grey spots — early blight season.")

2. [CURRENT] **Primary action section** [CURRENT]
   - Label: `What do you want to do?`
   - Large primary button: `Scan a leaf now` (full width, 56dp tall, camera icon)
   - Below it, two half-width secondary buttons side by side: `Gallery` | `History`

3. [CURRENT] **Recent scans section** [CURRENT]
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

1. [CURRENT] **Camera viewfinder** (fills top ~50% of screen) [CURRENT]
   - Live camera preview
   - Overlay guide frame (rounded rectangle, dashed border) to help farmer center the leaf
   - Corner brackets to indicate target area

2. [CURRENT] **Slide indicator** (two dots — showing camera mode is active vs. [CURRENT] gallery mode) [CURRENT]

3. [CURRENT] **Scan tips card** (compact) [CURRENT]
   - Label: `Tips for a good scan`
   - Tips:
     - Place leaf flat with good lighting
     - Capture the whole leaf in frame
     - Avoid blurry or dark photos

4. [CURRENT] **Shutter area** [CURRENT]
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

1. [CURRENT] Dimmed preview of the captured image (full width, 150dp tall, 50% opacity) [CURRENT]
2. [CURRENT] Title text: `Running AI analysis` [CURRENT]
3. [CURRENT] Subtitle: `This takes about 2–3 seconds` [CURRENT]
4. [CURRENT] Progress bar (indeterminate or animated from 0→100%) [CURRENT]
5. [CURRENT] Status text: `Processing image...` (updates to `Almost done...`) [CURRENT]

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

1. [CURRENT] **Leaf thumbnail** (full width, 90dp tall, captured image) [CURRENT]

2. [CURRENT] **Disease result card** (red tinted background `#fff0f0`, red border) [CURRENT]
   - Disease name: bold, 14sp, dark red
   - Badge top-right: `Diseased` (red badge)
   - Cause: 12sp, red, e.g. `Caused by Exserohilum turcicum fungus`
   - Confidence section:
     - Label: `AI confidence`
     - Horizontal bar (red fill)
     - Percentage (e.g. `91%`)

3. [CURRENT] **Treatment section** [CURRENT]
   - Section label: `What to do`
   - Numbered treatment steps (3–5 steps), e.g.:
1. [CURRENT] Remove and burn infected leaves immediately [CURRENT]
2. [CURRENT] Apply mancozeb or chlorothalonil fungicide [CURRENT]
3. [CURRENT] Consult an agronomist if spread is large [CURRENT]
   - Each step: numbered circle (green) + instruction text (13sp)

4. [CURRENT] **Disclaimer** (small, grey) [CURRENT]
   - `This is an AI suggestion. Consult an agronomist for serious outbreaks.`

5. [CURRENT] **Action buttons** (side by side) [CURRENT]
   - `Save result` (primary green)
   - `Scan again` (secondary)

---

### Screen 6 — Result: Healthy Leaf

**Toolbar (dark green background `#1a3d0a`):**
- Title: `Leaf looks healthy!`
- Subtitle: Crop type (e.g. `Tomato — Early Growth`)

**Body (scrollable):**

1. [CURRENT] **Leaf thumbnail** (full width, 90dp tall) [CURRENT]

2. [CURRENT] **Healthy result card** (green tinted `#f0f9eb`, green border) [CURRENT]
   - Label: `No disease found`
   - Badge: `Healthy` (green)
   - Body: `Your crop leaf appears to be in good condition.`
   - Confidence bar (green fill) + percentage (e.g. `97%`)

3. [CURRENT] **Maintenance tips card** (white card) [CURRENT]
   - Section label: `Keep your crop healthy`
   - Numbered tips:
1. [CURRENT] Continue regular watering schedule [CURRENT]
2. [CURRENT] Monitor weekly for any new spots or yellowing [CURRENT]
3. [CURRENT] Apply preventative fertiliser as needed [CURRENT]

4. [CURRENT] **Action buttons** [CURRENT]
   - `Save result` (primary green)
   - `Scan another` (secondary)

---

### Screen 7 — Result: Low Confidence / Unclear Image

**Toolbar (dark amber background `#5a3d00`):**
- Title: `Could not identify clearly`
- Subtitle: `Image unclear`

**Body (centered):**

1. [CURRENT] Dimmed/blurred image preview (full width, 120dp, low opacity) [CURRENT]

2. [CURRENT] **Amber warning card** [CURRENT]
   - Title: `Could not identify clearly`
   - Body: `The AI is only [X]% confident. This may not be a crop leaf, or the photo is blurry or too dark.`
   - Confidence bar (amber fill) + percentage

3. [CURRENT] **Guidance text** [CURRENT]
   - `Make sure the leaf fills the frame, is in focus, and there is enough light.`

4. [CURRENT] **Action buttons** (stacked) [CURRENT]
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

Each history row contains: [CURRENT]
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
| Setting | Type | Default | [CURRENT]
|---|---|---| [CURRENT]
| Large text mode | Toggle | Off | [CURRENT]
| Show confidence score | Toggle | On | [CURRENT]

#### Model & Data
| Setting | Type | Info | [CURRENT]
|---|---|---| [CURRENT]
| Model version | Info row | `MobileNetV2 — v1.2.0` + green "Up to date" badge | [CURRENT]
| Supported crops | Info row | `Maize, Tomato, Potato` + "View all" link | [CURRENT]
| Clear scan history | Destructive action | Red "Clear" text, confirmation dialog before deleting | [CURRENT]

#### About
| Setting | Type | Info | [CURRENT]
|---|---|---| [CURRENT]
| About CropGuard | Info row | `Version 1.0 · Built for farmers` | [CURRENT]
| How to use | Link | Opens simple user guide | [CURRENT]
| Disclaimer | Info | AI suggestion only, not a replacement for agronomist | [CURRENT]

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

| Role | Size | Weight | Usage | [CURRENT]
|---|---|---|---| [CURRENT]
| Screen title (toolbar) | 16sp | 500 | All toolbar titles | [CURRENT]
| Subtitle (toolbar) | 10sp | 400 | Toolbar subtitles | [CURRENT]
| Section labels | 11sp | 500, UPPERCASE | Category headers | [CURRENT]
| Disease name / headline | 14sp | 500 | Result card title | [CURRENT]
| Body text | 13sp | 400 | Cards, descriptions | [CURRENT]
| Tips / secondary | 11–12sp | 400 | Hints, tips, captions | [CURRENT]
| Badges / tags | 10sp | 500 | Status labels | [CURRENT]
| **Minimum (outdoor mode)** | **16sp** | 400 | Large text mode toggle | [CURRENT]

> **Rule:** Never use px. [CURRENT] Always use sp for text, dp for everything else. [CURRENT]

### Spacing System

| Token | Value | Usage | [CURRENT]
|---|---|---| [CURRENT]
| xs | 4dp | Tight gaps (icon-to-label) | [CURRENT]
| sm | 8dp | Between related elements | [CURRENT]
| md | 12dp | Card internal padding | [CURRENT]
| lg | 16dp | Screen edge margins | [CURRENT]
| xl | 24dp | Section spacing | [CURRENT]

### Component Dimensions

| Component | Size | [CURRENT]
|---|---| [CURRENT]
| Primary button | Full width, 48dp height, 10dp corner radius | [CURRENT]
| Secondary button | Full width or 50%, 44dp height | [CURRENT]
| Camera shutter button | 60dp diameter circle | [CURRENT]
| Navigation bar | 48dp height | [CURRENT]
| Toolbar / App bar | 56dp height | [CURRENT]
| History list row | Min 56dp height | [CURRENT]
| Touch targets (all) | Minimum 48×48dp | [CURRENT]
| Confidence progress bar | 6dp height, full width | [CURRENT]
| Card corner radius | 10dp | [CURRENT]
| Thumbnail (history) | 36×36dp, 6dp radius | [CURRENT]
| Badge | 10sp text, 2dp top/bottom, 7dp left/right padding, pill radius | [CURRENT]

### Elevation & Depth

- No drop shadows on cards (flat design)
- Toolbar: slight elevation (4dp) to separate from content
- Bottom nav: 8dp elevation
- Cards: 0dp elevation, 0.5dp border instead

---

## 7. UX Principles for This App

### Designed for farmers — not developers

These UX rules must be followed throughout the entire app: [CURRENT]

1. [CURRENT] **Plain language only.** No words like "CNN", "inference", "tensor", "confidence interval", "model". [CURRENT] Use "AI check", "how sure the AI is", "result". [CURRENT]

2. [CURRENT] **Color communicates everything.** Green = good. [CURRENT] Red = bad. [CURRENT] Amber = unsure. [CURRENT] Any farmer should understand the result screen in under 3 seconds without reading. [CURRENT]

3. [CURRENT] **Large, tappable buttons.** All buttons minimum 48dp tall. [CURRENT] Primary actions are full-width. [CURRENT] Never place two important actions right next to each other. [CURRENT]

4. [CURRENT] **Outdoor readability.** Default font at least 13sp. [CURRENT] Large text mode bumps to 16sp+. [CURRENT] High contrast — never light grey text on white background. [CURRENT]

5. [CURRENT] **Works offline.** No spinner that depends on internet. [CURRENT] Model loaded from assets. [CURRENT] History stored locally. [CURRENT] Tips stored locally. [CURRENT]

6. [CURRENT] **Fail gracefully.** Every error has a message and a recovery action. [CURRENT] Never show a blank screen or a raw exception. [CURRENT]

7. [CURRENT] **One action per screen.** The camera screen's only job is capturing a photo. [CURRENT] The result screen's only job is showing the result. [CURRENT] Don't crowd screens. [CURRENT]

8. [CURRENT] **Loading always visible.** Never run AI inference silently. [CURRENT] Always show Screen 4 (Analysing) so the farmer knows the app is working. [CURRENT]

9. [CURRENT] **Confidence score always shown.** Never display just a disease label. [CURRENT] Always pair it with a confidence bar and percentage. [CURRENT]

10. [CURRENT] **Disclaimer always present.** Every result screen includes: *"This is an AI suggestion. [CURRENT] Consult an agronomist for serious outbreaks."* [CURRENT]

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

| Feature | Description | [CURRENT]
|---|---| [CURRENT]
| Camera scan | Open camera, display viewfinder with guide frame, capture on shutter tap | [CURRENT]
| Gallery upload | Open Android photo picker, select existing image | [CURRENT]
| Image preprocessing | Resize to 224×224dp, normalize pixels to match training preprocessing | [CURRENT]
| TFLite inference | Run MobileNetV2 model on background thread, return class + confidence | [CURRENT]
| Disease result display | Show disease name, confidence bar, cause, and numbered treatment steps | [CURRENT]
| Healthy result display | Show healthy confirmation, confidence bar, maintenance tips | [CURRENT]
| Low confidence fallback | Show amber warning when confidence < 60%, prompt retry | [CURRENT]
| Detection history | Save result to Room database, display in History tab | [CURRENT]
| Offline operation | All features work with no internet connection | [CURRENT]
| Settings | Large text toggle, model info, clear history | [CURRENT]

### Secondary Features (Should Have)

| Feature | Description | [CURRENT]
|---|---| [CURRENT]
| Onboarding | 3-screen first-launch walkthrough | [CURRENT]
| Daily crop tips | Rotating local tips shown on Home screen | [CURRENT]
| History filtering | Filter by All / Diseased / Healthy | [CURRENT]
| Result sharing | Share screenshot of result (Android share sheet) | [CURRENT]
| About screen | App version, disclaimer, model info | [CURRENT]

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

1. [CURRENT] **Never run inference on the main thread.** Use `viewModelScope.launch(Dispatchers.IO)`. [CURRENT]
2. [CURRENT] **Load model once.** Initialise `Interpreter` in `DiseaseClassifier` constructor, reuse it. [CURRENT]
3. [CURRENT] **Normalization must match training.** Verify this before integration testing. [CURRENT]
4. [CURRENT] **Confidence threshold = 0.60f.** If `max(outputArray) < 0.60`, navigate to Low Confidence screen. [HISTORICAL]
5. [CURRENT] **Model in `assets/`.** Never download it at runtime. [CURRENT]
6. [CURRENT] **Image path, not Bitmap, stored in Room.** Save the file path; load image from path when needed. [CURRENT]

---

## 11. AI Model Integration

### Model Details

| Field | Value | [CURRENT]
|---|---| [CURRENT]
| Base model | MobileNetV2 (pretrained on ImageNet) | [CURRENT]
| Transfer learning | Final layers replaced and retrained on PlantVillage dataset | [CURRENT]
| Input shape | 224 × 224 × 3 (RGB) | [CURRENT]
| Input dtype | float32 | [CURRENT]
| Normalization | [-1, 1] (MobileNetV2 standard) | [CURRENT]
| Output shape | [1, N] where N = number of disease classes | [CURRENT]
| Output dtype | float32 (softmax probabilities) | [CURRENT]
| Export format | TensorFlow Lite (.tflite) | [CURRENT]
| Quantization | Post-training quantization (DEFAULT) — reduces size ~4× | [CURRENT]
| Target file size | < 20MB | [CURRENT]

### Disease Classes Supported (PlantVillage subset)

| Crop | Disease | Class label | [CURRENT]
|---|---|---| [CURRENT]
| Maize | Northern Leaf Blight | `Corn_Northern_Leaf_Blight` | [CURRENT]
| Maize | Common Rust | `Corn_Common_Rust` | [CURRENT]
| Maize | Gray Leaf Spot | `Corn_Gray_Leaf_Spot` | [CURRENT]
| Maize | Healthy | `Corn_Healthy` | [CURRENT]
| Tomato | Bacterial Spot | `Tomato_Bacterial_Spot` | [CURRENT]
| Tomato | Early Blight | `Tomato_Early_Blight` | [CURRENT]
| Tomato | Late Blight | `Tomato_Late_Blight` | [CURRENT]
| Tomato | Leaf Mold | `Tomato_Leaf_Mold` | [HISTORICAL]
| Tomato | Healthy | `Tomato_Healthy` | [CURRENT]
| Potato | Early Blight | `Potato_Early_Blight` | [CURRENT]
| Potato | Late Blight | `Potato_Late_Blight` | [CURRENT]
| Potato | Healthy | `Potato_Healthy` | [CURRENT]

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

| ID | Requirement | [CURRENT]
|---|---| [CURRENT]
| FR1 | The app shall allow a user to capture a crop leaf image using the device camera | [CURRENT]
| FR2 | The app shall allow a user to select an existing image from the device gallery | [CURRENT]
| FR3 | The app shall classify the leaf image and return a disease label and confidence score | [CURRENT]
| FR4 | If confidence is below 60%, the app shall prompt the user to retake the image | [CURRENT]
| FR5 | The app shall display a disease description and recommended treatment for each result | [CURRENT]
| FR6 | The app shall store detection history locally (image path, result, timestamp) | [CURRENT]
| FR7 | The app shall function without an internet connection after installation | [CURRENT]
| FR8 | The app shall display a confidence score alongside every result | [CURRENT]
| FR9 | The app shall show a disclaimer recommending agronomist consultation | [CURRENT]

### Non-Functional Requirements

| ID | Requirement | Measure | [CURRENT]
|---|---|---| [CURRENT]
| NFR1 | Classification accuracy | ≥ 85% on test set | [CURRENT]
| NFR2 | Inference time | ≤ 3 seconds on 2GB RAM device | [CURRENT]
| NFR3 | App cold start time | ≤ 4 seconds | [HISTORICAL]
| NFR4 | Model file size | ≤ 20MB | [CURRENT]
| NFR5 | Minimum Android version | API 26 (Android 8.0) | [CURRENT]
| NFR6 | Touch target size | Minimum 48×48dp | [CURRENT]
| NFR7 | Body text size | Minimum 13sp (16sp in large text mode) | [CURRENT]
| NFR8 | Offline support | 100% core features work without internet | [CURRENT]

### System Constraints

- Android platform only (no iOS in v1)
- Must run on devices with as little as 2GB RAM
- Farmers may have no mobile data in the field
- Target users may have low literacy — UI must not rely on reading alone
- No backend server — all computation on-device

---

## 14. Testing Plan

### Test Cases

| ID | Test | Type | Expected result | Pass/Fail | [CURRENT]
|---|---|---|---|---| [CURRENT]
| T01 | Preprocess 224×224 image, check tensor shape | Unit | Shape: [1, 224, 224, 3] | | [CURRENT]
| T02 | Preprocess image, check pixel range | Unit | All values in [-1.0, 1.0] | | [CURRENT]
| T03 | Run model on healthy tomato leaf | Integration | Label: Healthy, conf ≥ 80% | | [CURRENT]
| T04 | Run model on diseased maize leaf | Integration | Correct disease, conf ≥ 75% | | [CURRENT]
| T05 | Submit blurry image | Robustness | Low confidence screen shown | | [CURRENT]
| T06 | Submit non-plant image (face) | Edge case | Low confidence screen shown | | [CURRENT]
| T07 | Scroll history list 50+ items | Performance | No jank, smooth 60fps | | [CURRENT]
| T08 | Run on 2GB RAM device | Performance | No crash, inference ≤ 3s | | [CURRENT]
| T09 | Deny camera permission | Edge case | Rationale shown, gallery offered | | [CURRENT]
| T10 | Complete scan without internet | Functional | Full result shown offline | | [CURRENT]
| T11 | Non-technical user completes scan | Acceptance | Success without assistance | | [CURRENT]
| T12 | Save result and view in history | Functional | Appears in history correctly | | [CURRENT]
| T13 | Clear history in settings | Functional | All records deleted | | [CURRENT]
| T14 | Toggle large text mode | Functional | Text size increases throughout | | [CURRENT]

---

## 15. Prompts to Give Your AI (Vibe Coding Guide)

Use these exact prompts with your AI to build each part of the app: [CURRENT]

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
