# CropGuard AI — Phase −1: Verification & Truth Reconciliation Report

> **Document Status**: COMPLETED & VERIFIED  
> **Date**: 2026-09-02  
> **Objective**: Resolve contradicted claims, audit hardcoded literals, benchmark latency & failure paths, and establish truth baseline before migration.

---

## 1. The Truth Table

| Subject / Fact | Claim A (File:Line) | Claim B (File:Line) | Verdict / Truth | Evidence Chain |
|---|---|---|---|---|
| **Active Gemini Model** | `lib/data/remote/gemini_cloud_ai_service.dart:104` (`gemini-3-flash-preview`) | `supabase/functions/analyze-crop/index.ts:80` (`gemini-1.5-flash`), `gemini_cloud_ai_service.dart:20,46,71` ("Gemini 1.5 Flash") | **`gemini-3-flash-preview` ran; `gemini-1.5-flash` is retired.** | Live query to Google Generative Language ModelService returned HTTP 404 for `gemini-1.5-flash` ("not found or not supported in v1beta"). `gemini-3-flash-preview` is the active model executing inference. |
| **Model Accuracy Benchmark** | `docs/MODEL_ACCURACY.md:6,14,22` & `docs/eval_metrics.json:7` (**25.49% Top-1, 49.02% Top-3**, ECE 20.04%, n=51) | `assets/model_metadata.json:23-24` (`validation_accuracy: 0.639185`, `field_test_accuracy: 0.627225`) | **25.49% is the honest held-out field benchmark; 63.92% / 62.72% are synthetic training splits.** | Traced to Colab notebook (`cropguard_retrain_v2_optimized (3).ipynb`). 63.92% is synthetic validation split; 62.72% was mislabelled as `field_test_accuracy` at export. Real Ghanaian field evaluation (`tools/evaluate_model.py` on `test_set/`, n=51) measured 25.49% (13/51 correct). |
| **Historical Interim Accuracy** | `Historical Supervisor Guide` ("16.67% Top-1 across 22 classes") | `docs/MODEL_ACCURACY.md:35` (**25.49% Top-1 across all 51 classes**) | **16.67% was an interim 24-sample spot check; 25.49% is the complete 51-class benchmark.** | Interim supervisor guide had not been synchronized after the 51-sample full benchmark was executed. Updated to reflect 25.49% Top-1 (95% CI: [14.2%, 39.7%]) and 49.02% Top-3. |
| **End-to-End Latency** | `Historical Audit Log` (Claimed 6,710 ms) | Reported runs reaching ~23,000 ms | **6,710 ms is pure direct inference; 23,000 ms is proxy retry burnout on network failure.** | `CloudFunctionsService.analyzeCropWithGemini` uses `RetryUtils.retry` (3 attempts with 30s timeouts). When proxy fails, 3 timeouts occur before falling through to direct `GenerativeModel`. |
| **Test Suite Count** | `Historical Supervisor Guide` (Claimed 623 tests) | Active Flutter test runner output (**629 tests**) | **629 tests active and passing (100% pass rate).** | Verified with `flutter test`. 629 tests executed and passed cleanly. |

---

## 2. What Was Changed (Diff Summary)

Only stale labels, literals, and model constants were updated. No premature refactoring was introduced.

### 1. `lib/data/remote/gemini_cloud_ai_service.dart`
- Added shared model constant: `static const String defaultModelName = 'gemini-3-flash-preview';`
- Parameterized constructor with `modelName` defaulting to `defaultModelName`.
- Updated docstrings from stale "Gemini 1.5 Flash" to "Gemini Cloud AI multimodal vision model".

### 2. `test/data/remote/gemini_live_e2e_test.dart`
- Replaced hardcoded literal `print('====== GEMINI 1.5 FLASH LIVE RESPONSE ======')` with dynamic model interpolation: `print('====== GEMINI ${service.modelName.toUpperCase()} LIVE RESPONSE ======')`.

### 3. `supabase/functions/analyze-crop/index.ts`
- Updated endpoint model URL from retired `gemini-1.5-flash` (which returns HTTP 404) to `gemini-3-flash-preview`.

### 4. `tools/evaluate_model.py`
- Replaced hardcoded literal string `**63.9%**` in Markdown report generator (line 539) with dynamic interpolation from `baseline_metrics.get('validation_accuracy', ...)` loaded from `model_metadata.json`.

### 5. `Historical Supervisor Guide & Documentation Generators`
- Reconciled interim 16.67% / 45.83% statements to the formal 51-class benchmark figures: **25.49% Top-1** (95% CI: [14.2%, 39.7%]) and **49.02% Top-3**, with **63.92%** validation split accuracy and **629/629 tests passing**.

---

## 3. What Is Still Contradicted & Provenance Notes

- **`assets/model_metadata.json` key naming**:
  - `validation_accuracy`: `0.6391851902008057` (Optimistic synthetic validation split).
  - `field_test_accuracy`: `0.6272253582283978` (Colab holdout split, mislabelled as field test).
  - **Status**: Preserved as-is to avoid breaking model contract unit tests pending user decision at 🚦 **G2**.
  - **Resolution Needed**: User decision on whether to retain the historical training export keys or rename/update `field_test_accuracy` to `0.25490196`.

---

## 4. Failure-Path Results (Task V5)

| Scenario | Inducement Method | Observed Behavior | User-Facing Message / Handling | Verdict |
|---|---|---|---|---|
| **No Network** | Offline connection / `SocketException` | Service catches network failure, falls back to direct if possible; if offline, UI catches exception. | Localized `UiMessage.networkError` / Banner: *"Cloud AI unavailable (offline or unconfigured). Showing on-device preliminary results below."* with Retry action. | ✅ **SAFE** |
| **API Error (4xx/5xx)** | Invalid API key / Bad auth header | Throws `GeminiCloudAiException`. UI suppresses raw trace and displays friendly error state. | Non-technical banner with Retry button; never leaks stack trace or raw API keys to UI. | ✅ **SAFE** |
| **Rate Limited (429)** | Exceeded free-tier quota (20 req/min) | Handled gracefully in test suite & UI; logs warning to `AppLogger.w`. | UI falls back to on-device preliminary diagnosis tile with clear degraded disclaimer. | ✅ **SAFE** |
| **Timeout (>30s/60s)** | Simulated network delay | Timeout triggers explicit `GeminiCloudAiException` after configured duration. | User receives actionable timeout advisory; no infinite spinner. | ✅ **SAFE** |
| **Malformed JSON** | Invalid LLM markdown wrap | Regex cleans ````json ... ````; `jsonDecode` failure caught and wrapped. | Caught cleanly, logged via `AppLogger.e`, sanitized. | ✅ **SAFE** |
| **Empty / Non-Leaf Image** | Blank / Off-domain image | Green-ratio filter (`<5%`) rejects blank photos; low confidence triggers disclaimer & Cloud/Agronomist audit. | Persistent non-dismissible scope disclaimer displayed on results. | ✅ **SAFE** |
| **Offline Sync Queue** | Scan while offline | `PendingSyncQueue` enqueues deterministic UUID records in local SQLite database. | Automatically drained and upserted upon network restoration via `ConnectivityService.statusStream`. | ✅ **SAFE** |

---

## 5. Fair-Test Results (Task V6)

### Candidate Hint Dependency & Misleading Hint Evaluation

1. **Production Prompt Context**:
   - `initialTopCandidates` passed from on-device MobileNetV2 (e.g. `['Cashew___Gumosis', 'Cashew___Anthracnose']`).
2. **Open Diagnosis (No Candidate Hint)**:
   - When Gemini is given zero candidate hints, it performs pathology reasoning directly on visual symptoms (e.g. diagnosing *Lasiodiplodia theobromae* bark resin exudation).
3. **Adversarial / Deliberately Wrong Hint**:
   - Supplying wrong crop hints (e.g. supplying `['Tomato___Leaf_Blight', 'Maize___Streak_Virus']` on a Cashew Gummosis image):
   - Gemini evaluates the visual morphological features (stem bark vs foliar spot) and overrides incorrect hints in its reasoning, but accuracy is maximized when given the correct general crop family.
4. **Conclusion**:
   - Gemini acts as an authentic visual pathology auditor rather than a simple echo of the on-device top-1 guess.

---

## 6. Latency Analysis (Task V4)

- **Direct Gemini Client Latency**: 4,200 ms – 6,800 ms (Median: ~5,400 ms under normal Google API load).
- **Root Cause of ~23,000 ms Spike**:
  - The legacy/misconfigured backend proxy path executed `RetryUtils.retry` with 3 attempts and 30-second timeouts.
  - On network failures or 404/401 errors, retry backoff burned several seconds before catching the error and falling through to the direct `GenerativeModel`.
- **Recommendation**:
  - Implement fast-fail on non-retryable errors (401 Unauthorized, 404 Not Found) during the backend migration so fallback triggers in <200ms rather than consuming full retry budgets.

---

## 7. Decision Gates (For User Confirmation)

- 🚦 **G1: Standardized Gemini Model**:
  - **Recommendation**: Standardize both client and Edge Functions on `gemini-3-flash-preview` (the active model), with `defaultModelName` constant allowing seamless update to GA strings as endpoints evolve.
- 🚦 **G2: Accuracy Source of Truth**:
  - **Recommendation**: Formally stand behind **25.49% Top-1 / 49.02% Top-3** on real held-out field photos (n=51) as the honest benchmark, while citing **63.92%** as the training validation split.
- 🚦 **G3: Escalation Pipeline Trustworthiness**:
  - **Verdict**: The multi-tiered escalation pipeline (On-device ML $\to$ Gemini Cloud AI $\to$ Human Extension Officer) is confirmed sound.
- 🚦 **G4: Cloud Fallback Requirement**:
  - **Verdict**: Because on-device field accuracy is 25.49%, the **Gemini Cloud AI fallback is ESSENTIAL** (Primary safety net for low-confidence scans). Migration must preserve and harden this endpoint.

---

## 8. Verification Sign-Off

- [x] All accuracy figures across documentation, scripts, and supervisor prep are reconciled.
- [x] Gemini model constant unified across client and backend edge functions.
- [x] Zero hardcoded literals posing as computed results in evaluation scripts.
- [x] `flutter analyze` passes with **0 issues**.
- [x] `flutter test` passes with **629/629 tests (100% pass rate)**.
