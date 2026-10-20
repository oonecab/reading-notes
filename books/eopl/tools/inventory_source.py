#!/usr/bin/env python3
"""从同版 PDF 独立枚举编号项目；输出是定位清单，不是内容审阅结论。"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unicodedata

SOURCE_SHA256 = "b9e8770a4dc97206bd02230e6b21a878382eb02a340ff69321857d701e7d967c"
COUNTS = {"0": 1, "1": 36, "2": 31, "3": 44, "4": 42,
          "5": 58, "6": 40, "7": 30, "8": 27, "9": 42, "B": 5}


def inventory(pdf: Path) -> dict:
    if hashlib.sha256(pdf.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("PDF identity differs from reviewed third edition")
    result = subprocess.run(["pdftotext", "-layout", str(pdf), "-"],
                            capture_output=True, text=True, check=True)
    pages = result.stdout.split("\f")
    if pages[-1] == "":
        pages.pop()
    if len(pages) != 433:
        raise ValueError("PDF must contain 433 pages")
    records: dict[tuple, dict] = {}
    pattern = r"^\s*(Exercise|Definition|Example|Figure|Theorem) ([0-9AB]+(?:\.[0-9]+)+)\b"
    for number, page in enumerate(pages, 1):
        normalized = unicodedata.normalize("NFKC", page)
        for match in re.finditer(pattern, normalized, re.M):
            kind, identifier = match.groups()
            key = kind, identifier
            record = records.setdefault(key, {
                "kind": kind.lower(), "number": identifier,
                "chapter": identifier.split(".")[0],
                "printed_page": "xix" if number == 20 else number - 23,
                "pdf_page": number, "occurrence_pdf_pages": [],
                "coverage": "answered" if key == ("Exercise", "0.1") else "indexed",
            })
            record["occurrence_pdf_pages"].append(number)
    for chapter, expected in COUNTS.items():
        actual = {r["number"] for r in records.values()
                  if r["kind"] == "exercise" and r["chapter"] == chapter}
        wanted = {f"{chapter}.{n}" for n in range(1, expected + 1)}
        if actual != wanted:
            raise ValueError(f"exercise sequence mismatch: {chapter}")
    return {
        "schema_version": 1, "book": "eopl", "source_sha256": SOURCE_SHA256,
        "method": "NFKC normalized pdftotext -layout; anchored numbered headings; repeated figure captions grouped by kind and number",
        "scope_note": "Whole-book numbered-item locators, not full question/subquestion transcription. Only exercise 0.1 is answered in this batch.",
        "exercise_counts": COUNTS,
        "items": list(records.values()),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("--output", type=Path, required=True,
                        help="Use ignored tmp/ for a new extraction, then review.")
    args = parser.parse_args()
    output = inventory(args.pdf)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    counts = {kind: sum(r["kind"] == kind for r in output["items"])
              for kind in ("exercise", "definition", "theorem", "example", "figure")}
    print(json.dumps(counts, ensure_ascii=False))
