#!/usr/bin/env python3
"""Check current chapter coverage, source identity, reading copies and examples."""
import argparse
from html import unescape
from html.parser import HTMLParser
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

from inventory_source import inventory
from sync_code import synchronize
from check_algebra import run as check_algebra
from check_structures import run as check_structures, source_diagram_checks
from check_sylow_galois import run as check_sylow_galois
from check_reading import run as check_reading

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
sys.path.insert(0, str(REPO / 'books/stochastic/tools'))
from html_support import Document
EXPECTED = {'e': 'ABC', 'a': 'BAC', 'b': 'ACB', 'ab': 'BCA', 'ba': 'CAB', 'aba': 'CBA'}
# Independent hand-read adjacency of the six-node figure, not swap-array code.
EDGES = {'ABC': ('BAC', 'ACB'), 'BAC': ('ABC', 'BCA'), 'BCA': ('CBA', 'BAC'),
         'CBA': ('BCA', 'CAB'), 'CAB': ('ACB', 'CBA'), 'ACB': ('CAB', 'ABC')}


class Scan(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids, self.refs, self.external_dependencies = set(), [], []
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                raise ValueError('duplicate ID: ' + attrs['id'])
            self.ids.add(attrs['id'])
        for key in ('href', 'src', 'data', 'poster'):
            if key in attrs:
                self.refs.append((tag, attrs[key]))
                if tag != 'a' and urlsplit(attrs[key]).scheme in ('http', 'https'):
                    self.external_dependencies.append(attrs[key])
        if tag == 'base' or any(key.startswith('on') for key in attrs):
            raise ValueError('unexpected base or inline event handler')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def source_text(node):
    """Recover one continuous source spelling through inline MathML."""
    if isinstance(node, str):
        return node
    if node.tag == 'math' and node.attrs.get('aria-label'):
        return node.attrs['aria-label']
    return ''.join(source_text(child) for child in node.children)


def question_block(block):
    start = block.index('<div class="exercise-question">')
    depth = 0
    for tag in re.finditer(r'</?div\b[^>]*>', block[start:]):
        depth += -1 if tag[0].startswith('</') else 1
        if depth == 0:
            return block[start:start + tag.end()]
    raise ValueError('unclosed question block')


def structure():
    notes = ROOT / 'notes'
    manifest = json.loads((notes / 'source_manifest.json').read_text())
    source_items = json.loads((notes / 'source_inventory.json').read_text())
    require(len(manifest['chapters']) == 10 and manifest['source_pdf']['pages'] == 312,
            'source edition or chapter count changed')
    require(manifest['publication']['include_source_pdf'] is True and
            manifest['publication']['public_path'] == 'visual-group-theory/assets/source.pdf',
            'registered reader PDF publication differs')
    require(sum(c['source_exercise_count'] for c in manifest['chapters']) == 302,
            'independent source exercise total changed')
    local_pdf = ROOT / manifest['source_pdf']['path']
    if local_pdf.exists():
        require(hashlib.sha256(local_pdf.read_bytes()).hexdigest() == manifest['source_pdf']['sha256'],
                'source PDF identity changed')
        live = inventory(local_pdf)
        fields = ('kind', 'number', 'printed_page', 'pdf_page')
        identity = lambda rows: [tuple(row[k] for k in fields) for row in rows]
        require(live['pdf_pages'] == 312 and identity(live['items']) == identity(source_items['items']),
                'source inventory differs from PDF')
        require(live['page_labels'] == source_items['page_labels'], 'source page labels drifted')
    for row in source_items['page_labels'][15:]:
        require(row['printed_page'] is not None and int(row['printed_page']) + 15 == row['pdf_page'],
                'Arabic page mapping is not +15')
    files = sorted(notes.glob('*.html'))
    require([p.name for p in files] == sorted(manifest['current_scope']['pages']), 'page scope mismatch')
    texts = {p.resolve(): p.read_text() for p in files}
    scans = {p: Scan(text) for p, text in texts.items()}
    links, maths, diagrams = 0, 0, 0
    for path, text in texts.items():
        Document(text)
        require(not re.search(r'/Users/|file:///|https?://[^" ]+\.(?:js|css)', text), 'nonportable reading dependency')
        require(not scans[path].external_dependencies, 'external reading dependency')
        for tag, ref in scans[path].refs:
            url = urlsplit(ref)
            require(url.scheme not in ('file', 'javascript', 'vbscript'), 'unsafe reference')
            if url.scheme or url.netloc:
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            require(ROOT in target.parents and target.is_file(), f'missing/outside resource: {path.name}: {ref}')
            if url.fragment and target.suffix == '.html':
                require(unquote(url.fragment) in scans[target].ids, f'missing anchor: {ref}')
            links += 1
        for m in re.findall(r'<math\b.*?</math>', text, re.S):
            ET.fromstring(m)
            maths += 1
        for svg in re.findall(r'<svg\b.*?</svg>', text, re.S):
            require('<title ' in svg and '<desc ' in svg and 'aria-labelledby=' in svg,
                    'unlabelled diagram')
            diagrams += 1
        require('<footer>' in text and text.count('<p class="chapter-nav">') == 2,
                'missing chapter navigation')
        require(text.count('wide.matches ? 100 : 110') == 1, 'TOC publication contract mismatch')
    chapter = texts[(notes / 'chapter01_what_is_a_group.html').resolve()]
    ids = scans[(notes / 'chapter01_what_is_a_group.html').resolve()].ids
    require(all(f's1-{i}' in ids for i in range(1, 6)), 'missing original section')
    require(all(f's1-5-{i}' in ids for i in range(1, 5)), 'missing exercise subsection')
    actual = re.findall(r'<details class="exercise" id="([^"]+)" data-exercise="([^"]+)">', chapter)
    require([n for _, n in actual] == [f'1.{i}' for i in range(1, 15)], 'exercise number/order mismatch')
    exercise_data = json.loads((notes / 'exercise_manifest.json').read_text())['exercises']
    require(len(exercise_data) == 302, 'exercise manifest count mismatch')
    source_scope = {r['number']: r for r in source_items['items']
                    if r['kind'] == 'Exercise' and int(r['number'].split('.')[0]) <= 10}
    require(set(source_scope) == {r['number'] for r in exercise_data}, 'source exercise coverage differs')
    subparts = {'1.4': 4, '1.7': 2, '1.8': 5, '1.14': 4,
                '2.8': 2, '2.9': 3, '2.19': 4,
                '3.11': 6, '3.12': 5, '3.13': 2, '3.14': 3, '3.15': 3, '3.16': 3,
                '4.1': 6, '4.2': 2, '4.3': 5, '4.4': 6, '4.5': 2, '4.6': 3,
                '4.9': 4, '4.10': 2, '4.11': 2, '4.12': 2, '4.13': 4,
                '4.16': 4, '4.19': 5, '4.21': 3, '4.25': 3, '4.26': 4,
                '4.27': 3, '4.28': 3, '4.30': 3, '4.31': 3, '4.32': 4, '4.33': 7}
    independent_parts = json.loads((notes / 'structures_inputs.json').read_text())['source_subparts']
    subparts.update({k:len(v) for k,v in independent_parts.items()})
    subparts.update({k:len(v) for k,v in json.loads((notes/'sylow_galois_inputs.json').read_text())['source_subparts'].items()})
    for item in exercise_data:
        page_text = texts[(notes / item['page']).resolve()]
        block = page_text.split(f'id="{item["anchor"]}"', 1)[1].split('</details>', 1)[0]
        q = question_block(block)
        require(block.index('exercise-question') < block.index('class="answer"'), 'answer before question')
        require(hashlib.sha256(q.encode()).hexdigest() == item['question_sha256'], 'question binding drifted')
        require(q.count('<li>') == subparts.get(item['number'], 0), 'missing subquestion: '+item['number'])
        require(item['printed_pages'][0] == source_scope[item['number']]['printed_page'],
                'exercise source page changed: ' + item['number'])
        require(item['pdf_pages'] == [p + 15 for p in item['printed_pages']], 'exercise PDF page changed')
        if item['number'] in ('2.19', '4.9'):
            require('(i)' in q and '(ii)' in q, 'nested source subquestions missing')
    expected_files = {row['chapter']: row['file'] for row in manifest['chapters'] if row['chapter'] <= 10}
    for c, count, section_count, exercise_section_count in ((2,19,6,5),(3,16,4,4),(4,33,5,6),(5,44,5,6),(6,31,6,5),(7,37,6,5),(8,50,7,10),(9,28,5,5),(10,30,8,4)):
        text = texts[(notes / expected_files[c]).resolve()]
        page_ids = scans[(notes / expected_files[c]).resolve()].ids
        found = re.findall(r'<details class="exercise" id="([^"]+)" data-exercise="([^"]+)">', text)
        require([n for _, n in found] == [f'{c}.{i}' for i in range(1,count+1)], 'chapter exercise order changed')
        require(all(f's{c}-{i}' in page_ids for i in range(1,section_count+1)), 'original section missing')
        require(all(f's{c}-{section_count}-{i}' in page_ids for i in range(1,exercise_section_count+1)), 'exercise subsection missing')
    for c, prefixes in {5:{1:4,2:3,3:5,4:5},6:{1:1},7:{1:4},8:{1:2},9:{2:1,4:5},10:{5:5,7:3}}.items():
        page_ids = scans[(notes / expected_files[c]).resolve()].ids
        require(all(f's{c}-{section}-{i}' in page_ids for section,count in prefixes.items() for i in range(1,count+1)), 'original internal subsection missing')
    statements = [r for r in source_items['items'] if r['kind'] != 'Exercise' and int(r['number'].split('.')[0]) <= 10]
    require(len(statements) == 62, 'source chapter statements missing')
    for item in statements:
        c = int(item['number'].split('.')[0])
        require(f'data-source-item="{item["kind"]} {item["number"]}"' in texts[(notes/expected_files[c]).resolve()], 'missing numbered statement')
    excerpts = json.loads((notes / 'source_excerpts.json').read_text())['excerpts']
    for item in excerpts:
        text = texts[(notes / item['page']).resolve()]
        anchors = [node for node in Document(text).root.walk()
                   if node.attrs.get('id') == item['anchor']]
        require(len(anchors) == 1 and item['text'] in source_text(anchors[0]),
                'source excerpt drifted')
    table = dict(re.findall(r'data-word="([^"]+)" data-result="([^"]+)"', chapter))
    require(table == EXPECTED, 'six-action table disagrees with independent reference')
    binding = 'not yet completed'
    if manifest['current_scope']['status'] == 'completed_locally':
        review_path = ROOT / 'review/validation.json'
        require(review_path.is_file(), 'completed batch has no current review binding')
        review = json.loads(review_path.read_text())
        required = {p.relative_to(ROOT).as_posix() for p in files}
        required.update(('code/actions.c', 'code/actions.py', 'notes/exercise_manifest.json',
                         'notes/source_manifest.json', 'notes/source_inventory.json', 'notes/source_excerpts.json'))
        required.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'code').glob('*') if p.is_file())
        required.update(('notes/algebra_inputs.json','notes/structures_inputs.json','notes/sylow_galois_inputs.json'))
        require(required <= review['file_sha256'].keys(), 'review binding omits maintained content')
        for name, digest in review['file_sha256'].items():
            path = (ROOT / name).resolve()
            require(ROOT in path.parents and path.is_file(), 'review binding points outside book')
            require(hashlib.sha256(path.read_bytes()).hexdigest() == digest,
                    'review binding is stale: ' + name)
        binding = 'file hashes match; semantic and browser evidence recorded separately'
    return {'pages': len(files), 'original_exercises': len(exercise_data), 'numbered_statements': len(statements),
            'excerpts': len(excerpts), 'links': links, 'mathml': maths, 'svg': diagrams,
            'source_diagrams': source_diagram_checks(),
            'synchronized_sources': synchronize(),
            'review_binding': binding,
            'source_pdf': 'hash and inventory checked' if local_pdf.exists() else 'not installed; recorded identity only'}


def word_result(word, start='ABC'):
    for symbol in word:
        start = EDGES[start][0 if symbol == 'a' else 1]
    return start


def python_oracle(module):
    discovered = {word or 'e': module.format_state(state) for word, state in module.enumerate_actions()}
    require(discovered == EXPECTED, 'enumeration disagrees with six independent cases')
    require({state for _, state in module.enumerate_actions()} == set(itertools.permutations(range(3))),
            'reachable states are not all six permutations')
    checked = 0
    for length in range(8):
        for symbols in itertools.product('ab', repeat=length):
            word = ''.join(symbols)
            for state in itertools.permutations(range(3)):
                start = module.format_state(state)
                result = module.apply_word(word, state)
                require(module.format_state(result) == word_result(word, start), 'word direction or swap mismatch')
                require(module.apply_word(word[::-1], result) == state, 'inverse word failed')
                checked += 1
    for bad in ('c', 'a b', 'A', 'e', 'a\nb'):
        try:
            module.apply_word(bad)
        except ValueError:
            pass
        else:
            raise ValueError('illegal instruction accepted')
    for state in ((0, 0, 2), (0, 1), (0, 1, 3)):
        try:
            module.apply_word('', state)
        except ValueError:
            pass
        else:
            raise ValueError('invalid state accepted')
    return checked


def programs(run_dir):
    spec = importlib.util.spec_from_file_location('vgt_actions', ROOT / 'code/actions.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    cases = python_oracle(module)
    expected = ''.join(f'{w} {s}\n' for w, s in EXPECTED.items())
    compiler = ['clang', '-std=c11', '-Wall', '-Wextra', '-Werror', '-pedantic']
    variants = [('-O2',), ('-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer')]
    commands, c_cases = [], 0
    for index, flags in enumerate(variants):
        binary = run_dir / f'actions-{index}'
        command = compiler + list(flags) + [str(ROOT / 'code/actions.c'), '-o', str(binary)]
        subprocess.run(command, check=True, capture_output=True, text=True)
        commands.append(' '.join(compiler + list(flags) + ['code/actions.c', '-o', f'actions-{index}']))
        for driver in ([str(binary)], [sys.executable, str(ROOT / 'code/actions.py')]) if index == 0 else ([str(binary)],):
            result = subprocess.run(driver, capture_output=True, text=True)
            require(result.returncode == 0 and result.stdout == expected and not result.stderr, 'default program output mismatch')
            words = [''.join(x) for n in range(7) for x in itertools.product('ab', repeat=n)]
            words += ['ab' * 5000]
            for word in words:
                result = subprocess.run(driver + [word], capture_output=True, text=True)
                require(result.returncode == 0 and result.stdout == word_result(word) + '\n' and not result.stderr,
                        'CLI calculation mismatch')
                c_cases += 1
            for args in (['e'], ['c'], ['a b'], ['A'], ['a', 'b']):
                result = subprocess.run(driver + args, capture_output=True, text=True)
                require(result.returncode == 2 and not result.stdout and result.stderr, 'CLI failure contract changed')
    original = (ROOT / 'code/actions.py').read_text()
    mutations = {
        'wrong_swap': original.replace('left = 0 if action == "a" else 1', 'left = 1 if action == "a" else 0'),
        'reverse_time_order': original.replace('for action in word:\n', 'for action in reversed(word):\n')}
    rejected = []
    for name, source in mutations.items():
        require(source != original, 'mutation failed to alter source')
        namespace = {'__name__': 'mutated_actions'}
        exec(compile(source, name, 'exec'), namespace)
        from types import SimpleNamespace
        try:
            python_oracle(SimpleNamespace(**namespace))
        except ValueError:
            rejected.append(name)
        else:
            raise ValueError('oracle accepted incorrect action model: ' + name)
    return {'python_state_word_cases': cases, 'cli_word_cases': c_cases,
            'c_build_commands': commands, 'mutations_rejected': rejected,
            'platform': sys.platform, 'python': sys.version.split()[0]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--run-dir', type=Path)
    args = parser.parse_args()
    report = {'structure': structure(), 'reading_consistency': check_reading()}
    if not args.quick:
        if args.run_dir:
            run_dir = args.run_dir
            run_dir.mkdir(parents=True, exist_ok=True)
        else:
            (ROOT / 'tmp').mkdir(exist_ok=True)
            run_dir = Path(tempfile.mkdtemp(prefix='check-', dir=ROOT / 'tmp'))
        report['programs'] = programs(run_dir)
        report['chapters_2_4'] = check_algebra(run_dir)
        report['chapters_5_8'] = check_structures(run_dir)
        report['chapters_9_10'] = check_sylow_galois(run_dir)
        (run_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
