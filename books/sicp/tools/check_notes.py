#!/usr/bin/env python3
"""SICP two-page source/coverage checks; only Python standard library and Poppler."""
import argparse
import copy
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[3]
BOOK = ROOT / 'books/sicp'
STARTS = [29, 135, 322, 515, 694]
COUNTS = [46, 97, 82, 79, 52]
TITLES = ['Building Abstractions with Procedures', 'Building Abstractions with Data',
          'Modularity, Objects, and State', 'Metalinguistic Abstraction',
          'Computing with Register Machines']
MAJOR_PAGES = [34, 68, 102, 140, 160, 220, 257, 282, 324, 348, 369,
               429, 456, 520, 569, 587, 622, 696, 724, 751, 769, 795]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_manifest(manifest, digest, pages):
    source = manifest['source']
    require(source['file'] == 'books/sicp/sicp.pdf', 'PDF must be this repository source')
    require(source['sha256'] == digest, 'Source PDF identity changed')
    require(source['pdf_pages'] == pages == 883, 'PDF page count changed')
    require([c['pdf_start'] for c in manifest['chapters']] == STARTS, 'Chapter page mapping changed')
    require([c['exercise_count'] for c in manifest['chapters']] == COUNTS, 'Source exercise counts changed')
    require([c['title'] for c in manifest['chapters']] == TITLES, 'Chapter source titles changed')
    require(manifest['edition'] == 'Second edition; Unofficial Texinfo Format 2.andresraba5.6',
            'Wrong source edition')
    require(manifest['main_page_mapping'] == {'printed_start': 1, 'printed_end': 855,
            'pdf_start': 29, 'pdf_end': 883, 'offset': 28}, 'Main page mapping changed')
    require([(c['printed_start'], c['printed_end'], c['pdf_start'], c['pdf_end'])
             for c in manifest['chapters']] ==
            [(a - 28, b - 28, a, b) for a, b in zip(STARTS, [134, 321, 514, 693, 861])],
            'Chapter page ranges changed')
    require([(f['title'], f['printed_start'], f['printed_end'], f['pdf_start'], f['pdf_end'])
             for f in manifest['front_matter']] == [
                ('Title and copyright', None, None, 1, 2), ('Contents', 'iii', 'viii', 3, 8),
                ('Unofficial Texinfo Format', 'ix', 'xi', 9, 11), ('Dedication', 'xii', 'xii', 12, 12),
                ('Foreword', 'xiii', 'xviii', 13, 18), ('Preface to the Second Edition', 'xix', 'xx', 19, 20),
                ('Preface to the First Edition', 'xxi', 'xxiv', 21, 24),
                ('Acknowledgments', 'xxv', 'xxviii', 25, 28)], 'Front-matter mapping changed')
    require(manifest['current_scope']['chapter_notes'] == [], 'Chapter expansion is outside this batch')
    require(manifest['current_scope']['completed_original_exercises'] == 0, 'No original exercise solutions in this batch')


def check_inventory(inventory):
    expected_sections = [f'{c}.{n}' for c, count in enumerate([3, 5, 5, 4, 5], 1)
                         for n in range(1, count + 1)]
    require([s['number'] for s in inventory['sections']] == expected_sections,
            'Major sections must be complete, unique and ordered')
    require([s['pdf_page'] for s in inventory['sections']] == MAJOR_PAGES,
            'Major section source mapping changed')
    require(len(inventory['toc']) == 152, 'Source outline coverage changed')
    require(all(row['title'].strip() and row['level'] in (1, 2, 3, 4)
                and 1 <= row['pdf_page'] <= 883 for row in inventory['toc']), 'Invalid outline entry')
    require([row['pdf_page'] for row in inventory['toc']] ==
            sorted(row['pdf_page'] for row in inventory['toc']), 'Outline order changed')


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.hrefs, self.sections = [], [], []
        self.exercises = 0
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.hrefs.append(attrs['href'])
        if tag == 'section':
            self.sections.append(attrs.get('id'))
        if 'exercise' in attrs.get('class', '').split():
            self.exercises += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--run-dir', type=Path, default=ROOT / 'tmp/sicp/check')
    args = parser.parse_args()
    manifest = json.loads((BOOK / 'notes/source_manifest.json').read_text(encoding='utf8'))
    inventory = json.loads((BOOK / 'notes/source_inventory.json').read_text(encoding='utf8'))
    source = ROOT / manifest['source']['file']
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    info = subprocess.check_output(['pdfinfo', '-enc', 'UTF-8', '-isodates', str(source)], encoding='utf8')
    pages = int(re.search(r'^Pages:\s+(\d+)', info, re.M)[1])
    check_manifest(manifest, digest, pages)
    check_inventory(inventory)
    expected = {f'{c}.{n}' for c, count in enumerate(COUNTS, 1) for n in range(1, count + 1)}
    require({e['number'] for e in inventory['exercises']} == expected, 'Original exercise inventory incomplete')
    require(len(inventory['exercises']) == inventory['total_exercises'] == 356, 'Duplicate/missing original exercises')
    for entry in [*inventory['sections'], *inventory['exercises']]:
        require(entry['pdf_page'] == entry['printed_page'] + 28, 'Body page mapping invalid')
    filenames = {'book_overview.html', 'preface.html'}
    require({p.name for p in (BOOK / 'notes').glob('*.html')} == filenames, 'Only two reading pages are in scope')
    parsed = {name: Page((BOOK / 'notes' / name).read_text(encoding='utf8')) for name in filenames}
    pdf_links = 0
    for name, page in parsed.items():
        require(len(page.ids) == len(set(page.ids)), 'Duplicate anchor: ' + name)
        require(page.exercises == 0, 'Exercises are outside this batch')
        for href in page.hrefs:
            url = urlsplit(href)
            if url.scheme or url.netloc:
                continue
            target = (BOOK / 'notes' / unquote(url.path)).resolve() if url.path else BOOK / 'notes' / name
            require(ROOT in target.parents and target.is_file(), 'Broken/escaping source link: ' + href)
            if target.suffix == '.pdf':
                require(target == source, 'All original-book PDF links must use sicp.pdf')
                match = re.fullmatch(r'page=(\d+)', url.fragment)
                require(match and 1 <= int(match[1]) <= pages, 'PDF page outside source: ' + href)
                pdf_links += 1
            elif url.fragment:
                dest = parsed.get(target.name)
                require(dest and url.fragment in dest.ids, 'Broken HTML anchor: ' + href)
    overview = (BOOK / 'notes/book_overview.html').read_text(encoding='utf8')
    for chapter, start in enumerate(STARTS, 1):
        require(f'id="chapter-{chapter}"' in overview and f'../sicp.pdf#page={start}' in overview,
                'Chapter summary/source missing')
    # Independently re-read the PDF itself, not just two mutually matching JSON files.
    args.run_dir.mkdir(parents=True, exist_ok=True)
    text = subprocess.check_output(['pdftotext', '-layout', str(source), '-'], encoding='utf8')
    source_pages = text.split('\f')
    for section in inventory['sections']:
        # A heading may wrap to the next line but retains its original number.
        heading = re.escape(section['number']) + r'\s+'
        require(re.search(heading, source_pages[section['pdf_page'] - 1]),
                'Major section source position changed: ' + section['number'])
    for exercise in inventory['exercises']:
        page = source_pages[exercise['pdf_page'] - 1]
        if exercise['number'] == '1.13':
            require('Exercise' in page and '1.13:' in page, 'Formula-overlaid exercise source changed')
        else:
            require(re.search(r'Exercise\s+' + re.escape(exercise['number']) + r'\s*:', page),
                    'Exercise source position changed: ' + exercise['number'])
    for title, number in [('Foreword', 13), ('Preface to the Second Edition', 19),
                          ('Preface to the First Edition', 21)]:
        require(title in source_pages[number - 1], 'Source front-matter heading mismatch')
    for number in STARTS:
        require(manifest['chapters'][STARTS.index(number)]['title'].split()[0] in source_pages[number - 1],
                'Source chapter heading mismatch')
    negatives = 0
    for mutate in [lambda m: m['source'].update(sha256='0' * 64),
                   lambda m: m['chapters'][1].update(pdf_start=134),
                   lambda m: m['chapters'].pop(),
                   lambda m: m['current_scope'].update(completed_original_exercises=1)]:
        broken = copy.deepcopy(manifest)
        mutate(broken)
        try:
            check_manifest(broken, digest, pages)
        except ValueError:
            negatives += 1
        else:
            raise ValueError('Invalid source/scope mutation accepted')
    report = {'status': 'passed', 'book': 'sicp', 'quick': args.quick,
              'scope': 'map-and-introduction; source, coverage, links; no chapter programs in scope',
              'pages': 2, 'source_pdf_pages': pages, 'original_inventory_exercises': 356,
              'completed_exercises': 0, 'pdf_links': pdf_links, 'rejected_mutations': negatives,
              'program_execution': 'not-applicable: this batch contains no programs'}
    (args.run_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
