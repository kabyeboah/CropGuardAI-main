# CropGuard — New Model Integration Status

Last updated: 2026-08-29, by: Antigravity AI Assistant (real binary & codebase inspection session) [CURRENT]

---

## 1. Model Identity

- **File Name**: `assets/cropguard_plant_disease.tflite` (canonical production model: SHA-256 `a55cff8f192ca6e514c7964741f53faddcbd7e4c69e6eeded1c91b90e94641a7`, 9,121,360 bytes)
- **Labels File**: `assets/labels.txt` (51 lines, SHA-256 `5abb677a5d7344caef639b992355f55e8642d3e5138d04f1f0307262c5a99407`)
- **Metadata File**: `assets/model_metadata.json` (SHA-256 `64bcb1d306234f61a82064e4d45e8b5936abd619b7e0958a076c90300179c768`)
- **Location**: `assets/` in root Flutter app bundle
- **[BINARY-VERIFIED] File Identifier**: FlatBuffer header `TFL3` (version 3) at byte offset 4–8.
- **[BINARY-VERIFIED] Input Tensor**:
  - Name: `serving_default_image_input:0`
  - Shape: `[1, 128, 128, 3]` (Batch=1, Height=128, Width=128, Channels=3 RGB)
  - Data Type: `<class 'numpy.float32'>` (`Float32List`)
  - Quantization: Unquantized float32 weights / unquantized activation buffers (`scales: []`, `zero_points: []`)
- **[BINARY-VERIFIED] Output Tensor**:
  - Name: `StatefulPartitionedCall_1:0`
  - Shape: `[1, 51]` (Batch=1, 51 classes)
  - Data Type: `<class 'numpy.float32'>` (`Float32List`)
  - Format: Raw uncalibrated output logits (e.g. range spans approximately `[-15.78, 0.07]` on uniform inputs)
- **[BINARY-VERIFIED] Operator Graph & Execution Sequence (Total 66 Ops)**:
  - Total Tensors: 176
  - Unique Op Types Registered (TFLite FlatBuffer Opcode Table):
    - Opcode 0 (raw enum `18`): `RESIZE_BILINEAR` (1 occurrence)
    - Opcode 1 (raw enum `0`): `ADD` (11 occurrences — 1 input rescaling offset + 10 inverted bottleneck residual connections)
    - Opcode 2 (raw enum `3`): `CONV_2D` (35 occurrences — stem conv, $1 \times 1$ pointwise expansion/projection layers, and 1280-channel feature conv)
    - Opcode 3 (raw enum `4`): `DEPTHWISE_CONV_2D` (17 occurrences — $3 \times 3$ depthwise convolutions across bottleneck blocks)
    - Opcode 4 (raw enum `40`): `MEAN` (1 occurrence — **GlobalAveragePooling2D** collapsing spatial dimensions $[1, 4, 4, 1280] \to [1, 1280]$)
    - Opcode 5 (raw enum `9`): `FULLY_CONNECTED` (1 occurrence — dense linear projection $[1, 1280] \times [51, 1280]^T + [51] \to [1, 51]$ output logits)
  - Flex / Select-TF-Ops: **None** (Zero custom op codes in binary; executes natively in standard `ai_edge_litert` / `tflite_flutter` without requiring `libtensorflowlite_flex.so` or native delegates).

### [BINARY-VERIFIED] Full 66-Operator Execution Trace: Input $\to$ Output

| Op Index | Operator Name | Input Tensor Shape | Output Tensor Shape | Layer Output Name / Description | [CURRENT]
|---|---|---|---|---| [CURRENT]
| `00` | `RESIZE_BILINEAR` | `[1, 128, 128, 3]` | `[1, 128, 128, 3]` | `model_flutter_1/input_rescaling_1/mul` | [CURRENT]
| `01` | `ADD` | `[1, 128, 128, 3]` | `[1, 128, 128, 3]` | `model_flutter_1/input_rescaling_1/add` | [CURRENT]
| `02` | `CONV_2D` | `[1, 128, 128, 3]` | `[1, 64, 64, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/Conv1_relu` | [CURRENT]
| `03` | `DEPTHWISE_CONV_2D` | `[1, 64, 64, 32]` | `[1, 64, 64, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/expanded_conv_depthwise` | [CURRENT]
| `04` | `CONV_2D` | `[1, 64, 64, 32]` | `[1, 64, 64, 16]` | `model_flutter_1/mobilenetv2_1.00_128_1/expanded_conv_project` | [CURRENT]
| `05` | `CONV_2D` | `[1, 64, 64, 16]` | `[1, 64, 64, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_1_expand` | [CURRENT]
| `06` | `DEPTHWISE_CONV_2D` | `[1, 64, 64, 96]` | `[1, 32, 32, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_1_depthwise` | [CURRENT]
| `07` | `CONV_2D` | `[1, 32, 32, 96]` | `[1, 32, 32, 24]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_1_project` | [CURRENT]
| `08` | `CONV_2D` | `[1, 32, 32, 24]` | `[1, 32, 32, 144]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_2_expand` | [CURRENT]
| `09` | `DEPTHWISE_CONV_2D` | `[1, 32, 32, 144]` | `[1, 32, 32, 144]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_2_depthwise` | [CURRENT]
| `10` | `CONV_2D` | `[1, 32, 32, 144]` | `[1, 32, 32, 24]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_2_project` | [CURRENT]
| `11` | `ADD` | `[1, 32, 32, 24]` | `[1, 32, 32, 24]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_2_add/Add` | [CURRENT]
| `12` | `CONV_2D` | `[1, 32, 32, 24]` | `[1, 32, 32, 144]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_3_expand` | [CURRENT]
| `13` | `DEPTHWISE_CONV_2D` | `[1, 32, 32, 144]` | `[1, 16, 16, 144]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_3_depthwise` | [CURRENT]
| `14` | `CONV_2D` | `[1, 16, 16, 144]` | `[1, 16, 16, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_3_project` | [CURRENT]
| `15` | `CONV_2D` | `[1, 16, 16, 32]` | `[1, 16, 16, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_4_expand` | [CURRENT]
| `16` | `DEPTHWISE_CONV_2D` | `[1, 16, 16, 192]` | `[1, 16, 16, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_4_depthwise` | [CURRENT]
| `17` | `CONV_2D` | `[1, 16, 16, 192]` | `[1, 16, 16, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_4_project` | [CURRENT]
| `18` | `ADD` | `[1, 16, 16, 32]` | `[1, 16, 16, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_4_add/Add` | [CURRENT]
| `19` | `CONV_2D` | `[1, 16, 16, 32]` | `[1, 16, 16, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_5_expand` | [CURRENT]
| `20` | `DEPTHWISE_CONV_2D` | `[1, 16, 16, 192]` | `[1, 16, 16, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_5_depthwise` | [CURRENT]
| `21` | `CONV_2D` | `[1, 16, 16, 192]` | `[1, 16, 16, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_5_project` | [CURRENT]
| `22` | `ADD` | `[1, 16, 16, 32]` | `[1, 16, 16, 32]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_5_add/Add` | [CURRENT]
| `23` | `CONV_2D` | `[1, 16, 16, 32]` | `[1, 16, 16, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_6_expand` | [CURRENT]
| `24` | `DEPTHWISE_CONV_2D` | `[1, 16, 16, 192]` | `[1, 8, 8, 192]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_6_depthwise` | [CURRENT]
| `25` | `CONV_2D` | `[1, 8, 8, 192]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_6_project` | [CURRENT]
| `26` | `CONV_2D` | `[1, 8, 8, 64]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_7_expand` | [CURRENT]
| `27` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_7_depthwise` | [CURRENT]
| `28` | `CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_7_project` | [CURRENT]
| `29` | `ADD` | `[1, 8, 8, 64]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_7_add/Add` | [CURRENT]
| `30` | `CONV_2D` | `[1, 8, 8, 64]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_8_expand` | [CURRENT]
| `31` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_8_depthwise` | [CURRENT]
| `32` | `CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_8_project` | [CURRENT]
| `33` | `ADD` | `[1, 8, 8, 64]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_8_add/Add` | [CURRENT]
| `34` | `CONV_2D` | `[1, 8, 8, 64]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_9_expand` | [CURRENT]
| `35` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_9_depthwise` | [CURRENT]
| `36` | `CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_9_project` | [CURRENT]
| `37` | `ADD` | `[1, 8, 8, 64]` | `[1, 8, 8, 64]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_9_add/Add` | [CURRENT]
| `38` | `CONV_2D` | `[1, 8, 8, 64]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_10_expand` | [CURRENT]
| `39` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 384]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_10_depthwise` | [CURRENT]
| `40` | `CONV_2D` | `[1, 8, 8, 384]` | `[1, 8, 8, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_10_project` | [CURRENT]
| `41` | `CONV_2D` | `[1, 8, 8, 96]` | `[1, 8, 8, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_11_expand` | [CURRENT]
| `42` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 576]` | `[1, 8, 8, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_11_depthwise` | [CURRENT]
| `43` | `CONV_2D` | `[1, 8, 8, 576]` | `[1, 8, 8, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_11_project` | [CURRENT]
| `44` | `ADD` | `[1, 8, 8, 96]` | `[1, 8, 8, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_11_add/Add` | [CURRENT]
| `45` | `CONV_2D` | `[1, 8, 8, 96]` | `[1, 8, 8, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_12_expand` | [CURRENT]
| `46` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 576]` | `[1, 8, 8, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_12_depthwise` | [CURRENT]
| `47` | `CONV_2D` | `[1, 8, 8, 576]` | `[1, 8, 8, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_12_project` | [CURRENT]
| `48` | `ADD` | `[1, 8, 8, 96]` | `[1, 8, 8, 96]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_12_add/Add` | [CURRENT]
| `49` | `CONV_2D` | `[1, 8, 8, 96]` | `[1, 8, 8, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_13_expand` | [CURRENT]
| `50` | `DEPTHWISE_CONV_2D` | `[1, 8, 8, 576]` | `[1, 4, 4, 576]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_13_depthwise` | [CURRENT]
| `51` | `CONV_2D` | `[1, 4, 4, 576]` | `[1, 4, 4, 160]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_13_project` | [CURRENT]
| `52` | `CONV_2D` | `[1, 4, 4, 160]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_14_expand` | [CURRENT]
| `53` | `DEPTHWISE_CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_14_depthwise` | [CURRENT]
| `54` | `CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 160]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_14_project` | [CURRENT]
| `55` | `ADD` | `[1, 4, 4, 160]` | `[1, 4, 4, 160]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_14_add/Add` | [CURRENT]
| `56` | `CONV_2D` | `[1, 4, 4, 160]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_15_expand` | [CURRENT]
| `57` | `DEPTHWISE_CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_15_depthwise` | [CURRENT]
| `58` | `CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 160]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_15_project` | [CURRENT]
| `59` | `ADD` | `[1, 4, 4, 160]` | `[1, 4, 4, 160]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_15_add/Add` | [CURRENT]
| `60` | `CONV_2D` | `[1, 4, 4, 160]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_16_expand` | [CURRENT]
| `61` | `DEPTHWISE_CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 960]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_16_depthwise` | [CURRENT]
| `62` | `CONV_2D` | `[1, 4, 4, 960]` | `[1, 4, 4, 320]` | `model_flutter_1/mobilenetv2_1.00_128_1/block_16_project` | [CURRENT]
| `63` | `CONV_2D` | `[1, 4, 4, 320]` | `[1, 4, 4, 1280]` | `model_flutter_1/mobilenetv2_1.00_128_1/Conv_1` (feature expansion) | [CURRENT]
| `64` | `MEAN` | `[1, 4, 4, 1280]` | `[1, 1280]` | `model_flutter_1/global_average_pooling_1/Mean` (**Spatial collapse**) | [CURRENT]
| `65` | `FULLY_CONNECTED` | `[1, 1280]` | `[1, 51]` | `StatefulPartitionedCall_1:0` (**51 Logits Output**) | [CURRENT]

- **[CODE-TRACED] Normalization Scheme & Input Constants**:
  - Model architecture incorporates an internal Keras `Rescaling(scale=1./127.5, offset=-1)` layer (visible as Ops 00 & 01).
  - Feeding raw pixel values `[0, 255]` into the input tensor produces active logit distributions centered near 0.
  - Feeding `[0, 1]` pre-divided values (the old V1 pipeline bug) causes double normalization into `[-1, -0.992]`, suppressing model activations.
  - Traced implementation in [crop_disease_classifier.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L143-L156):
    ```dart
    // Contiguous [1 * 128 * 128 * 3] float tensor — RAW [0, 255]
    final inputTensor = Float32List(1 * inputSize * inputSize * 3);
    var idx = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        inputTensor[idx++] = pixel.r.toDouble();
        inputTensor[idx++] = pixel.g.toDouble();
        inputTensor[idx++] = pixel.b.toDouble();
      }
    }
    ```
- **[UNVERIFIED] Calibration Temperature (`1.3409216403961182`)**:
  - The temperature parameter $T = 1.3409$ is **not embedded in the TFLite computational graph**.
  - It was derived post-hoc in Colab notebook cell 43 via Temperature Scaling (`loss = cross_entropy(logits / T, y_true)` optimized over validation logits) and saved into `model_metadata.json`.
  - [CropDiseaseClassifier](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L210-L219) loads this float from `model_metadata.json` and computes $P_i = \text{softmax}(\text{logit}_i / T)$ unconditionally on the main thread.

---

## 2. Label Mapping

- **[CODE-TRACED] Derivation of Label Order**:
  - In `cropguard_retrain_v2_optimized (3).ipynb`, label order is generated directly by alphabetical directory sorting:
    ```python
    # Cell 17 / Step 4b
    class_names = sorted(os.listdir(CONSOLIDATED_DIR))
    
    # Cell 45 / Step 11
    with open(labels_path, 'w') as f:
        f.write('\n'.join(class_names))
    ```
  - `tf.keras.utils.image_dataset_from_directory` assigns numeric class indices based on standard alphanumeric directory sort order, matching `class_names` by construction.
- **[BINARY-VERIFIED] Output Dimension**:
  - TFLite output tensor `StatefulPartitionedCall_1:0` has shape `[1, 51]`, corresponding to **51 classes**.
- **[CODE-TRACED] Label File Alignment**:
  - `assets/labels_verified.txt`: **51 non-empty lines**.
  - Alphabetic sorting in `assets/labels_verified.txt`: **Confirmed strictly sorted alphabetically** from `Banana___Cordana` at index 0 to `Tomato___Verticillium_Wilt` at index 50.
  - All 51 labels map 1:1 to fully populated entries in [DiseaseDatabase](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/disease_info.dart#L1538-L2130) (verified by unit test in [crop_disease_classifier_test.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test/data/ml/crop_disease_classifier_test.dart#L248-L272)).

---

## 3. What's Done

| Phase / Step | Status | Evidence / File:Line Reference | [CURRENT]
|---|---|---| [CURRENT]
| **Phase 0 — Binary Verification** | **COMPLETED** | Loaded with `ai_edge_litert` 2.2.0 in Python. [CURRENT] Verified shape `[1, 128, 128, 3]`, output `[1, 51]`, complete 66-op execution trace (`CONV_2D`, `DEPTHWISE_CONV_2D`, `ADD`, `MEAN`, `FULLY_CONNECTED`, `RESIZE_BILINEAR`), raw `[0, 255]` activation behavior. [CURRENT] | [CURRENT]
| **Phase 1 — Asset Staging** | **COMPLETED** | Bundled `assets/cropguard_plant_disease_verified.tflite` (9.1 MB) and `assets/labels_verified.txt` (51 lines). [CURRENT] Listed in [pubspec.yaml](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/pubspec.yaml#L151-L155). [CURRENT] | [CURRENT]
| **Phase 2 — Single Model Classifier Refactoring** | **COMPLETED** | - Removed `_labelsV2`, `_interpreterV2`, and ensemble heuristics from [crop_disease_classifier.dart](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L254-L259).<br>- Input size set to 128 ([crop_disease_classifier.dart:250](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L250)).<br>- Raw `[0, 255]` pixel filling implemented ([crop_disease_classifier.dart:147-156](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L147-L156)).<br>- Unconditional temperature scaling implemented ([crop_disease_classifier.dart:210-220](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/crop_disease_classifier.dart#L210-L220)).<br>- Deleted `_selectBestFromEnsemble()`. [DEPRECATED] | [CURRENT]
| **Phase 3 — Update Dual/Versioned Call Sites** | **COMPLETED** | - Result screen uses `DiseaseDatabase.getAllLabels()` ([result_screen.dart:44](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/result/result_screen.dart#L44)).<br>- Settings dynamically loads verified model version and provides honest update checks ([settings_provider.dart:245-279](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/settings/settings_provider.dart#L245-L279), [settings_screen.dart:102-135](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/settings/settings_screen.dart#L102-L135)).<br>- Doc comments and guides updated ([disease_info.dart:3](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/data/ml/disease_info.dart#L3), [outbreak_map_screen.dart:147](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/lib/presentation/screens/outbreak_map/outbreak_map_screen.dart#L147), [MODEL_EXPANSION_GUIDE.md](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_EXPANSION_GUIDE.md), [MODEL_ACCURACY.md](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/MODEL_ACCURACY.md), [RETRAIN_INSTRUCTIONS.md](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/RETRAIN_INSTRUCTIONS.md), [CLAUDE.md:57](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/CLAUDE.md#L57)).<br>- Unit tests added for label alignment and settings updates ([crop_disease_classifier_test.dart:248-272](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test/data/ml/crop_disease_classifier_test.dart#L248-L272), [settings_provider_test.dart:87-106](file:///Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/test/presentation/screens/settings/settings_provider_test.dart#L87-L106)).<br>- All 397 Flutter tests passing cleanly. [CURRENT] | [CURRENT]

---

## 4. What's NOT Done / Open Risks

1. [CURRENT] **[UNVERIFIED] Real Field-Accuracy Validation is Still Missing**: [CURRENT]
   - The only accuracy number that currently exists is Google Colab's self-reported **63.9% validation accuracy** (from synthetic / web validation splits in `cropguard_retrain_v2_optimized (3).ipynb`).
   - The model has **NOT** been evaluated against a real held-out field dataset of Ghanaian farmer photos.
   - The earlier spot-check attempt (3/15 = 20%) used UI stock thumbnails and was invalid as an evaluation benchmark. Real field accuracy remains empirically unknown.
2. [CURRENT] **Metadata Export Bug in Training Pipeline (Fix #45)**: [CURRENT]
   - In Step 11 of the notebook (`cropguard_retrain_v2_optimized (3).ipynb`), the metadata export code hardcoded `'normalize_std': [255.0, 255.0, 255.0]` despite the model using raw `[0, 255]` inputs.
   - `assets/model_metadata.json` in the Flutter repo was manually corrected to `[1.0, 1.0, 1.0]`. If the notebook is re-run without patching Step 11, newly exported `model_metadata.json` files will reintroduce this discrepancy.
3. [CURRENT] **Phase 4 Asset File Cleanup**: [CURRENT]
   - Legacy filenames `assets/cropguard_plant_disease.tflite` and `assets/labels.txt` still physically exist on disk (as byte-for-byte copies of the verified files to prevent external breakage).
   - Once all tooling/scripts standardize on the verified naming, these duplicate files can be deleted.

---

## 5. Next Required Action

Before this model can be considered production-certified for field release, it must be evaluated on an actual held-out test set of real farmer photos using `tools/evaluate_model.py` or `integration_test/model_eval_test.dart` to establish true empirical precision, recall, and calibration error. [CURRENT]
