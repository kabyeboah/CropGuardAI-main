# Model Validation, Calibration & Release Gating Report

> **Document Status: ACTIVE EVALUATION REPORT & RELEASE GATE AUDIT** [CURRENT]
> **Generated:** 2026-08-31 | **Evaluator:** Antigravity Pair Programmer / `tools/evaluate_model.py` [CURRENT]
> **Evaluated Artifact:** `assets/cropguard_plant_disease.tflite` (SHA-256 binary verified) [CURRENT]
> **Release Gate Status:** **FAIL (RELEASE BLOCKED)** (Required Floor: $\ge 70.0\%$, Measured: **16.67%**) [CURRENT]

---

## 1. Executive Summary & Formal Gate Verdict

| Gate Requirement | Minimum Floor | Measured Value | Gate Verdict | Operational Safeguard | [CURRENT]
|---|---|---|---|---| [CURRENT]
| **Overall Top-1 Accuracy** | $\ge 70.0\%$ | **16.67%** | ❌ **FAIL** | Degraded Fallback to Gemini Cloud AI | [CURRENT]
| **Top-3 Accuracy** | $\ge 90.0\%$ | **45.83%** | ❌ **FAIL** | Multi-angle Soft Voting Ensemble | [CURRENT]
| **Macro F1-Score** | $\ge 70.0\%$ | **14.39%** | ❌ **FAIL** | Certified Agronomist Review | [CURRENT]
| **Expected Calibration Error (ECE)** | $\le 12.0\%$ | **30.51%** | ❌ **FAIL** | Overconfidence Warning Disclaimers | [CURRENT]
| **Confident Accuracy ($\tau \ge 0.60$)** | $\ge 88.0\%$ | **50.00%** | ❌ **FAIL** | Mandatory Human In The Loop (HITL) | [CURRENT]

> [!IMPORTANT] [CURRENT]
> **Formal Release Gate Verdict: FAIL (RELEASE BLOCKED FOR AUTONOMOUS DEPLOYMENT)** [CURRENT]
> The exact shipped model achieves **16.67% Top-1 Accuracy** on held-out field test samples and **63.9%** on synthetic Colab validation splits. [CURRENT] [CURRENT] Because the documented release floor is **70.0%**, this model **FAILS** the autonomous production release gate. [CURRENT]
> [CURRENT]
> **Academic & Prototype Release Exception:** [CURRENT]
> For supervisor demonstration and iterative testing, the application operates safely by gating the model with active visual fallbacks (`isDegraded: true`), displaying persistent disclaimers, and routing all scans to the multimodal **Gemini Cloud AI** and agronomist review pipeline. [CURRENT] [CURRENT]

---

## 2. Comprehensive 11-Condition Stress & Robustness Suite

The model was evaluated against 11 real-world operational scenarios simulating Ghanaian smallholder farming environments: [HISTORICAL]

| # | Test Condition / Scenario | Test Size | Measured Top-1 Acc | Top-3 Acc | Confident Acc ($\tau \ge 0.60$) | Coverage (Accepted) | Risk / Failure Mode | [CURRENT]
|---|---|---|---|---|---|---|---| [CURRENT]
| **1** | Good Images (Clean Baseline) | 24 | **16.67%** | 45.83% | 50.00% | 25.0% | Severe feature suppression | [CURRENT]
| **2a** | Bad Lighting (Underexposed / Dark) | 24 | **20.83%** | 45.83% | 40.00% | 20.8% | Moderate degradation | [CURRENT]
| **2b** | Bad Lighting (Overexposed / Direct Sun) | 24 | **20.83%** | 37.50% | 22.22% | 37.5% | Moderate degradation | [CURRENT]
| **3a** | Blur (Defocus Blur $\sigma=3.0$) | 24 | **25.00%** | 41.67% | 33.33% | 37.5% | Moderate degradation | [CURRENT]
| **3b** | Blur (Motion Blur) | 24 | **33.33%** | 41.67% | 37.50% | 33.3% | Moderate degradation | [CURRENT]
| **4** | Clutter & Soil/Weed Occlusion | 24 | **29.17%** | 45.83% | 42.86% | 29.2% | Moderate degradation | [CURRENT]
| **5** | Multiple Leaves (Overlapping Canopy) | 24 | **25.00%** | 29.17% | 25.00% | 16.7% | Moderate degradation | [CURRENT]
| **6** | Downloaded Internet Images | 23 | **17.39%** | 34.78% | 50.00% | 26.1% | Severe feature suppression | [CURRENT]
| **7** | WhatsApp Compressed (JPEG Q15) | 24 | **33.33%** | 45.83% | 50.00% | 25.0% | Moderate degradation | [CURRENT]
| **8** | Phone Camera Sensor Noise & Shift | 24 | **29.17%** | 41.67% | 28.57% | 29.2% | Moderate degradation | [CURRENT]

### Out-of-Distribution (OOD) & Abstention Evaluation

| # | Scenario | Test Samples | Rejection / Abstention Rate ($\tau < 0.60$) | False Positive Breach Rate ($\tau \ge 0.60$) | Mean Confidence | Critical Observation | [CURRENT]
|---|---|---|---|---|---|---| [CURRENT]
| **9** | Non-Plant Images (Objects, Dirt, Tools) | 14 | **100.0%** | 0.0% | 29.94% | Clean rejection | [CURRENT]
| **10** | Healthy Plants (Uninfected Leaves) | 15 | **73.3%** | 26.7% | 45.62% | Clean rejection | [CURRENT]
| **11** | Unsupported Crops (Apple, Grape, Potato) | 13 | **92.3%** | 7.7% | 41.45% | Clean rejection | [CURRENT]

---

## 3. Confidence Threshold Calibration ($\tau$ Sweep)

Evaluation of coverage and empirical accuracy across confidence cutoffs $\tau \in [0.30 \dots 0.90]$: [CURRENT]

| Threshold ($\tau$) | Coverage (% Scans Accepted) | Empirical Accuracy | Total Accepted Samples | Correct / Total | Routing Role | [HISTORICAL]
|---|---|---|---|---|---| [CURRENT]
| $\tau = 0.30$ | 54.2% | **30.77%** | 13 | 4 / 13 | Routes to Gemini Cloud AI | [CURRENT]
| $\tau = 0.40$ | 37.5% | **33.33%** | 9 | 3 / 9 | Routes to Gemini Cloud AI | [CURRENT]
| $\tau = 0.50$ | 33.3% | **37.50%** | 8 | 3 / 8 | Routes to Gemini Cloud AI | [CURRENT]
| $\tau = 0.60$ | 25.0% | **50.00%** | 6 👈 *(Production Cutoff)* | 3 / 6 | Permits on-device guidance | [CURRENT]
| $\tau = 0.70$ | 20.8% | **40.00%** | 5 | 2 / 5 | Permits on-device guidance | [CURRENT]
| $\tau = 0.80$ | 12.5% | **66.67%** | 3 | 2 / 3 | Permits on-device guidance | [CURRENT]
| $\tau = 0.90$ | 4.2% | **100.00%** | 1 | 1 / 1 | Permits on-device guidance | [CURRENT]

---

## 4. Expected Calibration Error (ECE) & Reliability Diagram

**Expected Calibration Error (ECE): 30.51%** across 10 confidence bins.

| Confidence Bin | Sample Count | Mean Bin Confidence | Empirical Accuracy | Calibration Gap (|Acc - Conf|) | Calibration State | [CURRENT]
|---|---|---|---|---|---| [CURRENT]
| `[0.0, 0.1]` | 0 | 5.0% | **0.0%** | 0.00% | Calibrated | [CURRENT]
| `[0.1, 0.2]` | 2 | 17.9% | **0.0%** | 17.89% | Severely Overconfident | [CURRENT]
| `[0.2, 0.3]` | 9 | 25.2% | **0.0%** | 25.23% | Severely Overconfident | [CURRENT]
| `[0.3, 0.4]` | 4 | 36.8% | **25.0%** | 11.75% | Underconfident | [CURRENT]
| `[0.4, 0.5]` | 1 | 43.5% | **0.0%** | 43.46% | Severely Overconfident | [CURRENT]
| `[0.5, 0.6]` | 2 | 58.2% | **0.0%** | 58.22% | Severely Overconfident | [CURRENT]
| `[0.6, 0.7]` | 1 | 64.4% | **100.0%** | 35.61% | Underconfident | [CURRENT]
| `[0.7, 0.8]` | 2 | 77.5% | **0.0%** | 77.51% | Severely Overconfident | [CURRENT]
| `[0.8, 0.9]` | 2 | 83.6% | **50.0%** | 33.58% | Severely Overconfident | [CURRENT]
| `[0.9, 1.0]` | 1 | 95.2% | **100.0%** | 4.76% | Calibrated | [CURRENT]

---

## 5. Per-Class Accuracy & Performance Metrics (All 51 Classes)

| Class Label | Precision | Recall | F1-Score | Support | [CURRENT]
|---|---|---|---|---| [CURRENT]
| `Banana___Sigatoka` | 0.000 | 0.000 | 0.000 | 2 | [CURRENT]
| `Cashew___Anthracnose` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Cashew___Gumosis` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Cashew___Leaf_Miner` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Cashew___Red_Rust` | 1.000 | 1.000 | 1.000 | 1 | [CURRENT]
| `Cassava___Bacterial_Blight` | 0.333 | 1.000 | 0.500 | 1 | [CURRENT]
| `Cassava___Brown_Streak_Disease` | 1.000 | 1.000 | 1.000 | 1 | [CURRENT]
| `Cassava___Green_Mottle` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Cassava___Mosaic` | 0.500 | 1.000 | 0.667 | 1 | [CURRENT]
| `Maize___Common_Rust` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Maize___Gray_Leaf_Spot` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Maize___Leaf_Blight` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Mango___Anthracnose` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Mango___Bacterial_Canker` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Mango___Powdery_Mildew` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Mango___Sooty_Mould` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Rice___Brown_Spot` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Rice___Leaf_Blast` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Rice___Leaf_Scald` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Tomato___Leaf_Blight` | 0.000 | 0.000 | 0.000 | 2 | [CURRENT]
| `Tomato___Leaf_Curl` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]
| `Tomato___Septoria_Leaf_Spot` | 0.000 | 0.000 | 0.000 | 1 | [CURRENT]

---

## 6. Confusion Matrix Highlights

```text
Banana___Sigatoka                   -> Rice___Leaf_Scald:1, Cassava___Bacterial_Blight:1
Cashew___Anthracnose                -> Mango___Bacterial_Canker:1
Cashew___Gumosis                    -> Cassava___Bacterial_Blight:1
Cashew___Leaf_Miner                 -> Maize___Blight:1
Cashew___Red_Rust                   -> Cashew___Red_Rust:1
Cassava___Bacterial_Blight          -> Cassava___Bacterial_Blight:1
Cassava___Brown_Streak_Disease      -> Cassava___Brown_Streak_Disease:1
Cassava___Green_Mottle              -> Cassava___Green_Mite:1
Cassava___Mosaic                    -> Cassava___Mosaic:1
Maize___Common_Rust                 -> Maize___Gray_Leaf_Spot:1
Maize___Gray_Leaf_Spot              -> Maize___Common_Rust:1
Maize___Leaf_Blight                 -> Cassava___Healthy:1
Mango___Anthracnose                 -> Cashew___Anthracnose:1
Mango___Bacterial_Canker            -> Cashew___Healthy:1
Mango___Powdery_Mildew              -> Cashew___Gumosis:1
Mango___Sooty_Mould                 -> Cassava___Mosaic:1
Rice___Brown_Spot                   -> Sugarcane___Rust:1
Rice___Leaf_Blast                   -> Rice___Leaf_Scald:1
Rice___Leaf_Scald                   -> Rice___Sheath_Blight:1
Tomato___Leaf_Blight                -> Cassava___Brown_Spot:1, Cashew___Healthy:1
Tomato___Leaf_Curl                  -> Groundnut___Leaf_Raw:1
Tomato___Septoria_Leaf_Spot         -> Tomato___Leaf_Curl:1
```

---

## 7. How to Reproduce This Evaluation

```bash
python3 tools/evaluate_model.py \
  --model assets/cropguard_plant_disease.tflite \
  --labels assets/labels.txt \
  --test-set test_set \
  --run-all-stress-tests \
  --output-md docs/MODEL_ACCURACY.md \
  --output-json docs/eval_metrics.json \
  --min-accuracy 0.70
```
