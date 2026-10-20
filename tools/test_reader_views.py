#!/usr/bin/env python3
"""Check source-page navigation across the reading-page publication boundary."""
from html.parser import HTMLParser
import base64
import hashlib
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
from publication import build_reader_views, transform_reading_page, entry_page, with_site_icon
from check_astro_records import matches_reviewed_output

ROOT = Path(__file__).resolve().parents[1]


class Links(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.hrefs = []
        self.downloads = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "href" in attrs:
            self.hrefs.append(attrs["href"])
            if "download" in attrs:
                self.downloads.append(attrs["href"])


class SectionSources(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.sections = []
        self.first_sources = {}
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "section":
            self.sections.append(attrs.get("id", ""))
        if tag == "a" and attrs.get("href", "").startswith("../csapp.pdf#page="):
            for section in self.sections:
                self.first_sources.setdefault(section, attrs["href"])

    def handle_endtag(self, tag):
        if tag == "section" and self.sections:
            self.sections.pop()


def reading_page(book, source_link):
    """An independent minimal reading page, including the normal navigation shell."""
    threshold = "110 : 144" if book == "csapp" else "100 : 110"
    return ("<!doctype html><html><head><meta charset=\"utf-8\"></head><body>"
            '<main id="top"><p class="chapter-nav"><a href="book_overview.html">地图</a></p>'
            '<h1>阅读夹具</h1><p class="source">' + source_link + '</p></main>'
            '<footer><p class="chapter-nav"><a href="book_overview.html">地图</a></p></footer>'
            '<script>const offset = wide.matches ? ' + threshold + ';</script></body></html>').encode()


class SourcePageNavigation(unittest.TestCase):
    def test_historical_review_binding_accepts_only_the_exact_head_icon_insertion(self):
        original = b'<html><head><title>Book</title></head><body><p>Original text</p><script>read()</script></body></html>'
        expected = hashlib.sha256(original).hexdigest()
        svg = (ROOT/'portal/favicon.svg').read_bytes()
        icon = b'<link rel="icon" href="data:image/svg+xml;base64,' + base64.b64encode(svg) + b'" type="image/svg+xml">'
        published = original.replace(b'</head>', icon+b'</head>')
        self.assertTrue(matches_reviewed_output(original, expected))
        self.assertTrue(matches_reviewed_output(published, expected))
        for bad in (published.replace(b'Original text', b'Changed text'),
                    published.replace(b'read()', b'write()'),
                    published.replace(b'<title>Book', b'<title>Changed'),
                    published.replace(icon, icon+icon),
                    original.replace(b'</body>', icon+b'</body>'),
                    published.replace(b'image/svg+xml;base64,', b'image/png;base64,')):
            with self.subTest(output=bad[:80]):
                self.assertFalse(matches_reviewed_output(bad, expected))

    def test_existing_site_icon_is_not_duplicated(self):
        original = b'<html><head><link type="image/svg+xml" href="../../favicon.svg" rel="icon"></head><body></body></html>'
        self.assertEqual(with_site_icon(original, 'weiss/notes/chapter01.html'), original)

    def test_every_book_declares_the_shared_icon_at_both_entry_depths(self):
        books = json.loads((ROOT / 'books/catalog.json').read_text())['books']
        for book in books:
            prefix = book['publish_prefix']
            reading = transform_reading_page(reading_page(prefix, ''),
                                             f'{prefix}/notes/chapter01.html', {}).decode()
            entry = entry_page(book).decode()
            for html, href in ((reading, '../../favicon.svg'), (entry, '../favicon.svg')):
                with self.subTest(book=prefix, href=href):
                    head = html.split('</head>', 1)[0]
                    self.assertIn(f'<link rel="icon" href="{href}" type="image/svg+xml">', head)
                    self.assertEqual(head.count('rel="icon"'), 1)

    def test_program_guides_keep_every_registered_download(self):
        # Exercise the published document, where an early maintenance section
        # previously hid all later chapters despite intact raw Markdown links.
        paths = ["stochastic/code/README.md", "stochastic/code/programs.json",
                 "weiss/notes/README.md", "visual-group-theory/code/README.md",
                 "measure-probability/code/README.md"]
        paths += [f"stochastic/notes/{name}.json" for name in
                  ("source_manifest", "review_manifest", "validation")]
        blobs = {name: (ROOT / "books" / name).read_bytes() for name in paths}
        generated, _ = build_reader_views(blobs)
        for book in ("visual-group-theory", "measure-probability"):
            guide = generated[f"{book}/code/index.html"].decode()
            registered = json.loads((ROOT / "books" / book / "code/programs.json").read_text())
            downloads = set(Links(guide).downloads)
            for program in registered["programs"]:
                for source in program["files"].values():
                    with self.subTest(book=book, program=program["id"], source=source):
                        self.assertIn(Path(source).name, downloads)

    def test_measure_probability_source_ranges_and_download_survive_publication(self):
        source = ('<a class="source-ref" href="book_overview.html#source">印刷 56—57 / PDF 68—69</a>'
                  '<a href="../code/finite_spaces.c" download>下载 C 程序</a>')
        html = transform_reading_page(reading_page('measure-probability', source),
                                     'measure-probability/notes/chapter02_measure_spaces.html', {}).decode()
        self.assertIn('程士宏 · 测度论与概率论基础', html)
        self.assertIn('印刷 56—57 / PDF 68—69', html)
        self.assertIn('book_overview.html#source', Links(html).hrefs)
        self.assertIn('<a href="../code/finite_spaces.c" download>', html)
        self.assertIn('wide.matches ? 100 : 132', html)
        self.assertIn('href="../../" data-notes-home="true"', html)

    def test_visual_group_theory_text_source_keeps_page_and_navigation(self):
        source = '<a class="source-ref" href="book_overview.html#source">印刷 9 / PDF 24</a>'
        html = transform_reading_page(reading_page('visual-group-theory', source),
                                      'visual-group-theory/notes/chapter01_what_is_a_group.html', {}).decode()
        self.assertIn('印刷 9 / PDF 24', html)
        self.assertIn('Carter · 视觉群论', html)
        self.assertIn('book_overview.html#source', Links(html).hrefs)
        self.assertNotIn('.pdf#page=', html)
        self.assertIn('wide.matches ? 100 : 132', html)

    def test_csapp_major_section_links_match_independent_source_manifest(self):
        notes = ROOT / "books/csapp/notes"
        manifest = json.loads((notes / "source_manifest.json").read_text())
        checked = 0
        for chapter in manifest["chapters"]:
            sources = SectionSources((notes / chapter["file"]).read_text()).first_sources
            for section in chapter["sections"]:
                with self.subTest(chapter=chapter["chapter"], section=section["anchor"]):
                    self.assertEqual(sources.get(section["anchor"]),
                                     f"../csapp.pdf#page={section['pdf_start']}")
                checked += 1
        self.assertEqual(checked, 117)

    def test_included_csapp_chapters_and_front_matter_keep_exact_pdf_page(self):
        # Independent expectations from this edition's chapter starts, not a
        # second implementation of either manifest parsing or URL rewriting.
        cases = [("chapter01_tour", 38), ("chapter02_information", 68),
                 ("chapter03_machine_level", 200), ("chapter04_architecture", 388),
                 ("chapter05_optimization", 532), ("chapter06_memory", 616),
                 ("chapter07_linking", 706), ("chapter08_exceptional", 758),
                 ("chapter09_virtual_memory", 838), ("chapter10_system_io", 926),
                 ("chapter11_network", 954), ("chapter12_concurrency", 1008),
                 ("preface", 20), ("book_overview", 8)]
        for stem, page in cases:
            with self.subTest(stem=stem, pdf_page=page):
                href = f"../csapp.pdf#page={page}"
                source = f'<a class="source-pdf" href="{href}">原书 PDF 第 {page} 页</a>'
                html = transform_reading_page(reading_page("csapp", source),
                                              f"csapp/notes/{stem}.html", {},
                                              csapp_pdf_included=True).decode()
                self.assertEqual(Links(html).hrefs.count(href), 1)
                self.assertNotIn('class="source-printed"', html)

    def test_included_csapp_exercise_retains_multiple_source_pages(self):
        hrefs = ["../csapp.pdf#page=173", "../csapp.pdf#page=174"]
        source = '<span id="exercise">习题：</span>' + "、".join(
            f'<a class="source-pdf" href="{href}">原书页码</a>' for href in hrefs)
        html = transform_reading_page(reading_page("csapp", source),
                                      "csapp/notes/chapter02_information.html", {},
                                      csapp_pdf_included=True).decode()
        self.assertEqual([href for href in Links(html).hrefs if "csapp.pdf" in href], hrefs)

    def test_excluded_csapp_pdf_keeps_readable_source_without_dead_link(self):
        source = '<a class="source-pdf" href="../csapp.pdf#page=926">印刷 925 / PDF 926</a>'
        for kwargs in ({}, {"csapp_pdf_included": False}):
            with self.subTest(kwargs=kwargs):
                html = transform_reading_page(reading_page("csapp", source),
                                              "csapp/notes/chapter10_system_io.html", {},
                                              **kwargs).decode()
                self.assertFalse(any("csapp.pdf" in href for href in Links(html).hrefs))
                self.assertIn('<span class="source-printed">印刷 925 / PDF 926</span>', html)

    def test_stochastic_pdf_navigation_is_independent_of_csapp_option(self):
        href = "../assets/essentials-of-stochastic-processes.pdf#page=104"
        source = f'<a href="{href}">第二章原书</a>'
        for kwargs in ({}, {"csapp_pdf_included": False}, {"csapp_pdf_included": True}):
            with self.subTest(kwargs=kwargs):
                html = transform_reading_page(reading_page("stochastic", source),
                                              "stochastic/notes/chapter02_poisson_processes.html", {},
                                              **kwargs).decode()
                self.assertEqual(Links(html).hrefs.count(href), 1)


if __name__ == "__main__":
    unittest.main()
