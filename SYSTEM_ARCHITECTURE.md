# CropGuard AI: Technical Architecture & Development Documentation (Flutter)

This document provides a technical overview of the CropGuard AI Flutter application, reflecting its current production-grade implementation. [CURRENT]

---

## 🏗️ Architecture Overview

The application follows a strict **Clean Architecture** structure combined with **Provider** for state management and **GetIt** for dependency injection. [CURRENT]

### 1. Layers & Dependency Flow
- **Domain Layer**: The core of the application.
    - **Models**: Plain Dart objects (`DetectionResult`, `AppUser`, `CommunityPost`).
    - **Repositories (Interfaces)**: Abstract definitions of data operations (`IAuthRepository`, `IDetectionRepository`).
    - **Use Cases**: Encapsulated business logic (`ScanCropUseCase`, `LoginUseCase`). Use cases orchestrate multiple repositories and ensure business rules are followed.
- **Data Layer**: Implementation details.
    - **Repositories (Implementations)**: Concrete implementations that wrap data sources.
    - **Data Sources**: Low-level services like **sqflite** (SQLite), **Firebase Auth**, **Cloud Firestore**, and **tflite_flutter**.
- **Presentation Layer**: UI logic.
    - **Providers (MVVM)**: `ChangeNotifier` classes that hold UI state and interact exclusively with **Use Cases**.
    - **Widgets**: Reusable UI components and feature screens.

### 2. Implementation Strategies
- **Decoupling**: The UI never interacts directly with Firebase or the Database. All calls go through Use Cases.
- **Error Handling**: A unified `Result` pattern is used to propagate `Failure` objects from the data layer to the UI.
- **Data Integrity**: Database operations utilize SQLite transactions to ensure consistency.
- **Offline Capability**: Core functionality, including AI inference and local history, is 100% functional without an internet connection.

---

## 🧠 AI Model & Inference

CropGuard AI utilizes a Convolutional Neural Network (CNN) based on the **MobileNetV2** architecture. [CURRENT]

### 1. Model Specifications
- **Architecture**: MobileNetV2 with Transfer Learning.
- **Inference Engine**: tflite_flutter.
- **Input Dimensions**: 224x224x3 (RGB).
- **Confidence Threshold**: Results below **0.60** trigger a "Low Confidence" warning.

### 2. Real-Time Analysis
- **Image Quality**: `ImageQualityAnalyzer` checks for blur and lighting before proceeding with inference.
- **Severity Mapping**: Use Cases determine disease severity (Early, Moderate, Severe) based on model confidence and diagnosis.

---

## ⚙️ Security & Privacy

- **On-Device Processing**: AI inference happens entirely on-device via TensorFlow Lite. Leaf scan images are not uploaded to third-party cloud servers without explicit user actions.
- **Location Privacy & Coarsening**:
  - Exact GPS coordinates are coarsened/rounded to 2 decimal places (~1.1 km grid resolution) using `LocationHelper.coarsen()`.
  - Crowd-sourced outbreak reports and weather queries only transmit and persist coarsened coordinates, protecting farm field boundaries, homesteads, and farmer privacy from public exposure.
- **OpenStreetMap & Nominatim Compliance**:
  - **OSM Tiles**: Cached to disk via `CachedTileProvider` / `flutter_cache_manager` (30-day stale period, 3000 objects) to minimize server load and enable offline mapping. Injects compliant User-Agent headers (`AppSecrets.osmUserAgent`).
  - **Nominatim Geocoding**: Rate-limited to max 1 request/second via `NominatimService`, identifies with compliant project contact User-Agent, and caches coordinate-bucket reverse lookups in memory and `SharedPreferences`.
- **Data Retention & User Controls**:
  - Scans are persisted locally in SQLite.
  - Users can clear local scan history at any time from Settings or initiate full cloud account deletion via Cloud Functions (`deleteUserData`).
- **Screen Security**: `ScreenSecurityHelper` prevents screenshots on sensitive pages.
- **Root & Tamper Detection**: `RootDetectionHelper` checks for device integrity.

---

## 🧪 Testing & Validation

The project utilizes a multi-tiered testing approach: [CURRENT]
1. [CURRENT] **Unit Tests**: Verifying Use Cases, Repositories, Services, and Utilities. [CURRENT]
2. [CURRENT] **Widget Tests**: Testing UI components and screens in isolation. [CURRENT]
3. [CURRENT] **Integration & E2E Tests**: End-to-end user and diagnostic flows. [CURRENT]

---
*Document Version: 3.1 (Maps, Location & Privacy Hardening Complete)*
