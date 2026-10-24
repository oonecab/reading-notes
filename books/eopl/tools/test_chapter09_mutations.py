#!/usr/bin/env python3
"""Independent witnesses reject loadable object-language faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK


def run(racket, run_dir=None):
    output=Path(run_dir) if run_dir else ROOT/'tmp/eopl-ch09-mutations'
    output.mkdir(parents=True,exist_ok=True)
    cases=[
      ('dynamic-self-uses-host','chapter09_runtime.rkt',
       "(context-host ctx) (object-class* obj))])", "(context-host ctx) (if ctx (context-host ctx) (object-class* obj)))])",
       '(check-equal? (m:run e:figure9-6) 33)'),
      ('super-uses-receiver-parent','chapter09_runtime.rkt',
       '(find-method (parent-of (context-host ctx)) name (length vs))',
       '(find-method (parent-of (object-class* (context-self ctx))) name (length vs))',
       '(check-equal? (m:run e:figure9-6) 33)'),
      ('field-uses-dynamic-view','chapter09_runtime.rkt',
       '(object-field-frame receiver (field-bindings host))', '(object-field-frame receiver (field-bindings (object-class* receiver)))',
       "(check-equal? (m:run e:figure9-4) '(101 102 101 999))"),
      ('new-returns-initializer-value','chapter09_runtime.rkt',
       "(invoke-method (find-method class 'initialize (length vs)) obj vs ctx) obj]",
       "(invoke-method (find-method class 'initialize (length vs)) obj vs ctx)]",
       "(check-equal? (m:run e:figure9-1) '((3 -3) (5 -5)))"),
      ('access-check-omitted','chapter09_runtime.rkt',
       '(unless (accessible? visibility owner (and ctx (context-host ctx)))', '(when #f',
       '(check-exn m:exn:fail:oo? (lambda () (m:run "class A extends object method initialize()1 private method secret()7 send new A() secret()")))'),
      ('final-check-omitted','chapter09_runtime.rkt',
       '(when (mdecl-final? (rmethod-decl p))', '(when #f',
       '(check-exn m:exn:fail:oo? (lambda () (m:run "class A extends object method initialize()1 final method m()7 class B extends A method m()9 0")))'),
      ('procedure-variance-reversed','chapter09_types.rkt',
       '(subtype? expected accepted classes)', '(subtype? accepted expected classes)',
       '(define cs (m:checked-classes (m:check/compiled "class A extends object method int initialize()1 class B extends A 0"))) (check-true (m:subtype? (quote (proc (A) B)) (quote (proc (B) A)) cs))'),
      ('initializer-elaboration-discarded','chapter09_types.rkt',
       '(struct-copy fdecl f [init initializer*])', 'f',
       '(check-equal? (m:run "class A extends object method int initialize()1 staticmethod int m()11 class B extends A staticmethod int m()22 class C extends object field int n=let f=proc(x:A)send x m() in (f new B()) method int initialize()1 method int get()n send new C() get()" #:typed? #t #:options (hash (quote field-initializers?) #t)) 11)'),
      ('initialize-policy-ignored','chapter09_types.rkt',
       "(and (eq? name 'initialize) (eq? (option 'initialization 'textbook) 'new-only))", '#f',
       '(check-exn m:exn:fail:oo? (lambda () (m:check "class A extends object method int initialize()1 send new A() initialize()" #:options (hash (quote initialization) (quote new-only)))))'),
      ('cast-interface-target-accepted','chapter09_types.rkt',
       '(and require-class? (sclass-interface? c))', '#f',
       '(check-exn m:exn:fail:oo? (lambda () (m:check "interface I class A extends object method int initialize()1 cast new A() I")))'),
      ('method-slots-unstable','chapter09_runtime.rkt',
       '(list-set answer pos m)', '(cons m answer)',
       '(check-equal? (m:method-slots (m:run/trace e:figure9-8-complete #:options (hash (quote stable?) #t)) (quote c2)) (quote ((0 initialize c2) (1 m1 c2) (2 m2 c1) (3 m3 c2))))'),
      ('lexical-assignment-loses-write','chapter09_runtime.rkt',
       '(set-box! (vector-ref (frame-cells (list-ref env depth)) index) v)', '(void v)',
       '(check-equal? (m:run "let x=7 in begin set x=9;x end" #:options (hash (quote lexical?) #t)) 9)'),
      ('field-frame-copies-locations','chapter09_runtime.rkt',
       '(hash-ref (object-fields obj) (rfield-id (cdr p)))', '(box (unbox (hash-ref (object-fields obj) (rfield-id (cdr p)))))',
       "(check-equal? (m:run e:figure9-1) '((3 -3) (5 -5)))"),
      ('future-nominal-relationship-ignored','chapter09_types.rkt',
       '(subtype? (signature (smethod-decl old)) (signature (smethod-decl current)) hierarchy)',
       '(subtype? (signature (smethod-decl old)) (signature (smethod-decl current)) classes)',
       '(check-equal? (m:check "interface I method A m() interface J method B m() interface K extends I,J class A extends object method int initialize()1 class B extends A 0") (quote int))'),
      ('static-dynamic-kind-check-omitted','chapter09_types.rkt',
       '(unless (eq? (mdecl-static? m) (mdecl-static? old))', '(when #f',
       '(check-exn m:exn:fail:oo? (lambda () (m:check "class A extends object method int initialize()1 staticmethod int m()11 class B extends A method int m()22 0")))'),
      ('diamond-duplicates-ancestor-field','chapter09_runtime.rkt',
       '(remove-duplicates (append-map rclass-fields parents) eq?)', '(append-map rclass-fields parents)',
       '(check-equal? (m:class-layout (m:run/trace e:exercise9-26 #:options (hash (quote multiple?) #t)) (quote D)) (quote ((0 A x))))'),
      ('method-body-type-check-omitted','chapter09_types.rkt',
       '(require-subtype! t (mdecl-result m) classes m)', '(void)',
       '(check-exn m:exn:fail:oo? (lambda () (m:check "class A extends object method int initialize()1 method bool m()12 0")))')
      ,('invalid-hierarchy-used-before-validation','chapter09_types.rkt',
       '(for ([p (cdecl-supers d)]) (parent! p #f))', '(for ([p (cdecl-supers d)]) (void p))',
       '(define cust (make-custodian)) (define ch (make-channel)) (parameterize ([current-custodian cust]) (thread (lambda () (channel-put ch (with-handlers ([exn:fail? (lambda(e)(quote rejected))]) (m:check "interface I method C m() interface J extends I method B m() class B extends B method int initialize()1 class C extends object method int initialize()1 0") (quote accepted)))))) (define result (or (sync/timeout 1 ch) (quote timeout))) (custodian-shutdown-all cust) (check-equal? result (quote rejected))')
    ]
    records=[]
    for name,file,before,after,witness in cases:
        with tempfile.TemporaryDirectory(prefix=name+'-',dir=output) as folder:
            folder=Path(folder)
            for path in (BOOK/'code').glob('chapter09*.rkt'):shutil.copy2(path,folder/path.name)
            probe=folder/'witness.rkt'
            probe.write_text('#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: "chapter09.rkt") (prefix-in e: "chapter09_examples.rkt"))\n'
                             '(exit (run-tests (test-suite "oracle" (test-case "independent witness" '+witness+'))))\n')
            baseline=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=30)
            (output/(name+'-baseline.log')).write_text(baseline.stdout+baseline.stderr)
            assert baseline.returncode==0,(name,baseline.stdout,baseline.stderr)
            target=folder/file;source=target.read_text();assert source.count(before)==1,(name,source.count(before))
            target.write_text(source.replace(before,after))
            loaded=subprocess.run([racket,'-e','(dynamic-require "chapter09.rkt" #f)'],cwd=folder,capture_output=True,text=True,timeout=30)
            assert loaded.returncode==0,(name,'mutant failed to load',loaded.stderr)
            result=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=30)
            (output/(name+'.log')).write_text(result.stdout+result.stderr)
            assert result.returncode!=0 and ('FAILURE' in result.stderr or 'ERROR' in result.stderr),(name,'not detected',result.stdout,result.stderr)
            records.append(dict(name=name,baseline='passed',mutant_load='passed',oracle='rejected'))
    report=dict(status='passed',cases=records)
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    installed=sorted(Path('/Applications').glob('Racket*/bin/racket'))
    racket=shutil.which('racket') or (str(installed[-1]) if installed else None)
    assert racket,'Racket required'
    print(json.dumps(run(racket),indent=2))
