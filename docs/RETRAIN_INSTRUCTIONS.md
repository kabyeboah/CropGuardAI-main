# CropGuard AI — Retraining Instructions

How to use the Colab notebook to retrain the disease detection model and put the new model into the app. [CURRENT] [CURRENT]

---

## Prerequisites

| Requirement | How to get it | [CURRENT]
|-------------|---------------| [CURRENT]
| Google account | [accounts.google.com](https://accounts.google.com) | [CURRENT]
| Kaggle account + API key | [kaggle.com](https://www.kaggle.com) → Account → API → Create New Token | [CURRENT]
| ~4–8 hours | Leave the Colab tab open | [CURRENT]

---

## Step 0 — Harvest Corrected Feedback Labels

Farmer-reported diagnosis corrections are continuously collected in Firestore's `feedback` collection. [CURRENT] [CURRENT] Before retraining: [CURRENT]

1. [CURRENT] [CURRENT] Run the feedback export tool: [CURRENT]
```bash
python3 tools/export_feedback.py --service-account-key path/to/service-account.json
```
2. [CURRENT] [CURRENT] Review `docs/feedback_export.json` to identify misclassification clusters (e.g. [CURRENT] `Tomato___Early_blight -> Tomato___Late_blight`). [CURRENT]
3. [CURRENT] [CURRENT] Audit flagged scan images from Cloud Storage / local storage and move verified images into the target training class folders prior to Step 3. [HISTORICAL]

---

## Step 1 — Open the Notebook in Colab

1. [CURRENT] [CURRENT] Go to [colab.research.google.com](https://colab.research.google.com) [CURRENT]
2. [CURRENT] [CURRENT] Click **File → Upload notebook** [CURRENT]
3. [CURRENT] [CURRENT] Upload `docs/cropguard_retrain.ipynb` from this project [CURRENT]

---

## Step 2 — Set the GPU Runtime

1. [CURRENT] [CURRENT] In Colab: **Runtime → Change runtime type** [CURRENT]
2. [CURRENT] [CURRENT] Set Hardware Accelerator to **T4 GPU** [CURRENT]
3. [CURRENT] [CURRENT] Click Save [CURRENT]

---

## Step 3 — Run All Cells

Click **Runtime → Run all** (or Shift+Enter through each cell). [CURRENT] [CURRENT]

The notebook will: [PLANNED]
- ✅ Install dependencies
- ✅ Ask you to upload `kaggle.json`
- ✅ Download plant disease datasets (~3–5 GB)
- ✅ Organise images into `Crop___Disease` folders
- ✅ Train MobileNetV2 (Phase 1: frozen base, Phase 2: fine-tune)
- ✅ Export `cropguard_plant_disease.tflite` + `labels.txt` + `model_metadata.json`
- ✅ Download all 3 files to your computer

> **Target accuracy:** ≥ 85% validation accuracy before deploying. [CURRENT] [CURRENT]
> If you get < 80%, add more images per class (aim for 300+). [CURRENT] [CURRENT]

---

## Step 4 — Put the New Files in the App

Replace the 3 files in the `assets/` folder: [HISTORICAL]

```
assets/cropguard_plant_disease.tflite   ← new file from Colab
assets/labels.txt                       ← new file from Colab
assets/model_metadata.json              ← new file from Colab
```

---

## Step 5 — Check for Missing Disease Info Entries

Add this block temporarily to `main()` in `lib/main.dart` (after `setupServiceLocator()`): [CURRENT]

```dart
import 'package:flutter/services.dart';
import 'data/ml/disease_info.dart';

// Inside main(), after setupServiceLocator():
final raw = await rootBundle.loadString('assets/labels.txt');
final labels = raw.split('\n').where((l) => l.isNotEmpty).toList();
for (final label in labels) {
  final info = DiseaseDatabase.getInfo(label);
  if (info.cropType == 'Unknown') {
    debugPrint('MISSING ENTRY ▶ $label');
  }
}
```

Run `flutter run` and check the debug console. [CURRENT] [CURRENT] For every line printed, add a `DiseaseInfoEntry` to `lib/data/ml/disease_info.dart`. [CURRENT] Follow the template in `MODEL_EXPANSION_GUIDE.md`. [CURRENT]

**Remove this debug code before releasing.**

---

## Step 6 — Test on Device

```bash
flutter run --release
```

Test with the reference images in `assets/diseases/`. [CURRENT] [CURRENT] Each should detect correctly with confidence ≥ 0.60. [CURRENT]

---

## Step 7 — Run Analyze

```bash
flutter analyze
```

Zero issues required before shipping. [CURRENT] [CURRENT]

---

## Troubleshooting

| Problem | Fix | [CURRENT]
|---------|-----| [CURRENT]
| Kaggle download fails | Check `kaggle.json` is valid; try re-creating the token | [CURRENT]
| Out of RAM in Colab | Reduce `BATCH` from 32 to 16 in Cell 6 | [CURRENT]
| Accuracy < 80% | Add more images per class; aim for 300+ per class | [CURRENT]
| Model too large (> 15 MB) | Apply quantisation: set `converter.optimizations = [tf.lite.Optimize.DEFAULT]` before conversion | [CURRENT]
| TFLite shape mismatch in app | Ensure `num_classes` in `model_metadata.json` matches the new label count | [CURRENT]
| MISSING ENTRY in debug console | Add a `DiseaseInfoEntry` block to `disease_info.dart` for that label | [CURRENT]

---

## Adding New Crops (Ghana-Specific)

From the `MODEL_EXPANSION_GUIDE.md`, the highest-priority crops not yet in the model are: [CURRENT]

| Crop | Diseases | Priority | [CURRENT]
|------|----------|----------| [CURRENT]
| Pineapple | Mealybug Wilt, Heart Rot | High | [CURRENT]
| Citrus (lime/lemon) | Black Spot, Scab, Greasy Spot | High | [CURRENT]
| Sweet Potato | Leaf Curl, Alternaria Blight | Medium | [CURRENT]
| Okra | Yellow Vein Mosaic, Leaf Curl | Medium | [CURRENT]
| Pawpaw | Ring Spot Virus, Anthracnose | Medium | [CURRENT]

To add them: [CURRENT]
1. [CURRENT] [CURRENT] Collect 300+ images per class (see Kaggle/Roboflow options in `MODEL_EXPANSION_GUIDE.md`) [CURRENT]
2. [CURRENT] [CURRENT] Add to the Colab `LABEL_MAP` dict in Cell 4 using `Crop___Disease` naming [CURRENT]
3. [CURRENT] [CURRENT] Re-run the notebook [CURRENT]
4. [CURRENT] [CURRENT] Add `DiseaseInfoEntry` blocks to `disease_info.dart` [CURRENT]

---

## TODO — Confidence Calibration

The 0.60 / 0.40 thresholds are currently uncalibrated. [HISTORICAL] [HISTORICAL] Softmax confidence ≠ empirical accuracy-conditioned-on-confidence. [CURRENT] Before these thresholds can be fully trusted: [HISTORICAL]

1. [CURRENT] [CURRENT] After retraining, hold out a validation set (not used in training) [HISTORICAL]
2. [CURRENT] [CURRENT] Run inference on the held-out set, collect (predicted_label, confidence, true_label) triples [CURRENT]
3. [CURRENT] [CURRENT] Plot a reliability diagram (calibration curve) and compute Expected Calibration Error (ECE) [CURRENT]
4. [CURRENT] [CURRENT] If miscalibrated, apply temperature scaling: optimize parameter T on the held-out set such that `softmax(logits / T)` produces well-calibrated probabilities [CURRENT]
5. [CURRENT] [CURRENT] Re-evaluate the 0.60/0.40 thresholds against the calibrated probabilities [HISTORICAL]

Until this is done, global thresholds remain empirical estimates. [HISTORICAL] [HISTORICAL]

