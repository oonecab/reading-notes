#!/usr/bin/env python3
"""在隔离副本注入错误，确认来源、锚点与代码漂移检查实际拒绝错误。"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def run(run_dir: Path) -> dict:
    run_dir.mkdir(parents=True, exist_ok=True)
    cases = []
    with tempfile.TemporaryDirectory(prefix="fixture-", dir=run_dir) as temp:
        fixture = Path(temp)
        shutil.copytree(ROOT / "books/eopl", fixture / "books/eopl",
                        ignore=shutil.ignore_patterns("tmp", "__pycache__"))
        shutil.copytree(ROOT / "src/content/books/eopl",
                        fixture / "src/content/books/eopl")
        for name in ("lib", "styles", "scripts"):
            (fixture / "src" / name).symlink_to(ROOT / "src" / name,
                                               target_is_directory=True)
        book = fixture / "books/eopl"
        source = fixture / "src/content/books/eopl"

        def sync() -> None:
            subprocess.run([sys.executable, book / "tools/sync_notes.py", "--write"],
                           cwd=fixture, check=True, capture_output=True, text=True)

        def check(name: str, expected_error: str | None = None) -> None:
            completed = subprocess.run(
                [sys.executable, book / "tools/check_notes.py", "--quick",
                 "--run-dir", run_dir / name],
                cwd=fixture, capture_output=True, text=True)
            report = json.loads(completed.stdout)
            if expected_error is None:
                assert completed.returncode == 0, report
                assert report["source_check"] == "not_available", report
            else:
                assert completed.returncode != 0, (name, "accepted injected error")
                assert expected_error in report.get("error", ""), report
            cases.append({"name": name, "status": "passed",
                          "checker_status": report["status"],
                          "observed_error": report.get("error")})

        check("unchanged_fixture")
        overview = source / "book_overview.html"
        original = overview.read_text()
        overview.write_text(original.replace('href="#models"', 'href="#missing-anchor"', 1))
        sync()
        check("missing_anchor", "missing anchor")
        overview.write_text(original)
        sync()

        manifest = book / "notes/source_manifest.json"
        original = manifest.read_text()
        data = json.loads(original)
        data["main_page_mapping"]["offset"] = 24
        manifest.write_text(json.dumps(data))
        check("page_mapping_shift", "page mapping differs")
        manifest.write_text(original)

        inventory_file = book / "notes/source_inventory.json"
        original_inventory = inventory_file.read_text()
        data = json.loads(original_inventory)
        data["exercise_counts"]["1"] = 35
        inventory_file.write_text(json.dumps(data))
        check("inventory_header_drift", "source inventory metadata differs")
        inventory_file.write_text(original_inventory)

        preface = source / "preface.html"
        original = preface.read_text()
        preface.write_text(original.replace("#!/usr/bin/env python3",
                                           "#!/usr/bin/env python3\n# injected drift", 1))
        check("program_copy_drift", "preface code copy differs")
        preface.write_text(original)
        sync()

        chapter = source / "chapter01_inductive_data.html"
        original = chapter.read_text()
        chapter.write_text(original.replace('id="ex-1-36"', 'id="omitted-exercise"', 1))
        sync()
        check("missing_chapter_exercise", "missing anchor")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace("Write inductive definitions", "[omitted condition]", 1))
        sync()
        check("truncated_original_question", "complete original question differs")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace('aria-label="{3n + 2 | n ∈ N }"',
                                            'aria-label="{3n + 3 | n ∈ N }"', 1))
        sync()
        check("original_math_condition_drift", "original question math differs from source spelling")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace('<mo>{</mo><mn>3</mn><mi>n</mi>',
                                            '<mo>{</mo><mn>4</mn><mi>n</mi>', 1))
        sync()
        check("original_visible_math_drift", "original question math differs from source spelling")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace('<msup><mi>n</mi><mn>2</mn></msup>',
                                            '<mrow><mi>n</mi><mn>2</mn></mrow>', 1))
        sync()
        check("original_exponent_flattened", "original question math differs from source spelling")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace('aria-label="{3n + 2 | n ∈ N }"', '', 1))
        sync()
        check("original_math_source_spelling_missing", "original question math needs its source spelling")
        chapter.write_text(original)
        sync()
        chapter.write_text(original.replace("Counts top-level elements.", "Injected program drift.", 1))
        check("chapter_program_copy_drift", "program copy differs")
        chapter.write_text(original)
        sync()
    report = {"status": "passed", "cases": cases,
              "fixture_note": "Source PDF omitted from isolated fixture; full source validation runs separately."}
    (run_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=ROOT / "tmp/eopl-checker-regression")
    args = parser.parse_args()
    print(json.dumps(run(args.run_dir.resolve()), ensure_ascii=False, indent=2))
