#!/usr/bin/env python3
"""Independent bounded witnesses for type-checking, inference and execution faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from sync_notes import ROOT, BOOK


def run(racket, run_dir=None):
    output = Path(run_dir) if run_dir else ROOT / "tmp/eopl-ch07-mutations"
    output.mkdir(parents=True, exist_ok=True)
    cases = [
        ("eager-forgets-old-right-sides", "chapter07_types.rkt",
         "(apply-one (cdr binding) variable replacement)", "(cdr binding)",
         "(define u (m:make-solver)) ((m:solver-unify u) (m:tv 0) (m:tv 1)) ((m:solver-unify u) (m:tv 1) 'int) (check-equal? ((m:solver-resolve u) (m:tv 0)) 'int)"),
        ("lazy-stops-after-one-binding", "chapter07_types.rkt",
         "(lambda (p) (walk (cdr p)))", "(lambda (p) (cdr p))",
         "(check-equal? (m:apply-lazy (m:tv 0) (list (cons (m:tv 0) (m:tv 1)) (cons (m:tv 1) 'int))) 'int)"),
        ("unifier-omits-occurs-check", "chapter07_types.rkt",
         "(when (occurs? left (resolve right))", "(when #f",
         "(define u (m:make-solver)) (check-exn m:exn:fail:typing? (lambda () ((m:solver-unify u) (m:tv 0) (m:proc-t (list (m:tv 0)) 'int))))"),
        ("fresh-variables-share-one-id", "chapter07.rkt",
         "(begin0 (tv next) (set! next (add1 next)))", "(tv 0)",
         "(check-equal? (m:infer \"proc(x)proc(y)x\") '(a0 -> (a1 -> a0)))"),
        ("inference-forgets-boolean-condition", "chapter07.rkt",
         "(emit (go (first es) env) 'bool (first es))", "(go (first es) env)",
         "(check-exn m:exn:fail:typing? (lambda () (m:infer \"if 1 then 2 else 3\")))"),
        ("recursive-result-annotation-unchecked", "chapter07.rkt",
         "(emit (go (fourth d) (extend-many (map car (second d)) args renv)) res (fourth d))",
         "(go (fourth d) (extend-many (map car (second d)) args renv))",
         "(check-exn m:exn:fail:typing? (lambda () (m:infer \"letrec bool f(x:int)=1 in f\")))"),
        ("w-generalizes-environment-variables", "chapter07.rkt",
         "(set-subtract (free-tvars normalized) (env-free env))", "(free-tvars normalized)",
         "(check-exn m:exn:fail:typing? (lambda () (m:infer \"proc(x) let f=proc(y)x in if (f 0) then -(x,1) else 2\" #:polymorphism 'w)))"),
        ("reference-allocations-are-generalized", "chapter07.rkt",
         "(and restriction? (not (nonexpansive? e mutable?)))", "(and #f (not (nonexpansive? e mutable?)))",
         "(check-exn m:exn:fail:typing? (lambda () (m:infer m:unsafe-reference #:polymorphism 'w)))"),
        ("copy-analysis-captures-use-site", "chapter07.rkt",
         "(go (copy-binding-expression b) (copy-binding-environment b))", "(go (copy-binding-expression b) env)",
         "(check-equal? (m:infer \"let x=1 in let f=proc(y)x in let x=zero?(0) in (f 0)\" #:polymorphism 'copy) 'int)"),
        ("checker-ignores-alternative-type", "chapter07.rkt",
         "(require-equal at bt e) at", "at",
         "(check-exn m:exn:fail:typing? (lambda () (m:check \"if zero?(0) then 1 else zero?(1)\")))"),
        ("closure-uses-caller-environment", "chapter07.rkt",
         "(map box args) (closure-environment f))", "(map box args) env)",
         "(check-equal? (m:evaluate \"let x=10 in let f=proc(y) -(x,y) in let x=3 in (f 1)\") 9)"),
    ]
    results = []
    for name, filename, before, after, witness in cases:
        with tempfile.TemporaryDirectory(prefix=name + "-", dir=output) as temp:
            folder = Path(temp)
            for file in (BOOK / "code").glob("chapter07*.rkt"):
                shutil.copy2(file, folder / file.name)
            probe = folder / "witness.rkt"
            probe.write_text(
                '#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: "chapter07.rkt") (prefix-in m: "chapter07_examples.rkt"))\n'
                '(exit (run-tests (test-suite "independent oracle" (test-case "bounded witness" '
                + witness + '))))\n')
            baseline = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=30)
            (output / (name + "-baseline.log")).write_text(baseline.stdout + baseline.stderr)
            assert baseline.returncode == 0, (name, baseline.stdout, baseline.stderr)
            target = folder / filename
            source = target.read_text()
            assert source.count(before) == 1, (name, source.count(before))
            target.write_text(source.replace(before, after))
            # A syntax/import failure is not evidence that a semantic witness rejected a fault.
            loaded = subprocess.run([racket, "-e", '(dynamic-require "chapter07.rkt" #f)'],
                                    cwd=folder, capture_output=True, text=True, timeout=30)
            assert loaded.returncode == 0, (name, "mutant failed to load", loaded.stderr)
            tested = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=30)
            (output / (name + ".log")).write_text(tested.stdout + tested.stderr)
            assert tested.returncode != 0 and ("FAILURE" in tested.stderr or "ERROR" in tested.stderr), (
                name, "fault not rejected by its oracle", tested.stdout, tested.stderr)
            results.append(dict(name=name, baseline="passed", mutant_load="passed", oracle="rejected"))
    report = dict(status="passed", cases=results)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


if __name__ == "__main__":
    installed = sorted(Path("/Applications").glob("Racket*/bin/racket"))
    racket = shutil.which("racket") or (str(installed[-1]) if installed else None)
    assert racket, "Racket required"
    print(json.dumps(run(racket), indent=2))
