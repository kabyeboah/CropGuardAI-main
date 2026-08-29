# Disease images

One representative photo per disease, shown in the Disease Library (list
thumbnail + detail banner). A bundled asset works offline and is the most
reliable source — prefer it over the network fallback.

## Naming convention

The filename is the disease **label** (from `assets/labels_verified.txt` /
`DiseaseInfoEntry.label`) "slugified": every run of non-alphanumeric characters
is replaced with a single underscore, then `.jpg` is appended.

This matches `_slugifyLabel()` in
`lib/presentation/screens/library/disease_library_screen.dart`.

Examples:

| Disease label                              | Asset filename                          |
| ------------------------------------------ | --------------------------------------- |
| `Apple___Apple_scab`                       | `Apple_Apple_scab.jpg`                  |
| `Corn_(maize)___Northern_Leaf_Blight`      | `Corn_maize_Northern_Leaf_Blight.jpg`   |
| `Pepper,_bell___Bacterial_spot`            | `Pepper_bell_Bacterial_spot.jpg`        |
| `Tomato___Late_blight`                     | `Tomato_Late_blight.jpg`                |

## How to add an image

1. Drop a JPEG named per the convention into this folder.
2. Add its **label** to the `_kDiseaseAssetLabels` set in
   `disease_library_screen.dart`.
3. `flutter pub get` (picks up new files under the declared `assets/diseases/`
   folder) and rebuild.

Diseases with no bundled asset fall back to a verified network disease photo
(if one exists in `_kDiseaseImages`) and then to the crop image — so missing
files never break the UI.

## Sourcing note

For correctness, prefer one labelled example per class from the dataset the
model was trained on (PlantVillage-style classes + the project's Ghana-specific
classes). Avoid unverified web images in a diagnostic app — a misidentified
disease photo is worse than a generic crop photo.

## Pending: bundle these (currently served from network)

These diseases now have a verified disease-specific **network** photo in
`_kDiseaseImages` (so they no longer share the generic crop image), but they are
**not yet bundled** as offline assets. To make them offline-correct, drop a
JPEG with the filename below into this folder and add the label to
`_kDiseaseAssetLabels` — the bundled asset then takes priority over the network
URL automatically. Source each from the Wikimedia Commons file already wired up
(see the URL next to the label in `disease_library_screen.dart`).

| Disease label                              | Asset filename                            |
| ------------------------------------------ | ----------------------------------------- |
| `Tomato___Early_blight`                    | `Tomato_Early_blight.jpg`                 |
| `Tomato___Late_blight`                     | `Tomato_Late_blight.jpg`                  |
| `Tomato___Leaf_Mold`                       | `Tomato_Leaf_Mold.jpg`                    |
| `Tomato___Septoria_leaf_spot`              | `Tomato_Septoria_leaf_spot.jpg`           |
| `Tomato___Target_Spot`                     | `Tomato_Target_Spot.jpg`                  |
| `Tomato___Tomato_mosaic_virus`             | `Tomato_Tomato_mosaic_virus.jpg`          |
| `Tomato___Ralstonia_Wilt`                  | `Tomato_Ralstonia_Wilt.jpg`               |
| `Mango___Anthracnose`                      | `Mango_Anthracnose.jpg`                   |
| `Mango___Powdery_Mildew`                   | `Mango_Powdery_Mildew.jpg`                |
| `Mango___Sooty_Mould`                      | `Mango_Sooty_Mould.jpg`                   |
| `Banana_Black_Sigatoka`                    | `Banana_Black_Sigatoka.jpg`               |
| `Banana_Fusarium_Wilt`                     | `Banana_Fusarium_Wilt.jpg`                |
| `Cassava_Brown_Streak_Disease`             | `Cassava_Brown_Streak_Disease.jpg`        |
| `Corn_(maize)___Common_rust_`              | `Corn_maize_Common_rust_.jpg`             |
| `Cocoa___Black_Pod_Rot`                    | `Cocoa_Black_Pod_Rot.jpg`                 |
| `Cocoa___Swollen_Shoot_Virus`             | `Cocoa_Swollen_Shoot_Virus.jpg`           |
| `Orange___Haunglongbing_(Citrus_greening)` | `Orange_Haunglongbing_Citrus_greening_.jpg` |
| `Pepper,_bell___Bacterial_spot`            | `Pepper_bell_Bacterial_spot.jpg`          |

### Still on the generic crop fallback (no verified free photo found)

Garden Egg (all 6), Cassava Mosaic / Bacterial Blight / Green Mottle, Banana
Moko / Yellow Sigatoka / Insect Pest, most Cashew / Yam / Plantain / Sorghum /
Millet / Oil Palm / Cowpea classes, Tomato Bacterial Spot / Spider Mites /
TYLCV, and Grape Esca. These are mostly Ghana-specific MoFA/CRIG classes with no
free-licensed field photo on Commons — bundling a dataset image is the only
reliable fix for them.
