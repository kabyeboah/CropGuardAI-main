#!/usr/bin/env python3
"""Annotate Markdown documentation statements with status tags.

This script walks through all *.md files (and .html files converted to markdown) in the
project root and `docs/` directory. For each plain text sentence it adds an inline tag
based on simple heuristics:

- contains words like "future", "will", "planned", "TODO" → [PLANNED]
- contains "deprecated", "no longer supported" → [DEPRECATED]
- contains "previously", "old", "historical", "was removed" → [HISTORICAL]
- otherwise → [CURRENT]

Code blocks (fenced with ```), tables, list items and headings are left untouched.
"""

import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DOC_PATHS = [PROJECT_ROOT, PROJECT_ROOT / "docs"]

def is_code_fence(line: str) -> bool:
    return line.lstrip().startswith("```")

def classify_sentence(sentence: str) -> str:
    lower = sentence.lower()
    if any(word in lower for word in ["future", "will", "planned", "todo", "to be added"]):
        return "[PLANNED]"
    if any(word in lower for word in ["deprecated", "no longer supported", "removed"]):
        return "[DEPRECATED]"
    if any(word in lower for word in ["previously", "old", "historical", "was removed", "legacy"]):
        return "[HISTORICAL]"
    return "[CURRENT]"

def process_file(path: Path):
    with path.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    new_lines = []
    in_fence = False
    for line in lines:
        if is_code_fence(line):
            in_fence = not in_fence
            new_lines.append(line)
            continue
        if in_fence or line.lstrip().startswith("#") or line.lstrip().startswith("-") or line.lstrip().startswith("*"):
            new_lines.append(line)
            continue
        sentences = re.split(r"(?<=[.!?])\s+", line)
        new_sentences = []
        for s in sentences:
            stripped = s.strip()
            if not stripped:
                continue
            if re.search(r"\[CURRENT\]|\[PLANNED\]|\[HISTORICAL\]|\[DEPRECATED\]", stripped):
                new_sentences.append(stripped)
                continue
            tag = classify_sentence(stripped)
            new_sentences.append(f"{stripped} {tag}")
        new_line = " ".join(new_sentences) + "\n"
        new_lines.append(new_line)

    with path.open("w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print(f"Annotated {path}")

def main():
    for base in DOC_PATHS:
        for root, _, files in os.walk(base):
            for fname in files:
                if fname.lower().endswith('.md'):
                    process_file(Path(root) / fname)
                elif fname.lower().endswith('.html'):
                    process_file(Path(root) / fname)

if __name__ == "__main__":
    main()
