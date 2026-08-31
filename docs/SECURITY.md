# Security & Secret/API Architecture

## 1. Core Security Architecture (Flutter → Backend → Third-Party API)

For genuinely sensitive credentials (e.g. [CURRENT] [CURRENT] Gemini AI API Keys, Ghana NLP Azure Subscription Keys, Cloudinary API Secrets), CropGuard AI enforces a **zero-client-trust architecture**: [CURRENT]

```
┌─────────────────┐       Firebase Auth JWT        ┌────────────────────────┐       Server Secret        ┌───────────────────┐
│  Flutter Mobile │ ─────────────────────────────> │ Firebase Cloud Function│ ─────────────────────────> │  Third-Party API  │
│   Client App    │      + App Check Token         │    (Backend Proxy)     │   (GCP Secret Manager)     │ (Gemini/GhanaNLP) │
└─────────────────┘                                └────────────────────────┘                            └───────────────────┘
```

### Exit Gate
> **No sensitive API credential needs to be trusted merely because it is hidden behind Remote Config or `--dart-define`.** [CURRENT]

---

## 2. Review of Third-Party Credentials & Security Boundaries

### A. Gemini Cloud AI
- **Risk Profile**: High (master API key controls LLM quota, billing, and generative capabilities).
- **Hardened Architecture**: The mobile client issues authenticated callable requests (`CloudFunctionsService.analyzeCropWithGemini`) to Firebase Cloud Functions (`functions/index.js:analyzeCropWithGemini`). The backend holds `GEMINI_API_KEY` in Google Cloud Secret Manager / environment variables and enforces Firebase Auth + App Check.
- **Local Dev / Testing**: In offline or local mock environments, direct API keys provided via `.env` or `--dart-define` are supported strictly as dev fallbacks.

### B. Ghana NLP (ASR & TTS)
- **Risk Profile**: High (paid Azure APIM subscription key).
- **Hardened Architecture**: The mobile client routes voice transcription and synthesis through `CloudFunctionsService.synthesizeGhanaNlp` and `transcribeGhanaNlp`. The master `GHANA_NLP_SUBSCRIPTION_KEY` is kept server-side in Cloud Functions.

### C. Cloudinary (Media Hosting)
- **Risk Profile**: Moderate (unsigned preset).
- **Hardened Architecture**: Primary community and diagnostic scan uploads are routed through **Firebase Cloud Storage** (`FirebaseStorageService`), which is strictly authenticated, user-scoped, size-capped (< 5MB), and enforced via `storage.rules` and Firebase App Check. Cloudinary unsigned presets are retained only as secondary failover and strictly scoped in Cloudinary dashboard settings.

### D. Firebase Configuration (`firebase_options.dart`)
- **Risk Profile**: Public Client Identifiers (NOT Secrets).
- **Hardened Architecture**: Firebase mobile `apiKey`, `appId`, and `projectId` are client configuration constants by design. Protection is achieved through:
1. [CURRENT] [CURRENT] **Firebase App Check** (Play Integrity on Android, App Attest on iOS) preventing unauthorized automated access. [CURRENT]
2. [CURRENT] [CURRENT] **Firestore & Storage Security Rules** (`firestore.rules`, `storage.rules`) enforcing user-scoped read/write permissions. [CURRENT]
3. [CURRENT] [CURRENT] **GCP API Key Restrictions** restricting the Android API key by package name and SHA-256 fingerprint, and iOS API key by bundle ID. [CURRENT]

### E. Firebase Remote Config
- **Classification**: Dynamic Runtime Configuration (NOT a Secret Store).
- **Usage Policy**: Remote Config is used for feature toggles, operational thresholds (e.g. `ood_threshold = 0.60`, `model_confidence_floor = 0.70`), and deep-link URLs. Raw third-party master secrets must never be placed in Remote Config in production.

### F. Compile-Time `--dart-define`
- **Classification**: Build Configuration & Environment Flags (NOT an Encrypted Secret Store).
- **Usage Policy**: `--dart-define` compiles plain strings into binary text segments (extractable via decompilation tools). It is used for build flavors, bundle IDs, and non-sensitive constants. Master production secrets must reside in backend services.

---

## 3. Platform Hardening & Enforcement Summary
- **App Check**: Enforced via Play Integrity / App Attest (`app_bootstrap.dart`). Callable functions and database resources reject unauthorized automated requests.
- **Firestore / Storage Rules**: Default-deny, strictly user-scoped, request size limits (< 5MB / < 10MB) and MIME-type restrictions.
- **Secret Manager Provisioning**: Backend secrets are configured via:
  ```bash
  firebase functions:secrets:set GEMINI_API_KEY
  firebase functions:secrets:set GHANA_NLP_SUBSCRIPTION_KEY
  ```
- **Crashlytics**: User ID is set dynamically on auth state change for forensic error attribution.
- **Integrity Checks**: Device jailbreak/root and screen security helpers (`core/utils/`) are integrated for runtime tamper defense.
