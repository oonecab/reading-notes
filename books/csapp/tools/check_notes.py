#!/usr/bin/env python3
"""Check CS:APP source bindings, reading pages and independent example results."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

BASE = Path(__file__).resolve().parents[1]
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'books/stochastic/tools'))
from html_support import Document, check_resources
from program_regressions import check_regressions
from part_two_regressions import check_part_two
from part_two_signal_regressions import check_signal_regressions
from part_three_regressions import check_part_three
from part_three_http_review_regressions import check_http_review
from part_three_cgi_regressions import check_cgi_review
from assertion_regressions import check_assertions
from content_review_regressions import check_content_review
from explanation_regressions import check_explanations
from reader_navigation_checks import check_reader_navigation, check_navigation_mutations
sys.path.insert(0, str(ROOT / 'tools'))
from check_astro_records import shared_asset


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_source_excerpts(sources, source_sha256):
    """Keep source statements bound to their reviewed page, text and PDF location."""
    inventory = json.loads((BASE / 'notes/source_excerpts.json').read_text())
    if inventory['source_sha256'] != source_sha256:
        raise ValueError('Excerpt source PDF identity differs')
    documents = {name: Document(source) for name, source in sources.items()}
    actual = {(name, node.attrs.get('id')) for name, doc in documents.items()
              for node in doc.root.walk() if node.has_class('source-statement')}
    expected = {(entry['file'], entry['id']) for entry in inventory['entries']}
    if actual != expected or len(expected) != len(inventory['entries']):
        raise ValueError('Source excerpt inventory differs')
    for entry in inventory['entries']:
        node = next(n for n in documents[entry['file']].root.walk()
                    if n.attrs.get('id') == entry['id'])
        quotes = [n for n in node.walk('blockquote') if n.has_class('original-excerpt')]
        bodies = [n for n in node.walk() if n.has_class('statement-body')]
        if len(quotes) != 1 or len(bodies) != 1 or quotes[0].attrs.get('lang') != 'en':
            raise ValueError('Missing source/translation structure: ' + entry['id'])
        text = ' '.join(quotes[0].text().split())
        if hashlib.sha256(text.encode()).hexdigest() != entry['english_text_sha256']:
            raise ValueError('Reviewed source statement changed: ' + entry['id'])
        refs = [n.attrs.get('href') for n in node.walk('a') if n.has_class('source-pdf')]
        if '../csapp.pdf#page=' + str(entry['pdf_pages'][0]) not in refs:
            raise ValueError('Excerpt source page differs: ' + entry['id'])
    return inventory['scope']


def validate_pages(sources, manifest, programs):
    expected = {'book_overview.html', 'preface.html', *[c['file'] for c in manifest['chapters']]}
    if (set(sources) != expected or len(expected) != manifest['scope']['reading_pages']
            or [c['chapter'] for c in manifest['chapters']] != manifest['scope']['chapters']):
        raise ValueError('Reading pages differ from the declared source scope')
    docs, ids = {}, {}
    common_style = common_script = None
    for name, source in sources.items():
        document = Document(source)
        check_resources(source, name)
        nodes = list(document.root.walk())
        anchors = [n.attrs['id'] for n in nodes if 'id' in n.attrs]
        if len(anchors) != len(set(anchors)):
            raise ValueError(name + ': duplicate ID')
        ids[name] = set(anchors); docs[name] = document
        required_navigation = {'top', 'toc-panel', 'chapter-toc', 'annotation-rail',
                               'annotation-context-link', 'annotation-content'}
        if not required_navigation <= ids[name]:
            raise ValueError(name + ': missing navigation elements ' + str(sorted(required_navigation - ids[name])))
        style = [n.text() for n in nodes if n.tag == 'style']
        script = [n.text() for n in nodes if n.tag == 'script']
        shared_style = (ROOT / 'src/styles/reading-components.css').read_text().strip()
        typography = shared_asset('styles/reading-typography.css').strip()
        shared_ok = (len(style) == 2 and style[1].strip().startswith(shared_style)
                     and style[1].strip()[len(shared_style):].strip() == typography)
        if not shared_ok or len(script) != 1:
            raise ValueError(name + ': expected book style, exact RN-001 shared style, and one script')
        if common_style is None:
            common_style, common_script = style, script
        if style != common_style or script != common_script:
            raise ValueError(name + ': inconsistent presentation/navigation')
        if source.count('wide.matches ? 110 : 144') != 1:
            raise ValueError(name + ': missing reading-position marker')
        if len([n for n in nodes if n.tag == 'p' and n.has_class('chapter-nav')]) != 2:
            raise ValueError(name + ': missing header/footer navigation')
    links = 0
    for name, document in docs.items():
        for node in document.root.walk():
            if 'href' not in node.attrs:
                continue
            ref = urlsplit(node.attrs['href'])
            if ref.scheme or ref.netloc:
                continue
            path = (BASE / 'notes' / name).parent / unquote(ref.path) if ref.path else BASE / 'notes' / name
            path = path.resolve()
            if ROOT not in path.parents or not path.is_file():
                raise ValueError(name + ': missing local link ' + node.attrs['href'])
            if path.suffix == '.html' and ref.fragment:
                if path.parent == BASE / 'notes':
                    target_ids = ids[path.name]
                else:
                    target_ids = {n.attrs['id'] for n in Document(path.read_text()).root.walk() if 'id' in n.attrs}
                if unquote(ref.fragment) not in target_ids:
                    raise ValueError(name + ': missing anchor ' + node.attrs['href'])
            if path == BASE / 'csapp.pdf':
                if not re.fullmatch(r'page=([1-9][0-9]*)', ref.fragment) or not 1 <= int(ref.fragment[5:]) <= 1122:
                    raise ValueError(name + ': invalid source page')
                if not node.has_class('source-pdf'):
                    raise ValueError(name + ': source link lacks publication marker')
            links += 1
    coverage = json.loads((BASE / 'notes/exercise_manifest.json').read_text())
    expected_exercises = {c['chapter']: c['exercises'] for c in coverage['chapters']}
    sections = exercises = original_exercises = annotations = 0
    for chapter in manifest['chapters']:
        document = docs[chapter['file']]
        actual = [n.attrs.get('id') for n in document.root.walk('section') if re.fullmatch(r's[1-9][0-9]*-[0-9]+', n.attrs.get('id', ''))]
        expected = [s['anchor'] for s in chapter['sections']]
        if actual != expected:
            raise ValueError(chapter['file'] + ': original major-section order differs')
        sections += len(actual)
        questions = [n for n in document.root.walk('details') if n.has_class('exercise')]
        self_checks = [n for n in questions if n.attrs.get('id', '').startswith('q')]
        originals = [n for n in questions if n.attrs.get('id', '').startswith('ex-')]
        if len(self_checks) != 3:
            raise ValueError(chapter['file'] + ': expected three original self-checks')
        entries = expected_exercises[chapter['chapter']]
        if [n.attrs.get('id') for n in originals] != [e['anchor'] for e in entries]:
            raise ValueError(chapter['file'] + ': original exercise coverage/order differs')
        for question, entry in zip(originals, entries):
            bodies = [n for n in question.walk() if n.has_class('exercise-question')]
            if len(bodies) != 1 or bodies[0].attrs.get('data-original-exercise') != entry['number']:
                raise ValueError('Original question binding differs: ' + entry['number'])
            pages = bodies[0].attrs.get('data-source-pdf-pages', '').split(',')
            if str(entry['pdf_start']) not in pages:
                raise ValueError('Original question source page differs: ' + entry['number'])
        for question in questions:
            children = [n for n in question.children if hasattr(n, 'tag')]
            if len(children) != 3 or not children[1].has_class('exercise-question') or not children[2].has_class('answer'):
                raise ValueError('Question must precede answer: ' + question.attrs.get('id',''))
        for section in chapter['sections']:
            groups = [n for n in document.root.walk('details') if n.attrs.get('data-notes-for') == section['anchor']]
            if len(groups) != 1 or not groups[0].has_class('reading-notes'):
                raise ValueError('Missing reading annotations: ' + section['number'])
            annotations += sum(n.has_class('annotation-card') for n in groups[0].walk())
        exercises += len(self_checks); original_exercises += len(originals)
    if (sections != manifest['scope']['major_sections']
            or exercises != manifest['scope']['supplementary_self_checks']
            or original_exercises != manifest['scope']['original_exercises']):
        raise ValueError('Original section/self-check coverage differs')
    blocks = 0
    for program in programs:
        document = docs[Path(program['page']).name]
        if program['anchor'] not in ids[Path(program['page']).name]:
            raise ValueError('Missing program reading anchor: ' + program['id'])
        for language, filename in program['files'].items():
            nodes = [n for n in document.root.walk('code') if n.attrs.get('id') == program['id'] + '-' + language]
            if len(nodes) != 1 or nodes[0].attrs.get('data-language') != language or nodes[0].text() != (BASE / filename).read_text():
                raise ValueError('Source/HTML code differs: ' + filename)
            blocks += 1
    return {'reading_pages': len(docs), 'major_sections': sections, 'original_self_checks': exercises,
            'original_book_exercises': original_exercises, 'reading_annotations': annotations,
            'local_links': links, 'synchronized_code_blocks': blocks,
            'chinese_characters': sum(len(re.findall(r'[\u4e00-\u9fff]', d.root.text())) for d in docs.values())}


def oracle(ways, trace):
    # Independent oracle: evict the block with oldest last-access position in each set.
    sets = [dict() for _ in range(4)]
    lines, hits = [], 0
    for position, address in enumerate(trace):
        block = address // 2
        index, tag = block % 4, block // 4
        group = sets[index]
        hit = block in group
        if not hit and len(group) == ways:
            del group[min(group, key=group.get)]
        group[block] = position
        hits += hit
        lines.append(f'addr={address} set={index} tag={tag} hit={int(hit)}')
    lines.append(f'hits={hits} misses={len(trace)-hits}')
    return '\n'.join(lines) + '\n'


def run_programs(run, programs):
    compiler = 'clang'
    results = {}
    def command(args, expected=None, failure=False, input_text=None):
        result = subprocess.run([str(x) for x in args], input=input_text, capture_output=True, text=True, timeout=90)
        if failure:
            if result.returncode != 2:
                raise ValueError('Expected invalid-input exit 2: ' + str(args[1:]))
        elif result.returncode or (expected is not None and result.stdout != expected):
            raise ValueError(f'Execution/output differs: {args[0]}\n{result.stdout[:1200]}\n{result.stderr[:1200]}')
        return result.stdout
    binaries = {}
    for program in programs:
        key = program['id']; binary = run / key
        if program.get('execution') == 'python':
            if set(program['files']) != {'python'} or 'expected_stdout' not in program:
                raise ValueError('Python-only programs require one source and an independent expected output')
            output = command([sys.executable, BASE / program['files']['python']],
                             program['expected_stdout'], input_text='')
            (run / (key + '.out')).write_text(output)
            results[key] = output
            continue
        if program.get('execution') == 'x86_64_assembly':
            command([compiler,'-arch','x86_64','-std=c11','-Wall','-Wextra','-Werror','-pedantic','-O2',
                     BASE / program['files']['c'],BASE / 'code/ch03_ranges.S','-o',binary])
            c = command(['arch','-x86_64',binary]); py = command([sys.executable,BASE / program['files']['python']])
            if c.replace('branch=pass cmov=pass','model=pass') != py:
                raise ValueError('x86 assembly classification differs from Python model')
            (run / (key + '.out')).write_text(c)
            binaries[key] = binary; results[key] = c
            continue
        thread_flags = ['-pthread'] if program.get('pthread') else []
        command([compiler, '-std=c11', '-Wall', '-Wextra', '-Werror', '-pedantic', '-O1',
                 '-ffp-contract=off', '-fsanitize=address,undefined', '-fno-omit-frame-pointer',
                 *thread_flags, BASE / program['files']['c'], '-o', binary])
        c = command([binary], input_text='')
        if 'python' in program['files']:
            command([sys.executable, BASE / program['files']['python']], c, input_text='')
        if 'expected_stdout' in program and c != program['expected_stdout']:
            raise ValueError('Independent expected output differs: ' + key)
        binaries[key] = binary; results[key] = c
        (run / (key + '.out')).write_text(c)
    if results['hello'] != 'hello, systems\n':
        raise ValueError('Hello output differs')
    rep = results['representation'].splitlines()
    expected = [f'u={u} signed={u if u < 128 else u-256} plus1={(u+1)%256}' for u in range(256)]
    expected += ['bytes=' + (0x12345678).to_bytes(4, sys.byteorder).hex(), 'double1=3ff0000000000000', 'grouping=1,0']
    if rep != expected:
        raise ValueError('Independent bit/IEEE reference differs')
    address = results['addresses']
    # The book's concrete layout uses LP64; refuse to label a different host as verified LP64.
    if address != ('long=8 pointer=8 int=4\nrecord=0,8,16 size=24\narray-offset=20 value=5\n' +
                   ''.join(f'affine={x},{3*x+7}\n' for x in range(-2,3))):
        raise ValueError('Host does not match the LP64 sample; record a separate platform expectation')
    pipeline = ''.join(f'n={n} seq-ns={n*920} pipe-cycles={n+2} pipe-ns={(n+2)*420}\n' for n in (1,4,10))
    pipeline += 'five-stage=4 instructions,1 stall,9 cycles\n'
    if results['pipeline'] != pipeline:
        raise ValueError('Pipeline arithmetic reference differs')
    reductions = ''
    for n in (0,1,2,3,4,5,7,8,17,64,65):
        # Sum of squares provides a separate closed-form oracle.
        total = 0 if n == 0 else (((n-1)*n*(2*n-1)//6 + 3*(n-1) - 1) % (1 << 64))
        reductions += f'n={n} sum={total}\n'
    if results['reductions'] != reductions:
        raise ValueError('Independent closed-form reduction differs')
    default = oracle(1, [0,1,13,8,0]) + 'matrix-row hits=48 misses=16\nmatrix-column hits=0 misses=64\n'
    if results['cache'] != default:
        raise ValueError('Hand-derived cache trace/matrix results differ')
    generator = random.Random(20261013)
    traces = [[0], [0,1,13,8,0], [0,8,0,8], [0,8,16,0,8,24], [2**64-1,2**64-2,0],
              *[[generator.randrange(256) for _ in range(n)] for n in (2,3,8,31,64,99)]]
    for ways in (1,2,4):
        for trace in traces:
            args = [str(ways), *map(str, trace)]
            expected = oracle(ways, trace)
            command([binaries['cache'], *args], expected)
            command([sys.executable, BASE / 'code/cache.py', *args], expected)
    invalid = [['3','0'], ['1'], ['0','1'], ['-1','0'], ['1','-2'], ['1','x'], ['1',str(1 << 64)], ['1','']]
    for args in invalid:
        command([binaries['cache'], *args], failure=True)
        command([sys.executable, BASE / 'code/cache.py', *args], failure=True)
    source = (BASE / 'code/addresses.c').read_text().split('*/', 1)[1].split('/* ASM_END */',1)[0]
    (run / 'affine.c').write_text(source)
    command([compiler,'-target','x86_64-unknown-linux-gnu','-O1','-S',run/'affine.c','-o',run/'affine-x86-64.s'])
    assembly = (run / 'affine-x86-64.s').read_text()
    if '%rdi' not in assembly or '%rax' not in assembly or 'leaq' not in assembly or 'retq' not in assembly:
        raise ValueError('x86-64 assembly example generation differs')
    if results.get('ch01-amdahl') != ('alpha=0.6 k=1.0 speedup=1.000000\nalpha=0.6 k=1.5 speedup=1.250000\n'
        'alpha=0.6 k=3.0 speedup=1.666667\nalpha=0.6 k=10.0 speedup=2.173913\nlimit=2.500000\nrequired-k=6.000000\n'):
        raise ValueError('Amdahl fraction reference differs')
    if results.get('ch05-loops') != ('lengths=131 modular-reductions=ok merge=ok overlap=ok\n'
        'prefix-exact=131 inplace=131 serial-last=1 grouped-last=2\n'):
        raise ValueError('Independent loop and floating counterexample differs')
    if results.get('ch05-polynomial') != 'polynomial-cases=645 sample=49\n':
        raise ValueError('Polynomial reference differs')
    if results.get('ch05-fill') != 'fill-cases=3120 word-bytes=8 guards=ok\n':
        raise ValueError('Fill bounds reference differs')
    # good_echo is a single text-line interface, including a final line at EOF.
    for sample in ('','one line\n','x'*8193+'\nsecond line','last without newline'):
        expected = sample.split('\n',1)[0] + ('\n' if '\n' in sample else '')
        command([binaries['ch03-good-echo']], expected, input_text=sample)
        command([sys.executable,BASE/'code/ch03_good_echo.py'], expected, input_text=sample)
    regressions = check_regressions(BASE, run / 'regressions', binaries, compiler)
    part_two = check_part_two(BASE, run / 'part-two-regressions', compiler)
    signal_regressions = check_signal_regressions(BASE, run / 'part-two-signals', compiler)
    part_three = check_part_three(BASE, run / 'part-three-regressions', compiler)
    http_review = check_http_review(BASE, run / 'part-three-http-review', compiler)
    cgi_review = check_cgi_review(BASE, run / 'part-three-cgi-review', compiler)
    assertions = check_assertions(BASE, run / 'assertion-regressions', compiler)
    content_review = check_content_review(BASE, run / 'content-review', compiler)
    explanations = check_explanations(BASE, run / 'explanations', compiler)
    return {'program_groups':len(programs),
            'program_pairs':sum({'c','python'} <= p['files'].keys() for p in programs),
            'standalone_c_programs':sum(set(p['files']) == {'c'} for p in programs),
            'standalone_python_programs':sum(set(p['files']) == {'python'} for p in programs),
            'c11_strict':'pass (GNU may_alias used by word-fill; POSIX interfaces declared by feature macros)',
            'asan_ubsan':'all native C programs; x86 assembly checked separately','cross_language':'all declared pairs pass',
            'eight_bit_patterns':256,'reduction_lengths':11,'cache_reference_traces':len(traces)*3,
            'invalid_inputs_per_language':len(invalid),'host_layout':'LP64 sample observed',
            'x86_64_assembly':'cross-target generation and executable classification via Rosetta; not Linux execution','compiler':command([compiler,'--version']).splitlines()[0],
            'python':sys.version.split()[0], 'maintained_regressions':regressions,
            'part_two_regressions':part_two, 'part_two_signal_regressions':signal_regressions,
            'part_three_regressions':part_three, 'part_three_http_review':http_review,
            'part_three_cgi_review':cgi_review, 'content_review_regressions':content_review,
            'explanation_regressions':explanations,
            'assertion_regressions':{'status':'passed', 'normal_and_disabled_runs':len(assertions['normal_runs']),
                                    'wrong_variant_runs':len(assertions['mutations']),
                                    'report':str((run/'assertion-regressions/report.json').resolve().relative_to(ROOT))}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick',action='store_true')
    parser.add_argument('--run-dir',type=Path,default=ROOT/'tmp/csapp/check')
    args = parser.parse_args()
    run = args.run_dir.resolve()
    if ROOT / 'tmp' not in run.parents and BASE / 'tmp' not in run.parents:
        parser.error('Evidence must be under an ignored tmp directory')
    run.mkdir(parents=True,exist_ok=True)
    manifest = json.loads((BASE/'notes/source_manifest.json').read_text())
    programs = json.loads((BASE/'code/programs.json').read_text())['programs']
    for program in programs:
        if set(program['files']) == {'python'} and (
                program.get('execution') != 'python' or 'expected_stdout' not in program):
            raise ValueError('Python-only execution/expected output missing: ' + program['id'])
    source = manifest['source_pdf']
    if source['sha256'] != sha(BASE/source['path']) or source['bytes'] != (BASE/source['path']).stat().st_size:
        raise ValueError('Original PDF identity differs')
    info = subprocess.check_output(['pdfinfo',BASE/source['path']],text=True)
    if not re.search(r'^Pages:\s+1122$',info,re.M):
        raise ValueError('Original PDF page count differs')
    pages = {p.name:p.read_text() for p in (BASE/'notes').glob('*.html')}
    structural = validate_pages(pages,manifest,programs)
    reader_navigation = check_reader_navigation(pages,manifest)
    navigation_mutations = check_navigation_mutations(pages,manifest)
    excerpts = validate_source_excerpts(pages, source['sha256'])
    # Mutation checks operate only on in-memory copies of the authored pages.
    mutations = [dict(pages) for _ in range(6)]
    mutations[0]['preface.html'] = pages['preface.html'].replace('href="book_overview.html"','href="missing.html"',1)
    mutations[1]['chapter01_tour.html'] = pages['chapter01_tour.html'].replace('puts(&quot;hello, systems&quot;);','puts(&quot;changed&quot;);',1)
    mutations[2]['preface.html'] = pages['preface.html'].replace('<header>','<header><span id="top">duplicate</span>',1)
    mutations[3]['chapter01_tour.html'] = pages['chapter01_tour.html'].replace('id="ex-1-1"','id="ex-1-99"',1)
    mutations[4]['chapter01_tour.html'] = pages['chapter01_tour.html'].replace('data-original-exercise="1.1"','data-original-exercise="1.99"',1)
    mutations[5]['chapter09_virtual_memory.html'] = pages['chapter09_virtual_memory.html'].replace('id="toc-panel"', 'id="missing-toc-panel"', 1)
    for mutated in mutations:
        try:
            validate_pages(mutated,manifest,programs)
        except ValueError:
            pass
        else:
            raise ValueError('Mutation not detected')
    changed_quote = dict(pages)
    changed_quote['preface.html'] = pages['preface.html'].replace(
        'class="original-excerpt"', 'class="unbound-excerpt"', 1)
    try:
        validate_source_excerpts(changed_quote, source['sha256'])
    except ValueError:
        pass
    else:
        raise ValueError('Missing source statement mutation not detected')
    subprocess.run(['pdftotext','-layout',BASE/'csapp.pdf',run/'source.txt'],check=True)
    original = (run/'source.txt').read_text().split('\f')
    original_contents = '\n'.join(original[7:19])
    subsection_checks = 0
    for chapter in manifest['chapters']:
        toc_sections = list(dict.fromkeys(re.findall(
            r'(?m)^\s*(' + str(chapter['chapter']) + r'\.\d+)\s+[A-Z]', original_contents)))
        if [s['number'] for s in chapter['sections']] != toc_sections:
            raise ValueError('Complete original major-section inventory differs: ' + str(chapter['chapter']))
        for section in chapter['sections']:
            if not re.search(r'(?m)^\s*'+re.escape(section['number'])+r'\s+[A-Z]',original[section['pdf_start']-1]):
                raise ValueError('Original heading/page differs: '+section['number'])
        expected_subsections = list(dict.fromkeys(re.findall(
            r'(?m)^\s*('+str(chapter['chapter'])+r'\.\d+\.\d+)\s', original_contents)))
        document = Document(pages[chapter['file']])
        headings = [n.text() for n in document.root.walk() if n.tag in {'h3','h4'}]
        for number in expected_subsections:
            if not any(re.match(r'^'+re.escape(number)+r'(?:\s|·)',heading) for heading in headings):
                raise ValueError('Original subsection missing: '+number)
        subsection_checks += len(expected_subsections)
    if subsection_checks != manifest['scope']['subsections']:
        raise ValueError('Original subsection inventory differs')
    exercise_manifest = json.loads((BASE/'notes/exercise_manifest.json').read_text())
    if exercise_manifest['source_sha256'] != source['sha256']:
        raise ValueError('Exercise source identity differs')
    for chapter in exercise_manifest['chapters']:
        for entry in chapter['exercises']:
            pattern = (r'Practice Problem '+re.escape(entry['number'])+r'\s+\(solution'
                       if entry['kind']=='practice' else r'(?m)^\s*'+re.escape(entry['number'])+r'\s+◆')
            if not re.search(pattern,original[entry['pdf_start']-1]):
                raise ValueError('Original exercise number/page differs: '+entry['number'])
    # Derive the new part's inventory independently from the actual source pages.
    # Checking only listed entries would fail to catch a silently omitted question.
    for chapter in manifest['chapters']:
        if chapter['chapter'] < 7:
            continue
        number = str(chapter['chapter'])
        found = {}
        for page in range(chapter['pdf_pages'][0], chapter['pdf_pages'][1] + 1):
            for kind, pattern in (
                ('practice', r'Practice Problem (' + number + r'\.\d+)\s+\(solution'),
                ('homework', r'(?m)^\s*(' + number + r'\.\d+)\s+◆'),
            ):
                for match in re.finditer(pattern, original[page - 1]):
                    found[match[1]] = (kind, page)
        declared = next(c for c in exercise_manifest['chapters'] if c['chapter'] == chapter['chapter'])
        if found != {e['number']: (e['kind'], e['pdf_start']) for e in declared['exercises']}:
            raise ValueError('Complete source exercise inventory differs: ' + number)
    for path in [BASE/'README.md',BASE/'agent.md',BASE/'notes/README.md',BASE/'code/README.md']:
        if not path.is_file():
            raise ValueError('Missing book documentation: '+path.name)
        if '/Users/' in path.read_text():
            raise ValueError('Local path in maintained documentation')
    report = {'status':'passed','checked_at':datetime.now(timezone.utc).isoformat(),'quick':args.quick,
              'source_sha256':source['sha256'],'structure':structural,'mutation_checks':7,
              'reader_navigation':reader_navigation,'reader_navigation_mutations':navigation_mutations,
              'source_excerpts':excerpts,
              'source_exercise_page_checks':sum(len(c['exercises']) for c in exercise_manifest['chapters']),
              'source_subsection_checks':subsection_checks,
              'source_heading_page_checks':sum(len(c['sections']) for c in manifest['chapters']),
              'page_sha256':{name:sha(BASE/'notes'/name) for name in pages},
              'source_code_sha256':{p:sha(BASE/p) for program in programs for p in program['files'].values()}}
    if not args.quick:
        report['program_checks']=run_programs(run,programs)
    (run/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({key:value for key,value in report.items() if key not in {'page_sha256','source_code_sha256'}},ensure_ascii=False,indent=2))

if __name__ == '__main__':
    main()
