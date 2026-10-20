#!/usr/bin/env python3
"""Bind reviewed reading content to a snapshot; this does not prove mathematics."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from html_support import Document, canonical

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools/content_baseline.json'


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode()).hexdigest()


def snapshot():
    pages = {}
    for path in sorted((ROOT/'notes').glob('*.html')):
        document = Document(path.read_text())
        mains = list(document.root.walk('main'))
        if len(mains) != 1:
            raise ValueError(path.name+': expected one reading main')
        maths = []
        for node in mains[0].walk('math'):
            if not node.attrs.get('data-tex') or not node.text().strip():
                raise ValueError(path.name+': empty TeX or rendered MathML')
            maths.append({'tex': digest(node.attrs['data-tex']),
                          'mathml': digest(canonical(node))})
        pages[path.name] = {
            'main_sha256': digest(canonical(mains[0], omit_programs=True)),
            'formulas': maths,
            'excerpts': [digest(canonical(n)) for n in mains[0].walk('blockquote')
                         if n.has_class('original-excerpt')],
        }
    return {'schema_version': 1,
            'scope': 'Reviewed text, formulas, quotes, page links and structure. Program bodies are checked against standalone sources separately. Snapshot equality is a change guard, not a mathematical proof.',
            'source_pdf_sha256': json.loads((ROOT/'notes/source_manifest.json').read_text())['sha256'],
            'pages': pages}


def check_snapshot():
    expected = json.loads(BASELINE.read_text())
    actual = snapshot()
    if actual != expected:
        changed = [name for name, page in actual['pages'].items()
                   if expected.get('pages', {}).get(name) != page]
        raise ValueError('Reading content changed since review: '+', '.join(changed)+
                         '. Review the change before recording a new content baseline.')
    return {'status': 'pass', 'pages': len(actual['pages']),
            'formula_bindings': sum(len(p['formulas']) for p in actual['pages'].values()),
            'scope': actual['scope']}


def check_pdf_locations():
    manifest = json.loads((ROOT/'notes/source_manifest.json').read_text())
    numbered = {(n['kind'], n['number']): n['pdf_page'] for n in manifest['numbered_results']}
    exercises = {n['number']: n['pdf_page'] for c in manifest['chapters'][:6] for n in c['exercises']}
    count = 0
    for path in sorted((ROOT/'notes').glob('*.html')):
        doc = Document(path.read_text())
        for node in doc.root.walk():
            expected = None
            if node.has_class('exercise'):
                number = node.attrs.get('data-original-exercise') or node.attrs['id'][3:].replace('-', '.')
                expected = exercises[number]
            elif node.has_class('source-statement') and node.attrs.get('data-source-number'):
                expected = numbered[(node.attrs['data-source-kind'], node.attrs['data-source-number'])]
            if expected is None:
                continue
            links = [a.attrs.get('href','') for a in node.walk('a') if '.pdf#page=' in a.attrs.get('href','')]
            cited = {int(re.search(r'#page=(\d+)', link)[1]) for link in links}
            if expected not in cited:
                raise ValueError(path.name+'#'+node.attrs['id']+': expected PDF page '+str(expected))
            count += 1
    return {'status': 'pass', 'numbered_results_and_exercises': count}


def check_source_numbers():
    executable = shutil.which('pdftotext')
    if not executable:
        raise RuntimeError('pdftotext is required for the complete source-page check')
    manifest = json.loads((ROOT/'notes/source_manifest.json').read_text())
    result = subprocess.run([executable, '-layout', ROOT/manifest['web_pdf']['path'], '-'],
                            check=True, text=True, capture_output=True)
    pages = result.stdout.split('\f')
    count = 0
    for row in manifest['numbered_results'] + [dict(x, kind='Exercise') for c in manifest['chapters'][:6] for x in c['exercises']]:
        page = pages[row['pdf_page']-1]
        number = re.escape(row['number'])
        pattern = r'(?m)^\s*'+number+r'\.' if row['kind'] == 'Exercise' else r'\b'+row['kind']+r'\s+'+number+r'(?![\d.])'
        # A period after a theorem number is ordinary punctuation.
        if row['kind'] != 'Exercise':
            pattern = r'\b'+row['kind']+r'\s+'+number+r'(?!\d)'
        if not re.search(pattern, page):
            raise ValueError('Source number not found on PDF page: '+str(row))
        count += 1
    return {'status': 'pass', 'source_numbers_checked': count,
            'scope': 'Number and starting-page correspondence; translated text and proofs require mathematical/source review.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true', help='Record the current content after reviewing it')
    parser.add_argument('--source-pages', action='store_true')
    args = parser.parse_args()
    if args.record:
        BASELINE.write_text(json.dumps(snapshot(), ensure_ascii=False, separators=(',', ':'))+'\n')
        print('Recorded reviewed reading-content baseline')
    else:
        print(json.dumps({'content_snapshot': check_snapshot(), 'page_links': check_pdf_locations(),
                          **({'source_pages': check_source_numbers()} if args.source_pages else {})},
                         ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
