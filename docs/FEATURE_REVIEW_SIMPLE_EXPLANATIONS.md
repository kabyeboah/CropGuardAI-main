# CropGuard AI — Feature Review with Simple Explanations

> **CropGuard AI Architecture & Capability Review**  
> **Repository Baseline**: `CropGuard AI` (Production Baseline, September 2026)  
> **Scope**: Plain-language explanation of system capabilities and honest technical limitations across all four core architectural subsystems, cross-referenced against exact codebase files and empirical evaluation benchmarks.

---

## Purpose & How to Use This Document

This document translates the verified findings from the codebase benchmarks ([docs/MODEL_ACCURACY.md](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md)) and architecture audits into simple, accessible language. 

It is designed specifically for:
1. Explaining the app clearly to non-technical stakeholders, agricultural extension officers, and developers without relying on confusing jargon.
2. Defending the engineering trade-offs honestly with zero hallucinations.

---

## System 1 — On-Device AI Disease Classification System

### What it does in simple terms:
A farmer takes a photo of a sick plant leaf using the phone's camera. The app's built-in artificial intelligence (AI) examines the photo right on the phone and predicts which disease the plant has, along with recommended organic and chemical treatments. Because the AI model is stored directly inside the phone, this entire process works instantly and requires zero internet connection.

### Main limitations — explained simply:

1. **Real-world accuracy is much lower than computer training lab numbers.**  
   * **In simple terms**: When the AI was trained on a computer with clean, artificial datasets, it scored **63.9%** validation accuracy (and a training export file recorded **62.7%**). However, when tested on **real field photographs from Ghanaian farms** ([docs/MODEL_ACCURACY.md:14](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md#L14)), the real-world accuracy drops to **25.5% Top-1** (the AI gets the exact right disease on its very first guess about 1 out of 4 times) and **49.0% Top-3** (the correct disease is in its top three guesses about half the time). The AI frequently gets confused by real farm backgrounds, soil, varying sunlight, and shadows.
   * *Codebase anchor*: [docs/MODEL_ACCURACY.md:14-22](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md#L14-L22), [VERIFICATION_REPORT.md:14](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/VERIFICATION_REPORT.md#L14), [tools/evaluate_model.py:539](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/tools/evaluate_model.py#L539).

2. **Diseases with similar-looking symptoms cause near-miss confusion.**  
   * **In simple terms**: Certain plant diseases produce visual symptoms that look almost identical in a photo. For example, Rice Leaf Scald and Rice Sheath Blight, or Cassava Mosaic Disease and Cassava Bacterial Blight, both show similar leaf yellowing and brown spots. The AI frequently confuses these sister conditions on the same crop.
   * *Codebase anchor*: [docs/MODEL_ACCURACY.md:68-71](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md#L68-L71).

3. **There is no separate AI filter dedicated solely to rejecting non-plant photos.**  
   * **In simple terms**: To keep the app download small, the app does not bundle a second AI model just to check "is this actually a leaf?" The gate that passes images to the AI accepts all pictures ([lib/data/ml/ood_gate.dart:34-41](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/ood_gate.dart#L34-L41)). The app protects against this by checking image lighting/blur ([lib/core/utils/image_quality_analyzer.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/image_quality_analyzer.dart)) and by rejecting low-confidence scans below 60%. But if someone points the camera at a green non-plant object (like green cloth or a green plastic bucket) and the AI happens to score over 60%, it will still attempt to name a plant disease.
   * *Codebase anchor*: [lib/data/ml/ood_gate.dart:34-41](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/ood_gate.dart#L34-L41), [lib/data/ml/crop_disease_classifier.dart:153-159](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L153-L159).

4. **The confidence percentages on screen can appear inconsistent to farmers.**  
   * **In simple terms**: When nearby disease reports exist, the app boosts the percentage score of certain suspected diseases (for example, adding +15% if an outbreak is active nearby). However, the main overall confidence score banner at the top of the screen does not include this bonus. As a result, a farmer might see individual disease candidate percentages that seem mathematically mismatched with the primary score card.
   * *Codebase anchor*: [lib/presentation/screens/result/low_confidence_screen.dart:88-118](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/result/low_confidence_screen.dart#L88-L118), [lib/core/utils/risk_weighted_classifier.dart:40-69](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/risk_weighted_classifier.dart#L40-L69).

5. **One single AI model attempts to recognize 51 diseases across many different crops.**  
   * **In simple terms**: Rather than having a specialist AI for maize, another for cassava, and another for cocoa, one single generalist model is tasked with handling all 51 disease categories across 8+ different crops simultaneously. A single generalist model has a harder time achieving expert accuracy across all crops than dedicated, crop-specific models.
   * *Codebase anchor*: [lib/data/ml/crop_disease_classifier.dart:337](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L337), [assets/model_metadata.json](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/assets/model_metadata.json).

### Easy way to explain the main weakness:
> *"The phone AI is fast, completely free to use, and works without internet, but it is not yet accurate enough for autonomous field diagnosis (25.5% Top-1 field accuracy). Because it covers 51 diseases across many crops in one compact model and lacks a dedicated non-plant filter, it requires our built-in safety gates: a 60% confidence threshold, multi-angle scanning, and a second-opinion cloud fallback."*

---

## System 2 — Cloud AI Fallback System (Gemini Multimodal Diagnosis)

### What it does in simple terms:
When the phone AI is unsure of its diagnosis (confidence falls below 60%), the app does not guess blindly. Instead, it invites the farmer to request a "Second Opinion." The app securely transmits the leaf photo to Google's cloud AI (**Gemini 3 Flash**), which acts as a virtual plant doctor. Gemini analyzes the leaf symptoms, explains the root causes, and returns structured organic and chemical treatment advice.

### Main limitations — explained simply:

1. **Requires stable internet connectivity, which is scarce on remote farms.**  
   * **In simple terms**: The cloud fallback is a secondary safety net, but smallholder farms in rural Ghana often have weak or non-existent cellular coverage. If a farmer has no internet connection, the cloud AI cannot be reached, and the farmer must rely solely on the on-device preliminary results and local extension officer contacts.
   * *Codebase anchor*: [lib/data/remote/gemini_cloud_ai_service.dart:57-61](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/gemini_cloud_ai_service.dart#L57-L61).

2. **Cloud analysis takes several seconds and can be delayed by network retries.**  
   * **In simple terms**: While the on-device model diagnoses a leaf in under 120 milliseconds, sending high-resolution photo bytes to Gemini over the internet typically takes **4 to 7 seconds** (median ~5.4 seconds). If the cellular connection stutters, the app automatically retries up to 3 times ([lib/data/remote/cloud_functions_service.dart:67-73](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/cloud_functions_service.dart#L67-L73)), which can cause the user to wait up to 20 seconds before receiving a result or a timeout message.
   * *Codebase anchor*: [lib/data/remote/cloud_functions_service.dart:67-73](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/cloud_functions_service.dart#L67-L73), [VERIFICATION_REPORT.md:86-91](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/VERIFICATION_REPORT.md#L86-L91).

3. **Third-party API quotas and commercial running costs.**  
   * **In simple terms**: Every time a photo is sent to Gemini, it consumes cloud computing quota. While the current prototype runs on developer quota, scaling the app to thousands of smallholder farmers would require ongoing funding or a paid Google Cloud billing account to prevent hitting rate limits (HTTP 429).
   * *Codebase anchor*: [supabase/functions/analyze-crop/index.ts:46-52](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/functions/analyze-crop/index.ts#L46-L52), [VERIFICATION_REPORT.md:60](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/VERIFICATION_REPORT.md#L60).

4. **Historical defect now resolved: The Firebase-to-Supabase authentication mismatch has been fixed.**  
   * **In simple terms**: An earlier version of the project had an architectural defect where the app logged in with Supabase but the cloud function expected a Firebase login key—meaning the cloud backup failed unless an insecure key was stored on the phone. **This has now been completely resolved.** The backend was ported to a **Supabase Edge Function** (`analyze-crop`), and the app uses a **Zero-Secret client architecture** where the master Gemini key is stored securely on the server, never on the phone.
   * *Codebase anchor*: [supabase/functions/analyze-crop/index.ts:23-35](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/functions/analyze-crop/index.ts#L23-L35), [lib/data/remote/cloud_functions_service.dart:27-62](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/cloud_functions_service.dart#L27-L62).

### Easy way to explain the main weakness:
> *"The Gemini cloud AI provides an exceptional, highly intelligent second opinion with deep pathology explanations, but it cannot replace the on-device AI because it requires cellular internet and takes several seconds to respond. It serves as an essential safety net when connectivity allows."*

---

## System 3 — Authentication & Backend Data System

### What it does in simple terms:
This system manages user accounts, farmer profiles, saved scan history, community discussion posts, and server-side operations. It also ensures that records created while a farmer is working offline in the field are safely saved on the phone and automatically synced to the cloud once an internet connection is detected.

### Main limitations — explained simply:

1. **Dual-database synchronization complexity (Phone SQLite vs Cloud PostgreSQL).**  
   * **In simple terms**: To guarantee that farmers never lose data offline, the phone saves scans immediately into an on-device database (SQLite). When offline, scans wait in a `pending_sync` queue. While this offline-first design works smoothly, maintaining two copies of the database (one on the phone, one in the Supabase cloud) requires careful conflict handling to ensure records don't get overwritten or synced out of order.
   * *Codebase anchor*: [lib/data/local/database_helper.dart:18-22](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/local/database_helper.dart#L18-L22), [lib/data/local/pending_sync_queue.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/local/pending_sync_queue.dart).

2. **Community interaction and cloud backup cannot happen offline.**  
   * **In simple terms**: Offline-first applies strictly to personal scanning, local history, and local treatment advice. A farmer cannot view new community forum posts, submit a question to other farmers, or view live outbreak maps until they reconnect to a mobile data network or Wi-Fi.
   * *Codebase anchor*: [lib/presentation/screens/community/community_provider.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/community/community_provider.dart), [lib/presentation/screens/outbreak_map/outbreak_map_screen.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/outbreak_map/outbreak_map_screen.dart).

3. **Background notifications rely on periodic polling rather than instant push daemons.**  
   * **In simple terms**: Because Firebase Cloud Messaging (FCM) was completely removed to achieve a clean, single-backend architecture, the app does not maintain an active persistent background push daemon. Instead, on Android it uses WorkManager to periodically wake up (every 15+ minutes) and check for nearby outbreaks, triggering local notifications. This is very battery- and data-efficient for rural phones, but means outbreak alerts are not received instantaneously the second an outbreak is posted.
   * *Codebase anchor*: [lib/core/utils/outbreak_alert_service.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/outbreak_alert_service.dart), [lib/core/utils/background_tasks.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/background_tasks.dart).

4. **Historical defect now resolved: The dual Firebase/Supabase backend split is eliminated.**  
   * **In simple terms**: Earlier project notes cited confusing overlap where Firebase and Supabase were running simultaneously. **The codebase has now completed a 100% migration to Supabase.** All Firebase dependencies, configuration files, and services (Remote Config, Crashlytics, Analytics, App Check, Cloud Functions) were completely uninstalled. The app now operates cleanly on a single unified Supabase backend (Supabase Auth, PostgreSQL with Row Level Security, and Deno Edge Functions).
   * *Codebase anchor*: [pubspec.yaml:19-21](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/pubspec.yaml#L19-L21), [supabase/migrations/0001_schema.sql:1-198](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/migrations/0001_schema.sql#L1-L198), Commit `a840a2a` (*feat: complete Supabase migration and safe removal of Firebase*).

### Easy way to explain the main weakness:
> *"The backend is now unified cleanly on Supabase, and its offline SQLite sync queue protects farmers from losing scan records. However, two-way community interactions and remote data backups still require mobile internet, and background alert checking operates on a periodic schedule rather than instant push notifications."*

---

## System 4 — Community, Outbreak Reporting & Regional Risk System

### What it does in simple terms:
This system allows farmers and agricultural officers to report confirmed crop disease outbreaks on an interactive regional map. The app combines these community outbreak reports with 7-day weather forecasts (temperature, rain, and humidity) to calculate an early warning risk level (Low, Moderate, High) for specific crop diseases in the farmer's district.

### Main limitations — explained simply:

1. **Risk adjustments use simple additive bonus points rather than proven statistical equations.**  
   * **In simple terms**: When the system detects a nearby disease report or humid weather, it simply adds fixed bonus points to a disease's probability score (such as `+0.15` for high weather risk, `+0.08` for moderate risk, and `+0.10` for a nearby outbreak). These points were chosen as practical engineering estimates rather than being calculated from a mathematically proven biological or epidemiological formula.
   * *Codebase anchor*: [lib/core/utils/risk_weighted_classifier.dart:46-54](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/risk_weighted_classifier.dart#L46-L54), [lib/data/repositories/risk_repository_impl.dart:141-158](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/repositories/risk_repository_impl.dart#L141-L158).

2. **No mandatory physical verification or extension officer sign-off for outbreak reports.**  
   * **In simple terms**: Any registered user can submit an outbreak report from their phone. While the app provides a community verification system where other farmers can tap "Confirm" or "Refute," there is no requirement for biological proof or formal validation by an accredited Ministry of Food and Agriculture (MoFA) / PPRSD extension officer before a report appears on the map. A mistaken diagnosis by an untrained user could therefore artificially elevate the disease risk score for neighboring farms.
   * *Codebase anchor*: [supabase/migrations/0001_schema.sql:61-76](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/migrations/0001_schema.sql#L61-L76), [lib/data/remote/cloud_functions_service.dart:99-110](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/cloud_functions_service.dart#L99-L110).

3. **GPS location fuzzing balances farmer privacy against map precision.**  
   * **In simple terms**: To prevent exposing the exact physical coordinates of individual smallholder farms, the app intentionally blurs (fuzzes) the farmer's GPS coordinates within an approximate 1 km radius before uploading the report. This protects farmer privacy and property, but it means the outbreak map shows general neighborhood hotspots rather than exact pinpoint farm locations.
   * *Codebase anchor*: [lib/core/utils/location_privacy.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/location_privacy.dart).

4. **Community reporting and live map viewing require an internet connection.**  
   * **In simple terms**: While previously saved risk alerts remain readable offline, discovering new outbreak reports submitted by other farmers and browsing the interactive map tiles require cellular data. In deep rural areas with zero network reception, farmers cannot receive real-time community updates.
   * *Codebase anchor*: [lib/presentation/screens/outbreak_map/outbreak_map_screen.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/outbreak_map/outbreak_map_screen.dart), [lib/core/utils/outbreak_alert_service.dart:45-55](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/outbreak_alert_service.dart#L45-L55).

### Easy way to explain the main weakness:
> *"The regional outbreak and risk system provides an innovative early warning tool for farming communities, but the risk bonus scores are rule-based estimates rather than complex biological simulations, and the system relies on crowdsourced honesty since reports are not pre-certified by government agricultural extension officers."*

---

## Overall Simple Summary of the Four Systems

| System | Primary Function | Works Offline? | Key Strength | Main Verified Limitation |
|---|---|:---:|---|---|
| **System 1: On-Device AI** | Instant leaf disease classification | **Yes (100%)** | Sub-120ms latency, zero mobile data cost, private. | Real field accuracy is **25.5% Top-1**; domain shift from real farm backgrounds causes near-misses. |
| **System 2: Cloud AI Fallback** | Second-opinion multimodal diagnosis | **No (Online)** | Deep visual reasoning by **Gemini 3 Flash**, comprehensive remedy explanations. | Requires cellular data; takes **4–7 seconds** to analyze image bytes over the network. |
| **System 3: Auth & Backend Data** | User profiles, history, and offline sync | **Hybrid (Queue)** | SQLite FIFO queue guarantees zero data loss when offline; unified on **Supabase**. | Background outbreak checking uses scheduled polling (15+ min) rather than instant push daemons. |
| **System 4: Outbreak & Regional Risk** | Spatial surveillance & weather-based risk | **No (Online)** | Connects local weather patterns with disease risk; GPS fuzzing protects privacy. | Risk points (+0.15, +0.08) are heuristic estimates; reports rely on community voting without mandatory official verification. |

### The "Bottom Line" Explanation:
CropGuard AI is built around a pragmatic, real-world engineering compromise designed specifically for Ghanaian agriculture:
1. **The phone AI does the heavy lifting in remote fields without internet**, providing instant, data-free triage even though its accuracy is moderate (~25.5% field Top-1, ~49% Top-3).
2. **Safety barriers (a strict 60% confidence gate, image quality checks, and multi-angle capture)** prevent the phone AI from making wild guesses.
3. **When network connectivity is available, the cloud AI (Gemini 3 Flash) provides a master-level second opinion**, while Supabase automatically syncs scan history, local language voice notes, and regional outbreak alerts.
4. **The project previously suffered from an awkward split between Firebase and Supabase, but that has now been completely resolved** by unifying the entire stack onto Supabase with zero secrets stored on client devices.

---

## Technical Audit Anchor & Evidence Chain

Every statement in this review reflects the true state of HEAD in repository `kabyeboah/CropGuardAI-main`:

- **Model Benchmark & Field Test Truth**: [docs/MODEL_ACCURACY.md:14-25](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md#L14-L25), [VERIFICATION_REPORT.md:10-18](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/VERIFICATION_REPORT.md#L10-L18).
- **Gemini Model Constant (`gemini-3-flash-preview`)**: [lib/data/remote/gemini_cloud_ai_service.dart:28](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/remote/gemini_cloud_ai_service.dart#L28), [supabase/functions/analyze-crop/index.ts:80](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/functions/analyze-crop/index.ts#L80).
- **OOD Gate Implementation**: [lib/data/ml/ood_gate.dart:34-41](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/ood_gate.dart#L34-L41).
- **Risk Weight Additions (+0.15, +0.08, +0.10)**: [lib/core/utils/risk_weighted_classifier.dart:46-54](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/core/utils/risk_weighted_classifier.dart#L46-L54), [lib/data/repositories/risk_repository_impl.dart:141-158](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/repositories/risk_repository_impl.dart#L141-L158).
- **Supabase Backend Schema & RLS**: [supabase/migrations/0001_schema.sql:1-198](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/supabase/migrations/0001_schema.sql#L1-L198).
- **Zero Firebase Dependencies**: [pubspec.yaml:9-80](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/pubspec.yaml#L9-L80), Git Commit `a840a2a7105f367deec58a2708f8f858c914aab3`.
- **Test Suite Pass Rate**: 629 of 629 tests passing ([VERIFICATION_REPORT.md:17](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/VERIFICATION_REPORT.md#L17)).
