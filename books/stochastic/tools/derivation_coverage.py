#!/usr/bin/env python3
"""Inventory all source items and check navigable, item-specific derivations.

These are structural review gates, not a proof of mathematical correctness.
The source catalog determines the inventory; HTML determines current evidence.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from html_support import Document, Element

ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / 'notes'
OUTPUT = NOTES / 'derivation_coverage.json'
SAMPLE_PAGE = 'chapter01_markov_chains.html'
RESULT_KINDS = {'Theorem', 'Lemma'}
EMPTY_STEP = re.compile(r'类似可得|同理可得|代入即可|计算即可|略去.*步骤|证明略|代回第二步每个方程可逐项核对')


def readable(node):
    if isinstance(node, str):
        return node
    if node.tag == 'math':
        return ' ' + node.attrs.get('data-tex', node.text()) + ' '
    return ' '.join(readable(c) for c in node.children)


def mentions(node, number):
    """Exact numbering or explicit same-chapter ranges; never 1.1 inside 1.10."""
    if node is None:
        return False
    text = readable(node)
    if re.search(r'(?<![\d.])' + re.escape(number) + r'(?!\d|\.\d)', text):
        return True
    chapter, index = number.split('.')
    for match in re.finditer(r'(?:定理|引理|例|Theorem|Lemma|Example)\s*([A-Z]|\d+)\.(\d+)\s*[–—−~～至-]\s*(?:([A-Z]|\d+)\.)?(\d+)', text):
        if match[1] == chapter and (match[3] or chapter) == chapter:
            if int(match[2]) <= int(index) <= int(match[4]):
                return True
    return False


def mentions_result(node, number):
    # Do not confuse Example 4.10 or a decimal with Lemma 4.10.
    if node is None:
        return False
    text = readable(node)
    groups = re.findall(r'(?:定理|引理|Theorem|Lemma)\s*[A-Z\d]+\.\d+(?:\s*[、,，–—−~～至-]\s*(?:[A-Z\d]+\.)?\d+)*', text)
    return any(mentions(Element('span', children=[group]), number) for group in groups)


def steps(node, css_class):
    if node is None:
        return []
    return [child for ol in node.walk('ol') if ol.has_class(css_class)
            for child in ol.children if isinstance(child, Element) and child.tag == 'li']


def proof_steps(node):
    if node is None:
        return False
    # Legacy paragraphs are inventory hints only. Strict validation below requires
    # a dedicated ordered proof for the selected result.
    return (len(steps(node, 'proof-steps')) >= 3 or
            (len(list(node.walk('p'))) >= 3 and len(list(node.walk('math'))) >= 1
             and len(readable(node)) >= 180 and
             bool(re.search(r'证明|因此|故|从而|所以|得到', readable(node)))))


def load_documents(notes=NOTES):
    return {p.name: Document(p.read_text(encoding='utf-8')) for p in sorted(notes.glob('*.html'))}


def section_of(doc, node):
    return next((s for s in doc.root.walk('section') if s.start <= node.start < s.end), None)


def target_for(documents, page, href):
    u = urlsplit(href or '')
    if u.scheme or u.netloc or not u.fragment:
        return None, None
    dest = unquote(u.path) if u.path else page
    doc = documents.get(dest)
    if doc is None:
        return dest, None
    if not hasattr(doc, 'id_index'):
        doc.id_index = {n.attrs['id']: n for n in doc.root.walk() if n.attrs.get('id')}
    return dest, doc.id_index.get(unquote(u.fragment))


def inventory(documents=None, notes=NOTES):
    documents = documents or load_documents(notes)
    manifest = json.loads((notes / 'source_manifest.json').read_text())
    examples = json.loads((notes / 'readability_review.json').read_text())['source_examples']
    records = []
    incoming = Counter()
    reviews = []
    for page, doc in documents.items():
        for a in doc.root.walk('a'):
            dest, target = target_for(documents, page, a.attrs.get('href'))
            if target is not None:
                incoming[(dest, target.attrs['id'])] += 1
        for n in doc.root.walk():
            if n.has_class('source-review'):
                reviews.append({'page': page, 'id': n.attrs['id'],
                                'text_characters': len(readable(n))})

    def add(page, kind, number, node, href, proof_href=None, source_pages=None):
        doc = documents[page]
        dest, target = target_for(documents, page, href)
        section = section_of(doc, node) if node else None
        candidates = [r for r in doc.root.walk() if r.has_class('source-review')
                      and mentions_result(r, number)] if kind in RESULT_KINDS else []
        target_class = next((c for c in ['source-review', 'body-derivation']
                             if target is not None and target.has_class(c)), 'other')
        specific = target
        if kind == 'Example' and target:
            specific = next((n for n in target.walk() if n.attrs.get('data-example-number') == number), target)
        if kind == 'Exercise':
            specific = next((n for n in node.walk('div') if n.has_class('answer')), None) if node else None
            target = specific
        has_number = mentions(specific, number) if kind != 'Exercise' else bool(node)
        has_steps = proof_steps(specific) if kind in RESULT_KINDS else len(steps(specific, 'solution-steps' if kind == 'Exercise' else 'derivation-steps')) >= 3
        if kind == 'Example' and not has_steps and specific:
            # An unsplit multi-example paragraph cannot establish per-example steps.
            has_steps = False
        if kind in RESULT_KINDS:
            if proof_href and has_number and has_steps:
                gap = 'OK'
            elif any(r is not target for r in candidates):
                gap = 'PROOF_EXISTS_UNLINKED'
            elif target is None:
                gap = 'NO_PROOF'
            elif not has_number:
                gap = 'WRONG_TARGET'
            elif not has_steps:
                gap = 'TOO_SHORT'
            else:
                gap = 'PROOF_EXISTS_UNLINKED'
        else:
            gap = ('NO_PROOF' if specific is None else 'WRONG_TARGET' if not has_number
                   else 'TOO_SHORT' if not has_steps or EMPTY_STEP.search(readable(specific)) else 'OK')
        records.append({
            'page': page, 'kind': kind, 'number': number,
            'statement_id': node.attrs.get('id') if node else None,
            'current_detail_href': href, 'proof_href': proof_href,
            'target_id': (target.attrs.get('id') if target else None) or (urlsplit(href or '').fragment or None),
            'target_class': target_class,
            'target_mentions_number': has_number, 'target_has_proof_steps': has_steps,
            'in_section_source_review_ids': [n.attrs['id'] for n in section.walk() if n.has_class('source-review')] if section else [],
            'candidate_proof_ids': [n.attrs['id'] for n in candidates],
            'gap_type': gap, 'source_pdf_pages': source_pages or [],
            'text_characters': len(readable(specific)) if specific else 0,
        })

    result_nodes = {}
    exercise_nodes = {}
    for page, doc in documents.items():
        for n in doc.root.walk():
            if n.has_class('source-statement') and n.attrs.get('data-source-kind') in RESULT_KINDS:
                key = (n.attrs['data-source-kind'], n.attrs['data-source-number'])
                if key in result_nodes:
                    raise ValueError('Duplicate numbered result: ' + str(key))
                result_nodes[key] = (page, n)
            if n.has_class('exercise'):
                key = n.attrs.get('data-original-exercise') or n.attrs['id'][3:].replace('-', '.')
                if key in exercise_nodes:
                    raise ValueError('Duplicate exercise: ' + key)
                exercise_nodes[key] = (page, n)
    expected_results = {(r['kind'], r['number']) for r in manifest['numbered_results'] if r['kind'] in RESULT_KINDS}
    if set(result_nodes) != expected_results:
        raise ValueError('Numbered result coverage differs from the source catalog')
    for kind, number in sorted(expected_results):
        page, n = result_nodes[(kind, number)]
        links = [a for a in n.walk('a') if '.pdf' not in a.attrs.get('href', '')]
        proof = next((a.attrs['href'] for a in links if a.has_class('proof-link') or '完整证明' in a.text()), None)
        old = next((a.attrs['href'] for a in links if '详细推导' in a.text()), None)
        source = next(r for r in manifest['numbered_results'] if (r['kind'], r['number']) == (kind, number))
        add(page, kind, number, n, proof or old, proof, [source['pdf_page']])
        records[-1]['example_detail_href'] = old
    for ex in examples:
        ref = ex['derivations'][0]
        page = ref['page']
        _, n = target_for(documents, page, '#' + ref['anchor'])
        add(page, 'Example', ex['number'], n, '#' + ref['anchor'], source_pages=ex['source_pdf_pages'])
    expected_exercises = {r['number']: r for c in manifest['chapters'][:6] for r in c['exercises']}
    if set(exercise_nodes) != set(expected_exercises):
        raise ValueError('Exercise coverage differs from the source catalog')
    for number, source in expected_exercises.items():
        page, n = exercise_nodes[number]
        add(page, 'Exercise', number, n, '#' + n.attrs['id'], source_pages=[source['pdf_page']])
    for r in reviews:
        r['inbound_links'] = incoming[(r['page'], r['id'])]
    counts = Counter('Result' if r['kind'] in RESULT_KINDS else r['kind'] for r in records)
    if dict(counts) != {'Result': 115, 'Example': 162, 'Exercise': 236} or len(documents) != 9:
        raise ValueError('Expected 9 pages, 115 results, 162 examples, 236 exercises: ' + str(counts))
    records.sort(key=lambda r: (r['page'], r['kind'], int(r['number'].split('.')[1])))
    return {
        'schema_version': 1,
        'scope': 'All 9 HTML pages; 115 theorems/lemmas, 162 source examples and 236 exercises. The two numbered definitions are inventoried by source_manifest.json, not proof obligations.',
        'interpretation': 'OK means structural evidence only. PROOF_EXISTS_UNLINKED identifies a candidate mentioning the number, not a verified complete proof. TOO_SHORT means missing item-specific ordered steps, not a character quota. Mathematical sufficiency requires source review.',
        'page_sha256': {p: hashlib.sha256(doc.source.encode()).hexdigest() for p, doc in documents.items()},
        'counts': dict(counts), 'gap_counts': dict(Counter(r['gap_type'] for r in records)),
        'by_page': {p: dict(Counter(r['gap_type'] for r in records if r['page'] == p)) for p in documents},
        'source_reviews': reviews, 'records': records,
    }


def validate(documents, pages=None):
    report = inventory(documents)
    errors = []
    selected = set(pages) if pages else set(documents)
    for r in report['records']:
        page, number, kind = r['page'], r['number'], r['kind']
        if page not in selected:
            continue
        label = f'{page} {kind} {number}'
        doc = documents[page]
        if kind in RESULT_KINDS:
            if not r['proof_href']:
                errors.append(label + ': missing complete-proof link')
                continue
            _, target = target_for(documents, page, r['proof_href'])
            if target is None or not target.has_class('source-review') or not mentions(target, number):
                errors.append(label + ': proof target does not cover this result')
                continue
            item = next((n for n in target.walk() if n.attrs.get('data-proof-for') == kind + ':' + number), None)
            if item is None or not any(mentions(h, number) for h in item.walk() if h.tag in {'h4', 'summary'}):
                errors.append(label + ': missing explicit item-specific proof and visible number')
                continue
            sequence = steps(item, 'proof-steps')
            for css in ('proof-conditions', 'proof-boundary', 'source'):
                if not any(n.has_class(css) and len(readable(n).strip()) >= 15 for n in item.walk('p')):
                    errors.append(label + ': missing ' + css)
            if not any('.pdf#page=' in a.attrs.get('href', '') for a in item.walk('a')):
                errors.append(label + ': proof source page missing')
        else:
            _, target = target_for(documents, page, r['current_detail_href'])
            if kind == 'Exercise':
                item = next((n for n in target.walk('div') if n.has_class('answer')), None) if target else None
                sequence = steps(item, 'solution-steps')
            else:
                item = next((n for n in target.walk('div') if n.attrs.get('data-example-number') == number), None) if target else None
                sequence = steps(item, 'derivation-steps')
                if item is None or not mentions(item, number):
                    errors.append(label + ': missing individually worked example')
                if not any(step.has_class('result-check') and len(readable(step)) >= 30
                           and list(step.walk('math')) for step in sequence):
                    errors.append(label + ': missing explicit result/check step')
            if item is not None:
                text = readable(item)
                if not re.search(r'验算|核对|检查|代回|验证|检验|复核|边界', text):
                    errors.append(label + ': missing result or boundary check')
                if not re.search(r'等于|得到|为|因此|故|所以|=', text):
                    errors.append(label + ': missing stated result')
        if len(sequence) < 3:
            errors.append(label + ': fewer than three item-specific steps')
        for i, step in enumerate(sequence, 1):
            text = readable(step).strip()
            if len(text) < 20 or EMPTY_STEP.search(text):
                errors.append(label + f': empty/template step {i}')
    for r in report['source_reviews']:
        if r['page'] in selected and not r['inbound_links']:
            errors.append(f"{r['page']}#{r['id']}: source-review has no inbound link")
    return errors


def check_current_inventory(documents=None):
    """The report is regenerated separately; a check never silently writes it."""
    current = inventory(documents)
    saved = json.loads(OUTPUT.read_text(encoding='utf-8'))
    if saved != current:
        raise ValueError('derivation_coverage.json is stale; review the diff and run derivation_coverage.py --write')
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Write full inventory; never records content review approval')
    parser.add_argument('--check', action='store_true', help='Enforce derivation rules; defaults to the whole book')
    parser.add_argument('--page', action='append', choices=sorted(p.name for p in NOTES.glob('*.html')), help='Explicit staged acceptance scope')
    args = parser.parse_args()
    docs = load_documents()
    report = inventory(docs)
    if args.write:
        OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    errors = validate(docs, args.page) if args.check else []
    print(json.dumps({'counts': report['counts'], 'gap_counts': report['gap_counts'],
                      'source_reviews_without_inbound_links': sum(not r['inbound_links'] for r in report['source_reviews']),
                      'checked_pages': args.page or (list(docs) if args.check else []),
                      'errors': errors}, ensure_ascii=False, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
