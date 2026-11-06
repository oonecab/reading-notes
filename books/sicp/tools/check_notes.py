#!/usr/bin/env python3
"""SICP source, question/input and executable-companion checks."""
import argparse
import copy
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
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


def quoted_code(text):
    """Only remove source-HTML line-end spaces/tabs; preserve tokens and indentation."""
    lines = text.splitlines()
    while lines and not lines[0].strip(): lines.pop(0)
    while lines and not lines[-1].strip(): lines.pop()
    return '\n'.join(line.rstrip(' \t') for line in lines)


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
    require(manifest['current_scope']['chapter_notes'] == [1], 'Only chapter 1 is complete')
    require(manifest['current_scope']['completed_original_exercises'] == 46, 'Chapter 1 must include all 46 exercises')
    require(manifest['current_scope']['pages'] == ['book_overview.html', 'preface.html', 'chapter01_procedures.html'],
            'Current reading-page scope changed')


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


class QuestionBodies(HTMLParser):
    """Retain nested formula containers rather than stopping at the first div end."""
    def __init__(self, text):
        super().__init__(convert_charrefs=False)
        self.depth, self.current, self.blocks = 0, '', []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        if tag == 'div' and 'exercise-question' in dict(attrs).get('class', '').split():
            require(self.depth == 0, 'Nested question body')
            self.depth, self.current = 1, ''
        elif self.depth:
            if tag == 'div': self.depth += 1
            self.current += self.get_starttag_text()

    def handle_endtag(self, tag):
        if not self.depth: return
        if tag == 'div': self.depth -= 1
        if self.depth: self.current += '</' + tag + '>'
        else: self.blocks.append(self.current)

    def handle_data(self, data):
        if self.depth: self.current += data

    def handle_entityref(self, name):
        if self.depth: self.current += '&' + name + ';'

    def handle_charref(self, name):
        if self.depth: self.current += '&#' + name + ';'


class DisplayFormulaText(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.current, self.blocks = None, []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        if tag == 'math' and dict(attrs).get('display') == 'block': self.current = ''

    def handle_endtag(self, tag):
        if tag == 'math' and self.current is not None:
            self.blocks.append(re.sub(r'\s+', '', self.current)); self.current = None

    def handle_data(self, data):
        if self.current is not None: self.current += data


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
    filenames = {'book_overview.html', 'preface.html', 'chapter01_procedures.html'}
    require({p.name for p in (BOOK / 'notes').glob('*.html')} == filenames, 'Reading-page scope mismatch')
    parsed = {name: Page((BOOK / 'notes' / name).read_text(encoding='utf8')) for name in filenames}
    pdf_links = 0
    for name, page in parsed.items():
        require(len(page.ids) == len(set(page.ids)), 'Duplicate anchor: ' + name)
        require(page.exercises == (46 if name == 'chapter01_procedures.html' else 0), 'Exercise count mismatch')
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
    chapter = (BOOK / 'notes/chapter01_procedures.html').read_text(encoding='utf8')
    questions = json.loads((BOOK / 'notes/questions_ch01.json').read_text(encoding='utf8'))['items']
    source_questions = [e for e in inventory['exercises'] if e['number'].startswith('1.')]
    require([(q['number'], q['pdf_page']) for q in questions] ==
            [(e['number'], e['pdf_page']) for e in source_questions], 'Chapter question source positions mismatch')
    require([x for x in parsed['chapter01_procedures.html'].ids if re.fullmatch(r'ex-1-\d+', x)] ==
            [f'ex-1-{n}' for n in range(1, 47)], 'Missing/reordered chapter questions')
    require(len([s for s in parsed['chapter01_procedures.html'].sections if re.fullmatch(r's1-\d-\d', s or '')]) == 18,
            'All eighteen source subsections required')

    class PreText(HTMLParser):
        def __init__(self, text):
            super().__init__(); self.blocks = []; self.current = None; self.feed(text)
        def handle_starttag(self, tag, attrs):
            if tag == 'pre': self.current = ''
        def handle_data(self, text):
            if self.current is not None: self.current += text
        def handle_endtag(self, tag):
            if tag == 'pre' and self.current is not None:
                self.blocks.append(quoted_code(self.current)); self.current = None

    bodies = QuestionBodies(chapter).blocks
    require(len(bodies) == len(questions) == 46, 'Chinese question body missing')
    for n, (body, question) in enumerate(zip(bodies, questions), 1):
        require(PreText(body).blocks == PreText(question['original_html']).blocks,
                'Given source programs/inputs changed: 1.' + str(n))
        require(DisplayFormulaText(body).blocks == DisplayFormulaText(question['original_html']).blocks,
                'Given display formula tokens changed: 1.' + str(n))
    inputs = json.loads((BOOK / 'notes/chapter01-inputs.json').read_text(encoding='utf8'))
    require(len(inputs['records']) == 14, 'Referenced textbook input inventory changed')
    for record in inputs['records']:
        require(record['code'] == quoted_code(record['original_code']), 'Quoted-code normalization changed tokens')
        block = re.search(r'<div class="source-input" id="' + re.escape(record['id']) + r'">(.*?)</div>', chapter, re.S)
        require(block and PreText(block[1]).blocks == [record['code']], 'Referenced input changed: ' + record['id'])
        require(all(29 <= p <= 134 for p in record['pdf_pages']), 'Referenced input outside chapter')
        if record['kind'] == 'source-fragment':
            original = re.sub(r'\s+', '', ''.join(source_pages[p - 1] for p in record['pdf_pages']))
            for name in re.findall(r'\(define\s+\(([^\s()]+)', record['code']):
                require('(define(' + name in original, 'Referenced procedure source page mismatch: ' + name)
    for exercise, targets in inputs['question_dependencies'].items():
        body = bodies[int(exercise.rsplit('-', 1)[1]) - 1]
        require(all('href="#' + target + '"' in body for target in targets), 'Missing precise question input link: ' + exercise)
    program = (BOOK / 'code/chapter01.rkt').read_text(encoding='utf8').rstrip()
    snippets = re.findall(r'<!-- SICP:snippet ([\w-]+) -->(.*?)<!-- /SICP:snippet -->', chapter, re.S)
    expected_units = re.findall(r'^;; BEGIN ([\w-]+)$', program, re.M)
    require(sorted(name for name, block in snippets) == sorted(expected_units), 'Teaching unit missing/duplicated')
    for name, block in snippets:
        expected = re.search(r';; BEGIN ' + name + r'\n(.*?);; END ' + name, program, re.S)[1].rstrip()
        require(PreText(block).blocks == [expected], 'Teaching code mirror differs: ' + name)
    full = re.search(r'<!-- SICP:full-source -->(.*?)<!-- /SICP:full-source -->', chapter, re.S)
    require(full and PreText(full[1]).blocks == [program], 'Full program reading copy differs')
    results = json.loads((BOOK / 'code/chapter01-results.json').read_text(encoding='utf8'))
    for name, expected in results['program_sha256'].items():
        require(hashlib.sha256((BOOK / 'code' / name).read_bytes()).hexdigest() == expected,
                'Experiment source changed; rerun and review results: ' + name)
    execution = 'not-run: --quick checks sources and mirrors only'
    if not args.quick:
        racket = shutil.which('racket')
        require(racket, 'Full chapter acceptance requires Racket')
        completed = subprocess.run([racket, str(BOOK / 'code/test-chapter01.rkt')], cwd=ROOT,
                                   capture_output=True, text=True, encoding='utf8', timeout=120)
        (args.run_dir / 'racket-tests.txt').write_text(completed.stdout + completed.stderr, encoding='utf8')
        require(completed.returncode == 0, 'Racket chapter regression failed: ' + completed.stdout + completed.stderr)
        execution = completed.stdout.strip()
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
              'scope': 'map, introduction and complete chapter1; source, questions, given inputs and program mirrors',
              'pages': 3, 'source_pdf_pages': pages, 'original_inventory_exercises': 356,
              'completed_exercises': 46, 'pdf_links': pdf_links, 'rejected_mutations': negatives,
              'program_execution': execution}
    (args.run_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
