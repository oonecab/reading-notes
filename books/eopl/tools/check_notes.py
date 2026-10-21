#!/usr/bin/env python3
"""检查 EOPL 地图、序言与第 1、2 章的来源、题解和实际教学程序。"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
import shutil
import sys
from urllib.parse import unquote, urlsplit

from inventory_source import COUNTS, SOURCE_SHA256, inventory
from sync_notes import ROOT, BOOK, SOURCE, sync
from test_scope import run as test_scope


class Page(HTMLParser):
    def __init__(self, text: str):
        super().__init__(convert_charrefs=True)
        self.ids: list[str] = []
        self.links: list[str] = []
        self.elements: list[tuple[str, dict]] = []
        self.feed(text)

    def handle_starttag(self, tag, pairs):
        attrs = dict(pairs)
        self.elements.append((tag, attrs))
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])


def need(condition: bool, label: str) -> None:
    if not condition:
        raise ValueError(label)


def check(quick: bool) -> dict:
    sync()
    manifest = json.loads((BOOK / "notes/source_manifest.json").read_text())
    items = json.loads((BOOK / "notes/source_inventory.json").read_text())
    need(manifest["source"]["sha256"] == items["source_sha256"] == SOURCE_SHA256,
         "source identity mismatch")
    need(manifest["source"]["pdf_pages"] == 433, "wrong PDF page count")
    need(manifest["main_page_mapping"] == {
        "printed_start": 1, "printed_end": 410,
        "pdf_start": 24, "pdf_end": 433, "offset": 23}, "page mapping differs")
    need(manifest["original_dependency_edges"] ==
         [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [4, 7], [7, 8], [7, 9]],
         "original dependency graph differs")
    for row in manifest["chapters"]:
        need(row["pdf_start"] == row["printed_start"] + 23 and
             row["pdf_end"] == row["printed_end"] + 23, "chapter page mapping")
    need(items["schema_version"] == 1 and items["book"] == "eopl" and
         items["exercise_counts"] == COUNTS, "source inventory metadata differs")
    actual = Counter(r["chapter"] for r in items["items"] if r["kind"] == "exercise")
    need(actual == COUNTS, "whole-book exercise counts")
    need(len({(r["kind"], r["number"]) for r in items["items"]}) == len(items["items"]),
         "duplicate source inventory entry")
    for chapter, total in COUNTS.items():
        nums = {r["number"] for r in items["items"]
                if r["kind"] == "exercise" and r["chapter"] == chapter}
        need(nums == {f"{chapter}.{n}" for n in range(1, total + 1)},
             f"exercise sequence: {chapter}")
    need([r["number"] for r in items["items"] if r["coverage"] == "answered"] == manifest["current_scope"]["answered_exercises"],
         "current answer coverage differs")
    need(len(manifest["current_scope"]["answered_exercises"]) == 68, "answer count must be 68")
    source_check = "not_available"
    pdf = ROOT / manifest["source"]["file"]
    if pdf.exists():
        need(pdf.stat().st_size == manifest["source"]["bytes"], "PDF size")
        need(hashlib.sha256(pdf.read_bytes()).hexdigest() == SOURCE_SHA256, "PDF hash")
        source_check = "hash_verified"
        if not quick:
            independent = inventory(pdf)
            header = lambda data: {k: v for k, v in data.items()
                                   if k not in ("items", "scope_note")}
            need(header(independent) == header(items), "independent PDF metadata differs")
            # Coverage is authoring state, not a claim inferred from the PDF.
            locators = lambda rows: [{k: v for k, v in r.items() if k != "coverage"} for r in rows]
            need(locators(independent["items"]) == locators(items["items"]),
                 "independent PDF inventory differs")
            source_check = "independent_inventory_verified"
    pages = {}
    for name in manifest["current_scope"]["pages"]:
        file = BOOK / "notes" / name
        text = file.read_text()
        page = Page(text)
        pages[name] = page
        need(len(page.ids) == len(set(page.ids)), f"duplicate ids: {name}")
        need("RN:include" not in text, "unexpanded shared asset")
        need('<body class="rn-components">' in text, "component class missing")
        need(len([1 for t, _ in page.elements if t == "h1"]) == 1, "h1 count")
        for tag, attrs in page.elements:
            if tag == "th":
                need(attrs.get("scope") in ("row", "col"), "table header scope")
            if tag == "table":
                need("aria-label" in attrs or "aria-labelledby" in attrs, "table name")
            if tag == "svg":
                need(attrs.get("role") == "img" and "aria-labelledby" in attrs, "SVG name")
            if tag in ("script", "link", "img"):
                need(not attrs.get("src", "").startswith(("http:", "https:", "//")),
                     "external runtime dependency")
            if "aria-labelledby" in attrs:
                need(all(x in page.ids for x in attrs["aria-labelledby"].split()),
                     "accessible name target missing")
        metadata = json.loads((SOURCE / name).read_text().split("---\n")[1])
        baseline = json.loads((BOOK / "review/content-baseline-astro.json").read_text())
        frozen = {row["page"]: row["source_sha256"] for row in baseline["records"]}
        need(metadata["stage"] == ("chapters-1-2" if name.startswith("chapter") else "map-and-preface") and
             metadata.get("original_sha256") == frozen.get("eopl/notes/" + name),
             "each page must retain its accepted source baseline")
    for name, page in pages.items():
        for target in page.links:
            url = urlsplit(target)
            if url.scheme:
                continue
            destination = (BOOK / "notes" / unquote(url.path)).resolve() if url.path else BOOK / "notes" / name
            need(destination.is_file(), f"broken link: {name} -> {target}")
            if url.fragment:
                other = Page(destination.read_text()) if destination.name not in pages else pages[destination.name]
                need(unquote(url.fragment) in other.ids, f"missing anchor: {name} -> {target}")
    overview = (BOOK / "notes/book_overview.html").read_text()
    for n in range(1, 10):
        need(f'id="chapter-{n}"' in overview, f"chapter {n} absent from map")
    preface = (BOOK / "notes/preface.html").read_text()
    need(re.findall(r'<details class="exercise" id="([^"]+)"', preface) == ["ex-0-1"],
         "preface exercise inventory")
    question = preface.index('<div class="exercise-question">')
    answer = preface.index('<div class="answer">')
    need(question < answer, "question must precede answer")
    from html import unescape
    visible = unescape(re.sub("<[^>]+>", " ", preface))
    visible = re.sub(r"\s+", " ", visible)
    for excerpt in json.loads((BOOK / "notes/source_excerpts.json").read_text())["entries"]:
        need(excerpt["anchor"] in pages["preface.html"].ids, "excerpt anchor")
        need(re.sub(r"\s+", " ", excerpt["text"]) in visible, "excerpt text differs")
    match = re.search(r'<code id="scope-demo-code" class="language-python">(.*?)</code>', preface, re.S)
    need(match is not None, "missing complete program")
    need(unescape(match[1]) == (BOOK / "code/scope_demo.py").read_text(), "program copy drift")
    questions = json.loads((BOOK / "notes/questions_ch01_02.json").read_text())
    need(questions["source_sha256"] == SOURCE_SHA256, "question source identity")
    wanted = [f"{c}.{n}" for c, total in [(1, 36), (2, 31)] for n in range(1, total + 1)]
    need([r["number"] for r in questions["items"]] == wanted, "complete question inventory")
    positions = {r["number"]: r for r in items["items"] if r["kind"] == "exercise"}
    names = {1: "chapter01_inductive_data.html", 2: "chapter02_data_abstraction.html"}
    for c, total in [(1, 36), (2, 31)]:
        text = (BOOK / "notes" / names[c]).read_text()
        ids = re.findall(r'<details class="exercise" id="([^"]+)"', text)
        need(ids == [f"ex-{c}-{n}" for n in range(1, total + 1)], "chapter exercise sequence")
        originals = re.findall(r'<pre class="original-source" lang="en">(.*?)</pre>', text, re.S)
        rows = [r for r in questions["items"] if r["number"].startswith(str(c) + ".")]
        need(len(originals) == total, "full original question count")
        for content, row in zip(originals, rows):
            need(unescape(content) == row["question_text"], "complete original question differs: " + row["number"])
            need(row["pdf_page"] == positions[row["number"]]["pdf_page"] and
                 row["printed_page"] == row["pdf_page"] - 23, "question locator differs")
        blocks = re.findall(r'<details class="exercise" id="ex-[^"]+">(.*?)(?=<details class="exercise"|</section>)', text, re.S)
        for block in blocks:
            need(block.index('class="exercise-question"') < block.index('class="answer"'),
                 "question must precede answer")
        need(f'id="chapter0{c}-code"' in text and '<!-- EOPL:end-program -->' in text,
             "missing complete chapter program")
    contexts = json.loads((BOOK / "notes/question_contexts.json").read_text())
    need(contexts["source_sha256"] == SOURCE_SHA256, "context source identity")
    for context in contexts["items"]:
        chapter = int(context["exercises"][0].split(".")[0])
        text = (BOOK / "notes" / names[chapter]).read_text()
        need('id="' + context["anchor"] + '"' in text and
             context["code"] in unescape(text), "referenced source code differs")
    report = {"status": "passed", "stage": "chapters-1-2", "pages": 4,
              "source_exercises": sum(COUNTS.values()), "answered_exercises": 68,
              "source_check": source_check, "quick": quick,
              "page_sha256": {name: hashlib.sha256((BOOK / "notes" / name).read_bytes()).hexdigest()
                              for name in pages},
              "checked_at": datetime.now(timezone.utc).isoformat()}
    if not quick:
        report["semantic_tests"] = test_scope()
        executed = subprocess.run([sys.executable, BOOK / "code/scope_demo.py"],
                                  capture_output=True, text=True, check=True)
        need(executed.stdout == "lexical: 15\ndynamic: 5\n", "demonstration output")
        report["demo_stdout"] = executed.stdout
        report["python"] = sys.version.split()[0]
        racket = shutil.which("racket")
        if racket is None:
            installed = sorted(Path("/Applications").glob("Racket*/bin/racket"))
            racket = str(installed[-1]) if installed else None
        need(racket is not None, "Racket runtime not found; full example verification is required")
        results = {}
        expected = {"chapter01.rkt": "((0 a) (1 b) (2 c))\n((x b) (c (x)))\n(red (bar 1 1) (red 2 (quux 2 2)))\n(foo (bar 0 1) (baz 2 (quux 3 4)))\n",
                    "chapter02.rkt": "(2 0 1)\n((lambda (a) (a b)) c)\n2\n(13 (12 () (99 () ())) ())\n"}
        for program in ["chapter01.rkt", "chapter02.rkt", "test_chapters.rkt"]:
            completed = subprocess.run([racket, str(BOOK / "code" / program)],
                                       capture_output=True, text=True, check=True, timeout=60)
            if program in expected:
                need(completed.stdout == expected[program], "chapter demonstration output: " + program)
                results[program] = completed.stdout
            else:
                results[program] = json.loads(completed.stdout.splitlines()[-1])
                need(results[program]["status"] == "passed" and results[program]["failures"] == 0,
                     "Racket semantic failures")
        report["racket_execution"] = results
        from test_source_contexts import run as test_source_contexts
        report["textbook_context_execution"] = test_source_contexts(racket)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--run-dir", type=Path, default=ROOT / "tmp/eopl-check")
    args = parser.parse_args()
    try:
        report = check(args.quick)
    except Exception as error:
        report = {"status": "failed", "error": str(error)}
    args.run_dir.mkdir(parents=True, exist_ok=True)
    (args.run_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "passed" else 1)
