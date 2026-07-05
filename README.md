# CropGuard AI (Flutter)

Flutter application for crop disease detection.

For a detailed technical overview of the app's components, AI engine, and architecture, see [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md).

## Getting Started

1.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

2.  **Add Firebase:**
    - Run `dart pub global activate flutterfire_cli` then `flutterfire configure` (select project `crop-guard-d36e5`) to refresh `lib/firebase_options.dart` and download platform config files.
    - Or manually place `google-services.json` (Android) in `android/app/` and `GoogleService-Info.plist` (iOS) in `ios/Runner/`.
    - `lib/firebase_options.dart` is committed with Android/iOS keys; CI must not expose secrets in public forks.

3.  **Add AI Model:**
    - Place `cropguard_plant_disease.tflite` in the `assets/` directory.

4.  **Run the app:**
    ```bash
    flutter run
    ```

## Project Structure

- `lib/core`: Theme, DI, and common utilities.
- `lib/data`: Local (sqflite), Remote (Firebase), and ML services.
- `lib/domain`: Business logic and data models.
- `lib/presentation`: UI screens and state providers.
- `assets`: ML models, labels, and static resources.

