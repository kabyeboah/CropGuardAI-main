# Disease images

One representative photo per disease, shown in the Disease Library (list [CURRENT]
thumbnail + detail banner). [CURRENT] A bundled asset works offline and is the most [CURRENT]
reliable source — prefer it over the network fallback. [CURRENT]

## Naming convention

The filename is the disease **label** (from `assets/labels.txt` / [CURRENT]
`DiseaseInfoEntry.label`) "slugified": every run of non-alphanumeric characters [CURRENT]
is replaced with a single underscore, then `.jpg` is appended. [CURRENT]

This matches `_slugifyLabel()` in [CURRENT]
`lib/presentation/screens/library/disease_library_screen.dart`. [CURRENT]

Examples: [CURRENT]

| Disease label                              | Asset filename                          | [CURRENT]
| ------------------------------------------ | --------------------------------------- | [CURRENT]
| `Apple___Apple_scab`                       | `Apple_Apple_scab.jpg`                  | [CURRENT]
| `Corn_(maize)___Northern_Leaf_Blight`      | `Corn_maize_Northern_Leaf_Blight.jpg`   | [CURRENT]
| `Pepper,_bell___Bacterial_spot`            | `Pepper_bell_Bacterial_spot.jpg`        | [CURRENT]
| `Tomato___Late_blight`                     | `Tomato_Late_blight.jpg`                | [CURRENT]

## How to add an image

1. [CURRENT] Drop a JPEG named per the convention into this folder. [HISTORICAL]
2. [CURRENT] Add its **label** to the `_kDiseaseAssetLabels` set in [CURRENT]
`disease_library_screen.dart`. [CURRENT]
3. [CURRENT] `flutter pub get` (picks up new files under the declared `assets/diseases/` [CURRENT]
folder) and rebuild. [HISTORICAL]

Diseases with no bundled asset fall back to a verified network disease photo [CURRENT]
(if one exists in `_kDiseaseImages`) and then to the crop image — so missing [CURRENT]
files never break the UI. [CURRENT]

## Sourcing note

For correctness, prefer one labelled example per class from the dataset the [CURRENT]
model was trained on (PlantVillage-style classes + the project's Ghana-specific [CURRENT]
classes). [CURRENT] Avoid unverified web images in a diagnostic app — a misidentified [CURRENT]
disease photo is worse than a generic crop photo. [CURRENT]

## Pending: bundle these (currently served from network)

These diseases now have a verified disease-specific **network** photo in [CURRENT]
`_kDiseaseImages` (so they no longer share the generic crop image), but they are [CURRENT]
**not yet bundled** as offline assets. To make them offline-correct, drop a
JPEG with the filename below into this folder and add the label to [HISTORICAL]
`_kDiseaseAssetLabels` — the bundled asset then takes priority over the network [CURRENT]
URL automatically. [CURRENT] Source each from the Wikimedia Commons file already wired up [CURRENT]
(see the URL next to the label in `disease_library_screen.dart`). [CURRENT]

| Disease label                              | Asset filename                            | [CURRENT]
| ------------------------------------------ | ----------------------------------------- | [CURRENT]
| `Tomato___Early_blight`                    | `Tomato_Early_blight.jpg`                 | [CURRENT]
| `Tomato___Late_blight`                     | `Tomato_Late_blight.jpg`                  | [CURRENT]
| `Tomato___Leaf_Mold`                       | `Tomato_Leaf_Mold.jpg`                    | [HISTORICAL]
| `Tomato___Septoria_leaf_spot`              | `Tomato_Septoria_leaf_spot.jpg`           | [CURRENT]
| `Tomato___Target_Spot`                     | `Tomato_Target_Spot.jpg`                  | [CURRENT]
| `Tomato___Tomato_mosaic_virus`             | `Tomato_Tomato_mosaic_virus.jpg`          | [CURRENT]
| `Tomato___Ralstonia_Wilt`                  | `Tomato_Ralstonia_Wilt.jpg`               | [CURRENT]
| `Mango___Anthracnose`                      | `Mango_Anthracnose.jpg`                   | [CURRENT]
| `Mango___Powdery_Mildew`                   | `Mango_Powdery_Mildew.jpg`                | [CURRENT]
| `Mango___Sooty_Mould`                      | `Mango_Sooty_Mould.jpg`                   | [CURRENT]
| `Banana_Black_Sigatoka`                    | `Banana_Black_Sigatoka.jpg`               | [CURRENT]
| `Banana_Fusarium_Wilt`                     | `Banana_Fusarium_Wilt.jpg`                | [CURRENT]
| `Cassava_Brown_Streak_Disease`             | `Cassava_Brown_Streak_Disease.jpg`        | [CURRENT]
| `Corn_(maize)___Common_rust_`              | `Corn_maize_Common_rust_.jpg`             | [CURRENT]
| `Cocoa___Black_Pod_Rot`                    | `Cocoa_Black_Pod_Rot.jpg`                 | [CURRENT]
| `Cocoa___Swollen_Shoot_Virus`             | `Cocoa_Swollen_Shoot_Virus.jpg`           | [CURRENT]
| `Orange___Haunglongbing_(Citrus_greening)` | `Orange_Haunglongbing_Citrus_greening_.jpg` | [CURRENT]
| `Pepper,_bell___Bacterial_spot`            | `Pepper_bell_Bacterial_spot.jpg`          | [CURRENT]

### Still on the generic crop fallback (no verified free photo found)

Garden Egg (all 6), Cassava Mosaic / Bacterial Blight / Green Mottle, Banana [CURRENT]
Moko / Yellow Sigatoka / Insect Pest, most Cashew / Yam / Plantain / Sorghum / [CURRENT]
Millet / Oil Palm / Cowpea classes, Tomato Bacterial Spot / Spider Mites / [CURRENT]
TYLCV, and Grape Esca. [CURRENT] These are mostly Ghana-specific MoFA/CRIG classes with no [CURRENT]
free-licensed field photo on Commons — bundling a dataset image is the only [CURRENT]
reliable fix for them. [CURRENT]
