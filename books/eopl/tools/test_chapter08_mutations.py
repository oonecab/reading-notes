#!/usr/bin/env python3
"""Independent witnesses reject loadable module-system faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket, run_dir=None):
    output = Path(run_dir) if run_dir else ROOT / "tmp/eopl-ch08-mutations"
    output.mkdir(parents=True, exist_ok=True)
    cases = [
        ("solved-variable-escapes-alpha-renaming", "  (set! actual (map-interface resolve actual))\n  (set! expected (map-interface resolve expected))", "  (void)",
         '(check-equal? (m:check "module F interface ((A:[transparent t=int z:t]) => [f:(int -> int)]) body module-proc(A:[opaque t z:t]) [f=proc(x:?) if zero?(0) then x else from A take z] 0" #:inferred? #t) (quote int))'),
        ("duplicate-module-check-omitted", "(when (assq (mdef-name d) (tenv-modules env))", "(when #f",
         '(check-exn m:exn:fail:typing? (lambda () (m:check "module a interface [] body [] module a interface [] body [] 0")))'),
        ("private-runtime-exports-leak", "(define (project-module v iface env)\n  (cond", "(define (project-module v iface env)\n  (cond [#t v]",
         '(check-exn m:exn:fail:typing? (lambda () (m:run "module a interface [] body [hidden=7] from a take hidden" #:check? #f)))'),
        ("opaque-types-collapse-to-int", "(define q (qualified (list key) n))", "(define q 'int)",
         '(check-exn m:exn:fail:typing? (lambda () (m:check "module a interface [opaque t z:t] body [type t=int z=0] -(from a take z,0)")))'),
        ("parameter-variance-reversed", "(go bi ai)) ; arguments contravariant", "(go ai bi)) ; wrong variance",
         '(check-true (m:compare-interfaces "((A:[x:int]) => [y:int])" "((B:[x:int extra:bool]) => [y:int])"))'),
        ("dependent-result-not-instantiated", "(define replaced (map-interface go iface))", "(define replaced iface)",
         '(check-equal? (m:run e:example8-15) 2)'),
        ("module-closure-forgets-definition-environment", "(define local (module-closure-environment fn))", "(define local empty-renv)",
         '(check-equal? (m:run "module A interface [] body [] module F interface ((X:[]) => [v:int]) body let n=7 in module-proc(X:[]) [v=n] module R interface [v:int] body (F A) from R take v") 7)'),
        ("imports-evaluate-again", "[(done) (unbox (delayed-module-value v))]", "[(done) (evaluate-module (delayed-module-definition v) (delayed-module-environment v))]",
         '(check-equal? (m:execution-output (m:run/trace e:exercise8-10-explicit #:dependencies (quote imports))) (quote (2 3 1)))'),
        ("default-declaration-order-ignored", "[(current-unordered?)", "[#t",
         '(check-false (m:compare-interfaces "[v:int u:int]" "[u:int v:int]"))'),
        ("constraints-forget-previous-components", "((solver-unify (current-solver)) a b context)", "((solver-unify (make-solver)) a b context)",
         '(check-exn m:exn:fail:typing? (lambda () (m:check "module m interface [f:(int -> int) g:(bool -> bool)] body [f=proc(x:?)x g=f] 0" #:inferred? #t)))'),
    ]
    results = []
    for name, before, after, witness in cases:
        with tempfile.TemporaryDirectory(prefix=name+"-", dir=output) as temporary:
            folder = Path(temporary)
            for file in ["chapter07_types.rkt", "chapter07_syntax.rkt", "chapter08.rkt", "chapter08_syntax.rkt", "chapter08_examples.rkt"]:
                shutil.copy2(BOOK / "code" / file, folder / file)
            probe = folder / "witness.rkt"
            probe.write_text('#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: "chapter08.rkt") (prefix-in e: "chapter08_examples.rkt"))\n'
                             '(exit (run-tests (test-suite "oracle" (test-case "witness" '+witness+'))))\n')
            baseline = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=30)
            (output/(name+"-baseline.log")).write_text(baseline.stdout+baseline.stderr)
            assert baseline.returncode == 0, (name, baseline.stderr)
            target = folder / "chapter08.rkt"
            source = target.read_text(); assert source.count(before) == 1, (name, source.count(before))
            target.write_text(source.replace(before, after))
            loaded = subprocess.run([racket, "-e", '(dynamic-require "chapter08.rkt" #f)'], cwd=folder, capture_output=True, text=True, timeout=30)
            assert loaded.returncode == 0, (name, "mutant failed to load", loaded.stderr)
            tested = subprocess.run([racket, str(probe)], capture_output=True, text=True, timeout=30)
            (output/(name+".log")).write_text(tested.stdout+tested.stderr)
            assert tested.returncode != 0 and ("FAILURE" in tested.stderr or "ERROR" in tested.stderr), (name, "fault not detected", tested.stdout, tested.stderr)
            results.append(dict(name=name, baseline="passed", mutant_load="passed", oracle="rejected"))
    report = dict(status="passed", cases=results)
    (output/"report.json").write_text(json.dumps(report, indent=2)+"\n")
    return report


if __name__ == "__main__":
    installed = sorted(Path("/Applications").glob("Racket*/bin/racket"))
    racket = shutil.which("racket") or (str(installed[-1]) if installed else None)
    assert racket, "Racket required"
    print(json.dumps(run(racket), indent=2))
