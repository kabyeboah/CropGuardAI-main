# Model Validation, Calibration & Release Gating Report

> **Document Status: ACTIVE EVALUATION REPORT & RELEASE GATE AUDIT**  
> **Generated:** 2026-09-02 | **Evaluator:** Antigravity Pair Programmer / `tools/evaluate_model.py`  
> **Evaluated Artifact:** `assets/cropguard_plant_disease_verified.tflite` (SHA-256 binary verified)  
> **Release Gate Status:** **FAIL (RELEASE BLOCKED)** (Required Floor: $\ge 70.0\%$, Measured: **25.49%**)

---

## 1. Executive Summary & Formal Gate Verdict

| Gate Requirement | Minimum Floor | Measured Value | Gate Verdict | Operational Safeguard |
|---|---|---|---|---|
| **Overall Top-1 Accuracy** | $\ge 70.0\%$ | **25.49%** | ❌ **FAIL** | Degraded Fallback to Gemini Cloud AI |
| **Top-3 Accuracy** | $\ge 90.0\%$ | **49.02%** | ❌ **FAIL** | Multi-angle Soft Voting Ensemble |
| **Macro F1-Score** | $\ge 70.0\%$ | **23.53%** | ❌ **FAIL** | Certified Agronomist Review |
| **Expected Calibration Error (ECE)** | $\le 12.0\%$ | **20.04%** | ❌ **FAIL** | Overconfidence Warning Disclaimers |
| **Confident Accuracy ($\tau \ge 0.60$)** | $\ge 88.0\%$ | **66.67%** | ❌ **FAIL** | Mandatory Human In The Loop (HITL) |

> [!IMPORTANT]
> **Formal Release Gate Verdict: FAIL (RELEASE BLOCKED FOR AUTONOMOUS DEPLOYMENT)**  
> The exact shipped model achieves **25.49% Top-1 Accuracy** on held-out field test samples and **63.9%** on synthetic Colab validation splits. Because the documented release floor is **70.0%**, this model **FAILS** the autonomous production release gate.
> 
> **Academic & Prototype Release Exception:**  
> For supervisor demonstration and iterative testing, the application operates safely by gating the model with active visual fallbacks (`isDegraded: true`), displaying persistent disclaimers, and routing all scans to the multimodal **Gemini Cloud AI** and agronomist review pipeline.

---

## 2. Comprehensive 11-Condition Stress & Robustness Suite

The model was evaluated against 11 real-world operational scenarios simulating Ghanaian smallholder farming environments:

| # | Test Condition / Scenario | Test Size | Measured Top-1 Acc | Top-3 Acc | Confident Acc ($\tau \ge 0.60$) | Coverage (Accepted) | Risk / Failure Mode |
|---|---|---|---|---|---|---|---|
| **1** | Good Images (Clean Baseline) | 51 | **25.49%** | 49.02% | 66.67% | 17.6% | Moderate degradation |
| **2a** | Bad Lighting (Underexposed / Dark) | 51 | **19.61%** | 43.14% | 44.44% | 17.6% | Severe feature suppression |
| **2b** | Bad Lighting (Overexposed / Direct Sun) | 51 | **25.49%** | 45.10% | 40.00% | 39.2% | Moderate degradation |
| **3a** | Blur (Defocus Blur $\sigma=3.0$) | 51 | **21.57%** | 47.06% | 50.00% | 23.5% | Moderate degradation |
| **3b** | Blur (Motion Blur) | 51 | **29.41%** | 49.02% | 54.55% | 21.6% | Moderate degradation |
| **4** | Clutter & Soil/Weed Occlusion | 51 | **33.33%** | 52.94% | 60.00% | 19.6% | Moderate degradation |
| **5** | Multiple Leaves (Overlapping Canopy) | 51 | **15.69%** | 37.25% | 14.29% | 13.7% | Severe feature suppression |
| **6** | Downloaded Internet Images | 23 | **17.39%** | 34.78% | 50.00% | 26.1% | Severe feature suppression |
| **7** | WhatsApp Compressed (JPEG Q15) | 51 | **27.45%** | 45.10% | 60.00% | 19.6% | Moderate degradation |
| **8** | Phone Camera Sensor Noise & Shift | 51 | **21.57%** | 47.06% | 60.00% | 19.6% | Moderate degradation |

### Out-of-Distribution (OOD) & Abstention Evaluation

| # | Scenario | Test Samples | Rejection / Abstention Rate ($\tau < 0.60$) | False Positive Breach Rate ($\tau \ge 0.60$) | Mean Confidence | Critical Observation |
|---|---|---|---|---|---|---|
| **9** | Non-Plant Images (Objects, Dirt, Tools) | 14 | **100.0%** | 0.0% | 29.94% | Clean rejection |
| **10** | Healthy Plants (Uninfected Leaves) | 15 | **73.3%** | 26.7% | 45.62% | Clean rejection |
| **11** | Unsupported Crops (Apple, Grape, Potato) | 13 | **92.3%** | 7.7% | 41.45% | Clean rejection |

---

## 3. Confidence Threshold Calibration ($\tau$ Sweep)

Evaluation of coverage and empirical accuracy across confidence cutoffs $\tau \in [0.30 \dots 0.90]$:

| Threshold ($\tau$) | Coverage (% Scans Accepted) | Empirical Accuracy | Total Accepted Samples | Correct / Total | Routing Role |
|---|---|---|---|---|---|
| $\tau = 0.30$ | 60.8% | **38.71%** | 31 | 12 / 31 | Routes to Gemini Cloud AI |
| $\tau = 0.40$ | 35.3% | **38.89%** | 18 | 7 / 18 | Routes to Gemini Cloud AI |
| $\tau = 0.50$ | 23.5% | **50.00%** | 12 | 6 / 12 | Routes to Gemini Cloud AI |
| $\tau = 0.60$ | 17.6% | **66.67%** | 9 👈 *(Production Cutoff)* | 6 / 9 | Permits on-device guidance |
| $\tau = 0.70$ | 15.7% | **62.50%** | 8 | 5 / 8 | Permits on-device guidance |
| $\tau = 0.80$ | 11.8% | **83.33%** | 6 | 5 / 6 | Permits on-device guidance |
| $\tau = 0.90$ | 7.8% | **100.00%** | 4 | 4 / 4 | Permits on-device guidance |

---

## 4. Expected Calibration Error (ECE) & Reliability Diagram

**Expected Calibration Error (ECE): 20.04%** across 10 confidence bins.

| Confidence Bin | Sample Count | Mean Bin Confidence | Empirical Accuracy | Calibration Gap (|Acc - Conf|) | Calibration State |
|---|---|---|---|---|---|
| `[0.0, 0.1]` | 0 | 5.0% | **0.0%** | 0.00% | Calibrated |
| `[0.1, 0.2]` | 4 | 18.6% | **0.0%** | 18.58% | Severely Overconfident |
| `[0.2, 0.3]` | 16 | 25.0% | **6.2%** | 18.79% | Severely Overconfident |
| `[0.3, 0.4]` | 13 | 35.3% | **38.5%** | 3.21% | Calibrated |
| `[0.4, 0.5]` | 6 | 43.8% | **16.7%** | 27.12% | Severely Overconfident |
| `[0.5, 0.6]` | 3 | 55.8% | **0.0%** | 55.85% | Severely Overconfident |
| `[0.6, 0.7]` | 1 | 64.4% | **100.0%** | 35.61% | Underconfident |
| `[0.7, 0.8]` | 2 | 77.5% | **0.0%** | 77.51% | Severely Overconfident |
| `[0.8, 0.9]` | 2 | 83.6% | **50.0%** | 33.58% | Severely Overconfident |
| `[0.9, 1.0]` | 4 | 95.7% | **100.0%** | 4.29% | Calibrated |

---

## 5. Per-Class Accuracy & Performance Metrics (All 51 Classes)

| Class Label | Precision | Recall | F1-Score | Support |
|---|---|---|---|---|
| `Banana___Cordana` | 1.000 | 1.000 | 1.000 | 1 |
| `Banana___Sigatoka` | 0.000 | 0.000 | 0.000 | 4 |
| `Cashew___Anthracnose` | 0.000 | 0.000 | 0.000 | 1 |
| `Cashew___Gumosis` | 0.000 | 0.000 | 0.000 | 1 |
| `Cashew___Leaf_Miner` | 0.000 | 0.000 | 0.000 | 1 |
| `Cashew___Red_Rust` | 1.000 | 1.000 | 1.000 | 1 |
| `Cassava___Bacterial_Blight` | 0.333 | 1.000 | 0.500 | 2 |
| `Cassava___Brown_Streak_Disease` | 1.000 | 1.000 | 1.000 | 2 |
| `Cassava___Green_Mite` | 0.000 | 0.000 | 0.000 | 1 |
| `Cassava___Green_Mottle` | 0.000 | 0.000 | 0.000 | 1 |
| `Cassava___Mosaic` | 0.250 | 0.500 | 0.333 | 2 |
| `Groundnut___Leaf_Raw` | 0.500 | 1.000 | 0.667 | 1 |
| `Maize___Common_Rust` | 0.000 | 0.000 | 0.000 | 1 |
| `Maize___Fall_Armyworm` | 0.000 | 0.000 | 0.000 | 1 |
| `Maize___Grasshopper` | 1.000 | 1.000 | 1.000 | 1 |
| `Maize___Gray_Leaf_Spot` | 0.000 | 0.000 | 0.000 | 1 |
| `Maize___Leaf_Beetle` | 1.000 | 1.000 | 1.000 | 1 |
| `Maize___Leaf_Blight` | 0.000 | 0.000 | 0.000 | 1 |
| `Maize___Streak_Virus` | 0.500 | 1.000 | 0.667 | 1 |
| `Mango___Anthracnose` | 0.000 | 0.000 | 0.000 | 2 |
| `Mango___Bacterial_Canker` | 0.000 | 0.000 | 0.000 | 1 |
| `Mango___Cutting_Weevil` | 0.000 | 0.000 | 0.000 | 1 |
| `Mango___Healthy` | 0.000 | 0.000 | 0.000 | 1 |
| `Mango___Powdery_Mildew` | 0.000 | 0.000 | 0.000 | 2 |
| `Mango___Sooty_Mould` | 0.000 | 0.000 | 0.000 | 1 |
| `Rice___Bacterial_Blight` | 0.000 | 0.000 | 0.000 | 2 |
| `Rice___Brown_Spot` | 0.000 | 0.000 | 0.000 | 2 |
| `Rice___Healthy` | 0.500 | 0.500 | 0.500 | 2 |
| `Rice___Leaf_Blast` | 0.000 | 0.000 | 0.000 | 2 |
| `Rice___Leaf_Scald` | 0.000 | 0.000 | 0.000 | 2 |
| `Rice___Sheath_Blight` | 0.250 | 0.500 | 0.333 | 2 |
| `Tomato___Leaf_Blight` | 0.000 | 0.000 | 0.000 | 2 |
| `Tomato___Leaf_Curl` | 0.000 | 0.000 | 0.000 | 2 |
| `Tomato___Septoria_Leaf_Spot` | 0.000 | 0.000 | 0.000 | 2 |

---

## 6. Confusion Matrix Highlights

```text
Banana___Cordana                    -> Banana___Cordana:1
Banana___Sigatoka                   -> Rice___Leaf_Scald:1, Cassava___Bacterial_Blight:1, Maize___Fall_Armyworm:1, Maize___Streak_Virus:1
Cashew___Anthracnose                -> Mango___Bacterial_Canker:1
Cashew___Gumosis                    -> Cassava___Bacterial_Blight:1
Cashew___Leaf_Miner                 -> Maize___Blight:1
Cashew___Red_Rust                   -> Cashew___Red_Rust:1
Cassava___Bacterial_Blight          -> Cassava___Bacterial_Blight:2
Cassava___Brown_Streak_Disease      -> Cassava___Brown_Streak_Disease:2
Cassava___Green_Mite                -> Cassava___Green_Mottle:1
Cassava___Green_Mottle              -> Cassava___Green_Mite:1
Cassava___Mosaic                    -> Cassava___Mosaic:1, Cassava___Green_Mottle:1
Groundnut___Leaf_Raw                -> Groundnut___Leaf_Raw:1
Maize___Common_Rust                 -> Maize___Gray_Leaf_Spot:1
Maize___Fall_Armyworm               -> Maize___Leaf_Blight:1
Maize___Grasshopper                 -> Maize___Grasshopper:1
Maize___Gray_Leaf_Spot              -> Maize___Common_Rust:1
Maize___Leaf_Beetle                 -> Maize___Leaf_Beetle:1
Maize___Leaf_Blight                 -> Cassava___Healthy:1
Maize___Streak_Virus                -> Maize___Streak_Virus:1
Mango___Anthracnose                 -> Cashew___Anthracnose:1, Cashew___Healthy:1
Mango___Bacterial_Canker            -> Cashew___Healthy:1
Mango___Cutting_Weevil              -> Cashew___Leaf_Miner:1
Mango___Healthy                     -> Cassava___Bacterial_Blight:1
Mango___Powdery_Mildew              -> Cashew___Gumosis:1, Cassava___Mosaic:1
Mango___Sooty_Mould                 -> Cassava___Mosaic:1
Rice___Bacterial_Blight             -> Sugarcane___Rust:1, Rice___Sheath_Blight:1
Rice___Brown_Spot                   -> Sugarcane___Rust:1, Maize___Common_Rust:1
Rice___Healthy                      -> Rice___Brown_Spot:1, Rice___Healthy:1
Rice___Leaf_Blast                   -> Rice___Leaf_Scald:1, Rice___Sheath_Blight:1
Rice___Leaf_Scald                   -> Rice___Sheath_Blight:1, Rice___Healthy:1
Rice___Sheath_Blight                -> Rice___Sheath_Blight:1, Sugarcane___Red_Rot:1
Tomato___Leaf_Blight                -> Cassava___Brown_Spot:1, Cashew___Healthy:1
Tomato___Leaf_Curl                  -> Groundnut___Leaf_Raw:1, Cassava___Mosaic:1
Tomato___Septoria_Leaf_Spot         -> Cassava___Bacterial_Blight:1, Tomato___Leaf_Curl:1
```

---

## 7. How to Reproduce This Evaluation

```bash
python3 tools/evaluate_model.py \
  --model assets/cropguard_plant_disease_verified.tflite \
  --labels assets/labels.txt \
  --test-set test_set \
  --run-all-stress-tests \
  --output-md docs/MODEL_ACCURACY.md \
  --output-json docs/eval_metrics.json \
  --min-accuracy 0.70
```
