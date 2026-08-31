# CropGuard AI

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D%203.10.0-blue.svg?logo=flutter)](https://flutter.dev) [CURRENT]
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D%203.6.0%20%3C%204.0.0-blue.svg?logo=dart)](https://dart.dev) [CURRENT]
[![Platform support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](#) [CURRENT]
[![Offline First](https://img.shields.io/badge/Offline--First-100%25%20Functionality-brightgreen.svg)](#) [CURRENT]
[![Target Region](https://img.shields.io/badge/Region-Ghana%20%2F%20Sub--Saharan%20Africa-orange.svg)](#) [CURRENT]
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#) [CURRENT]

**CropGuard AI** is a production-grade, offline-first mobile application built with Flutter & Dart. It is tailored specifically for smallholder farmers in Ghana and Sub-Saharan Africa to instantly diagnose crop diseases on-device using quantized TensorFlow Lite models, access localized treatment recommendations, track outbreak alerts on an offline-capable interactive map, and receive audio assistance in native regional languages.

---

## 🏗️ Clean Architecture

The project strictly follows **Clean Architecture** principles to separate concerns into predictable, testable, and maintainable layers. [CURRENT] Dependencies flow inwards: **Presentation (UI & Providers) ➔ Domain (Use Cases & Entities) ➔ Data (Repositories, Local DB & Remote Services)**. [CURRENT]

Global Dependency Injection is configured using [GetIt](https://pub.dev/packages/get_it) in [`lib/core/di/service_locator.dart`](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/di/service_locator.dart). [CURRENT]

```
lib/
├── main.dart                  # Zone-guarded bootstrap, Firebase initialization & background workers
├── app.dart                   # MaterialApp.router config, global theme, and localized locales
├── core/
│   ├── config/                # Secrets resolution (AppSecrets) & feature flag configurations
│   ├── di/                    # GetIt service locator setup (service_locator.dart)
│   ├── error/                 # Domain failures & exception mappers
│   ├── theme/                 # Harmonized brand colors, typography tokens, and light/dark themes
│   └── utils/                 # Utilities: Result wrapper, connectivity, app lock, input sanitizer, loggers
├── domain/
│   ├── models/                # Pure Dart domain entities (DetectionResult, AppUser, OutbreakReport, etc.)
│   ├── repositories/          # Abstract contracts for scanner, history, community, auth, etc.
│   └── usecases/              # Isolated business rules (e.g. ScanCropUseCase, LoginUseCase)
├── data/
│   ├── local/                 # On-device SQLite database helpers (sqflite) & cache storage
│   ├── ml/                    # TFLite classifier engine & ImageQualityAnalyzer validation
│   ├── remote/                # Cloudinary, Firebase (Auth, Firestore, Storage, Remote Config), GhanaNLP API
│   └── repositories/          # Concrete implementation of domain repository interfaces
└── presentation/
    ├── components/            # Standardized accessible UI widgets (CropGuardCard, PrimaryButton, etc.)
    ├── navigation/            # GoRouter configuration & auth/biometric route guards (app_router.dart)
    └── screens/               # 22 feature screen modules (screens & provider controllers):
        ├── analysing/          # Processing & image quality check feedback animation
        ├── community/          # Peer forum, diagnostic sharing & expert Q&A
        ├── error/              # Standardized failure fallback screen
        ├── forgot_password/    # Password reset link dispatcher
        ├── history/            # Searchable, filterable scan history log
        ├── home/               # Dashboard, quick scan CTA, weather & disease risk forecast
        ├── legal/              # Privacy policy & terms of service
        ├── library/            # Offline disease handbook & treatment guides
        ├── lock/               # Biometric security overlay screen
        ├── login/              # Phone / email authentication screen
        ├── more/               # Secondary options & regional configurations
        ├── notifications/      # In-app outbreak alerts & broadcast feed
        ├── onboarding/         # First-time app walkthrough & permission prompts
        ├── outbreak_map/       # OpenStreetMap interactive disease cluster map
        ├── profile/            # Farmer profile, crop preferences & farm location
        ├── register/           # User onboarding & sign-up screen
        ├── reset_password/     # Password reset confirmation screen
        ├── result/             # Scan diagnosis, confidence breakdown & action buttons
        ├── scanner/            # Live camera view, image upload & guidance overlay
        ├── settings/           # Language preference, biometric lock & app preferences
        ├── splash/             # Startup splash & initialization check
        └── treatment_tracker/  # Chemical/organic recovery schedule tracker
```

---

## 🌟 Subsystems & Features

### 1. On-Device TensorFlow Lite ML Engine
* **Quantized CNN Models**: Runs on `tflite_flutter` without requiring active cloud network connections.
  * **MobileNetV2 Model** (`cropguard_plant_disease.tflite`): Detects 51 classes across major staple and regional crops (Maize, Potato, Tomato, Rice, Cassava, Banana, Yam, Cashew, Cocoa, Groundnut, Cowpea, Mango, Sugarcane, etc.).
* **Pre-Execution Quality Gate**: `ImageQualityAnalyzer` checks image lighting and blur before running tensor operations. Low-confidence predictions (< 60%) automatically navigate to a low-confidence diagnostic helper screen to prevent false treatment recommendations.

### 2. Offline-First Architecture & Auto-Sync Engine
* **SQLite Storage**: Scan history, custom treatment tracker tasks, and cached disease info are stored locally using `sqflite`.
* **Auto-Sync Queue**: Community posts, scan logs, and farmer feedback submitted while offline enter a local pending queue. `ConnectivityService` monitors network status changes and automatically drains the pending queue to Cloud Firestore & Cloudinary when connectivity is re-established.

### 3. Native Localization & GhanaNLP Audio Synthesis
* **Regional Dialect Support**: Built-in support for **English (`en`)**, **Twi (`tw`)**, **Ewe (`ee`)**, and **Dagbani (`dag`)** via standard `.arb` localization files.
* **Text-to-Speech (TTS)**: Synthesizes disease descriptions and treatment steps into native regional audio using `flutter_tts` and the GhanaNLP API to support farmers with varying literacy levels.

### 4. Interactive Outbreak Map & Proximity Alerts
* **OpenStreetMap (OSM)**: Zero-cost, keyless mapping built on `flutter_map` with marker clustering (`flutter_map_marker_cluster`) and persistent tile caching (`flutter_cache_manager`).
* **Background Surveillance**: Android `workmanager` schedules routine background tasks (`scheduleOutbreakAlerts`) that match current geolocation against recent community reports and fire local notifications (`flutter_local_notifications`).

### 5. Enterprise App Security & Privacy
* **App Integrity**: Root and jailbreak detection using `flutter_jailbreak_detection`.
* **Screen Protection**: Prevents screenshots and recording on sensitive screens using `flutter_windowmanager_plus`.
* **Biometric Lock Screen**: App locking using `local_auth` (Face ID / Fingerprint) when resuming from backgrounding.

---

## ⚙️ App Secrets Resolution Order

Sensitive API keys and endpoints are never hardcoded. [CURRENT] [`AppSecrets`](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/config/app_secrets.dart) resolves values in the following order (first available wins): [CURRENT]

1. [CURRENT] **Compile-Time `--dart-define` Flags**: e.g., `--dart-define=GHANA_NLP_SUBSCRIPTION_KEY=your_key` [CURRENT]
2. [CURRENT] **Local `.env` File**: Loaded at runtime in local debug mode. [CURRENT]
3. [CURRENT] **Firebase Remote Config**: Dynamic production patching via `AppBootstrap.runStartupTasks()`. [CURRENT]

---

## 🛠️ Installation & Setup

### Prerequisites
- **Flutter SDK**: `>= 3.10.0`
- **Dart SDK**: `>= 3.6.0 < 4.0.0`
- **Xcode** (for iOS builds, macOS required) or **Android Studio** (for Android builds)

### 1. Repository Setup & Dependencies
```bash
# Clone repository
git clone <repository_url>
cd <repository_directory>

# Install dependencies
flutter pub get
```

### 2. Firebase Configuration
* **CLI Setup (Recommended)**:
  ```bash
  dart pub global activate flutterfire_cli
  # Run interactively to select/create your Firebase project:
  flutterfire configure
  # Or explicitly specify your project ID:
  # flutterfire configure --project=<your-firebase-project-id>
  ```
* **Manual Setup**: Place configuration files in the appropriate platform directories:
  * Android: `android/app/google-services.json`
  * iOS: `ios/Runner/GoogleService-Info.plist`

### 3. Verify Asset Bundling
Ensure the following AI models and metadata files exist in `assets/`: [CURRENT]
- `assets/cropguard_plant_disease.tflite`
- `assets/labels.txt`
- `assets/model_metadata.json`

### 4. Run the Application
```bash
# Debug run (using local .env if present)
flutter run

# Release/Debug run supplying compile-time secrets
flutter run --dart-define=GHANA_NLP_SUBSCRIPTION_KEY=your_key_here
```

---

## 🧪 Testing & Quality Assurance

The application features a comprehensive test suite in the [`test/`](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test) directory, utilizing `flutter_test`, `mocktail`, and `sqflite_common_ffi`. [CURRENT]

### Test Execution Commands
```bash
# Run all unit and widget tests
flutter test

# Run static code analysis & linter
flutter analyze

# Run a specific test file
flutter test test/domain/usecases/scanner/scan_crop_usecase_test.dart
```

### Test Coverage Highlights
* **Core & Utilities**: Tests for `AppLockController`, `InputSanitizer`, and `AgriWeatherUtils`.
* **Data Layer**: SQLite transaction tests (`database_helper_test.dart` and `database_helper_extended_test.dart`).
* **Domain Layer**: Unit tests for scanner, authentication, and history use cases.
* **Presentation & Accessibility**: Widget accessibility checks (`components_a11y_test.dart`) and map marker clustering tests (`outbreak_map_aggregation_test.dart`).

---

## 📄 License & Attribution

This project is licensed under the **MIT License**. [CURRENT]
