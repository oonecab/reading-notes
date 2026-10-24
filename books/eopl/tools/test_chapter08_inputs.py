#!/usr/bin/env python3
"""Execute the actual displayed chapter8 programs with independent expectations."""
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket, run_dir):
    output = Path(run_dir); output.mkdir(parents=True, exist_ok=True)
    page = (BOOK / 'notes/chapter08_modules.html').read_text()
    shown = {name: html.unescape(code) for name, code in re.findall(
        r'<code class="language-text" data-object-input="([^"]+)">(.*?)</code>', page, re.S)}
    expected = {
        'example8-1': ('int', '22'), 'example8-5': ('int', '11'),
        'example8-6': ('(int -> bool)', '<procedure>'),
        'example8-7': ('((from m1 take t) -> bool)', '<procedure>'),
        'example8-8': ('(from colors take color)', '1'),
        'example8-9': ('(from ints1 take t)', '10'),
        'example8-10': ('(from ints2 take t)', '-6'),
        'example8-11': ('int', '2'), 'example8-12': ('int', '2'),
        'example8-13': ('(from mybool take t)', '13'),
        'example8-14': ('int', '0'), 'example8-15': ('int', '2'), 'example8-16': ('int', '0')}
    rejected = ['example8-2', 'example8-3', 'example8-4', 'example8-5-reversed', 'example8-7-invalid']
    assert set(shown) == set(expected) | set(rejected), 'displayed numbered example inventory changed'
    cases = []

    def add(name, operation, source, result, options='', category='complete-program'):
        cases.append(dict(name=name, operation=operation, program=source, expected=result, options=options, category=category))

    for name, (typ, value) in expected.items():
        source = shown[name]
        if name == 'example8-8': source += '\nfrom colors take green'
        if name == 'example8-14': source += '\n0'
        category = 'module-definition-with-explicit-client' if name in ('example8-8', 'example8-14') else 'complete-program'
        add(name+'-type', 'check', source, typ, category=category)
        add(name+'-value', 'run', source, value, category=category)
    for name in rejected: add(name+'-rejected', 'typing-error', shown[name], 'typing')
    add('example8-4-unordered', 'run', shown['example8-4'], '44', '#:unordered? #t')
    rows = json.loads((BOOK/'notes/questions_ch08.json').read_text())['items']

    def inputs(n):
        return [html.unescape(s) for s in re.findall(r'<pre><code class="language-text">(.*?)</code></pre>', rows[n-1]['chinese_html'], re.S)]

    add('8.6-original-with-client', 'run', inputs(6)[0]+'\nfrom m1 take v', '32', category='module-definition-with-explicit-client')
    add('8.7-original', 'run', inputs(7)[0], '33')
    add('8.10-original-value', 'run', inputs(10)[0], '33', "#:dependencies 'imports")
    add('8.10-original-order', 'output', inputs(10)[0], '(2 3 1)', "#:dependencies 'imports")
    add('8.11-original-accepted', 'run', inputs(11)[0]+'\n(from m take f 7)', '7', '#:inferred? #t', 'module-definition-with-explicit-client')
    add('8.11-original-rejected', 'typing-error', inputs(11)[1]+'\n0', 'typing', '#:inferred? #t')
    add('8.14-original-alternate', 'run', inputs(14)[0]+'\n(from mybool take to-bool from mybool take true)', '#t', category='module-definition-with-explicit-client')
    for n in [5, 9, 15, 19, 20, 22, 27]:
        # The source intentionally supplies unfinished skeletons. Preserve and
        # reject their literal ellipses; their completed implementations are
        # executed separately in test_chapter08.rkt, never substituted silently.
        for k, source in enumerate(inputs(n), 1):
            if '...' in source:
                add(f'8.{n}-skeleton-{k}', 'parse-error', source, 'parse', category='original-unfinished-skeleton')

    quote = lambda s: json.dumps(s, ensure_ascii=False)
    assertions = []
    for case in cases:
        op, source, result, opts = (case[k] for k in ('operation','program','expected','options'))
        call = f"(m:{'run/trace' if op == 'output' else 'check' if op == 'typing-error' else 'parse-program' if op == 'parse-error' else op} {quote(source)} {opts})"
        if op in ('typing-error', 'parse-error'):
            pred = "m:exn:fail:typing?" if op == 'typing-error' else "(lambda (e) (and (m:exn:fail:typing? e) (eq? (m:exn:fail:typing-kind e) 'parse)))"
            assertion = f'(check-exn {pred} (lambda () {call}))'
        else:
            expression = '(m:execution-output '+call+')' if op == 'output' else call
            assertion = f'(check-equal? (format "~s" {expression}) {quote(result)})'
        assertions.append(f'(test-case {quote(case["name"])} {assertion})')
    script = '#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: (file '+quote(str(BOOK/'code/chapter08.rkt'))+')))\n'
    script += '(exit (run-tests (test-suite "actual source and displayed programs" '+ '\n'.join(assertions)+')))\n'
    with tempfile.TemporaryDirectory(prefix='programs-',dir=output) as folder:
        probe=Path(folder)/'probe.rkt';probe.write_text(script)
        tested=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=60)
    (output/'execution.log').write_text(tested.stdout+tested.stderr)
    assert tested.returncode==0,(tested.stdout,tested.stderr)
    report=dict(status='passed',cases=cases,complete_program_cases=sum(r['category']!='original-unfinished-skeleton'for r in cases),unfinished_skeleton_parse_cases=sum(r['category']=='original-unfinished-skeleton'for r in cases))
    (output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    return report


if __name__=='__main__':
    installed=sorted(Path('/Applications').glob('Racket*/bin/racket'))
    racket=shutil.which('racket')or(str(installed[-1])if installed else None)
    assert racket,'Racket required'
    print(json.dumps(run(racket,ROOT/'tmp/eopl-ch08-source-inputs'),ensure_ascii=False,indent=2))
