# CropGuard AI — Formal Data Retention & Privacy Lifecycle Policy

**Version:** 1.0.0 (Production / Scale-Tier Governance)  
**Last Updated:** August 2026  
**Compliance Standard:** GDPR (General Data Protection Regulation), CCPA, ISO/IEC 27001 Data Minimization Principles  

---

## 1. Executive Summary & Purpose

CropGuard AI is committed to respecting user privacy, data sovereignty, and agricultural intelligence confidentiality. This document outlines the formal retention, archiving, anonymization, and deletion policies for all data managed by the CropGuard AI platform across mobile clients, local SQLite databases, Firebase Cloud Firestore, Firebase Storage, and Cloud Functions.

---

## 2. Data Retention Schedule

| Data Category | Data Elements | Storage Location | Active Retention | Retention Trigger / Deletion Action | Anonymization Policy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **User Profile & Account** | Name, Email, Phone, Preferred Language, Auth UID | Firestore (`/users/{uid}`) & Firebase Auth | Duration of active account + 30 days grace | Account deletion request by user or 24 months inactivity | Complete purge via `onUserDeleted` Cloud Function |
| **Diagnostic Scans & Images** | Leaf photos, disease diagnosis, confidence score, timestamps | Firebase Storage (`scans/{uid}/*`) & Firestore (`/scans/*`) | 12 months from scan creation | Automated purge upon user account deletion or manual user scan delete | Images & scan metadata permanently deleted |
| **Local Device Cache** | Offline scans, pending sync queue, SQLite database | On-device SQLite (`cropguard.db`) & SharedPreferences | 30 days max offline cache | Explicit app sign-out, "Clear Local Data" trigger, or app uninstall | Local database destroyed on device |
| **Outbreak Reports & Telemetry** | Disease type, geohash, severity, confidence score, reporter ID | Firestore (`/outbreak_reports/*`) | Permanent (epidemiological dataset) | Account deletion scrubs `userId` and PII notes | `userId` replaced with `"deleted_user"`; reporter name set to `"Anonymous"`; personal notes scrubbed |
| **Notification Tokens** | FCM Device Tokens, platform push topics | Firestore (`/users/{uid}/fcmToken`) & Firebase Messaging | Active session | Invalidated token refresh, sign-out, or user deletion | Token record permanently deleted |
| **Analytics & Crash Diagnostics** | Crash logs, performance metrics, feature usage | Firebase Crashlytics & Analytics (opt-in) | 90 days rolling window | Automatically purged by Firebase backend after 90 days | Fully anonymized aggregated metrics |

---

## 3. Account Closure & Data Deletion Mechanisms

CropGuard AI provides a multi-tiered data deletion architecture ensuring immediate user privacy protection while maintaining scalability:

### 3.1 Pilot-Tier Client-Side Purge
When a user requests account deletion from the app settings screen (`SettingsScreen`):
1. **Local Cleanup:** Immediate erasure of all SQLite database records (`cropguard.db`), cached images, and local key-value stores.
2. **Auth Deletion:** Firebase Auth user record is revoked and deleted.

### 3.2 Scale-Tier Server-Side Cascade Delete (`onUserDeleted`)
For enterprise and public-scale deployments, account deletion triggers the `onUserDeleted` serverless Cloud Function (`functions/index.js`), executing the following atomic actions:
- **Profile Purge:** Recursively deletes `/users/{userId}` document and all subcollections.
- **Top-Level Data Purge:** Batch deletes user-owned documents in `/scans`, `/treatments`, `/community_posts`, `/feedback`, `/expert_requests`, and `/missing_crops`.
- **Cloud Storage Purge:** Deletes all uploaded images under `scans/{userId}/*` and `users/{userId}/*`.
- **Public Health Anonymization:** Converts user-submitted `outbreak_reports` to anonymous records (scrubbing PII while preserving regional crop disease tracking data for community protection).

---

## 4. Geo-Spatial Privacy & Outbreak Telemetry

To protect smallholder farm privacy and prevent location pinpointing of specific properties:
1. **Geohashing:** Exact GPS coordinates are converted into low-precision geohashes (approx. 1km² radius) for regional outbreak mapping.
2. **Data Minimization:** Specific farm boundary details or owner contact numbers are never stored in public outbreak telemetry documents.

---

## 5. Security & Access Governance

1. **Firestore Security Rules:** Access is strictly bounded by `request.auth.uid == userId` for personal data paths.
2. **Transport Security:** All client-to-cloud telemetry uses TLS 1.3 encryption with certificate pinning (`CERT_PIN_ROTATION.md`).
3. **Data Access:** End-to-end audit logging tracks administrator access to support requests or expert escalations.
