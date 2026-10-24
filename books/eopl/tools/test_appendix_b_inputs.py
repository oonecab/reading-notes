#!/usr/bin/env python3
"""Execute every tagged final-page SLLGEN input against independent result data."""
import html
import json
from pathlib import Path
import re
import subprocess
import tempfile
from sync_notes import BOOK


def run(racket, run_dir):
    output = Path(run_dir); output.mkdir(parents=True, exist_ok=True)
    page = (BOOK / 'notes/appendix_b_sllgen.html').read_text()
    found = re.findall(r'<code class="language-scheme" data-appendix-input="([^"]+)">(.*?)</code>', page, re.S)
    shown = {name: html.unescape(text) for name, text in found}
    expected = {
        'scanner-keywords': '("while" whilex ":=" 3 foo)',
        'statement-tree': '(block (assign x (var foo)) (while (var x) (assign x (- (var x) (var bar)))))',
        'bindings': '(let (x u) ((var y) (var v)) (var z))',
        'blocks': '((x y) (z t))\n((x y) (z t))',
        'parallel': '(((x y) (z) (t1 t2)) ((u v) (4) (5 6)))',
        'precedence-tree': '(expr (term 3 () ()) (+ -) ((term 2 (*) (66)) (term 5 () ())))',
        'left-fold': '12\n4\n5/6',
        'variables': '1\n6',
        'unary': '-6\n2\n-20\n5',
    }
    assert len(found) == len(shown) and set(shown) == set(expected), 'displayed appendix input inventory differs'
    # The Racket reader consumes the exact displayed forms, including multi-form
    # blocks and string literals. Each result is compared before the next block.
    quote = lambda s: json.dumps(s, ensure_ascii=False)
    blocks = []
    for name, source in shown.items():
        blocks.append('(test-case ' + quote(name) + '\n' +
            '(check-equal? (string-trim (with-output-to-string (lambda ()\n' +
            '(define in (open-input-string ' + quote(source) + '))\n' +
            '(let loop () (define form (read in)) (unless (eof-object? form)\n' +
            '(write (eval form ns)) (newline) (loop)))))) ' + quote(expected[name]) + '))')
    program = '#lang racket\n(require rackunit rackunit/text-ui json)\n(define ns (make-base-namespace))\n'
    program += '(parameterize ([current-namespace ns]) (namespace-require (quote (file ' + quote(str(BOOK / 'code/appendix_b.rkt')) + '))))\n'
    program += '(define failures (run-tests (test-suite "final-page-inputs"\n' + '\n'.join(blocks) + ')))\n'
    program += '(write-json (hash (quote status) (if (zero? failures) "passed" "failed") (quote cases) 9 (quote failures) failures)) (newline) (exit failures)\n'
    with tempfile.TemporaryDirectory(prefix='appendix-inputs-', dir=output) as tmp:
        probe = Path(tmp) / 'probe.rkt'; probe.write_text(program)
        result = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=60)
    (output / 'execution.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (result.stdout, result.stderr)
    report = {'status': 'passed', 'cases': [{'name': name, 'input': shown[name], 'expected': expected[name]} for name in shown],
              'execution': json.loads(result.stdout.splitlines()[-1]), 'source': 'Final expanded appendix B page; independent expected AST/value data.'}
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report
