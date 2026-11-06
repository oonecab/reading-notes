"""Regression expectations from catalog, RN-001 and ordinary Git clone semantics."""
import copy
from html.parser import HTMLParser
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class Cards(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.cards, self.current, self.scope = [], None, False
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'article' and 'book' in attrs.get('class', '').split():
            self.current = {'links': [], 'scope': ''}
            self.cards.append(self.current)
        if self.current is not None:
            if tag == 'a':
                self.current['links'].append(attrs.get('href'))
            if tag == 'p' and 'book-scope' in attrs.get('class', '').split():
                self.scope = True

    def handle_endtag(self, tag):
        if tag == 'p':
            self.scope = False
        if tag == 'article':
            self.current = None

    def handle_data(self, text):
        if self.current is not None and self.scope:
            self.current['scope'] += text


class ProjectContracts(unittest.TestCase):
    def test_visible_shelf_counts_match_catalog(self):
        books = json.loads((ROOT / 'books/catalog.json').read_text(encoding='utf8'))['books']
        cards = Cards((ROOT / 'portal/index.html').read_text(encoding='utf8')).cards
        self.assertEqual(len(cards), len(books))
        for book in books:
            entry = book['publish_prefix'] + '/' + book['entry']
            matches = [card for card in cards if entry in card['links']]
            self.assertEqual(len(matches), 1, book['id'])
            for pattern, expected in [(r'(\d+)\s*页笔记', book['expected_pages']),
                                       (r'(\d+)\s*道习题', book['expected_exercises'])]:
                match = re.search(pattern, matches[0]['scope'])
                if match:
                    self.assertEqual(int(match[1]), expected, book['id'])

    def test_build_source_commits_travel_with_head(self):
        state = json.loads((ROOT / 'scripts/migration-state.json').read_text(encoding='utf8'))
        refs = {state['baseline_ref'], *state['book_baselines'].values(), *state['page_baselines'].values()}
        for ref in sorted(refs):
            with self.subTest(ref=ref):
                result = subprocess.run(['git', 'merge-base', '--is-ancestor', ref, 'HEAD'], cwd=ROOT)
                self.assertEqual(result.returncode, 0, 'Normal clones must contain every source snapshot')

    def test_source_manifest_rejects_identity_and_page_drift(self):
        checker = module('sicp_check', ROOT / 'books/sicp/tools/check_notes.py')
        manifest = json.loads((ROOT / 'books/sicp/notes/source_manifest.json').read_text(encoding='utf8'))
        changes = [lambda m: m['chapters'][0].update(title='Building the Wrong Book'),
                   lambda m: m['front_matter'][4].update(pdf_start=14),
                   lambda m: m['main_page_mapping'].update(offset=27),
                   lambda m: m.update(edition='First edition')]
        for i, change in enumerate(changes):
            with self.subTest(mutation=i):
                bad = copy.deepcopy(manifest)
                change(bad)
                with self.assertRaises(ValueError):
                    checker.check_manifest(bad, manifest['source']['sha256'], 883)

    def test_build_help_needs_no_optional_timezone_database(self):
        with tempfile.TemporaryDirectory() as empty:
            env = {**os.environ, 'PYTHONTZPATH': empty, 'PYTHONUTF8': '1'}
            result = subprocess.run([sys.executable, '-S', str(ROOT / 'deploy/build_astro.py'), '--help'],
                                    cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--release-id', result.stdout)

    def test_release_clock_chinese_midnight_and_naive_rejection(self):
        from datetime import datetime, timezone
        sys.path.insert(0, str(ROOT / 'deploy'))
        builder = module('astro_release_clock', ROOT / 'deploy/build_astro.py')
        self.assertEqual(builder.default_release_id(datetime(2026, 11, 5, 15, 59, 59, tzinfo=timezone.utc)),
                         '20261105T235959')
        self.assertEqual(builder.default_release_id(datetime(2026, 11, 5, 16, 0, 0, tzinfo=timezone.utc)),
                         '20261106T000000')
        with self.assertRaises(ValueError):
            builder.default_release_id(datetime(2026, 11, 6))

    def test_inventory_rejects_duplicate_or_missing_section(self):
        checker = module('sicp_inventory_check', ROOT / 'books/sicp/tools/check_notes.py')
        inventory = json.loads((ROOT / 'books/sicp/notes/source_inventory.json').read_text(encoding='utf8'))
        checker.check_inventory(inventory)
        inventory['sections'][1] = copy.deepcopy(inventory['sections'][0])
        with self.assertRaises(ValueError):
            checker.check_inventory(inventory)

    def test_reviewed_source_json_uses_portable_lf(self):
        for name in ['source_manifest.json', 'source_inventory.json']:
            with self.subTest(file=name):
                self.assertNotIn(b'\r\n', (ROOT / 'books/sicp/notes' / name).read_bytes())


if __name__ == '__main__':
    unittest.main()
