# CropGuard AI Codebase Validation and Review Dossier

Last updated: 2026-03-26
Workspace: `/Users/kwameyeboah/Documents/APP`

## 1) Executive Summary

CropGuard AI is a single-module Android application built with Kotlin + Jetpack Compose, using a layered architecture (`presentation` -> `domain` -> `data`) and dependency injection via Hilt.  
The codebase is production-oriented with Firebase integrations (Auth, Firestore, FCM, Storage, Remote Config), local persistence (Room + DataStore), and on-device ML inference (TFLite).

Recent work completed in this codebase includes:

- Security/session hardening (auth truth, scoped scan data, logout invalidation, token/logging fixes)
- Accessibility/responsiveness hardening (touch targets, font sizing, adaptive spacing, device-class helpers)
- Replacement of placeholder feature routes with implemented screens:
  - `OutbreakMap`
  - `Community`
  - `TreatmentTracker`

Validation status:

- `:app:compileDebugKotlin` -> success
- `:app:testDebugUnitTest` -> success
- `:app:assembleDebug` -> success
- `:app:ktlintCheck` -> success (configured as blocking with `ignoreFailures = false`)

## 2) Repository and Module Structure

Root:

- `settings.gradle.kts` (includes `:app`)
- `build.gradle.kts` (top-level plugins/tasks)
- `app/build.gradle.kts` (Android app module config/deps)
- `gradle/libs.versions.toml` (version catalog)
- `README.md` (build/run/test quickstart)
- `docs/` (project documentation)

Main source:

- `app/src/main/java/com/cropguard/ai`

Major packages:

- `presentation/` (Compose UI, ViewModels, navigation, theme, reusable components)
- `domain/` (entities/models, repository interfaces, use cases)
- `data/` (repository implementations, Room, DataStore, network, Firebase, ML, security)
- `di/` (Hilt modules)
- `work/` (WorkManager jobs)

## 3) Architecture and Flow

### 3.1 Layering

- UI composables call ViewModels.
- ViewModels orchestrate use cases/repositories.
- Domain defines interfaces and use-case contracts.
- Data implements domain repositories with Firebase/Room/network/ML.

### 3.2 Dependency Injection

Hilt modules provide:

- Firebase clients (`FirebaseAuth`, Firestore, Messaging, Storage, Remote Config)
- Retrofit/OkHttp stack
- Room DB and DAOs
- DataStore sources
- Security helpers (encrypted preferences/files)
- Connectivity observers
- ML classifier/dependencies
- Repository bindings + use-case construction

### 3.3 Critical App Flows

Auth/session:

- Splash decides route using onboarding + authenticated user + session validity.
- Session activity is updated in `MainActivity.onResume()`.
- Logout clears auth/session/tokens and user-scoped local scan data.

Scan pipeline:

- Scanner screen captures from camera/gallery.
- Image quality checks + classifier prediction.
- Scan results persisted locally and optionally synced remotely.

Sync:

- Periodic background worker schedules scan sync.
- Unsynced user-scoped scans are pushed to Firestore; optional image upload to Storage.

## 4) Navigation and Screen Inventory

Defined in `presentation/navigation/CropGuardNavGraph.kt`.

Routes/screens:

- `Splash`
- `Onboarding`
- `Login`
- `Register`
- `Home`
- `Scanner`
- `Result`
- `History`
- `Profile`
- `EditProfile`
- `Settings`
- `ForgotPassword`
- `DiseaseLibrary`
- `OutbreakMap` (implemented)
- `Community` (implemented)
- `TreatmentTracker` (implemented)

## 5) Feature Modules (Detailed)

### 5.1 OutbreakMap

Files:

- `presentation/screens/outbreakmap/OutbreakMapScreen.kt`
- `presentation/screens/outbreakmap/OutbreakMapViewModel.kt`

Behavior:

- Builds outbreak hotspots from diseased/warning scans.
- Presents loading, empty, error, offline states.
- Current UI is list/summary based; map rendering is not yet using maps UI components.

### 5.2 Community

Files:

- `presentation/screens/community/CommunityScreen.kt`
- `presentation/screens/community/CommunityViewModel.kt`

Behavior:

- Community feed + local compose/post interaction.
- Offline and validation feedback.
- Data is in-memory/seeded for now (not persisted to backend yet).

### 5.3 TreatmentTracker

Files:

- `presentation/screens/treatmenttracker/TreatmentTrackerScreen.kt`
- `presentation/screens/treatmenttracker/TreatmentTrackerViewModel.kt`

Behavior:

- Derives treatment tasks from scan history severity.
- Supports local check-off toggles and priority labels.
- Completion is currently in-memory.

## 6) Data, Storage, and External Integrations

Local:

- Room:
  - `data/local/db/CropGuardDatabase.kt`
  - `data/local/dao/ScanDao.kt`, `UserDao.kt`
- DataStore:
  - `UserPreferencesDataSource.kt`
  - `SessionPreferencesDataSource.kt`
- Encrypted storage:
  - `EncryptedPrefsManager.kt`
  - `EncryptedFileManager.kt`

Cloud/remote:

- Firebase Auth/Firestore/FCM/Storage/Remote Config
- Retrofit/OkHttp API stack (Meta API + repository)
- Open-Meteo weather client

ML:

- TFLite classifier and related use cases
- Model config and threshold logic

## 7) Security Posture

Implemented controls:

- `allowBackup=false`
- Network security config in manifest
- Encrypted token storage
- App Check bootstrap
- Redacted sensitive headers in HTTP logging
- Session + logout hardening
- User-scoped scan query model

Open concerns:

- Certificate pinning currently deferred/documented but not active.
- `READ_EXTERNAL_STORAGE` remains declared (review least-privilege need by API level).
- `AuthInterceptor` token retrieval occurs in interceptor path with blocking wait.
- Ktlint now blocking and enforcing code style.

## 8) Responsiveness and UX Hardening Status

Implemented:

- Adaptive device-class utilities in `presentation/theme/Adaptive.kt`
- Breakpoint-based horizontal padding and readable width constraints
- Scroll and keyboard-safe handling in long forms
- Minimum touch target improvements on many tappable controls
- Typography baseline increased from prior too-small styles

Remaining practical QA need:

- Screenshot/device pass for small phone, standard phone, foldable, tablet
- Font scale checks at 100% / 130% / 150%
- Landscape checks for major flows
- Long localized-string overflow verification

## 9) Testing and Quality Tooling

Tests:

- Unit tests under `app/src/test`
- Instrumentation tests under `app/src/androidTest`

Build/static:

- `assembleDebug`, `compileDebugKotlin`, `testDebugUnitTest`
- `ktlint` plugin integrated
- Ktlint is configured as blocking (enforcing)
  - `ignoreFailures = true`
  - test/androidTest ktlint tasks disabled

## 10) Validation Evidence

Commands executed during validation:

```bash
./gradlew :app:compileDebugKotlin :app:testDebugUnitTest
./gradlew :app:assembleDebug
./gradlew :app:ktlintCheck
```

Observed outcomes:

- Build: successful
- Unit tests: successful
- Debug APK assembly: successful
- Ktlint task: pass (configured as blocking)
- All style violations resolved via `ktlintFormat`.

## 11) Risks and Recommended Next Actions

High-impact next steps:

1. Productionize new feature modules:
   - Persist `Community` and `TreatmentTracker` data (Firestore-backed or equivalent)
   - Decide whether `OutbreakMap` should render real map overlays
2. Maintain ktlint as blocking after baseline cleanup (Completed)
3. Complete release QA matrix:
   - Device class + font scale + landscape + core workflow checks
4. Security refinements:
   - Reassess storage permission scope and cert pinning roadmap

## 12) Reference Index (Key Files)

Entry/composition:

- `app/src/main/java/com/cropguard/ai/CropGuardAiApp.kt`
- `app/src/main/java/com/cropguard/ai/presentation/MainActivity.kt`

Navigation:

- `app/src/main/java/com/cropguard/ai/presentation/navigation/CropGuardNavGraph.kt`

Auth/session:

- `app/src/main/java/com/cropguard/ai/data/repository/AuthRepositoryImpl.kt`
- `app/src/main/java/com/cropguard/ai/presentation/screens/splash/SplashViewModel.kt`
- `app/src/main/java/com/cropguard/ai/data/local/preferences/SessionPreferencesDataSource.kt`

Scans/sync:

- `app/src/main/java/com/cropguard/ai/data/repository/ScanRepositoryImpl.kt`
- `app/src/main/java/com/cropguard/ai/data/local/dao/ScanDao.kt`
- `app/src/main/java/com/cropguard/ai/work/ScanSyncWorker.kt`

New features:

- `app/src/main/java/com/cropguard/ai/presentation/screens/outbreakmap/OutbreakMapScreen.kt`
- `app/src/main/java/com/cropguard/ai/presentation/screens/community/CommunityScreen.kt`
- `app/src/main/java/com/cropguard/ai/presentation/screens/treatmenttracker/TreatmentTrackerScreen.kt`

Build/deps:

- `app/build.gradle.kts`
- `build.gradle.kts`
- `gradle/libs.versions.toml`
