# CropGuard AI — Formal Data Retention & Privacy Lifecycle Policy

**Version:** 1.0.0 (Production / Scale-Tier Governance)  
**Last Updated:** August 2026  
**Compliance Standard:** GDPR (General Data Protection Regulation), CCPA, ISO/IEC 27001 Data Minimization Principles  

---

## 1. Executive Summary & Purpose

CropGuard AI is committed to respecting user privacy, data sovereignty, and agricultural intelligence confidentiality. [CURRENT] [CURRENT] This document outlines the formal retention, archiving, anonymization, and deletion policies for all data managed by the CropGuard AI platform across mobile clients, local SQLite databases, Supabase PostgreSQL, Supabase Storage, and Supabase Edge Functions. [CURRENT]

---

## 2. Data Retention Schedule

| Data Category | Data Elements | Storage Location | Active Retention | Retention Trigger / Deletion Action | Anonymization Policy | [CURRENT]
| :--- | :--- | :--- | :--- | :--- | :--- | [CURRENT]
| **User Profile & Account** | Name, Email, Phone, Preferred Language, Auth UID | Supabase `profiles` & Supabase Auth | Duration of active account + 30 days grace | Account deletion request by user or 24 months inactivity | Complete purge via `delete-account` Edge Function | [CURRENT]
| **Diagnostic Scans & Images** | Leaf photos, disease diagnosis, confidence score, timestamps | Supabase Storage (`scan-images/{uid}/*`) & `scans` table | 12 months from scan creation | Automated purge upon user account deletion or manual user scan delete | Images & scan metadata permanently deleted | [CURRENT]
| **Local Device Cache** | Offline scans, pending sync queue, SQLite database | On-device SQLite (`cropguard.db`) & SharedPreferences | 30 days max offline cache | Explicit app sign-out, "Clear Local Data" trigger, or app uninstall | Local database destroyed on device | [CURRENT]
| **Outbreak Reports & Telemetry** | Disease type, geohash, severity, confidence score, reporter ID | Supabase `outbreak_reports` | Permanent (epidemiological dataset) | Account deletion scrubs `userId` and PII notes | `userId` set to NULL / anonymous; personal notes scrubbed | [CURRENT]
| **Notification Tokens** | Push Device Tokens, platform push topics | Supabase `profiles` / device tokens | Active session | Invalidated token refresh, sign-out, or user deletion | Token record permanently deleted | [CURRENT]
| **Diagnostics & Telemetry** | Diagnostic logs, performance metrics, feature usage | App diagnostics (opt-in) | 90 days rolling window | Automatically purged after 90 days | Fully anonymized aggregated metrics | [CURRENT]

---

## 3. Account Closure & Data Deletion Mechanisms

CropGuard AI provides a multi-tiered data deletion architecture ensuring immediate user privacy protection while maintaining scalability: [CURRENT]

### 3.1 Client-Side Purge
When a user requests account deletion from the app settings screen (`SettingsScreen`): [CURRENT]
1. [CURRENT] [CURRENT] **Local Cleanup:** Immediate erasure of all SQLite database records (`cropguard.db`), cached images, and local key-value stores. [CURRENT]
2. [CURRENT] [CURRENT] **Auth Deletion:** Supabase Auth user record is revoked and deleted. [CURRENT]

### 3.2 Server-Side Cascade Delete (`delete-account` Edge Function)
Account deletion triggers the `delete-account` serverless Supabase Edge Function (`supabase/functions/delete-account`), executing the following atomic actions: [CURRENT]
- **Profile Purge:** Deletes row from `profiles` table and triggers database foreign key cascades.
- **Data Purge:** Cascading deletion of user-owned records in `scans`, `treatment_records`, `community_posts`, `feedback`, `expert_requests`, and `missing_crops`.
- **Storage Purge:** Deletes all uploaded images in user-scoped folders.
- **Public Health Anonymization:** Converts user-submitted `outbreak_reports` to anonymous records (scrubbing PII while preserving regional crop disease tracking data for community protection).

---

## 4. Geo-Spatial Privacy & Outbreak Telemetry

To protect smallholder farm privacy and prevent location pinpointing of specific properties: [HISTORICAL]
1. [CURRENT] [CURRENT] **Geohashing:** Exact GPS coordinates are converted into low-precision geohashes (approx. [CURRENT] 1km² radius) for regional outbreak mapping. [CURRENT]
2. [CURRENT] [CURRENT] **Data Minimization:** Specific farm boundary details or owner contact numbers are never stored in public outbreak telemetry documents. [CURRENT]

---

## 5. Security & Access Governance

1. [CURRENT] [CURRENT] **Firestore Security Rules:** Access is strictly bounded by `request.auth.uid == userId` for personal data paths. [CURRENT]
2. [CURRENT] [CURRENT] **Transport Security:** All client-to-cloud telemetry uses TLS 1.3 encryption with certificate pinning (`CERT_PIN_ROTATION.md`). [CURRENT]
3. [CURRENT] [CURRENT] **Data Access:** End-to-end audit logging tracks administrator access to support requests or expert escalations. [CURRENT]
