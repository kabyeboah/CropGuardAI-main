#!/usr/bin/env python3
"""Cleanup repository for Phase 22.
Moves obsolete files to an archive folder and removes generated artefacts.
"""
import os, shutil, re
from pathlib import Path
import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[2]  # adjust if script in scripts/
ARCHIVE_ROOT = PROJECT_ROOT / "archive" / "research_history"
ARCHIVE_ROOT.mkdir(parents=True, exist_ok=True)

# Patterns to archive
ARCHIVE_PATTERNS = [
    "*.bak",
    "*V1*",
    "*V2*",
    "*.pdf",
    "*.docx",
    "*_export*",
    "exports",
    "screenshots",
    "audit_reports",
]

def should_archive(p: Path):
    for pat in ARCHIVE_PATTERNS:
        if p.match(pat):
            return True
    return False

def archive_file(p: Path):
    rel = p.relative_to(PROJECT_ROOT)
    dest = ARCHIVE_ROOT / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(p), str(dest))
    print(f"Archived {p} -> {dest}")

def clean_generated():
    for rel in ["pubspec.lock", ".dart_tool", "build", "\.venv"]:
        target = PROJECT_ROOT / rel
        if target.is_dir():
            shutil.rmtree(target)
            print(f"Removed directory {target}")
        elif target.is_file():
            target.unlink()
            print(f"Removed file {target}")

def replace_machine_paths():
    for root, _, files in os.walk(PROJECT_ROOT):
        for f in files:
            if f.endswith(('.dart', '.js', '.java', '.kt', '.swift', '.yaml', '.yml', '.gradle', '.xml')):
                fp = Path(root) / f
                text = fp.read_text(encoding='utf-8')
                new_text = re.sub(r"/Users/[^/]+/", "<PROJECT_ROOT>/", text)
                if new_text != text:
                    fp.write_text(new_text, encoding='utf-8')
                    print(f"Rewrote paths in {fp}")

def main():
    for root, dirs, files in os.walk(PROJECT_ROOT):
        for name in files + dirs:
            p = Path(root) / name
            if should_archive(p):
                archive_file(p)
    clean_generated()
    replace_machine_paths()
    print("Cleanup complete.")

if __name__ == "__main__":
    main()
