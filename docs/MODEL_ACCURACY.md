# Model Accuracy Report

> **Status: NOT YET MEASURED.** This is the single most important
> production-readiness gap. A crop-disease detector must publish validated
> accuracy before launch.

## How to produce this report

1. Assemble a **held-out test set** the model was never trained or validated on.
   - One sub-folder per class, named exactly as in `assets/labels.txt`.
   - Prefer **real field photos from Ghana** (farmer-captured, varied lighting,
     real cameras) over clean lab images — that's the deployment distribution.
   - Aim for ≥30 images per class where possible.
2. Run the evaluation harness (see `integration_test/model_eval_test.dart`):
   ```bash
   adb push ./test_set /data/local/tmp/cropguard_test_set
   flutter test integration_test/model_eval_test.dart \
     --dart-define=TEST_SET_DIR=/data/local/tmp/cropguard_test_set
   ```
3. Paste the printed report below and commit it.

## Results

| Metric | Value |
|--------|-------|
| Test set source | _TBD_ |
| Number of samples | _TBD_ |
| Overall accuracy | _TBD_ |
| Macro F1 | _TBD_ |
| Date measured | _TBD_ |
| Model file | `assets/cropguard_plant_disease.tflite` |

### Per-class metrics
_Paste the harness output here._

### Confusion matrix notes
_Call out the worst confusions (e.g. early vs. late blight) and any class with
recall < 0.5 — those need more training data or a UI caveat._

## Interpreting for launch

- The harness fails below **70% accuracy** as a hard floor; treat that as a
  bug, not a passing build.
- For classes that perform poorly, either (a) collect more local training data,
  (b) merge ambiguous classes, or (c) surface the low-confidence flow more
  aggressively and route to the expert-help path.
- Re-run and update this file whenever the `.tflite` model changes.
