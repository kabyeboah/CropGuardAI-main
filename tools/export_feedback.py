#!/usr/bin/env python3
"""
CropGuard AI — Feedback Collection Exporter

This script connects to Firestore or parses local feedback data to export
user-submitted disease corrections from the `feedback` collection.
The exported feedback dataset (feedback_export.json) is used to audit
misclassified scan diagnoses and feed retrainable image samples into
Colab retraining notebooks (see docs/RETRAIN_INSTRUCTIONS.md).

Usage:
  python3 tools/export_feedback.py --service-account-key path/to/key.json
  or
  python3 tools/export_feedback.py --help
"""

import argparse
import json
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Export CropGuard AI Firestore feedback collection for model retraining.")
    parser.add_argument("--service-account-key", help="Path to Firebase Service Account JSON key", default=None)
    parser.add_argument("--output", help="Output file path", default="docs/feedback_export.json")
    args = parser.parse_args()

    print("=" * 60)
    print("CropGuard AI — Feedback Collection Retraining Exporter")
    print("=" * 60)

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        print("[!] firebase_admin library not installed. Install with: pip install firebase-admin")
        sys.exit(1)

    key_path = args.service_account_key or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key_path or not os.path.exists(key_path):
        print(f"[!] Error: Firebase Service Account Key not found at '{key_path}'.")
        print("    Specify key path with --service-account-key or set GOOGLE_APPLICATION_CREDENTIALS.")
        sys.exit(1)

    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    print("[+] Querying Firestore 'feedback' collection...")
    feedback_ref = db.collection("feedback")
    docs = feedback_ref.stream()

    exported_records = []
    correction_counts = {}

    for doc in docs:
        data = doc.to_dict()
        record = {
            "id": doc.id,
            "userId": data.get("userId", ""),
            "detectionId": data.get("detectionId", 0),
            "originalLabel": data.get("originalLabel", ""),
            "correctedLabel": data.get("correctedLabel", ""),
            "imagePath": data.get("imagePath", ""),
            "confidence": data.get("confidence", None),
            "modelVersion": data.get("modelVersion", None),
            "timestamp": str(data.get("timestamp", ""))
        }
        exported_records.append(record)

        pair = f"{record['originalLabel']} -> {record['correctedLabel']}"
        correction_counts[pair] = correction_counts.get(pair, 0) + 1

    print(f"[+] Total feedback reports retrieved: {len(exported_records)}")
    print("[+] Correction Breakdown:")
    for pair, count in sorted(correction_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"    - {pair}: {count} report(s)")

    print("[+] Querying Firestore 'training_candidates' collection...")
    candidates_ref = db.collection("training_candidates")
    cand_docs = candidates_ref.stream()
    exported_candidates = []

    for doc in cand_docs:
        data = doc.to_dict()
        record = {
            "id": doc.id,
            "userId": data.get("userId", ""),
            "imagePath": data.get("imagePath", ""),
            "topCandidates": data.get("topCandidates", []),
            "averageConfidence": data.get("averageConfidence", 0.0),
            "anglesUsed": data.get("anglesUsed", 1),
            "modelVersion": data.get("modelVersion", None),
            "deviceInfo": data.get("deviceInfo", ""),
            "timestamp": str(data.get("timestamp", ""))
        }
        exported_candidates.append(record)

    print(f"[+] Total training candidates retrieved: {len(exported_candidates)}")

    output_path = args.output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({
            "exported_at": str(firestore.SERVER_TIMESTAMP),
            "total_feedback_count": len(exported_records),
            "total_candidates_count": len(exported_candidates),
            "corrections": exported_records,
            "training_candidates": exported_candidates,
        }, f, indent=2)

    print(f"[+] Saved feedback export to '{output_path}'.")
    print("[+] Follow docs/RETRAIN_INSTRUCTIONS.md to incorporate these samples into Colab retraining.")

if __name__ == "__main__":
    main()
