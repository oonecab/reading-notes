#!/usr/bin/env python3
"""Execute the six reviewed textbook code excerpts in isolated Racket test cases."""
import json
from pathlib import Path
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket: str) -> dict:
    rows = json.loads((BOOK / 'notes/question_contexts.json').read_text())['items']
    checks = {
        'source-context-nth-element': '''
(check-equal? (nth-element '(a b c d e) 3) 'd)
(check-exn #rx"List too short by 5 elements" (lambda () (nth-element '(a b c) 7)))
(check-exn exn:fail? (lambda () (nth-element '() 0)))''',
        'source-context-remove-first': '''
(check-equal? (remove-first 'b '(a b c b)) '(a c b))
(check-equal? (remove-first 'x '()) '())''',
        'source-context-subst': '''
(check-equal? (subst 'x 'a '((a b) (c (a)))) '((x b) (c (x))))
(check-equal? (subst 'x 'a '(() a ())) '(() x ()))''',
        'source-context-partial-vector-sum': '''
(check-equal? (partial-vector-sum #(7 -2 0 5) 3) 10)
(check-equal? (partial-vector-sum #(7) 0) 7)''',
        'source-context-figure-2-1': '''
(define old (extend-env 'y 14 (empty-env)))
(define new (extend-env 'd 6 (extend-env 'y 8 (extend-env 'x 7 old))))
(check-equal? (apply-env new 'y) 8)
(check-equal? (apply-env old 'y) 14)
(check-exn #rx"No binding" (lambda () (apply-env new 'z)))''',
        'source-context-parse-expression': '''
(check-equal? (parse-expression '(a b c)) '(app (var a) (var b)))
(check-exn exn:fail? (lambda () (parse-expression '(lambda))))''',
    }
    constructors = '''
(define (var-exp v) (list 'var v))
(define (lambda-exp v b) (list 'lambda v b))
(define (app-exp f x) (list 'app f x))
(define (report-invalid-concrete-syntax x) (error 'parse-expression "invalid syntax"))
'''
    cases = []
    for row in rows:
        key = row['anchor']
        if key not in checks:
            continue  # The alternative concrete grammar is not a Scheme program.
        support = constructors if key.endswith('parse-expression') else ''
        cases.append('(test-case "' + key + '"\n' + support + row['code'] + '\n' + checks[key] + ')')
    script = '#lang racket/base\n(require eopl rackunit rackunit/text-ui)\n'
    script += '(define failures (run-tests (test-suite "reviewed textbook excerpts"\n' + '\n'.join(cases) + ')))\n'
    script += '(exit (if (zero? failures) 0 1))\n'
    target = ROOT / 'tmp/eopl-source-context-tests'
    target.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target) as temp:
        path = Path(temp) / 'original-contexts.rkt'
        path.write_text(script)
        result = subprocess.run([racket, str(path)], capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise ValueError(result.stdout + result.stderr)
    return {'status': 'passed', 'textbook_code_cases': len(cases), 'stdout': result.stdout,
            'scope': 'Six exact code excerpts with typographic quotes normalized. Parser constructor stubs preserve AST shape; its known acceptance of (a b c) is explicitly demonstrated.'}
