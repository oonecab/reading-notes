#!/usr/bin/env python3
"""Independent bounded witnesses reject chapter 4 semantic faults in isolated copies."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket, run_dir=None):
    output = Path(run_dir) if run_dir else ROOT / 'tmp/eopl-ch04-20261024/program-mutations'
    output.mkdir(parents=True, exist_ok=True)
    variants = [
        ('value-aliases-variable', 'chapter04.rkt',
         "[(eq? mode 'value) (newref! (value-of exp env))]",
         "[(eq? mode 'value) (cases expression exp (var-exp (v) (mutable-location env v)) (else (newref! (value-of exp env))))]",
         '(check-equal? (s:datum (s:run "let a = 3 in let p = proc(x) set x = 4 in begin (p a); a end")) 3)'),
        ('need-does-not-memoize', 'chapter04.rkt',
         "(when (eq? (parameter-mode) 'need) (setref! loc answer))", "(when #f (setref! loc answer))",
         '(check-equal? (s:datum (s:run "let c = 0 in let f = proc(x) -(x,x) in (f begin set c = -(c,-1); c end)" #:mode \'need)) 0)'),
        ('thunk-loses-caller-environment', 'chapter04.rkt',
         "(begin (bump! 'thunks) (thunk exp env))", "(begin (bump! 'thunks) (thunk exp '()))",
         '(check-equal? (s:datum (s:run "let x = 7 in let f = proc(z) let x = 99 in z in (f -(x,1))" #:mode \'need)) 6)'),
        ('array-allows-one-past-end', 'chapter04.rkt',
         '(< i (array-val-length a))', '(<= i (array-val-length a))',
         '(check-exn #rx"bounds" (lambda () (s:run "let a = newarray(2,0) b = newarray(2,99) in arrayref(a,2)")))'),
        ('pure-difference-reuses-old-store', 'chapter04_explicit.rkt',
         '(define a (ev e1 sigma)) (define b (ev e2 (answer-store a)))',
         '(define a (ev e1 sigma)) (define b (ev e2 sigma))',
         '(check-equal? (s:datum (e:run "let r = newref(0) in -(begin setref(r,9); 1 end,deref(r))")) -8)'),
        ('recursive-location-rebuilt', 'chapter04.rkt',
         "(if (eq? (rec-mode) 'fresh)", '(if #t',
         '(check-equal? (hash-ref (s:execution-metrics (s:run/details "letrec f(x) = x in begin (f 1); (f 2) end")) \'closures) 1)'),
        ('dynamic-assignment-not-restored', 'chapter04.rkt',
         '(lambda () (setref! loc old))', '(lambda () (void))',
         '(check-equal? (s:datum (s:run "let x = 11 in let p = proc(y) -(y,x) in -(setdynamic x = 17 during (p 22),(p 13))")) 3)'),
        ('initializer-ignores-earlier-declarations', 'chapter04_statements.rkt',
         '(define val (value-of-expression e current))', '(define val (value-of-expression e env))',
         '(check-equal? (t:statement-result-output (t:run "varinit x = 3 y = +(x,1); print y")) "4\\n")'),
    ]
    results = []
    for name, filename, before, after, witness in variants:
        with tempfile.TemporaryDirectory(prefix=name+'-', dir=output) as temp:
            folder = Path(temp)
            for file in ('chapter04.rkt', 'chapter04_explicit.rkt', 'chapter04_statements.rkt', 'sllgen_guard.rkt'):
                shutil.copy2(BOOK/'code'/file, folder/file)
            probe = folder/'witness.rkt'
            probe.write_text('#lang racket\n(require rackunit rackunit/text-ui (prefix-in s: "chapter04.rkt") (prefix-in e: "chapter04_explicit.rkt") (prefix-in t: "chapter04_statements.rkt"))\n'
                             '(exit (run-tests (test-suite "semantic witness" (test-case "independent expectation" '+witness+'))))\n')
            baseline = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=20)
            assert baseline.returncode == 0, (name, baseline.stdout, baseline.stderr)
            target=folder/filename; source=target.read_text()
            assert source.count(before) == 1, (name, 'mutation target count', source.count(before))
            target.write_text(source.replace(before,after))
            completed=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=20)
            (output/(name+'.log')).write_text(completed.stdout+completed.stderr)
            assert completed.returncode != 0, (name,'accepted semantic fault')
            assert 'FAILURE' in completed.stderr or 'ERROR' in completed.stderr, (name,'did not reach semantic test')
            results.append(dict(name=name,status='rejected',unmodified_witness='passed',exit_code=completed.returncode,
                                log=str((output/(name+'.log')).relative_to(ROOT))))
    report=dict(status='passed',cases=results)
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run-dir',type=Path)
    args=parser.parse_args();racket=shutil.which('racket')
    if not racket:
        installed=sorted(Path('/Applications').glob('Racket*/bin/racket'))
        racket=str(installed[-1]) if installed else None
    if not racket:raise SystemExit('Racket is required')
    print(json.dumps(run(racket,args.run_dir),indent=2))
