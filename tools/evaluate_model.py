#!/usr/bin/env python3
"""
CropGuard AI — Model Accuracy & Confidence Calibration Evaluation Harness.

Evaluates an exported TFLite crop disease classification model on a held-out
test dataset structured ImageNet-style:
    test_set/
        Tomato___Late_blight/
            img_001.jpg
            ...
        Cocoa___Black_pod_rot/
            img_001.jpg
            ...

Computes:
  - Overall Top-1 & Top-3 Accuracy
  - Macro F1 & Weighted F1
  - Per-class Precision, Recall, F1-score, and Support
  - Confusion Matrix
  - Expected Calibration Error (ECE) across 10 confidence bins
  - Threshold Sweep Analysis (Accuracy vs Coverage for tau in [0.30..0.90])
  - Formatted Markdown table block for docs/MODEL_ACCURACY.md

Usage:
  python3 tools/evaluate_model.py \
      --model assets/cropguard_plant_disease_verified.tflite \
      --labels assets/labels_verified.txt \
      --test-set path/to/held_out_test_set \
      --output-md docs/MODEL_ACCURACY.md
"""

import argparse
import importlib
import json
import math
import os
import sys
from collections import defaultdict
from typing import Dict, List, Optional, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="CropGuard AI Model Evaluation & Calibration Tool"
    )
    parser.add_argument(
        "--model",
        type=str,
        default="assets/cropguard_plant_disease_verified.tflite",
        help="Path to the .tflite model file",
    )
    parser.add_argument(
        "--labels",
        type=str,
        default="assets/labels_verified.txt",
        help="Path to the labels_verified.txt file",
    )
    parser.add_argument(
        "--test-set",
        type=str,
        required=False,
        help="Path to the held-out test set directory (sub-folders per class)",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.60,
        help="Production confidence threshold (default: 0.60)",
    )
    parser.add_argument(
        "--input-size",
        type=int,
        default=128,
        help="Model input width/height in pixels (default: 128)",
    )
    parser.add_argument(
        "--output-md",
        type=str,
        default=None,
        help="Path to markdown file to write or update",
    )
    parser.add_argument(
        "--output-json",
        type=str,
        default=None,
        help="Path to json file to export raw evaluation data",
    )
    return parser.parse_args()


def load_labels(labels_path: str) -> List[str]:
    if not os.path.exists(labels_path):
        raise FileNotFoundError(f"Labels file not found: {labels_path}")
    with open(labels_path, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    return labels


def find_images(test_set_dir: str) -> List[Tuple[str, str]]:
    """Gathers (image_path, ground_truth_label) pairs from class subdirectories."""
    valid_exts = {".jpg", ".jpeg", ".png", ".webp"}
    samples = []
    if not os.path.isdir(test_set_dir):
        raise FileNotFoundError(f"Test set directory not found: {test_set_dir}")

    for class_name in sorted(os.listdir(test_set_dir)):
        class_dir = os.path.join(test_set_dir, class_name)
        if not os.path.isdir(class_dir):
            continue
        for fname in sorted(os.listdir(class_dir)):
            ext = os.path.splitext(fname)[1].lower()
            if ext in valid_exts:
                samples.append((os.path.join(class_dir, fname), class_name))
    return samples


class TFLiteEvaluator:
    def __init__(self, model_path: str, labels: List[str], input_size: int = 128):
        self.model_path = model_path
        self.labels = labels
        self.input_size = input_size
        self.interpreter = None
        self._init_interpreter()

    def _init_interpreter(self):
        try:
            tf = importlib.import_module("tensorflow")
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
        except ImportError:
            try:
                tflite_mod = importlib.import_module("tflite_runtime.interpreter")
                self.interpreter = tflite_mod.Interpreter(model_path=self.model_path)
                self.interpreter.allocate_tensors()
                self.input_details = self.interpreter.get_input_details()
                self.output_details = self.interpreter.get_output_details()
            except ImportError:
                self.interpreter = None

    def predict(self, image_path: str) -> List[Tuple[str, float]]:
        """Returns sorted list of (label, confidence) for top predictions."""
        if self.interpreter is None:
            raise RuntimeError(
                "Neither tensorflow nor tflite_runtime is installed. "
                "Please run: pip install tensorflow OR pip install tflite-runtime pillow numpy"
            )

        try:
            pil_image = importlib.import_module("PIL.Image")
            np = importlib.import_module("numpy")
        except ImportError:
            raise RuntimeError(
                "Required dependencies 'pillow' and 'numpy' are not installed. "
                "Please run: pip install pillow numpy"
            )

        img = pil_image.open(image_path).convert("RGB")
        img = img.resize((self.input_size, self.input_size))
        # Feed raw [0, 255] float values. The model graph contains an internal
        # Rescaling layer (x/127.5 - 1.0) and must NOT be divided by 255.0 here.
        input_data = np.expand_dims(img, axis=0).astype(np.float32)

        self.interpreter.set_tensor(self.input_details[0]["index"], input_data)
        self.interpreter.invoke()
        output_data = self.interpreter.get_tensor(self.output_details[0]["index"])[0]

        # Model outputs raw logits; apply softmax to obtain normalized probabilities
        exp_scores = np.exp(output_data - np.max(output_data))
        output_data = exp_scores / np.sum(exp_scores)

        results = []
        for idx, conf in enumerate(output_data):
            label = self.labels[idx] if idx < len(self.labels) else f"Class_{idx}"
            results.append((label, float(conf)))

        results.sort(key=lambda x: x[1], reverse=True)
        return results


def compute_metrics(
    predictions: List[Dict],
    ground_truth_classes: List[str],
    threshold: float = 0.60,
) -> Dict:
    """Computes precision, recall, F1, ECE, and confusion matrix."""
    total = len(predictions)
    if total == 0:
        return {}

    correct_top1 = sum(1 for p in predictions if p["predicted"] == p["truth"])
    correct_top3 = sum(1 for p in predictions if p["truth"] in p.get("top3", []))

    # Confusion matrix
    all_classes = sorted(list(set(ground_truth_classes + [p["predicted"] for p in predictions])))
    confusion = {t: defaultdict(int) for t in all_classes}
    for p in predictions:
        confusion[p["truth"]][p["predicted"]] += 1

    per_class = {}
    macro_f1_sum = 0.0
    weighted_f1_sum = 0.0
    total_support = 0

    for c in all_classes:
        tp = confusion[c][c]
        support = sum(confusion[c].values())
        fp = sum(confusion[other][c] for other in all_classes if other != c)
        fn = sum(confusion[c][other] for other in all_classes if other != c)

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0

        per_class[c] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": support,
            "tp": tp,
            "fp": fp,
            "fn": fn,
        }

        if c in ground_truth_classes:
            macro_f1_sum += f1
            weighted_f1_sum += f1 * support
            total_support += support

    macro_f1 = macro_f1_sum / len(ground_truth_classes) if ground_truth_classes else 0.0
    weighted_f1 = weighted_f1_sum / total_support if total_support > 0 else 0.0

    # Threshold metrics
    confident = [p for p in predictions if p["confidence"] >= threshold]
    confident_correct = sum(1 for p in confident if p["predicted"] == p["truth"])
    coverage = len(confident) / total if total > 0 else 0.0
    confident_accuracy = (confident_correct / len(confident)) if confident else 0.0

    # Threshold sweep: tau in 0.30..0.90
    sweep = []
    for tau in [0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90]:
        c_sub = [p for p in predictions if p["confidence"] >= tau]
        c_acc = (sum(1 for p in c_sub if p["predicted"] == p["truth"]) / len(c_sub)) if c_sub else 0.0
        c_cov = len(c_sub) / total
        sweep.append({"threshold": tau, "coverage": c_cov, "accuracy": c_acc, "samples": len(c_sub)})

    # Expected Calibration Error (ECE) over 10 bins
    num_bins = 10
    ece = 0.0
    bin_details = []
    for b in range(num_bins):
        b_low = b / num_bins
        b_high = (b + 1) / num_bins
        if b == num_bins - 1:
            bin_preds = [p for p in predictions if b_low <= p["confidence"] <= b_high]
        else:
            bin_preds = [p for p in predictions if b_low <= p["confidence"] < b_high]

        if bin_preds:
            bin_acc = sum(1 for p in bin_preds if p["predicted"] == p["truth"]) / len(bin_preds)
            bin_conf = sum(p["confidence"] for p in bin_preds) / len(bin_preds)
            bin_weight = len(bin_preds) / total
            ece += abs(bin_acc - bin_conf) * bin_weight
            bin_details.append({
                "bin": f"[{b_low:.1f}, {b_high:.1f}]",
                "count": len(bin_preds),
                "accuracy": bin_acc,
                "confidence": bin_conf,
                "diff": abs(bin_acc - bin_conf),
            })

    return {
        "total_samples": total,
        "top1_accuracy": correct_top1 / total,
        "top3_accuracy": correct_top3 / total,
        "macro_f1": macro_f1,
        "weighted_f1": weighted_f1,
        "threshold": threshold,
        "coverage": coverage,
        "confident_accuracy": confident_accuracy,
        "ece": ece,
        "per_class": per_class,
        "confusion": {k: dict(v) for k, v in confusion.items()},
        "threshold_sweep": sweep,
        "calibration_bins": bin_details,
    }


def generate_markdown_report(metrics: Dict, model_name: str, test_set_path: str) -> str:
    """Generates the Markdown document content for MODEL_ACCURACY.md."""
    lines = [
        "# Model Accuracy & Confidence Calibration Report",
        "",
        "> **Audit Status:** This document records empirical accuracy benchmarks and confidence",
        "> calibration curves for the CropGuard AI mobile disease classifier.",
        "",
        "## Evaluation Summary",
        "",
        f"| Metric | Measured Value | Target / Release Standard |",
        f"|---|---|---|",
        f"| **Model Artifact** | `{model_name}` | Construction-aligned classes |",
        f"| **Test Set Path** | `{test_set_path}` | Held-out field dataset |",
        f"| **Total Test Samples** | {metrics.get('total_samples', 0)} | $\\ge 15\\text{{--}}20$ per class |",
        f"| **Overall Top-1 Accuracy** | **{metrics.get('top1_accuracy', 0.0)*100:.2f}%** | $\\ge 85.00\\%$ (Hard Floor: $70.00\\%$) |",
        f"| **Top-3 Accuracy** | {metrics.get('top3_accuracy', 0.0)*100:.2f}% | $\\ge 95.00\\%$ |",
        f"| **Macro F1** | **{metrics.get('macro_f1', 0.0)*100:.2f}%** | $\\ge 80.00\\%$ |",
        f"| **Weighted F1** | {metrics.get('weighted_f1', 0.0)*100:.2f}% | $\\ge 85.00\\%$ |",
        f"| **Expected Calibration Error (ECE)** | **{metrics.get('ece', 0.0)*100:.2f}%** | $\\le 10.00\\%$ (10 bins) |",
        f"| **Coverage at $\\tau = {metrics.get('threshold', 0.60):.2f}$** | {metrics.get('coverage', 0.0)*100:.2f}% | Expected $> 80.00\\%$ |",
        f"| **Accuracy at $\\tau = {metrics.get('threshold', 0.60):.2f}$** | **{metrics.get('confident_accuracy', 0.0)*100:.2f}%** | $\\ge 90.00\\%$ on confident scans |",
        "",
        "---",
        "",
        "## Confidence Threshold Calibration ($\\tau$ Sweep)",
        "",
        "The application uses `confidenceThreshold = 0.60` (`CropDiseaseClassifier.confidenceThreshold`).",
        "Scans below $\\tau$ route to multi-angle soft voting or the Gemini Cloud AI fallback pipeline.",
        "",
        "| Threshold ($\\tau$) | Coverage (% Scans Accepted) | Empirical Accuracy | Total Accepted Samples |",
        "|---|---|---|---|",
    ]

    for s in metrics.get("threshold_sweep", []):
        marker = " 👈 *(Production Cutoff)*" if math.isclose(s["threshold"], metrics.get("threshold", 0.60)) else ""
        lines.append(
            f"| $\\tau = {s['threshold']:.2f}$ | {s['coverage']*100:.1f}% | **{s['accuracy']*100:.2f}%** | {s['samples']}{marker} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## Per-Class Accuracy & Performance Metrics",
        "",
        "| Class Label | Precision | Recall | F1-Score | Support |",
        "|---|---|---|---|---|",
    ])

    for c, stats in sorted(metrics.get("per_class", {}).items()):
        if stats["support"] > 0:
            lines.append(
                f"| `{c}` | {stats['precision']:.3f} | {stats['recall']:.3f} | {stats['f1']:.3f} | {stats['support']} |"
            )

    lines.extend([
        "",
        "---",
        "",
        "## How to Reproduce This Evaluation",
        "",
        "### 1. Offline / Desktop / CI Evaluation",
        "```bash",
        "python3 tools/evaluate_model.py \\",
        f"  --model {model_name} \\",
        "  --labels assets/labels_verified.txt \\",
        f"  --test-set {test_set_path} \\",
        "  --output-md docs/MODEL_ACCURACY.md",
        "```",
        "",
        "### 2. On-Device Flutter Integration Test",
        "```bash",
        "# Push test images to Android device / emulator",
        "adb push ./test_set /data/local/tmp/cropguard_test_set",
        "",
        "# Run automated accuracy evaluation harness",
        "flutter test integration_test/model_eval_test.dart \\",
        "  --dart-define=TEST_SET_DIR=/data/local/tmp/cropguard_test_set",
        "```",
    ])

    return "\n".join(lines) + "\n"


def main():
    args = parse_args()

    print("=======================================================")
    print("      CropGuard AI — Model Accuracy Evaluator")
    print("=======================================================")

    if not args.test_set or not os.path.exists(args.test_set):
        print(f"Notice: No test set directory provided or found at '{args.test_set}'.")
        print("Displaying CLI documentation and usage instructions.\n")
        print("To run evaluation on a dataset:")
        print("  python3 tools/evaluate_model.py --test-set path/to/test_set --model assets/cropguard_plant_disease_verified.tflite")
        sys.exit(0)

    labels = load_labels(args.labels)
    samples = find_images(args.test_set)
    print(f"Loaded {len(labels)} labels from {args.labels}")
    print(f"Discovered {len(samples)} test samples in {args.test_set}")

    evaluator = TFLiteEvaluator(args.model, labels, input_size=args.input_size)

    predictions = []
    ground_truth_classes = sorted(list(set(s[1] for s in samples)))

    print("\nRunning inference over test samples...")
    for idx, (img_path, true_label) in enumerate(samples, 1):
        top_preds = evaluator.predict(img_path)
        pred_label, conf = top_preds[0]
        top3_labels = [p[0] for p in top_preds[:3]]
        predictions.append({
            "image_path": img_path,
            "truth": true_label,
            "predicted": pred_label,
            "confidence": conf,
            "top3": top3_labels,
        })
        if idx % 50 == 0 or idx == len(samples):
            print(f"  Processed {idx}/{len(samples)} samples...")

    metrics = compute_metrics(predictions, ground_truth_classes, threshold=args.threshold)

    print("\n================ Results ================")
    print(f"Overall Top-1 Accuracy: {metrics['top1_accuracy']*100:.2f}%")
    print(f"Top-3 Accuracy        : {metrics['top3_accuracy']*100:.2f}%")
    print(f"Macro F1              : {metrics['macro_f1']*100:.2f}%")
    print(f"Weighted F1           : {metrics['weighted_f1']*100:.2f}%")
    print(f"ECE (Calibration Err) : {metrics['ece']*100:.2f}%")
    print(f"Accuracy at τ={args.threshold:.2f}  : {metrics['confident_accuracy']*100:.2f}% (Coverage: {metrics['coverage']*100:.1f}%)")

    md_report = generate_markdown_report(metrics, args.model, args.test_set)

    if args.output_md:
        with open(args.output_md, "w", encoding="utf-8") as f:
            f.write(md_report)
        print(f"\nSaved Markdown report to: {args.output_md}")

    if args.output_json:
        with open(args.output_json, "w", encoding="utf-8") as f:
            json.dump(metrics, f, indent=2)
        print(f"Saved JSON metrics to: {args.output_json}")


if __name__ == "__main__":
    main()
