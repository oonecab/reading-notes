#!/usr/bin/env python3
"""Check the registered source scope, reading files and executable finite models."""
import argparse
import copy
import hashlib
from html import unescape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import tempfile
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET
from sync_code import synchronize, check_displayed, parser_regressions
from check_models import run as check_models
from check_integrals import run as check_integrals
from check_excerpts import check_excerpts
from check_products import run as check_products

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


class Scan(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids, self.refs, self.dependencies = set(), [], []
        self.examples = {}
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            require(attrs['id'] not in self.ids, 'duplicate anchor: ' + attrs['id'])
            self.ids.add(attrs['id'])
        if attrs.get('data-source-item', '').startswith('例 '):
            kind = attrs.get('data-example-kind')
            require(kind in ('完整例题', '定义性短说明'), 'example lacks reading type')
            self.examples[attrs['id']] = kind
        require(tag != 'base' and not any(a.startswith('on') for a in attrs), 'unsafe HTML handler')
        for key in ('href', 'src', 'data', 'poster'):
            if attrs.get(key):
                self.refs.append((tag, attrs[key]))
                if tag != 'a' and urlsplit(attrs[key]).scheme in ('http', 'https'):
                    self.dependencies.append(attrs[key])


def question_block(block):
    start = block.index('<div class="exercise-question">')
    depth = 0
    for tag in re.finditer(r'</?div\b[^>]*>', block[start:]):
        depth += -1 if tag[0].startswith('</') else 1
        if depth == 0:
            return block[start:start + tag.end()]
    raise ValueError('unclosed question')


def load(name):
    return json.loads((ROOT / name).read_text())


def check_coverage(texts, source, exercises, chapters):
    require(len(source['items']) == 236 and len(source['exercises']) == 170, 'independent source scope changed')
    actual_items = [item for text in texts.values() for item in re.findall(r'data-source-item="([^"]+)"', text)]
    require(sorted(actual_items) == sorted(i['key'] for i in source['items']), 'numbered source item missing or duplicated')
    require([sum(i['chapter'] == c for i in source['items']) for c in range(1, 7)] == [34, 41, 36, 36, 34, 55], 'per-chapter numbered scope drift')
    expected_subparts = {(1, 1): 6, (1, 9): 4, (2, 3): 4, (2, 20): 2, (2, 26): 2, (2, 27): 2, (3, 9): 2, (3, 10): 2, (3, 22): 2, (4, 2): 2, (4, 6): 3, (4, 11): 2, (4, 17): 2, (5, 1): 3, (5, 11): 2, (6, 22): 3}
    source_ex = {(e['chapter'], e['number']): e for e in source['exercises']}
    require(len(exercises) == 170 and {(e['chapter'], e['number']) for e in exercises} == set(source_ex),
            'exercise scope differs from independent source inventory')
    for chapter, count in ((1, 25), (2, 32), (3, 30), (4, 28), (5, 28), (6, 27)):
        text = texts[chapters[chapter]]
        actual = re.findall(r'<details class="exercise" id="ex-\d+-\d+" data-exercise="([^"]+)">', text)
        require(actual == [f'{chapter}.{n}' for n in range(1, count + 1)], 'exercise order or number differs')
        require(all(f'<section id="s{chapter}-{n}">' in text for n in range(1, 5 if chapter in (3, 5) else 6)), 'source section omitted')
    for item in source['items']:
        text = texts[chapters[item['chapter']]]
        require(f'id="{item["anchor"]}"' in text, 'source anchor missing')
        require(item['pdf_page'] == item['printed_page'] + 12, 'numbered source page drift')
        if item['chapter'] >= 3 and not item['key'].startswith('例 '):
            require(f'id="{item["anchor"]}-proof"' in text, 'new statement explanation missing')
    for item in exercises:
        source_row = source_ex[(item['chapter'], item['number'])]
        require(item['printed_page'] == source_row['printed_page'] and item['pdf_page'] == item['printed_page'] + 12,
                'exercise source page drift')
        text = texts[item['page']]
        block = text.split(f'id="{item["anchor"]}"', 1)[1].split('</details>', 1)[0]
        q = question_block(block)
        require(hashlib.sha256(q.encode()).hexdigest() == item['question_sha256'], 'question binding drift')
        require(block.index('exercise-question') < block.index('class="answer"'), 'question must precede answer')
        require(item['subparts'] == expected_subparts.get((item['chapter'], item['number']), 0), 'subquestion inventory drift')
        if item['chapter'] == 1:
            require(q.count('<li>') == item['subparts'], 'missing listed subquestion')
        elif item['subparts']:
            require(all(f'({i})' in q for i in range(1, item['subparts'] + 1)), 'missing numbered subquestion')
        last = item['printed_page'] + bool(source_row['continued_on_next_page'])
        label = str(item['printed_page']) if last == item['printed_page'] else f'{item["printed_page"]}—{last}'
        require(f'印刷 {label} / PDF ' in q, 'exercise source range omitted')
        answer = block.split('<div class="answer">', 1)[1]
        require(len(re.sub('<[^>]+>', '', answer)) > 65, 'answer unexpectedly empty')


def structure():
    manifest, source = load('notes/source_manifest.json'), load('notes/source_inventory.json')
    exercises = load('notes/exercise_manifest.json')['exercises']
    reading_review = load('review/source-reading.json')
    for name, inventory in [('items', source['items']), ('exercises', exercises)]:
        rows = reading_review[name]
        require(len(rows) == len(inventory) and {r['anchor'] for r in rows} == {r['anchor'] for r in inventory},
                'review does not match source anchors: ' + name)
        require(len({r['review'] for r in rows}) == len(rows), 'repeated review placeholder: ' + name)
        require(all(len(r['review']) >= 16 and '论证见对应题目' not in r['review'] for r in rows), 'generic review placeholder')
    require(manifest['source_pdf']['pages'] == 256 and len(manifest['chapters']) == 6, 'edition identity changed')
    require([c['source_exercise_count'] for c in manifest['chapters']] == [25, 32, 30, 28, 28, 27], 'source chapter totals changed')
    require(manifest['publication']['include_source_pdf'] is True and
            manifest['publication']['public_path'] == 'measure-probability/assets/source.pdf',
            'registered reader PDF publication differs')
    pdf = ROOT / manifest['source_pdf']['path']
    if pdf.exists():
        require(hashlib.sha256(pdf.read_bytes()).hexdigest() == manifest['source_pdf']['sha256'], 'source PDF hash changed')
    paths = sorted((ROOT / 'notes').glob('*.html'))
    require([p.name for p in paths] == sorted(manifest['current_scope']['pages']) and len(paths) == 8, 'reading page scope changed')
    texts = {p.name: p.read_text() for p in paths}
    require(manifest['current_scope']['label'] == '全六章伴读', 'companion scope label missing')
    require(all('全六章伴读' in re.search(r'<title>(.*?)</title>', text).group(1) for text in texts.values()),
            'reading title does not state current scope')
    accessible = load('review/mathml-accessibility.json')['records']
    ns = {'m': 'http://www.w3.org/1998/Math/MathML'}
    for row in accessible:
        candidates = [m for m in re.findall(r'<math\b.*?</math>', texts[row['page']], re.S)
                      if f'data-accessibility-key="{row["anchor"]}"' in m]
        require(len(candidates) == 1, 'accessible formula missing or duplicated')
        element = ET.fromstring(candidates[0])
        annotation = element.find('m:semantics/m:annotation', ns)
        require(element.get('aria-label') == row['label'] and annotation is not None
                and annotation.get('encoding') == 'text/plain' and annotation.text == row['label'],
                'accessible formula label/annotation drift')
        presentation = candidates[0].split('<semantics>', 1)[1].split('<annotation ', 1)[0]
        require(hashlib.sha256(presentation.encode()).hexdigest() == row['presentation_sha256'],
                'accessible formula changed presentation MathML')
    scans = {p.name: Scan(texts[p.name]) for p in paths}
    maths, links, diagrams = 0, 0, 0
    for path in paths:
        text, scan = texts[path.name], scans[path.name]
        require(not re.search(r'/Users/|file:///|<merror\b', text), 'nonportable or invalid reading content')
        require(not scan.dependencies, 'external reading dependency')
        require(text.count('wide.matches ? 100 : 110') == 1, 'TOC publication contract changed')
        require(text.count('<p class="chapter-nav">') == 2 and '<footer>' in text, 'chapter navigation omitted')
        for tag, ref in scan.refs:
            url = urlsplit(ref)
            require(url.scheme not in ('file', 'javascript', 'vbscript'), 'unsafe link')
            if url.scheme or url.netloc:
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path.resolve()
            require(ROOT in target.parents and target.is_file(), f'missing/outside reading target: {ref}')
            if url.fragment and target.suffix == '.html':
                require(target.parent == ROOT / 'notes' and unquote(url.fragment) in scans[target.name].ids,
                        'missing fragment: ' + ref)
            links += 1
        for math in re.findall(r'<math\b.*?</math>', text, re.S):
            ET.fromstring(math)
            maths += 1
        for svg in re.findall(r'<svg\b.*?</svg>', text, re.S):
            require('<title ' in svg and '<desc ' in svg and 'aria-labelledby=' in svg, 'diagram lacks accessible explanation')
            diagrams += 1
    chapters = {c['chapter']: c['file'] for c in manifest['chapters'] if c['chapter'] <= 6}
    check_coverage(texts, source, exercises, chapters)
    example_index = load('review/example-index.json')['examples']
    expected_examples = {x['anchor'] for x in source['items'] if x['kind'] == '例'}
    require(len(example_index) == len(expected_examples) and {r['anchor'] for r in example_index} == expected_examples,
            'example index is not one-to-one')
    for row in example_index:
        require(scans[row['page']].examples.get(row['anchor']) == row['type'], 'example classification drift')
        require(f'href="{row["page"]}#{row["anchor"]}"' in texts['book_overview.html'], 'example index target missing')
    excerpt_record = load('notes/source_excerpts.json')
    quotation_status = check_excerpts(texts, source, excerpt_record, chapters)
    for item in load('notes/source_excerpts.json')['excerpts']:
        require(item['text'] in unescape(texts[item['page']]) and f'id="{item["anchor"]}"' in texts[item['page']],
                'preface quotation changed')
    for item in load('notes/source_issues.json')['issues']:
        require(item['anchor'] in scans[item['page']].ids, 'source correction anchor omitted')
    # Sensitivity checks operate on copies, never modifying formal notes.
    rejected = []
    for label in ('excerpt_status', 'excerpt_page'):
        bad_texts, bad_record = dict(texts), copy.deepcopy(excerpt_record)
        first = bad_record['statements'][0]
        if label == 'excerpt_status':
            bad_texts[first['page']] = bad_texts[first['page']].replace('data-source-status="location-only"', 'data-source-status="excerpt"', 1)
        else:
            first['pdf_pages'][0] += 1
        try:
            check_excerpts(bad_texts, source, bad_record, chapters)
        except ValueError:
            rejected.append(label)
        else:
            raise ValueError('accepted altered quotation record: ' + label)
    question = question_block(texts[chapters[2]].split('id="ex-2-6"', 1)[1])
    wrong_condition = question.replace('&lt;∞', '&lt;0', 1)
    require(wrong_condition != question, 'condition mutation did not alter question')
    for name, changes in [('exercise_number', {chapters[1]: texts[chapters[1]].replace('data-exercise="1.25"', 'data-exercise="1.26"')}),
                          ('question_condition', {chapters[2]: texts[chapters[2]].replace(question, wrong_condition, 1)})]:
        candidate = {**texts, **changes}
        require(candidate != texts, 'mutation did not modify reading content')
        try:
            check_coverage(candidate, source, exercises, chapters)
        except (ValueError, IndexError):
            rejected.append(name)
        else:
            raise ValueError('coverage checker accepted mutation: ' + name)
    for chapter, number, before, after in [(3, 9, '(2)', '(0)'), (4, 27, '几乎必然', '处处'), (5, 11, '(2)', '(0)'), (6, 22, '(3)', '(0)')]:
        page = chapters[chapter]
        q = question_block(texts[page].split(f'id="ex-{chapter}-{number}"', 1)[1])
        changed = q.replace(before, after, 1)
        require(changed != q, 'new condition mutation did not change text')
        candidate = {**texts, page: texts[page].replace(q, changed, 1)}
        try:
            check_coverage(candidate, source, exercises, chapters)
        except ValueError:
            rejected.append(f'chapter_{chapter}_question_condition')
        else:
            raise ValueError('accepted altered new chapter condition')
    shifted = [dict(item) for item in exercises]
    shifted[0]['pdf_page'] += 1
    try:
        check_coverage(texts, source, shifted, chapters)
    except ValueError:
        rejected.append('source_page')
    else:
        raise ValueError('coverage checker accepted wrong PDF page')
    try:
        check_displayed('return 1\n', 'return 0\n')
    except ValueError:
        rejected.append('displayed_source')
    else:
        raise ValueError('synchronization accepted changed source')
    binding = 'pending final local review'
    if manifest['current_scope']['status'] == 'completed_locally':
        review = load('review/validation.json')
        required = {p.relative_to(ROOT).as_posix() for p in paths}
        required |= {p.relative_to(ROOT).as_posix() for directory in ('code', 'tools') for p in (ROOT/directory).glob('*') if p.is_file()}
        required |= {p.relative_to(ROOT).as_posix() for p in (ROOT/'notes').glob('*.json')}
        require(required <= set(review['file_sha256']), 'review binding omits formal content')
        for name, sha in review['file_sha256'].items():
            file = (ROOT/name).resolve()
            require(ROOT in file.parents and file.is_file(), 'review file is outside book')
            require(hashlib.sha256(file.read_bytes()).hexdigest() == sha, 'stale review: ' + name)
        binding = 'current files match recorded review; semantic and browser evidence are separate'
    return {'pages': len(paths), 'original_exercises': len(exercises), 'numbered_statements': 203,
            'numbered_examples': 33, 'mathml': maths, 'svg': diagrams, 'local_links': links,
            'quotation_status': quotation_status,
            'annotated_core_formulae': len(accessible),
            'synchronized_sources': synchronize(), 'source_parser_mutations_rejected': parser_regressions(),
            'mutations_rejected': rejected,
            'source_pdf': 'local hash verified; page inventory read from scan' if pdf.exists() else 'recorded identity; local scan unavailable',
            'review_binding': binding}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--run-dir', type=Path)
    args = parser.parse_args()
    report = {'structure': structure()}
    if not args.quick:
        (ROOT / 'tmp').mkdir(exist_ok=True)
        run_dir = args.run_dir or Path(tempfile.mkdtemp(prefix='check-', dir=ROOT / 'tmp'))
        run_dir.mkdir(parents=True, exist_ok=True)
        report['programs'] = check_models(run_dir)
        report['integration_program'] = check_integrals(run_dir / 'integration')
        report['product_limits_program'] = check_products(run_dir / 'product-limits')
        (run_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
