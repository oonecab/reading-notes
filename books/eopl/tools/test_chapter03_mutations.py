#!/usr/bin/env python3
"""Run bounded, independent chapter 3 witnesses against isolated semantic faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket):
    variants = [
        ('closure-uses-caller', 'chapter03.rkt',
         "(if (eq? (scope-mode) 'dynamic) caller (closure-saved p))", 'caller',
         '(check-equal? (s:datum (s:run s:closure-example)) -100)'),
        ('difference-reverses-operands', 'chapter03.rkt',
         "(num-val (- (expval->num a) (expval->num b)))",
         "(num-val (- (expval->num b) (expval->num a)))",
         '(check-equal? (s:datum (s:run "-(7,2)")) 5)'),
        ('unpack-truncates-long-list', 'chapter03.rkt',
         '(unless (= (length vs) (length vals)) (error \'unpack "list length mismatch"))\n      (value-of b (extend-many vs vals env))',
         '(value-of b (extend-many vs (take vals (length vs)) env))',
         '(check-exn exn:fail? (lambda () (s:run "unpack x = list(1,2) in x")))'),
        ('cache-reconstructs-every-query', 'chapter03.rkt',
         "[(eq? (rec-mode) 'cached)", "[(and #f (eq? (rec-mode) 'cached))",
         "(parameterize ([s:rec-mode 'cached] [s:env-mode 'data]) (define env (s:extend-rec '(f) '((x)) (list (s:parse-expression \"x\")) (s:initial-environment))) (check-eq? (s:lookup env 'f) (s:lookup env 'f)))"),
        ('rib-ignores-slot-position', 'chapter03_lexical.rkt',
         '(vector-ref frame p)', '(vector-ref frame 0)',
         '(check-equal? (s:datum (l:run/nameless "let x = 7 y = 3 in -(x,y)" #:layout \'rib)) 4)'),
        ('known-call-resolves-free-name-in-caller', 'chapter03_lexical.rkt',
         '(known-saved-scope info) runtime', 'scope runtime',
         '(check-equal? (s:datum (l:run/nameless "let x = 3 in let f = proc (y) -(y,x) in let x = 100 in (f 13)" #:optimize 1)) 10)'),
    ]
    output = ROOT / 'tmp/eopl-ch03-20261023/program-mutations'
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for name, filename, before, after, witness in variants:
        with tempfile.TemporaryDirectory(prefix=name+'-', dir=output) as tmp:
            folder = Path(tmp)
            for f in ('chapter03.rkt', 'chapter03_lexical.rkt'):
                shutil.copy2(BOOK/'code'/f, folder/f)
            probe = folder/'witness.rkt'
            probe.write_text('#lang racket\n(require rackunit rackunit/text-ui (prefix-in s: "chapter03.rkt") (prefix-in l: "chapter03_lexical.rkt"))\n'
                             '(exit (run-tests (test-suite "semantic witness" (test-case "independent expectation" '+witness+'))))\n')
            baseline = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=20)
            assert baseline.returncode == 0, (name, baseline.stdout, baseline.stderr)
            target = folder/filename
            source = target.read_text()
            assert source.count(before) == 1, (name, 'mutation target count')
            target.write_text(source.replace(before, after))
            completed = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=20)
            (output/(name+'.log')).write_text(completed.stdout+completed.stderr)
            assert completed.returncode != 0, (name, 'accepted semantic fault')
            assert 'FAILURE' in completed.stderr or 'ERROR' in completed.stderr, (name, 'did not reach semantic test')
            results.append(dict(name=name, status='rejected', unmodified_witness='passed',
                                exit_code=completed.returncode, log=str((output/(name+'.log')).relative_to(ROOT))))
    report = dict(status='passed', cases=results)
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


if __name__ == '__main__':
    racket = shutil.which('racket')
    if not racket:
        installed = sorted(Path('/Applications').glob('Racket*/bin/racket'))
        racket = str(installed[-1]) if installed else None
    if not racket: raise SystemExit('Racket is required')
    print(json.dumps(run(racket), indent=2))
