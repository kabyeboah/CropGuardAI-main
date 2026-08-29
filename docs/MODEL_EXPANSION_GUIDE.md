# CropGuard AI — Model Expansion Guide

How to add new crop/disease classes to the TFLite model and update the app.

---

## Overview

The current model (`cropguard_plant_disease_verified.tflite`) covers **51 classes** across Ghana & Sub-Saharan regional crop types.
Adding new classes requires four steps:

1. [Collect images](#step-1--collect-images)
2. [Organise the dataset](#step-2--organise-into-one-folder-structure)
3. [Retrain and export](#step-3--retrain-in-google-colab)
4. [Update the app](#step-4--update-the-app)

---

## Priority crops to add (Ghana / West Africa)

| Crop | Diseases to include | Priority |
|------|---------------------|----------|
| **Mango** | Anthracnose, Powdery Mildew, Sooty Mould, Bacterial Canker | High |
| **Pineapple** | Mealybug Wilt, Heart Rot, Fruitlet Core Rot | High |
| **Citrus** (lime / lemon) | Black Spot, Scab, Greasy Spot | High |
| **Garden Egg** | Phomopsis Blight, Leaf Spot, Mosaic Virus | Medium |
| **Sweet Potato** | Leaf Curl, Alternaria Blight, Weevil Damage | Medium |
| **Okra** | Yellow Vein Mosaic, Enation Leaf Curl | Medium |
| **Sugarcane** | Red Rot, Smut, Grassy Shoot | Medium |
| **Pawpaw / Papaya** | Ring Spot Virus, Powdery Mildew, Anthracnose | Medium |
| **Watermelon** | Fusarium Wilt, Gummy Stem Blight, Downy Mildew | Low |
| **Cabbage** | Black Rot, Clubroot, Diamondback Moth | Low |

Always include a `healthy` class for every crop you add.

---

## Step 1 — Collect images

You need at least **300–500 images per class**. Use the sources below.

### Option A — Kaggle (bulk download)

1. Create a free account at [kaggle.com](https://www.kaggle.com).
2. Go to **Account → API → Create New Token** — this downloads `kaggle.json`.
3. Open [Google Colab](https://colab.research.google.com) and upload `kaggle.json`.
4. Run the following cell:

```python
import os, subprocess

# Install Kaggle CLI and configure credentials
subprocess.run(['pip', 'install', '-q', 'kaggle'])
os.makedirs('/root/.kaggle', exist_ok=True)
os.rename('/content/kaggle.json', '/root/.kaggle/kaggle.json')
os.chmod('/root/.kaggle/kaggle.json', 0o600)

# Datasets to download  (workspace/dataset-slug)
datasets = [
    # Existing classes — download to augment or verify
    "emmarex/plantdisease",                          # PlantVillage (classes 1–38)
    "c2-ai/iCassava-2019-fine-grained-visual-categorization-challenge",
    "vbookshelf/rice-leaf-diseases",

    # New classes
    "warcoder/mango-leaf-disease-dataset",
    "rashikrahaman/pineapple-disease",
    "jonathansilva2020/dataset-for-crops-disease",   # citrus, papaya
    "faysalhossain/okra-plant-disease-dataset",
    "fahmidulhaq/sweet-potato-disease-dataset",
    "marquis03/banana-disease-classification",
    "vipoooool/new-plant-diseases-dataset",          # extended PlantVillage
]

os.makedirs('/content/raw_data', exist_ok=True)
for ds in datasets:
    name = ds.split("/")[1]
    print(f'Downloading {ds} ...')
    subprocess.run([
        'kaggle', 'datasets', 'download', '-d', ds,
        '--unzip', '-p', f'/content/raw_data/{name}'
    ])

print('Done.')
```

### Option B — Roboflow Universe

For crops not on Kaggle (garden egg, sugarcane, watermelon, cabbage):

1. Create a free account at [roboflow.com](https://roboflow.com).
2. Go to **Settings → Roboflow API** and copy your API key.
3. Run:

```python
subprocess.run(['pip', 'install', '-q', 'roboflow'])
from roboflow import Roboflow

rf = Roboflow(api_key="YOUR_ROBOFLOW_API_KEY")

# Search universe.roboflow.com for each crop, then paste workspace + project below
projects = [
    ("roboflow-100",     "papaya-disease-se4g7"),
    ("roboflow-100",     "watermelon-disease"),
    ("agricultural-ai",  "garden-egg-disease"),
    ("mohamedgobara",    "mango-disease-detection-mtu9n"),
]

for workspace, project_name in projects:
    proj = rf.workspace(workspace).project(project_name)
    proj.version(1).download(
        "folder",
        location=f"/content/raw_data/{project_name}"
    )
```

### Option C — Collect your own (recommended for Ghana-specific accuracy)

Use a smartphone and photograph real diseased plants.
Aim for varied lighting, angles, and growth stages.
Minimum: **300 images per class**, split 80 % train / 20 % validation.

You can label images for free at [app.roboflow.com](https://app.roboflow.com).

---

## Step 2 — Organise into one folder structure

Training expects one sub-folder per class. Run this to merge all downloaded data:

```python
import shutil, pathlib

SRC = pathlib.Path('/content/raw_data')
DST = pathlib.Path('/content/dataset')
DST.mkdir(exist_ok=True)

for class_dir in SRC.rglob('*'):
    if class_dir.is_dir() and any(class_dir.iterdir()):
        target = DST / class_dir.name
        target.mkdir(exist_ok=True)
        for img in class_dir.glob('*.[jp][pn]g'):
            shutil.copy(img, target / img.name)

classes = sorted([d.name for d in DST.iterdir() if d.is_dir()])
print(f'Total classes: {len(classes)}')
print('\n'.join(classes))
```

**Naming convention for new folders:**

Use `Crop___Disease` (triple underscore) for consistency with the newer half of
the existing dataset:

```
Mango___Anthracnose/
Mango___Powdery_Mildew/
Mango___healthy/
Pineapple___Mealybug_Wilt/
Pineapple___healthy/
```

The folder name becomes the label string the model outputs, and must exactly
match the `label:` field you add in `disease_info.dart` later.

---

## Step 3 — Retrain in Google Colab

> **Runtime:** Runtime → Change runtime type → **T4 GPU** (free tier is enough).

```python
import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras import layers, models

DATASET_PATH = '/content/dataset'
IMG_SIZE     = 224   # must stay 224 — matches model_metadata.json
BATCH        = 32
EPOCHS_1     = 20    # frozen base
EPOCHS_2     = 10    # fine-tune top layers

# ── 1. Load data ──────────────────────────────────────────────────────────────
train_ds = tf.keras.utils.image_dataset_from_directory(
    DATASET_PATH, validation_split=0.2, subset='training',
    seed=42, image_size=(IMG_SIZE, IMG_SIZE), batch_size=BATCH)

val_ds = tf.keras.utils.image_dataset_from_directory(
    DATASET_PATH, validation_split=0.2, subset='validation',
    seed=42, image_size=(IMG_SIZE, IMG_SIZE), batch_size=BATCH)

class_names = train_ds.class_names
NUM_CLASSES  = len(class_names)
print(f'Training on {NUM_CLASSES} classes')

# ── 2. Normalise to [0, 1] — matches current model_metadata.json ─────────────
norm     = layers.Rescaling(1.0 / 255)
AUTOTUNE = tf.data.AUTOTUNE
train_ds = train_ds.map(lambda x, y: (norm(x), y)).cache().prefetch(AUTOTUNE)
val_ds   = val_ds.map(lambda x, y:   (norm(x), y)).cache().prefetch(AUTOTUNE)

# ── 3. Build model ────────────────────────────────────────────────────────────
base = MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights='imagenet',
)
base.trainable = False  # freeze base for first pass

model = models.Sequential([
    base,
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.3),
    layers.Dense(NUM_CLASSES, activation='softmax'),
])

# ── 4. Train with frozen base ─────────────────────────────────────────────────
model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy'],
)
model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_1)

# ── 5. Unfreeze top 30 layers and fine-tune ───────────────────────────────────
base.trainable = True
for layer in base.layers[:-30]:
    layer.trainable = False

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-5),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy'],
)
model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_2)

# ── 6. Export to TFLite ───────────────────────────────────────────────────────
converter    = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open('/content/cropguard_plant_disease_verified.tflite', 'wb') as f:
    f.write(tflite_model)

# ── 7. Save labels in the exact same order as model output nodes ──────────────
with open('/content/labels_verified.txt', 'w') as f:
    f.write('\n'.join(class_names))

print(f'✅  Exported {NUM_CLASSES} classes.')
print('Download cropguard_plant_disease_verified.tflite and labels_verified.txt from Colab.')
```

Download both files from the Colab file browser (left sidebar → Files).

---

## Step 4 — Update the app

### 4a. Replace the model and labels

```
assets/cropguard_plant_disease_verified.tflite  ← replace with the new file from Colab
assets/labels_verified.txt                      ← replace with the new file from Colab
```

### 4b. Update model metadata

Open `assets/model_metadata.json` and change `num_classes` to match your new count:

```json
{
  "model_name": "CropGuard Plant Disease Classifier",
  "model_file": "cropguard_plant_disease_verified.tflite",
  "input_size": 128,
  "input_channels": 3,
  "normalize_mean": [0.0, 0.0, 0.0],
  "normalize_std": [1.0, 1.0, 1.0],
  "num_classes": 107,
  "version": "3.0",
  "architecture": "MobileNetV2",
  "confidence_threshold": 0.60,
  "labels_file": "labels_verified.txt"
}
```

### 4c. Find which labels need new database entries

Add this temporarily to `main()` in `lib/main.dart`, after `setupServiceLocator()`:

```dart
import 'package:flutter/services.dart';
import 'data/ml/disease_info.dart';

// Inside main(), after setupServiceLocator():
final raw = await rootBundle.loadString('assets/labels_verified.txt');
final labels = raw.split('\n').where((l) => l.isNotEmpty).toList();
for (final label in labels) {
  final info = DiseaseDatabase.getInfo(label);
  if (info.cropType == 'Unknown') {
    debugPrint('MISSING ENTRY ▶ $label');
  }
}
```

Run `flutter run` and open the debug console. Every line printed is a label that
needs a new entry.

### 4d. Add entries to `lib/data/ml/disease_info.dart`

For each missing label, add a `DiseaseInfoEntry` block inside `_rawEntries`.
Follow this template — the `label:` field must **exactly** match the string
printed in the debug console:

```dart
// ─── Mango ────────────────────────────────────────────────────────────────
DiseaseInfoEntry(
  label: 'Mango___Anthracnose',        // must match labels_verified.txt exactly
  displayName: 'Mango Anthracnose',
  cropType: 'Mango',
  cause: 'Fungal infection by Colletotrichum gloeosporioides',
  severity: 'moderate',               // early | moderate | severe | healthy
  isHealthy: false,
  treatments: [
    'Prune and destroy infected twigs and fruits.',
    'Apply Mancozeb or copper-based fungicide at flowering.',
    'Harvest fruit promptly when ripe to avoid post-harvest infection.',
    'Store harvested mangoes in cool, ventilated conditions.',
  ],
),
DiseaseInfoEntry(
  label: 'Mango___healthy',
  displayName: 'Healthy Mango',
  cropType: 'Mango',
  cause: '',
  severity: 'healthy',
  isHealthy: true,
  treatments: [
    'Prune annually after harvest to maintain canopy.',
    'Monitor for mango hoppers during flowering.',
  ],
),
```

### 4e. Remove the debug check

Delete the temporary `debugPrint` loop from `main.dart` before shipping.

### 4f. Bump the database version (only if you changed the SQLite schema)

If you only added model classes and `disease_info.dart` entries — no SQLite
changes — you can skip this. If you added new database columns, open
`lib/data/local/database_helper.dart`, increment `_dbVersion`, and add a new
migration block:

```dart
static const _dbVersion = 12; // was 11

// Inside _onUpgrade:
if (oldVersion < 12) {
  // add new ALTER TABLE statements here
}
```

---

## Label naming rules

Always name training folders consistently so `disease_info.dart` entries are
predictable:

| Pattern | Use for |
|---------|---------|
| `Crop___Disease` | All new crops you add |
| `Crop___healthy` | The healthy class for every crop |

Avoid spaces in folder names — use underscores. The folder name becomes the
label string verbatim.

---

## Quick checklist

```
[ ] Collected 300+ images per new class (including a healthy class)
[ ] All images organised into one folder per class
[ ] Model trained and validated (aim for > 85 % validation accuracy)
[ ] cropguard_plant_disease_verified.tflite replaced in assets/
[ ] labels_verified.txt replaced in assets/
[ ] model_metadata.json num_classes updated
[ ] disease_info.dart has one DiseaseInfoEntry per label (no MISSING ENTRY lines)
[ ] Debug check removed from main.dart
[ ] flutter analyze reports no errors
[ ] Tested on a real device with a photo of each new crop
```

---

## Recommended Colab notebooks (ready to use)

| Purpose | Link |
|---------|------|
| PlantVillage fine-tuning | Search "Plant Disease Classification MobileNetV2" on Kaggle Notebooks |
| General image classification | [tensorflow.org/tutorials/images/transfer_learning](https://www.tensorflow.org/tutorials/images/transfer_learning) |
| TFLite conversion | [tensorflow.org/lite/models/modify/model_maker/image_classification](https://www.tensorflow.org/lite/models/modify/model_maker/image_classification) |

The TensorFlow Lite Model Maker library (second link) can also handle the entire
pipeline — data loading, training, and export — with fewer lines of code if you
prefer a simpler starting point.
