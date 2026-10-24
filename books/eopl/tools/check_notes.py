#!/usr/bin/env python3
"""检查 EOPL 地图、序言、第 1–9 章与附录 A/B的来源、原题归档、题解和实际教学程序。"""
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
import xml.etree.ElementTree as ET
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


class OriginalQuestion(HTMLParser):
    """Recover source spelling while allowing code and native mathematical layout."""
    def __init__(self, markup: str):
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.math_depth = 0
        for formula in re.findall(r'<math\b.*?</math>', markup, re.S):
            tree = ET.fromstring(formula)
            source = tree.get("aria-label")
            need(bool(source), "original question math needs its source spelling")
            # Preserve exponent/subscript roles while comparing visible math to
            # the original spelling. OCR spells t1/n1 without subscript glyphs.
            spelling = source.translate(str.maketrans({
                "²": "^2", "₁": "_1", "ₖ": "_k", "ᵢ": "_i"}))
            spelling = re.sub(r"\b([tn])([12])\b", r"\1_\2", spelling)
            need(re.sub(r"\s+", "", self.math_text(tree)) ==
                 re.sub(r"\s+", "", spelling),
                 "original question math differs from source spelling")
        self.feed(markup)

    @classmethod
    def math_text(cls, node):
        tag = node.tag.rsplit("}", 1)[-1]
        if tag in {"msub", "msup"}:
            need(len(node) == 2, "original question math script needs two operands")
            marker = "_" if tag == "msub" else "^"
            return cls.math_text(node[0]) + marker + cls.math_text(node[1])
        need(tag in {"math", "mrow", "mi", "mn", "mo", "mtext", "mspace"},
             "unsupported original question math structure: " + tag)
        return (node.text or "") + "".join(cls.math_text(n) + (n.tail or "") for n in node)

    def handle_starttag(self, tag, pairs):
        attrs = dict(pairs)
        if tag == "math":
            need(self.math_depth == 0 and bool(attrs.get("aria-label")),
                 "original question math needs its source spelling")
            self.parts.append(attrs["aria-label"])
        if tag == "math" or self.math_depth:
            self.math_depth += 1

    def handle_endtag(self, tag):
        if self.math_depth:
            self.math_depth -= 1

    def handle_data(self, text):
        if not self.math_depth:
            self.parts.append(text)

    @property
    def text(self):
        need(self.math_depth == 0, "unclosed original question math")
        return "".join(self.parts)


def need(condition: bool, label: str) -> None:
    if not condition:
        raise ValueError(label)


def check(quick: bool, run_dir: Path | None = None) -> dict:
    execution_dir = (run_dir if run_dir is not None else ROOT / "tmp/eopl-check").resolve()
    sync()
    manifest = json.loads((BOOK / "notes/source_manifest.json").read_text())
    items = json.loads((BOOK / "notes/source_inventory.json").read_text())
    archive_path = BOOK / "notes/original_questions.json"
    need(archive_path.is_file(), "original question archive missing")
    archive = json.loads(archive_path.read_text())
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
    need(len(manifest["current_scope"]["answered_exercises"]) == 356, "answer count must be 356")
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
        need('<details class="original-question"' not in text and
             'class="original-source"' not in text,
             f"reading page retains a full English original: {name}")
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
        stage = ("appendices" if name.startswith("appendix") else
                 "chapter-9" if name.startswith("chapter09") else
                 "chapter-8" if name.startswith("chapter08") else
                 "chapter-7" if name.startswith("chapter07") else
                 "chapters-5-6" if name.startswith(("chapter05", "chapter06")) else
                 "chapter-4" if name.startswith("chapter04") else
                 "chapter-3" if name.startswith("chapter03") else
                 "chapters-1-2" if name.startswith("chapter") else "map-and-preface")
        need(metadata["stage"] == stage and
             metadata.get("original_sha256") == frozen.get("eopl/notes/" + name),
             "each page must retain its accepted source baseline")
    for name, page in pages.items():
        for target in page.links:
            url = urlsplit(target)
            if url.scheme:
                continue
            destination = (BOOK / "notes" / unquote(url.path)).resolve() if url.path else BOOK / "notes" / name
            need(destination.is_file(), f"broken link: {name} -> {target}")
            if destination.suffix == '.pdf':
                need(destination == BOOK / 'assets/source.pdf', 'wrong source PDF: ' + target)
                need(bool(re.fullmatch(r'page=[1-9][0-9]*', url.fragment)) and
                     1 <= int(url.fragment[5:]) <= manifest['source']['pdf_pages'],
                     'invalid source PDF page: ' + target)
            elif url.fragment:
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
        if excerpt["role"] == "complete_exercise_and_translation":
            archived_text = next(row["text"] for row in archive["items"]
                                 if row["number"] == "0.1")
            need(excerpt["text"] == archived_text, "archived exercise excerpt differs")
            continue
        need(re.sub(r"\s+", " ", excerpt["text"]) in visible, "excerpt text differs")
    match = re.search(r'<code id="scope-demo-code" class="language-python">(.*?)</code>', preface, re.S)
    need(match is not None, "missing complete program")
    need(unescape(match[1]) == (BOOK / "code/scope_demo.py").read_text(), "program copy drift")
    questions = json.loads((BOOK / "notes/questions_ch01_02.json").read_text())
    need(questions["source_sha256"] == SOURCE_SHA256, "question source identity")
    wanted = [f"{c}.{n}" for c, total in [(1, 36), (2, 31)] for n in range(1, total + 1)]
    need([r["number"] for r in questions["items"]] == wanted, "complete question inventory")
    chapter3 = json.loads((BOOK / "notes/questions_ch03.json").read_text())
    need(chapter3["source_sha256"] == SOURCE_SHA256, "chapter 3 question source identity")
    chapter3_numbers = [f"3.{n}" for n in range(1, 45)]
    need([r["number"] for r in chapter3["items"]] == chapter3_numbers,
         "chapter 3 complete question inventory")
    questions["items"].extend(chapter3["items"])
    wanted.extend(chapter3_numbers)
    chapter4 = json.loads((BOOK / "notes/questions_ch04.json").read_text())
    need(chapter4["source_sha256"] == SOURCE_SHA256, "chapter 4 question source identity")
    chapter4_numbers = [f"4.{n}" for n in range(1, 43)]
    need([r["number"] for r in chapter4["items"]] == chapter4_numbers,
         "chapter 4 complete question inventory")
    questions["items"].extend(chapter4["items"])
    wanted.extend(chapter4_numbers)
    for chapter, count in [(5, 58), (6, 40), (7, 30), (8, 27), (9, 42)]:
        new_questions = json.loads((BOOK / f"notes/questions_ch{chapter:02}.json").read_text())
        need(new_questions["source_sha256"] == SOURCE_SHA256,
             f"chapter {chapter} question source identity")
        numbers = [f"{chapter}.{n}" for n in range(1, count + 1)]
        need([r["number"] for r in new_questions["items"]] == numbers,
             f"chapter {chapter} complete question inventory")
        questions["items"].extend(new_questions["items"])
        wanted.extend(numbers)
    appendix = json.loads((BOOK / "notes/questions_appendix_b.json").read_text())
    need(appendix["source_sha256"] == SOURCE_SHA256, "appendix B question source identity")
    numbers = [f"B.{n}" for n in range(1, 6)]
    need([r["number"] for r in appendix["items"]] == numbers, "appendix B complete question inventory")
    questions["items"].extend(appendix["items"])
    wanted.extend(numbers)
    for row in questions["items"]:
        need(row["pdf_page"] == row["printed_page"] + 23, "question locator differs")
    qmap = {r["number"]: r for r in questions["items"]}
    positions = {r["number"]: r for r in items["items"] if r["kind"] == "exercise"}
    names = {1: "chapter01_inductive_data.html", 2: "chapter02_data_abstraction.html",
             3: "chapter03_expressions.html", 4: "chapter04_state.html",
             5: "chapter05_continuations.html", 6: "chapter06_cps.html", 7: "chapter07_types.html", 8: "chapter08_modules.html", 9: "chapter09_objects.html", "B": "appendix_b_sllgen.html"}
    need(archive["schema_version"] == 1 and archive["book"] == "eopl" and
         archive["standard"] == "RN-002", "original question archive metadata differs")
    need(archive["source_sha256"] == SOURCE_SHA256, "original question archive source identity")
    archived = archive["items"]
    need(archive["item_count"] == len(archived), "original question archive item count")
    archived_exercises = [row for row in archived if row["kind"] == "exercise"]
    need(archive["exercise_count"] == len(archived_exercises) == 356,
         "original question archive exercise count")
    need([row["number"] for row in archived_exercises] == ["0.1", *wanted],
         "archive exercise sequence")
    need(next(row["exercise_id"] for row in archived_exercises if row["number"] == "0.1") == "ex-0-1",
         "preface archived exercise id")
    need([row["pdf_page"] for row in archived] == sorted(row["pdf_page"] for row in archived),
         "archive page order")
    shared = [row for row in archived if row["kind"] == "shared-preamble"]
    need(len(shared) == 1, "shared original preamble inventory")
    shared_index = archived.index(shared[0])
    need(0 < shared_index < len(archived) - 1 and
         archived[shared_index - 1]["number"] == "1.14" and
         archived[shared_index + 1]["number"] == "1.15",
         "shared original preamble position")
    for row in archived:
        need(row["sha256"] == hashlib.sha256(row["html"].encode()).hexdigest(),
             "archived original sha256 differs: " + row["number"])
        need(OriginalQuestion(row["html"]).text == row["text"],
             "archived original text differs: " + row["number"])
        if row["kind"] == "shared-preamble":
            need(row["number"] == "1.15–1.36" and row["pdf_page"] == 48 and
                 row["pdf_end"] == 49, "shared original locator differs")
            continue
        position = positions[row["number"]]
        need(row["printed_page"] == position["printed_page"] and
             row["pdf_page"] == position["pdf_page"],
             "archived question locator differs: " + row["number"])
        if row["number"] == "0.1":
            need(row["pdf_end"] == position["pdf_page"] == 20,
                 "preface original locator differs")
            continue
        source = qmap[row["number"]]
        need(row["text"] == source["question_text"],
             "archived original differs from source JSON: " + row["number"])
        need(row["printed_page"] == source["printed_page"] and
             row["pdf_page"] == source["pdf_page"] and
             row["pdf_end"] == source["pdf_end"],
             "archived question page sequence differs: " + row["number"])
    for c, total in [(1, 36), (2, 31), (3, 44), (4, 42), (5, 58), (6, 40), (7, 30), (8, 27), (9, 42), ("B", 5)]:
        text = (BOOK / "notes" / names[c]).read_text()
        ids = re.findall(r'<details class="exercise" id="([^"]+)"', text)
        need(ids == [f"ex-{c}-{n}" for n in range(1, total + 1)], "chapter exercise sequence")
        need([row["exercise_id"] for row in archived_exercises
              if row["chapter"] == str(c)] == ids, "archived exercise ids differ")
        need(len(re.findall(r'class="question-translation"', text)) == total,
             "chapter Chinese question count")
        blocks = re.findall(r'<details class="exercise" id="ex-[^"]+">(.*?)(?=<details class="exercise"|</section>)', text, re.S)
        for block in blocks:
            need('class="exercise-question"' in block and
                 block.index('class="exercise-question"') < block.index('class="answer"'),
                 "question must precede answer")
            need('class="question-translation"' in block, "Chinese question missing")
        code_id = "appendix_b-code" if c == "B" else f"chapter0{c}-code"
        need(f'id="{code_id}"' in text and '<!-- EOPL:end-program -->' in text,
             "missing complete chapter program")
    for chapter, count in [(3, 44), (4, 42), (5, 58), (6, 40), (7, 30), (8, 27), (9, 42), ("B", 5)]:
        chapter_text = (BOOK / "notes" / names[chapter]).read_text()
        chinese = re.findall(r'<div class="question-translation" lang="zh-CN" data-exercise="(' + str(chapter) + r'\.\d+)">(.*?)</div><p class="source">', chapter_text, re.S)
        need(len(chinese) == count, f"chapter {chapter} independent Chinese input inventory")
        for number, markup in chinese:
            need(markup == qmap[number]["chinese_html"],
                 f"chapter {chapter} Chinese question or supplied input differs: " + number)
    contexts = json.loads((BOOK / "notes/question_contexts.json").read_text())
    need(contexts["source_sha256"] == SOURCE_SHA256, "context source identity")
    for context in contexts["items"]:
        chapter = int(context["exercises"][0].split(".")[0])
        text = (BOOK / "notes" / names[chapter]).read_text()
        need('id="' + context["anchor"] + '"' in text and
             context["code"] in unescape(text), "referenced source code differs")
    report = {"status": "passed", "stage": "complete-book", "pages": 13,
              "source_exercises": sum(COUNTS.values()), "answered_exercises": 356,
              "original_question_archive": "notes/original_questions.json",
              "archived_original_items": len(archived),
              "archived_original_exercises": len(archived_exercises),
              "archived_original_sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
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
        expected.update({
            "chapter03.rkt": "3\n18\n-5\n-100\n12\n120\n",
            "chapter03_lexical.rkt": "(%let\n (37)\n (%proc 1 #f (%let ((- (%lexref 0) (%lexref 1))) (- (%lexref 2) (%lexref 1)))))\n-100\n12\n",
            "chapter03_variants.rkt": "7\n10\n",
            "chapter04.rkt": "3\n4\n88\n-1\n0\n",
            "chapter04_explicit.rkt": "-1\n0\n11\n11\n",
            "chapter04_statements.rkt": "7\n12\n3\n4\n3\n12\n"})
        for program in ["chapter01.rkt", "chapter02.rkt", "test_chapters.rkt",
                        "chapter03.rkt", "chapter03_lexical.rkt", "chapter03_variants.rkt",
                        "test_chapter03.rkt", "chapter04.rkt", "chapter04_explicit.rkt",
                        "chapter04_statements.rkt", "test_chapter04.rkt"]:
            completed = subprocess.run([racket, str(BOOK / "code" / program)],
                                       capture_output=True, text=True, check=True, timeout=60)
            if program in expected:
                need(completed.stdout == expected[program], "chapter demonstration output: " + program)
                results[program] = completed.stdout
            else:
                results[program] = json.loads(completed.stdout.splitlines()[-1])
                need(results[program]["status"] == "passed" and results[program]["failures"] == 0,
                     "Racket semantic failures")
        additions = {
            "chapter05.rkt": "machine: 30; max-continuation=3; end-count=1\n",
            "chapter05_cps.rkt": "procedural-pair: 30; end-count=1\n",
            "chapter05_statements.rkt": "commands/data: (3 2 1)\ncommands/procedural: (3 2 1)\n",
            "chapter06.rkt": "CPS-OUT: 12; output=()\n",
            "chapter06_algorithms.rkt": "factorial-register: fixed=24 original=1 self-jumps-omitted=24\n",
        }
        for program, expected_stdout in additions.items():
            completed = subprocess.run([racket, str(BOOK / "code" / program)],
                                       capture_output=True, text=True, check=True, timeout=60)
            need(completed.stdout == expected_stdout, "chapter demonstration output: " + program)
            results[program] = completed.stdout
        for program in ["test_chapter05_06.rkt", "chapter06_examples.rkt", "test_chapter06_scheme.rkt"]:
            completed = subprocess.run([racket, str(BOOK / "code" / program)],
                                       capture_output=True, text=True, check=True, timeout=60)
            results[program] = json.loads(completed.stdout.splitlines()[-1])
            need(results[program]["status"] == "passed" and results[program]["failures"] == 0,
                 "chapter 5/6 semantic failures: " + program)
        completed = subprocess.run([racket, str(BOOK / "code/chapter07.rkt")],
                                   capture_output=True, text=True, check=True, timeout=60)
        need(completed.stdout == "(int -> int)\n((int -> int) -> (int -> int))\n(a0 -> a0)\n11\n",
             "chapter7 demonstration output")
        results["chapter07.rkt"] = completed.stdout
        for program in ["chapter07_examples.rkt", "test_chapter07.rkt"]:
            completed = subprocess.run([racket, str(BOOK / "code" / program)],
                                       capture_output=True, text=True, check=True, timeout=60)
            results[program] = json.loads(completed.stdout.splitlines()[-1])
            need(results[program]["status"] == "passed" and results[program]["failures"] == 0,
                 "chapter7 actual execution: " + program)
        completed = subprocess.run([racket, str(BOOK / "code/chapter08.rkt")],
                                   capture_output=True, text=True, check=True, timeout=60)
        need(completed.stdout == "int\n22\n", "chapter8 demonstration output")
        results["chapter08.rkt"] = completed.stdout
        completed = subprocess.run([racket, str(BOOK / "code/test_chapter08.rkt")],
                                   capture_output=True, text=True, check=True, timeout=60)
        results["test_chapter08.rkt"] = json.loads(completed.stdout.splitlines()[-1])
        need(results["test_chapter08.rkt"]["status"] == "passed" and
             results["test_chapter08.rkt"]["failures"] == 0, "chapter8 actual execution")
        completed = subprocess.run([racket, str(BOOK / "code/chapter09.rkt")], capture_output=True, text=True, check=True, timeout=60)
        need(completed.stdout == "5\n", "chapter9 demonstration output")
        results["chapter09.rkt"] = completed.stdout
        completed = subprocess.run([racket, str(BOOK / "code/test_chapter09.rkt")], capture_output=True, text=True, check=True, timeout=60)
        results["test_chapter09.rkt"] = json.loads(completed.stdout.splitlines()[-1])
        need(results["test_chapter09.rkt"]["status"] == "passed" and results["test_chapter09.rkt"]["failures"] == 0, "chapter9 actual execution")
        completed = subprocess.run([racket, str(BOOK / "code/chapter09_examples.rkt")], capture_output=True, text=True, check=True, timeout=60)
        examples = json.loads(completed.stdout)
        need(examples == {"state": [[3, -3], [5, -5]], "tree_sum": 12, "field_shadow": [101, 102, 101, 999],
                          "super_self": 33, "typed_tree": [12, 100], "queue_counts": [2, 2, 4], "serials": [1, 2],
                          "overloads": [0, 7], "prototype": [10, 11, 10], "summable": [12, 12, 12],
                          "stringable": ["(3,(4,(5,[])))", "((3,4),5)", "5:(3,(4,[]))"], "static_dispatch": [12, 21]},
             "chapter9 source/exercise example oracles")
        results["chapter09_examples.rkt"] = {"status": "passed", "oracles": examples}
        completed = subprocess.run([racket, str(BOOK / "code/appendix_b.rkt")], capture_output=True, text=True, check=True, timeout=60)
        need(completed.stdout == "(expr (term 3 () ()) (+ -) ((term 2 (*) (66)) (term 5 () ())))\n130\n12\n4\n1\n-6\n", "appendix B demonstration output")
        results["appendix_b.rkt"] = completed.stdout
        completed = subprocess.run([racket, str(BOOK / "code/test_appendix_b.rkt")], capture_output=True, text=True, check=True, timeout=60)
        results["test_appendix_b.rkt"] = json.loads(completed.stdout.splitlines()[-1])
        need(results["test_appendix_b.rkt"]["status"] == "passed" and results["test_appendix_b.rkt"]["failures"] == 0, "appendix B actual execution")
        from test_appendix_b_inputs import run as test_appendix_b_inputs
        report["appendix_b_displayed_inputs"] = test_appendix_b_inputs(racket, execution_dir / "appendix-inputs")
        from test_chapter09_mutations import run as test_chapter09_mutations
        report["chapter9_semantic_mutations"] = test_chapter09_mutations(racket, execution_dir / "object-mutations")
        from test_chapter09_inputs import run as test_chapter09_inputs
        report["chapter9_source_input_execution"] = test_chapter09_inputs(racket, execution_dir / "object-source-inputs")
        from test_chapter08_mutations import run as test_chapter08_mutations
        report["chapter8_semantic_mutations"] = test_chapter08_mutations(racket, execution_dir / "module-mutations")
        from test_chapter08_inputs import run as test_chapter08_inputs
        report["chapter8_source_input_execution"] = test_chapter08_inputs(racket, execution_dir / "module-source-inputs")
        from test_chapter07_mutations import run as test_chapter07_mutations
        report["chapter7_semantic_mutations"] = test_chapter07_mutations(racket, execution_dir / "type-mutations")
        from test_chapter07_inputs import run as test_chapter07_inputs
        report["chapter7_source_input_execution"] = test_chapter07_inputs(racket, execution_dir / "type-source-inputs")
        completed = subprocess.run([sys.executable, BOOK / "code/chapter05_sync.py"],
                                   capture_output=True, text=True, check=True, timeout=30)
        report["synchronization_models"] = json.loads(completed.stdout)
        need(report["synchronization_models"]["models"] == {
            "counting_semaphore_peak": 2, "condition_value": 44,
            "barrier_generations": 2, "private_counter": 3}, "synchronization model oracle")
        from test_chapter05_06_mutations import run as test_chapter05_06_mutations, run_c_drivers
        report["chapter5_6_semantic_mutations"] = test_chapter05_06_mutations(racket, execution_dir / "control-mutations")
        report["c_control_drivers"] = run_c_drivers(execution_dir / "c-drivers")
        report["racket_execution"] = results
        from test_source_contexts import run as test_source_contexts
        report["textbook_context_execution"] = test_source_contexts(racket)
        from test_chapter04_mutations import run as test_chapter04_mutations
        report["chapter4_semantic_mutations"] = test_chapter04_mutations(racket, execution_dir / "state-mutations")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--run-dir", type=Path, default=ROOT / "tmp/eopl-check")
    args = parser.parse_args()
    try:
        report = check(args.quick, args.run_dir)
    except Exception as error:
        report = {"status": "failed", "error": str(error)}
    args.run_dir.mkdir(parents=True, exist_ok=True)
    (args.run_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "passed" else 1)
