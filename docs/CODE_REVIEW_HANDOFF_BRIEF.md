# CropGuard AI - Code Review Handoff Brief

Last updated: 2026-03-26  
Project root: `/Users/kwameyeboah/Documents/APP`

## 1) What this project is

CropGuard AI is an Android app for crop disease detection using on-device ML (TFLite), with Firebase-backed auth/sync and Room-backed local persistence.

Core stack:

- Kotlin, Jetpack Compose, Material 3, Navigation Compose
- Hilt DI
- Coroutines/Flow
- Firebase (Auth, Firestore, FCM, Storage, Remote Config, App Check)
- Room + DataStore

## 2) Architecture at a glance

Layering:

- `presentation/` -> screens, viewmodels, navigation, components
- `domain/` -> models, repository interfaces, use cases
- `data/` -> repository implementations, local/remote/security/ml
- `di/` -> Hilt modules
- `work/` -> background sync jobs

Entry points:

- `app/src/main/java/com/cropguard/ai/CropGuardAiApp.kt`
- `app/src/main/java/com/cropguard/ai/presentation/MainActivity.kt`
- `app/src/main/java/com/cropguard/ai/presentation/navigation/CropGuardNavGraph.kt`

## 3) Key user flows

- Auth/session: Splash -> Onboarding/Login/Register -> Home
- Scan flow: Scanner -> Result -> History/Profile stats
- Background sync: local unsynced scans -> Firestore/Storage via WorkManager
- Settings/feature access: Settings routes to OutbreakMap, Community, TreatmentTracker

## 4) Current feature coverage

Implemented screens:

- Splash, Onboarding, Login, Register, Home, Scanner, Result, History, Profile, EditProfile, Settings, ForgotPassword, DiseaseLibrary
- OutbreakMap (implemented list/hotspot view)
- Community (implemented local feed/composer)
- TreatmentTracker (implemented task list from scan history)

Note:

- OutbreakMap currently uses hotspot summaries/cards, not full map plotting UI.
- Community and TreatmentTracker are currently local-state driven (not yet persisted to backend).

## 5) Security and reliability highlights

Strengths:

- Session/auth routing hardened (Firebase user + session validity)
- Logout clears session state and user-scoped local scan data
- User-scoped scan queries in local DAO/repositories
- Encrypted token storage
- HTTP logging redacts `Authorization` and `Cookie`
- Offline-state handling present on major data screens

Open items:

- Certificate pinning is documented but not yet active
- Storage permission scope should be re-reviewed by API level
- Ktlint is configured as blocking (enforcing)

## 6) Validation status (latest)

Commands run:

```bash
./gradlew :app:compileDebugKotlin :app:testDebugUnitTest
./gradlew :app:assembleDebug
./gradlew :app:ktlintCheck
```

Outcome:

- Build: pass
- Unit tests: pass
- Debug APK assembly: pass
- Ktlint task: pass (configured as blocking)

## 7) Files a reviewer should inspect first

- Navigation/routes:
  - `app/src/main/java/com/cropguard/ai/presentation/navigation/CropGuardNavGraph.kt`
- Auth/session:
  - `app/src/main/java/com/cropguard/ai/data/repository/AuthRepositoryImpl.kt`
  - `app/src/main/java/com/cropguard/ai/presentation/screens/splash/SplashViewModel.kt`
  - `app/src/main/java/com/cropguard/ai/data/local/preferences/SessionPreferencesDataSource.kt`
- Scan/sync:
  - `app/src/main/java/com/cropguard/ai/data/repository/ScanRepositoryImpl.kt`
  - `app/src/main/java/com/cropguard/ai/data/local/dao/ScanDao.kt`
  - `app/src/main/java/com/cropguard/ai/work/ScanSyncWorker.kt`
- Newly implemented features:
  - `app/src/main/java/com/cropguard/ai/presentation/screens/outbreakmap/OutbreakMapScreen.kt`
  - `app/src/main/java/com/cropguard/ai/presentation/screens/community/CommunityScreen.kt`
  - `app/src/main/java/com/cropguard/ai/presentation/screens/treatmenttracker/TreatmentTrackerScreen.kt`
- Build config:
  - `app/build.gradle.kts`
  - `gradle/libs.versions.toml`

## 8) Recommended next review focus (priority)

1. Backend persistence strategy for Community/TreatmentTracker
2. OutbreakMap map-rendering requirements vs current card-based implementation
3. End-to-end UI QA matrix (small/phone/foldable/tablet, portrait/landscape, 100/130/150% font scale)
