#!/usr/bin/env python3
"""
CropGuard AI — Feedback Collection Exporter

This script connects to Supabase REST API to export user-submitted
disease corrections from the `feedback` table.
The exported feedback dataset (feedback_export.json) is used to audit
misclassified scan diagnoses and feed retrainable image samples into
Colab retraining notebooks (see docs/RETRAIN_INSTRUCTIONS.md).

Usage:
  python3 tools/export_feedback.py --supabase-url https://xyz.supabase.co --api-key YOUR_KEY
  or
  python3 tools/export_feedback.py --help
"""

import argparse
import datetime
import json
import os
import sys
import urllib.parse
import urllib.request


def fetch_table(base_url: str, api_key: str, table: str):
    url = f"{base_url.rstrip('/')}/rest/v1/{table}?select=*"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": api_key,
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data
            else:
                print(f"[!] Warning: Received status {response.status} from {table}")
                return []
    except Exception as e:
        print(f"[!] Request error fetching {table}: {e}")
        return []


def main():
    parser = argparse.ArgumentParser(
        description="Export CropGuard AI Supabase feedback collection for model retraining."
    )
    parser.add_argument(
        "--supabase-url",
        help="Supabase Project URL (or SUPABASE_URL env var)",
        default=os.environ.get("SUPABASE_URL", "https://xrjltpchcssztitswjvm.supabase.co"),
    )
    parser.add_argument(
        "--api-key",
        help="Supabase Service Role or Anon API Key (or SUPABASE_ANON_KEY env var)",
        default=os.environ.get("SUPABASE_ANON_KEY", ""),
    )
    parser.add_argument("--output", help="Output file path", default="docs/feedback_export.json")
    args = parser.parse_args()

    print("=" * 60)
    print("CropGuard AI — Feedback Collection Retraining Exporter")
    print("=" * 60)

    if not args.api_key:
        # Check if .env exists to read key
        env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
        if os.path.exists(env_path):
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("SUPABASE_ANON_KEY="):
                        args.api_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    elif line.startswith("SUPABASE_URL=") and not args.supabase_url:
                        args.supabase_url = line.split("=", 1)[1].strip().strip('"').strip("'")

    if not args.api_key:
        print("[!] Error: Supabase API key is required.")
        print("    Specify key with --api-key or set SUPABASE_ANON_KEY environment variable.")
        sys.exit(1)

    print(f"[+] Connecting to Supabase at: {args.supabase_url}")
    print("[+] Querying Supabase 'feedback' table...")

    records = fetch_table(args.supabase_url, args.api_key, "feedback")

    exported_records = []
    correction_counts = {}

    for row in records:
        record = {
            "id": row.get("id", ""),
            "userId": row.get("user_id", ""),
            "detectionId": row.get("detection_id", 0),
            "originalLabel": row.get("original_label", ""),
            "correctedLabel": row.get("corrected_label", ""),
            "imagePath": row.get("image_path", ""),
            "confidence": row.get("confidence", None),
            "modelVersion": row.get("model_version", None),
            "timestamp": str(row.get("created_at", "")),
        }
        exported_records.append(record)

        orig = record["originalLabel"] or "Unknown"
        corr = record["correctedLabel"] or "Unknown"
        pair = f"{orig} -> {corr}"
        correction_counts[pair] = correction_counts.get(pair, 0) + 1

    print(f"[+] Total feedback reports retrieved: {len(exported_records)}")
    if correction_counts:
        print("[+] Correction Breakdown:")
        for pair, count in sorted(correction_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"    - {pair}: {count} report(s)")

    output_path = args.output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "exported_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "total_feedback_count": len(exported_records),
                "corrections": exported_records,
            },
            f,
            indent=2,
        )

    print(f"[+] Saved feedback export to '{output_path}'.")
    print("[+] Follow docs/RETRAIN_INSTRUCTIONS.md to incorporate these samples into retraining.")


if __name__ == "__main__":
    main()
