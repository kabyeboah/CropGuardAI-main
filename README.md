# CropGuard AI

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D%203.10.0-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D%203.6.0%20%3C%204.0.0-blue.svg?logo=dart)](https://dart.dev)
[![Platform support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](#)
[![Offline First](https://img.shields.io/badge/Offline--First-100%25%20Functionality-brightgreen.svg)](#)
[![Target Region](https://img.shields.io/badge/Region-Ghana%20%2F%20Sub--Saharan%20Africa-orange.svg)](#)

CropGuard AI is a production-grade, offline-first mobile application developed in Flutter. It is designed to assist smallholder farmers in Ghana and Sub-Saharan Africa in instantly detecting plant diseases and applying appropriate agricultural treatments without requiring a persistent internet connection.

---

## 🏗️ Clean Architecture Overview

CropGuard AI is built following a strict **Clean Architecture** design pattern. It enforces unidirectional dependency flow: **UI (Widgets) ➔ State (Providers) ➔ Use Cases ➔ Repositories (Interfaces) ➔ Data Sources (Implementations & Services)**. 

Dependency Injection is managed globally via [GetIt](https://pub.dev/packages/get_it) in [service_locator.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/di/service_locator.dart).

```
lib/
├── main.dart                  # Zone-guarded bootstrap, Firebase initialization & background workers
├── app.dart                   # MaterialApp.router config, global theme, and localized locales
├── core/
│   ├── di/                    # GetIt service registrations (service_locator.dart)
│   ├── theme/                 # Harmonized brand colors, typography tokens, and layout guidelines
│   ├── config/                # Environment-specific AppSecrets resolving mechanism
│   ├── error/                 # Domain-agnostic failures
│   └── utils/                 # Utilities: Result wrapper, connectivity monitoring, app lock, loggers
├── domain/
│   ├── models/                # Plain Dart objects representing domain entities (DetectionResult, AppUser)
│   ├── repositories/          # Abstract contracts defining repository interfaces
│   └── usecases/              # Independent business logic commands (e.g., ScanCropUseCase)
├── data/
│   ├── local/                 # Database helper using sqflite (SQLite) for history and trackers
│   ├── ml/                    # TFLite classifier wrapper doing on-device tensor calculations
│   ├── remote/                # Integration with Cloudinary, Firebase (Auth, Firestore, Storage), GhanaNLP
│   └── repositories/          # Concrete implementation of domain interfaces mapping raw data to models
└── presentation/
    ├── navigation/            # GoRouter structure with guards (app_router.dart)
    ├── components/            # Standardized responsive UI components (CropGuardCard, PrimaryButton)
    └── screens/               # 21 feature subdirectories separating screens and state providers
```

---

## 🌟 Key Subsystems & Features

### 1. On-Device AI/ML Classification
*   **Engine & Model**: Powered by `tflite_flutter` running a quantized Convolutional Neural Network (CNN) based on the **MobileNetV2** architecture.
*   **Dual-Model Setup**:
    *   **V1 Model** (`cropguard_plant_disease.tflite`): Detects **93 classes** covering staple crops like Maize, Potato, Tomato, Rice, Cassava, Banana, Yam, Cashew, Cocoa, Groundnut, and Cowpea.
    *   **V2 Model** (`cropguard_plant_disease_v2.tflite`): Optimized for **16 classes** focusing specifically on local variants such as Garden Egg (African Eggplant), Mango, and Sugarcane.
*   **Inference Quality**: Runs an `ImageQualityAnalyzer` locally to flag blurry or dark photos before execution. If the maximum prediction probability is lower than `0.60`, it redirects to a "Low Confidence" fallback screen rather than suggesting an incorrect diagnosis.

### 2. Offline-First Capability & Synchronization
*   **Local Storage**: Local history records, diagnostics, and customized treatment trackers are managed on-device via SQLite utilizing the `sqflite` package.
*   **Online Auto-Drain Queue**: When offline, community forum posts and feedback details are stored in a local pending queue. The `ConnectivityService` listens to network state changes; when an online status is recovered, it automatically triggers a synchronization worker (`drainPendingSync`) to upload entries to Cloud Firestore and Cloudinary.

### 3. Localization & GhanaNLP Translation
*   **Local Dialects**: Fully localized using Flutter `.arb` files to support **English (`en`)**, **Twi (`tw`)**, **Ewe (`ee`)**, and **Dagbani (`dag`)**.
*   **Text-to-Speech (TTS)**: Leverages the **GhanaNLP Translation API** to synthesize text into local language audio files (`.wav`) at runtime, catering to farmers with low literacy levels.

### 4. Interactive Outbreak Mapping & Background Alerts
*   **OpenStreetMap (OSM)**: Implements offline-capable outbreak mapping using `flutter_map` combined with custom marker clustering (`flutter_map_marker_cluster`) and on-disk caching (`flutter_cache_manager`) to display nearby crop disease alerts without active data packages.
*   **Background Alerts**: Android `workmanager` registers a background check (`scheduleOutbreakAlerts`) that triggers local notifications when an outbreak is logged in proximity to the farmer's geolocated coordinates.

### 5. Enterprise Security & Privacy Controls
*   **App Integrity**: Implements root and jailbreak checks via `RootDetectionHelper` (wrapping `flutter_jailbreak_detection`).
*   **Screen Protection**: Activates high-security layout flags to block screenshot/screen-recording tools on sensitive application pages using `ScreenSecurityHelper` (wrapping `flutter_windowmanager_plus`).
*   **App Lock**: Optional biometric lock screen (FaceID/Fingerprint) utilizing `local_auth` that locks the active session upon application backgrounding/resuming.

---

## ⚙️ Secrets Resolution Order

To keep API keys secure, they are never checked in or bundled as asset files. The [AppSecrets](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/config/app_secrets.dart) class checks variables in the following sequence (first match wins):
1.  **Compile-time Define**: `--dart-define=GHANA_NLP_SUBSCRIPTION_KEY=...`
2.  **Local Environment**: Read from a local `.env` file (loaded at runtime in debug mode only).
3.  **Firebase Remote Config**: Dynamically fetched and patched at startup by `AppBootstrap.runStartupTasks()`.

---

## 🛠️ Getting Started

### 1. Install Dependencies
Ensure you have the Flutter SDK (>= 3.10.0) and Dart SDK (>= 3.6.0) installed:
```bash
flutter pub get
```

### 2. Configure Firebase
*   **Option A (CLI - Recommended)**: Install the Flutterfire CLI and run config matching project `crop-guard-d36e5`:
    ```bash
    dart pub global activate flutterfire_cli
    flutterfire configure --project=crop-guard-d36e5
    ```
*   **Option B (Manual)**: Download the configuration files from the Firebase Console and place them in:
    *   Android: `android/app/google-services.json`
    *   iOS: `ios/Runner/GoogleService-Info.plist`

### 3. Add AI Assets
Verify that you have downloaded and placed the necessary ML models and mapping labels in the `assets/` directory (these are registered in [pubspec.yaml](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/pubspec.yaml)):
*   `assets/cropguard_plant_disease.tflite`
*   `assets/cropguard_plant_disease_v2.tflite`
*   `assets/labels.txt`
*   `assets/labels_v2.txt`
*   `assets/model_metadata.json`

### 4. Run the Application
For local testing (with an optional `.env` file containing local API secrets):
```bash
flutter run
```
To run supplying compilation secrets:
```bash
flutter run --dart-define=GHANA_NLP_SUBSCRIPTION_KEY=your_ghana_nlp_key
```

---

## 🧪 Testing Suite

CropGuard AI features a robust test pipeline located under the [test/](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test) directory. Detections, repository mocks, and state models are verified using `flutter_test` and `mocktail`.

### Execution Commands
*   Run the complete test suite:
    ```bash
    flutter test
    ```
*   Run static analysis / lint check:
    ```bash
    flutter analyze
    ```
*   Test a specific use case file:
    ```bash
    flutter test test/domain/usecases/scanner/scan_crop_usecase_test.dart
    ```

### Key Test Coverage
*   **Core Helpers**: Biometrics lock state transitions (`app_lock_controller_test.dart`), input sanitation (`input_sanitizer_test.dart`), and weather formatting (`agri_weather_utils_test.dart`).
*   **Data Models**: SQLite transaction logic (`database_helper_test.dart` and `database_helper_extended_test.dart`).
*   **Domain Rules**: Verification of mock repositories executing use cases (`scan_crop_usecase_test.dart`, `login_usecase_test.dart`).
*   **UI Components**: Accessibility (a11y) widgets check (`components_a11y_test.dart`) and map geo-aggregation checks (`outbreak_map_aggregation_test.dart`).
