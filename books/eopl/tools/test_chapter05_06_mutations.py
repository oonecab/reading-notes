#!/usr/bin/env python3
"""Bounded, independent semantic witnesses for EOPL control/CPS faults."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from sync_notes import ROOT, BOOK

def run(racket, run_dir=None):
    output = Path(run_dir) if run_dir else ROOT/'tmp/eopl-ch05-06-20261024/program-mutations'
    output.mkdir(parents=True, exist_ok=True)
    variants = [
      ('closure-uses-call-env','chapter05.rkt',
       "(if (eq? scope 'dynamic) env (closure-env p))",'env',
       '(check-equal? (m:result-value (m:run "let x = 10 in let f = proc(y) -(x,y) in let x = 3 in (f 1)")) 9)'),
      ('child-overwrites-main-answer','chapter05.rkt',
       '(when (= (thread-id current) 0)', '(when #t',
       '(check-equal? (m:result-value (m:run "begin spawn(proc(d)9); 33 end")) 33)'),
      ('resume-keeps-abort-target','chapter05.rkt',
       "(if (eq? exception-mode 'resume) resume outer)", 'outer',
       '(check-equal? (m:result-value (m:run "try -(10,raise 99) catch(e)3" #:exception-mode \'resume)) 7)'),
      ('mutex-opens-during-handoff','chapter05.rkt',
       '(enqueue! th))))) ; direct handoff keeps the mutex closed',
       '(set-mutex-value-closed?! m #f) (enqueue! th))))) ; faulty handoff',
       '(define s "let x = 0 in let mut = mutex() in let a = mutex() b = mutex() c = mutex() in let w = proc(done) begin wait(mut); set x = -(x,-1); signal(mut); signal(done) end in begin wait(a);wait(b);wait(c);spawn(proc(d)(w a));spawn(proc(d)(w b));spawn(proc(d)(w c));wait(a);wait(b);wait(c);x end") (for ([q (in-range 1 20)]) (check-equal? (m:result-value (m:run s #:implicit? #t #:quantum q)) 3))'),
      ('cps-reverses-argument-slots','chapter06.rkt',
       '(builder (map (lambda (i) (hash-ref converted i)) indices))',
       '(builder (reverse (map (lambda (i) (hash-ref converted i)) indices)))',
       '(define-values (v metrics) (c:run-converted "let f = proc(x) x in -((f 8),3)")) (check-equal? v 5)'),
      ('cps-parallel-let-captures-new-binding','chapter06.rkt',
       ',(map (lambda (a) (go a rho)) es) ,(go b r)',
       ',(map (lambda (a) (go a r)) es) ,(go b r)',
       '(define-values (v metrics) (c:run-converted "let x = 10 in let x = 2 y = x in -(y,x)")) (check-equal? v 8)'),
      ('cps-duplicates-continuation','chapter06.rkt',
       '(and share-if? (not (eq? (car k) \'var)))', '#f',
       '(define (n i) (if (zero? i) \'(num 0) `(prim + (if (prim zero? (num 0)) (num 1) (num 2)) ,(n (sub1 i))))) (check-true (< (c:ast-size (c:cps-program (n 8))) 1500))'),
      ('factorial-missing-multiply','chapter06_algorithms.rkt',
       '(set! val (* (car k) val))', '(set! n (car k))',
       '(check-equal? (a:factorial-register 4) 24)'),
      ('atomicization-captures-existing-name','chapter06_transforms.rkt',
       '(for ([name (all-vars target)]) (hash-set! used name #t))', '(void)',
       '(define target (x:atomicize (c:cps-program "let atom = 10 in -(-(5,2),atom)"))) (define-values (value metrics) (t:run-target (t:parse-target (t:target-string target)))) (check-equal? value -7)'),
      ('user-procedure-mistaken-for-continuation','chapter06_transforms.rkt',
       '#rx"^(k|join)%%[0-9]+$"', '#rx"^(k|join)%"',
       '(define-values (data table) (x:defunctionalize (c:cps-program "let k = proc(x) x in (k 3)") #:all? #f)) (define-values (value metrics) (t:run-target data)) (check-equal? value 3)'),
      ('user-result-parameter-mistaken-for-control-role','chapter06_transforms.rkt',
       '#rx"^[kh]%%[0-9]+$"', '#rx"^[kh]%"',
       '(define-values (data table) (x:defunctionalize (c:cps-program "let k = (proc(x) x 7) in -(k,2)") #:all? #f)) (define-values (value metrics) (t:run-target data)) (check-equal? value 5)'),
      ('implicit-capture-omits-location','chapter06.rkt',
       ',(bind-values (list x) (list `(var ,raw)) (go body))', ',(go body)',
       '(define target (c:cps-program "letcc out in throw 7 to out" #:implicit? #t)) (define-values (value metrics) (t:run-target (t:parse-target (t:target-string target)))) (check-equal? value 7)'),
      ('private-spawn-retains-sender-closure','chapter05.rkt',
       '(define child-procedure (if private? (copy-between v current child) v))', '(define child-procedure v)',
       '(define source "let x = 100 in let child = spawn(proc(id) begin set x = 9; send(parent(),x) end) in list(receive(),x)") (check-equal? (m:result-value (m:run source #:implicit? #t #:private-store? #t #:thread-ids? #t)) (list 9 100))'),
      ('semaphore-invents-spare-permit','chapter05.rkt',
       '(enqueue! th))) ; transferred permit must not also increment the count',
       '(set-semaphore-value-permits! v 1) (enqueue! th))) ; faulty handoff',
       '(define r (m:run "let s = semaphore(0) in begin spawn(proc(id) begin down(s); print(1) end); spawn(proc(id) begin down(s); print(2) end); yield(); up(s); spawn(proc(id) begin down(s); print(3) end); yield(); 0 end")) (check-equal? (m:result-output r) (list 1)) (check-equal? (hash-ref (m:result-metrics r) \'blocked) 2)'),
      ('condition-does-not-reacquire','chapter05.rkt',
       "(state 'reacquire #f #f k m)", '(A k 52)',
       '(check-equal? (m:result-value (m:run m:condition-program #:implicit? #t #:thread-ids? #t)) 45)'),
      ('barrier-reuses-generation','chapter05.rkt',
       '(add1 (barrier-value-generation v))', '(barrier-value-generation v)',
       '(check-equal? (m:result-value (m:run m:barrier-program #:thread-ids? #t)) (list 1 2))'),
    ]
    results=[]
    for name, filename, before, after, witness in variants:
        with tempfile.TemporaryDirectory(prefix=name+'-',dir=output) as temp:
            folder=Path(temp)
            for file in (BOOK/'code').glob('*.rkt'):shutil.copy2(file,folder/file.name)
            probe=folder/'witness.rkt'
            probe.write_text('#lang racket\n(require rackunit rackunit/text-ui (prefix-in m: "chapter05.rkt") (prefix-in c: "chapter06.rkt") (prefix-in a: "chapter06_algorithms.rkt") (prefix-in x: "chapter06_transforms.rkt") (prefix-in t: "chapter06_target.rkt"))\n'
             '(exit (run-tests (test-suite "independent semantic oracle" (test-case "bounded witness" '+witness+'))))\n')
            baseline=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=30)
            assert baseline.returncode==0,(name,baseline.stdout,baseline.stderr)
            target=folder/filename;s=target.read_text();assert s.count(before)==1,(name,s.count(before))
            target.write_text(s.replace(before,after))
            completed=subprocess.run([racket,str(probe)],capture_output=True,text=True,timeout=30)
            (output/(name+'.log')).write_text(completed.stdout+completed.stderr)
            assert completed.returncode!=0,(name,'accepted fault')
            assert 'FAILURE' in completed.stderr or 'ERROR' in completed.stderr,(name,'test did not reach its oracle',completed.stderr)
            results.append(dict(name=name,unmodified_witness='passed',status='rejected',exit_code=completed.returncode))
    report=dict(status='passed',cases=results)
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def run_c_drivers(run_dir=None):
    output=Path(run_dir) if run_dir else ROOT/'tmp/eopl-ch05-06-20261024/c-check'
    output.mkdir(parents=True,exist_ok=True)
    cc=shutil.which('cc');assert cc,'C11 compiler required'
    src=BOOK/'code/chapter05_machine.c';binary=output/'machine'
    commands=[]
    def execute(args):
        r=subprocess.run(list(map(str,args)),capture_output=True,text=True,timeout=45)
        commands.append(dict(command=list(map(str,args)),exit_code=r.returncode,stdout=r.stdout,stderr=r.stderr))
        assert r.returncode==0,commands[-1];return r
    execute([cc,'-std=c11','-O0','-fno-optimize-sibling-calls','-Wall','-Wextra','-Werror',src,'-o',binary])
    for driver,n in [(0,100),(0,1000),(1,100),(1,1000),(1,20000),(2,100),(2,1000),(2,20000)]:
        r=execute([binary,str(driver),str(n)])
        assert f'result=0 steps={15*n+14} max_frames=2' in r.stdout,r.stdout
    sanitized=output/'machine-sanitized'
    execute([cc,'-std=c11','-O1','-g','-fno-omit-frame-pointer','-fsanitize=address,undefined','-Wall','-Wextra','-Werror',src,'-o',sanitized])
    for driver in (1,2):execute([sanitized,str(driver),'20000'])
    report=dict(status='passed',commands=commands,numeric_scope='Only bounded decrement AST; arbitrary replacement C AST arithmetic needs independent overflow bounds.')
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

if __name__=='__main__':
    installed=sorted(Path('/Applications').glob('Racket*/bin/racket'))
    racket=shutil.which('racket') or (str(installed[-1]) if installed else None)
    assert racket,'Racket required'
    print(json.dumps(run(racket),indent=2));print(json.dumps(run_c_drivers(),indent=2))
