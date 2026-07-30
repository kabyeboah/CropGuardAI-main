# CropGuard AI — Retraining Instructions

How to use the Colab notebook to retrain the disease detection model and put the new model into the app.

---

## Prerequisites

| Requirement | How to get it |
|-------------|---------------|
| Google account | [accounts.google.com](https://accounts.google.com) |
| Kaggle account + API key | [kaggle.com](https://www.kaggle.com) → Account → API → Create New Token |
| ~4–8 hours | Leave the Colab tab open |

---

## Step 1 — Open the Notebook in Colab

1. Go to [colab.research.google.com](https://colab.research.google.com)
2. Click **File → Upload notebook**
3. Upload `docs/cropguard_retrain.ipynb` from this project

---

## Step 2 — Set the GPU Runtime

1. In Colab: **Runtime → Change runtime type**
2. Set Hardware Accelerator to **T4 GPU**
3. Click Save

---

## Step 3 — Run All Cells

Click **Runtime → Run all** (or Shift+Enter through each cell).

The notebook will:
- ✅ Install dependencies
- ✅ Ask you to upload `kaggle.json`
- ✅ Download plant disease datasets (~3–5 GB)
- ✅ Organise images into `Crop___Disease` folders
- ✅ Train MobileNetV2 (Phase 1: frozen base, Phase 2: fine-tune)
- ✅ Export `cropguard_plant_disease.tflite` + `labels.txt` + `model_metadata.json`
- ✅ Download all 3 files to your computer

> **Target accuracy:** ≥ 85% validation accuracy before deploying.  
> If you get < 80%, add more images per class (aim for 300+).

---

## Step 4 — Put the New Files in the App

Replace the 3 files in the `assets/` folder:

```
assets/cropguard_plant_disease.tflite   ← new file from Colab
assets/labels.txt                        ← new file from Colab
assets/model_metadata.json               ← new file from Colab
```

---

## Step 5 — Check for Missing Disease Info Entries

Add this block temporarily to `main()` in `lib/main.dart` (after `setupServiceLocator()`):

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

Run `flutter run` and check the debug console. For every line printed, add a `DiseaseInfoEntry` to `lib/data/ml/disease_info.dart`. Follow the template in `MODEL_EXPANSION_GUIDE.md`.

**Remove this debug code before releasing.**

---

## Step 6 — Test on Device

```bash
flutter run --release
```

Test with the reference images in `assets/diseases/`. Each should detect correctly with confidence ≥ 0.60.

---

## Step 7 — Run Analyze

```bash
flutter analyze
```

Zero issues required before shipping.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Kaggle download fails | Check `kaggle.json` is valid; try re-creating the token |
| Out of RAM in Colab | Reduce `BATCH` from 32 to 16 in Cell 6 |
| Accuracy < 80% | Add more images per class; aim for 300+ per class |
| Model too large (> 15 MB) | Apply quantisation: set `converter.optimizations = [tf.lite.Optimize.DEFAULT]` before conversion |
| TFLite shape mismatch in app | Ensure `num_classes` in `model_metadata.json` matches the new label count |
| MISSING ENTRY in debug console | Add a `DiseaseInfoEntry` block to `disease_info.dart` for that label |

---

## Adding New Crops (Ghana-Specific)

From the `MODEL_EXPANSION_GUIDE.md`, the highest-priority crops not yet in the model are:

| Crop | Diseases | Priority |
|------|----------|----------|
| Pineapple | Mealybug Wilt, Heart Rot | High |
| Citrus (lime/lemon) | Black Spot, Scab, Greasy Spot | High |
| Sweet Potato | Leaf Curl, Alternaria Blight | Medium |
| Okra | Yellow Vein Mosaic, Leaf Curl | Medium |
| Pawpaw | Ring Spot Virus, Anthracnose | Medium |

To add them:
1. Collect 300+ images per class (see Kaggle/Roboflow options in `MODEL_EXPANSION_GUIDE.md`)
2. Add to the Colab `LABEL_MAP` dict in Cell 4 using `Crop___Disease` naming
3. Re-run the notebook
4. Add `DiseaseInfoEntry` blocks to `disease_info.dart`
