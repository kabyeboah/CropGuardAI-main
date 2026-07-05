# CropGuard AI: Technical Architecture & Development Documentation (Flutter)

This document provides a technical overview of the CropGuard AI Flutter application, reflecting its current production-grade implementation.

---

## 🏗️ Architecture Overview

The application follows a strict **Clean Architecture** structure combined with **Provider** for state management and **GetIt** for dependency injection.

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

CropGuard AI utilizes a Convolutional Neural Network (CNN) based on the **MobileNetV2** architecture.

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

- **On-Device Processing**: AI inference happens entirely on-device. Images are not uploaded to the cloud for analysis.
- **Screen Security**: `ScreenSecurityHelper` prevents screenshots on sensitive pages.
- **Root Detection**: `RootDetectionHelper` checks for device integrity.

---

## 🧪 Testing & Validation

The project utilizes a multi-tiered testing approach:
1. **Unit Tests**: Verifying Use Cases and Repository logic.
2. **Widget Tests**: Testing UI components in isolation.
3. **Integration Tests**: End-to-end flows.

---
*Document Version: 3.0 (Architecture Hardening Complete)*
