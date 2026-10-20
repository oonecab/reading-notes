#!/usr/bin/env python3
"""Reading contracts, including independent spellings of key MathML structures."""
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / 'books/stochastic/tools'))
from html_support import Document

# Written from the mathematical statements: _{} is a subscript, ^{} a power,
# frac has numerator/denominator order, sqrt/root retain their radicands.
# These are semantic references, not hashes of the generated presentation.
EXPECTED = {
    'b∘a': 'b∘a',
    'Tₖ(x)=x+k': 'T_{k}(x)=x+k',
    '(ab)⁻¹=b⁻¹a⁻¹': '(ab)^{−1}=b^{−1}a^{−1}',
    'h²=v²=e': 'h^{2}=v^{2}=e',
    'rⁱfʲ': 'r^{i}f^{j}',
    'hgh=g⁻¹': 'hgh=g^{−1}',
    '(a*b)*c=a*(b*c)': '(a*b)*c=a*(b*c)',
    'g*g⁻¹=g⁻¹*g=e': 'g*g^{−1}=g^{−1}*g=e',
    '|Aₙ|=n!/2': '|A_{n}|=frac(n!,2)',
    '|G|/|H|': 'frac(|G|,|H|)',
    'aH={ah:h∈H}': 'aH={ah:h∈H}',
    'H◁G': 'H◁G',
    '(aH)(bH)=abH': '(aH)(bH)=abH',
    'N_G(H)': 'N_{G}(H)',
    'N_G(P)': 'N_{G}(P)',
    'G⋊αH': 'G⋊_{α}H',
    'φ(ab)=φ(a)φ(b)': 'φ(ab)=φ(a)φ(b)',
    'φ(ab)=φ(b)∘φ(a)': 'φ(ab)=φ(b)∘φ(a)',
    'Cₙ×Cₘ≅Cₙₘ': 'C_{n}×C_{m}≅C_{nm}',
    'α_h': 'α_{h}',
    '|Orb(s)|·|Stab(s)|=|G|': '|Orb(s)|·|Stab(s)|=|G|',
    '|S|≡|Sᴳ| (mod p)': '|S|≡|S^{G}|(modp)',
    '[N_G(H):H]≡[G:H] (mod p)': '[N_{G}(H):H]≡[G:H](modp)',
    'pⁱ⁺¹': 'p^{i+1}',
    'pⁿ': 'p^{n}',
    'nₚ∣|G|': 'n_{p}∣|G|',
    'nₚ≡1 (mod p)': 'n_{p}≡1(modp)',
    'nₚ=[G:N_G(P)]': 'n_{p}=[G:N_{G}(P)]',
    'nₚ∣m': 'n_{p}∣m',
    'C₃⋊C₄': 'C_{3}⋊C_{4}',
    'F×': 'F^{×}',
    'p²∤a₀': 'p^{2}∤a_{0}',
    'rᵈ⁻¹': 'r^{d−1}',
    '√2/2': 'frac(sqrt(2),2)',
    'Q(√2,√3)': 'Q(sqrt(2),sqrt(3))',
    '[L:F]=[L:E][E:F]': '[L:F]=[L:E][E:F]',
    '|Gal(L/F)|=[L:F]': '|Gal(L/F)|=[L:F]',
    '[L:Lᴴ]=|H|': '[L:L^{H}]=|H|',
    '[Lᴴ:F]=[G:H]': '[L^{H}:F]=[G:H]',
    'Gᵢ/Gᵢ₋₁': 'G_{i}/G_{i−1}',
    '{e}=G₀◁G₁◁⋯◁Gᵣ=G': '{e}=G_{0}◁G_{1}◁⋯◁G_{r}=G',
}

# Independent references for the structured display formulas. Existing mtext
# displays retain their authored presentation; all displays still need a name
# and a single continuous plain-text notation.
DISPLAY_EXPECTED = {
    's²=e，s^(2m)=e，s^(2m+1)=s': 's^{2}=e,s^{2m}=e,s^{2m+1}=s',
    '3!=3×2×1=6': '3!=3×2×1=6',
    'g⁻¹(g(x))=x': 'g^{−1}(g(x))=x',
    '(T_l∘T_k)(x)=(x+k)+l=T_(k+l)(x)': '(T_{l}∘T_{k})(x)=(x+k)+l=T_{k+l}(x)',
    '(rⁱfʲ)(rᵏfˡ)=r^(i+(−1)^j k)f^(j+l)，r 的指数模 n，f 的指数模 2。':
        '(r^{i}f^{j})(r^{k}f^{l})=r^{i+(−1)^{j}k}f^{j+l}，r 的指数模 n，f 的指数模 2。',
    '[G:H]=|G|/|H|': '[G:H]=frac(|G|,|H|)',
    'X={(g₁,…,gₚ):g₁⋯gₚ=e}，|X|=|G|^(p−1)': 'X={(g_{1},…,g_{p}):g_{1}⋯g_{p}=e},|X|=|G|^{p−1}',
    'x=(−b±√(b²−4ac))/(2a)': 'x=frac(−b±sqrt(b^{2}−4ac),2a)',
}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def tag(node):
    return node.tag.rsplit('}', 1)[-1]


def spelling(node):
    kind = tag(node)
    parts = [spelling(child) for child in node]
    if kind in ('mi', 'mn', 'mo', 'mtext'):
        require(not parts, 'MathML token contains an element')
        return node.text or ''
    if kind == 'semantics':
        return parts[0]
    if kind == 'annotation':
        return ''
    if kind == 'mspace':
        return ''
    if kind == 'msubsup':
        require(len(parts) == 3, 'MathML arity: ' + kind)
        a, b, c = parts
        require(a not in ')]}⟩', 'MathML script attached only to closing fence')
        return a + '_{' + b + '}^{' + c + '}'
    if kind in ('msub', 'msup', 'mfrac', 'mroot', 'mover'):
        require(len(parts) == 2, 'MathML arity: ' + kind)
        a, b = parts
        if kind in ('msub', 'msup'):
            # Exponentiation applies to a whole fenced base, not just its ')'.
            require(a not in ')]}⟩', 'MathML script attached only to closing fence')
            return a + ('_{' if kind == 'msub' else '^{') + b + '}'
        if kind == 'mfrac':
            return f'frac({a},{b})'
        if kind == 'mroot':
            return f'root({a},{b})'
        return f'over({a},{b})'
    if kind == 'msqrt':
        require(bool(parts), 'empty square root')
        return 'sqrt(' + ''.join(parts) + ')'
    require(kind in ('math', 'mrow'), 'Unexpected MathML structure: ' + kind)
    return ''.join(parts)


def check_math(source):
    doc = Document(source)
    formulas = {}
    count = 0
    for node in doc.root.walk('math'):
        tree = ET.fromstring(source[node.start:node.end])
        require(len(tree) == 1 and tag(tree[0]) == 'semantics', 'formula needs one semantics wrapper')
        require(len(tree[0]) == 2 and tag(tree[0][0]) != 'annotation' and
                tag(tree[0][1]) == 'annotation', 'formula needs presentation then annotation')
        annotations = [x for x in tree.iter() if tag(x) == 'annotation']
        require(len(annotations) == 1 and annotations[0].attrib.get('encoding') == 'text/plain',
                'formula lacks plain-text notation')
        label = annotations[0].text
        require(label and label.strip() and not list(annotations[0]) and
                tree.attrib.get('aria-label') == label,
                'formula accessible name differs from source notation')
        value = spelling(tree)
        if node.attrs.get('display') == 'inline':
            require(any(tag(x) in ('mi', 'mn', 'mo', 'msup', 'msub', 'msqrt', 'mfrac') for x in tree.iter()),
                    'inline formula cannot be only mtext')
            count += 1
        expected = {**EXPECTED, **DISPLAY_EXPECTED}
        if label in expected:
            require(value == expected[label], f'MathML meaning differs: {label}: {value}')
        require(label not in formulas or formulas[label] == value, 'inconsistent repeated formula')
        formulas[label] = value
    return count, formulas


def run(root=ROOT):
    notes = root / 'notes'
    texts = {p.name: p.read_text() for p in notes.glob('*.html')}
    total, display_total, formulas = 0, 0, {}
    copy_scripts = set()
    for name, source in texts.items():
        count, rows = check_math(source)
        total += count
        formulas.update(rows)
        if name.startswith('chapter'):
            require(count > 0, name + ': no key inline MathML')
        doc = Document(source)
        display_total += sum(n.attrs.get('display') == 'block' for n in doc.root.walk('math'))
        copy_script = [n for n in doc.root.walk('script') if n.attrs.get('id') == 'math-copy-controller']
        require(len(copy_script) == 1, name + ': formula copy controller missing')
        copy_scripts.add(source[copy_script[0].content_start:copy_script[0].content_end])
    require(len(copy_scripts) == 1, 'formula copy controllers differ between pages')
    require(EXPECTED.keys() <= formulas.keys(), 'missing protected key formula')
    require(DISPLAY_EXPECTED.keys() <= formulas.keys(), 'missing protected display formula')
    require(display_total == 31, 'display formula coverage changed')
    overview = Document(texts['book_overview.html'])
    chapter_table = next(t for t in overview.root.walk('table') if '原书习题 / 进度' in t.text())
    require(chapter_table.text().count('已完成本地验收') == 10, 'chapter statuses disagree')
    annotation_count = 0
    for chapter in (2, 3, 4):
        name = next(n for n in texts if n.startswith(f'chapter{chapter:02}'))
        doc = Document(texts[name])
        ids = {n.attrs.get('id'): n for n in doc.root.walk() if n.attrs.get('id')}
        groups = [n for n in doc.root.walk('details') if n.has_class('reading-notes')]
        require(len(groups) >= 5, name + ': missing reading notes')
        for group in groups:
            target = group.attrs.get('data-notes-for')
            require(target in ids and ids[target].tag == 'section', 'annotation target missing')
            require(any(n.tag == 'h2' for n in ids[target].walk()), 'annotation controller needs an h2 target')
            require(any(n.has_class('reading-notes-body') for n in group.walk()), 'annotation body missing')
            require(any(n.has_class('annotation-card') for n in group.walk()), 'annotation card missing')
            annotation_count += 1
    excerpts = json.loads((notes/'source_excerpts.json').read_text())['excerpts']
    partial_count = 0
    for row in excerpts:
        if not row.get('excerpt_scope'):
            continue
        d = Document(texts[row['page']])
        block = next(n for n in d.root.walk() if n.attrs.get('id') == row['anchor'])
        labels = [n for n in block.walk('p') if n.has_class('excerpt-label')]
        require(len(labels) == 1 and labels[0].text() == row['display_label'], 'excerpt scope label drifted')
        require('原文摘录：' not in block.text(), 'ambiguous duplicate excerpt label')
        partial_count += 1
    quotient = next(x for x in excerpts if x['anchor'] == 'definition-7-5')
    require(quotient['pdf_page'] == 148 and quotient['printed'] == '133', 'quotient excerpt is on the next page')
    inventory = json.loads((notes/'source_inventory.json').read_text())
    exclusions = inventory['excluded_wrapped_references']
    expected_refs = {('Definition', '3.1', 47), ('Definition', '3.1', 52),
                     ('Exercise', '5.6', 109), ('Definition', '7.1', 133),
                     ('Theorem', '8.5', 184), ('Exercise', '8.13', 205),
                     ('Theorem', '9.10', 223)}
    require({(r['kind'], r['number'], r['pdf_page']) for r in exclusions} == expected_refs,
            'excluded-reference coverage changed')
    for row in exclusions:
        canonical = next(i for i in inventory['items'] if (i['kind'], i['number']) == (row['kind'], row['number']))
        require(row['review_status'] == 'duplicate/reference' and row.get('exclusion_basis') and
                row.get('canonical_pdf_page') == canonical['pdf_page'], 'unreviewed wrapped reference')
    manifest = json.loads((notes/'source_manifest.json').read_text())
    issue = next(i for i in manifest['source_issues'] if 'Exercise 10.10' in i.get('where', ''))
    require('pending' not in issue['resolution'] and '已复核并补解' in issue['resolution'], '10.10 stale resolution')
    for c, ids in ((4, [f'ex-4-1-{x}' for x in 'abcdef']),
                   (6, [f'ex-6-4-{x}' for x in 'abcde'] + [f'ex-6-5-{x}' for x in 'abcdef']),
                   (9, [f'ex-9-28-step-{i}' for i in (1, 2, 3)]),
                   (10, [f'ex-10-26-step-{i}' for i in (1, 2, 3)])):
        text = texts[next(n for n in texts if n.startswith(f'chapter{c:02}'))]
        present = {n.attrs.get('id') for n in Document(text).root.walk()}
        require(set(ids) <= present, 'missing solution step/subpart anchors')
    # Mutation checks verify that visible but mathematically different markup fails.
    samples = {}
    for text in texts.values():
        for n in Document(text).root.walk('math'):
            if n.attrs.get('aria-label') in ('nₚ∣|G|', '√2/2', 'G⋊αH', '(ab)⁻¹=b⁻¹a⁻¹',
                                           'x=(−b±√(b²−4ac))/(2a)'):
                samples[n.attrs['aria-label']] = text[n.start:n.end]
    mutations = {
        'Sylow count exponent instead of subscript': samples['nₚ∣|G|'].replace('msub', 'msup'),
        'division instead of divisibility': samples['nₚ∣|G|'].replace('<mo>∣</mo>', '<mo>/</mo>'),
        'wrong radical denominator': samples['√2/2'].replace('</msqrt><mn>2</mn>', '</msqrt><mn>3</mn>'),
        'lost semidirect action': samples['G⋊αH'].replace('<mi>α</mi>', '<mi>β</mi>'),
        'display formula missing accessible name': samples['x=(−b±√(b²−4ac))/(2a)'].replace('aria-label=', 'data-old-label='),
        'display formula mismatched fallback': samples['x=(−b±√(b²−4ac))/(2a)'].replace('text/plain">x=', 'text/plain">y='),
        'quadratic formula wrong denominator': samples['x=(−b±√(b²−4ac))/(2a)'].replace('<mn>2</mn><mi>a</mi>', '<mn>3</mn><mi>a</mi>'),
    }
    rejected = []
    for label, source in mutations.items():
        try:
            check_math(source)
        except ValueError:
            rejected.append(label)
        else:
            raise ValueError('accepted MathML mutation: ' + label)
    return {'inline_mathml': total, 'display_mathml': display_total,
            'total_mathml': total + display_total, 'distinct_formulas': len(formulas),
            'protected_semantic_references': len(EXPECTED) + len(DISPLAY_EXPECTED), 'mutations_rejected': rejected,
            'new_reading_notes': annotation_count, 'scoped_excerpts': partial_count,
            'reviewed_cross_references': len(exclusions)}


if __name__ == '__main__':
    print(json.dumps(run(), ensure_ascii=False, indent=2))
