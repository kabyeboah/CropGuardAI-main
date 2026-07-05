# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint / static analysis
flutter test             # Run all tests
flutter test test/domain/usecases/scanner/scan_crop_usecase_test.dart  # Single test file
flutter run --dart-define=GHANA_NLP_SUBSCRIPTION_KEY=your_key          # Run with secrets
```

For a release/profile build: `flutter run --release` or `flutter build apk`.

## Architecture

Clean Architecture with three layers. Dependency direction is strict: **UI → Use Cases → Repositories → Data Sources**.

```
lib/
  main.dart                    # Bootstraps Firebase, GetIt, notifications, background tasks
  app.dart                     # MaterialApp.router + theming + localization
  core/
    di/service_locator.dart    # GetIt registrations for all data sources, repos, use cases, providers
    theme/                     # AppColors, AppTheme, DeviceLayout
    utils/                     # Cross-cutting helpers (Result, AppLogger, AppBootstrap, etc.)
    error/failures.dart        # Failure types for Result propagation
    config/app_secrets.dart    # Secrets resolved from --dart-define or Remote Config
  domain/
    models/                    # Pure Dart data classes (DetectionResult, AppUser, …)
    repositories/              # Abstract interfaces (IAuthRepository, IDetectionRepository, …)
    usecases/                  # Business logic, one class per operation
  data/
    local/database_helper.dart # sqflite (SQLite) — scan history, treatment plans
    ml/crop_disease_classifier.dart  # tflite_flutter wrapper — on-device CNN inference
    remote/                    # Firebase Auth/Firestore/Storage, GhanaNLP HTTP, Cloudinary
    repositories/              # Concrete implementations of domain interfaces
  presentation/
    navigation/app_router.dart # go_router — all routes including ShellRoute for bottom nav
    components/                # Shared widgets: CropGuardCard, PrimaryButton, OfflineBanner, …
    screens/*/
      *_screen.dart            # Widget only — reads state from provider
      *_provider.dart          # ChangeNotifier — calls use cases, maps to UI state
```

State management is **Provider** (`ChangeNotifier`) registered globally in `buildProviders()` inside `service_locator.dart`. Every provider is constructed from GetIt singletons.

## Key Conventions

**Result pattern** — all fallible operations return `Result<T>` (see `lib/core/utils/result.dart`). Use `result.fold(onSuccess, onError)` in providers; never let Failures reach widgets.

**No direct data-layer access from UI** — widgets and providers must not import Firebase, sqflite, or tflite directly. All calls go through use cases.

**ML model contract** — `CropDiseaseClassifier` uses `assets/cropguard_plant_disease.tflite`, input 224×224 RGB normalised to [0,1], confidence threshold 0.60. Do not change input dimensions or normalisation without shipping a matching `.tflite` and updating `labels.txt`.

**Localization** — generated from `l10n/app_*.arb` into `lib/l10n/`. Supported locales: `en`, `tw` (Twi), `ee` (Ewe), `dag` (Dagbani). Use `AppLocalizations.of(context)!` in widgets; no hardcoded user-visible strings.

**Routing** — add new routes to `AppRouter` in `app_router.dart`. The bottom-nav shell (`ShellRoute`) wraps `/home`, `/history`, and `/more` only. Scanner and result screens are full-screen push routes.

**New Firestore collections** — update `firestore.rules` and redeploy (`firebase deploy --only firestore:rules` or via Console, see `docs/FIRESTORE_DEPLOY.md`).

**Secrets** — the only secret is `GHANA_NLP_SUBSCRIPTION_KEY`. Pass it via `--dart-define` or let `AppBootstrap` fetch it from Firebase Remote Config. Never commit real values.

**Theme** — use tokens from `AppColors` and `AppTheme`; prefer shared components from `lib/presentation/components/` before creating one-off styled widgets.

**Screen states** — every data-driven screen must handle loading, error, empty, and offline. Use `OfflineBanner` for connectivity; never show a blank screen.

## Testing

Tests live under `test/domain/usecases/`. Use `flutter_test` and `mocktail` for mocking repositories. Follow the existing pattern: mock the repository interface, inject it into the use case, assert `Result` outcomes.

