#!/usr/bin/env python3
"""检查 EOPL 两页准备批的来源、导航、组件和实际教学程序。"""
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
    actual = Counter(r["chapter"] for r in items["items"] if r["kind"] == "exercise")
    need(actual == COUNTS, "whole-book exercise counts")
    need(len({(r["kind"], r["number"]) for r in items["items"]}) == len(items["items"]),
         "duplicate source inventory entry")
    for chapter, total in COUNTS.items():
        nums = {r["number"] for r in items["items"]
                if r["kind"] == "exercise" and r["chapter"] == chapter}
        need(nums == {f"{chapter}.{n}" for n in range(1, total + 1)},
             f"exercise sequence: {chapter}")
    need([r["number"] for r in items["items"] if r["coverage"] == "answered"] == ["0.1"],
         "current answer coverage differs")
    source_check = "not_available"
    pdf = ROOT / manifest["source"]["file"]
    if pdf.exists():
        need(pdf.stat().st_size == manifest["source"]["bytes"], "PDF size")
        need(hashlib.sha256(pdf.read_bytes()).hexdigest() == SOURCE_SHA256, "PDF hash")
        source_check = "hash_verified"
        if not quick:
            need(inventory(pdf) == items, "independent PDF inventory differs")
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
        need(metadata["stage"] == "map-and-preface" and
             metadata.get("original_sha256") == frozen.get("eopl/notes/" + name),
             "published map and preface must retain the accepted Git baseline")
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
    report = {"status": "passed", "stage": "map-and-preface", "pages": 2,
              "source_exercises": sum(COUNTS.values()), "answered_exercises": 1,
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
