#lang racket
(require rackunit rackunit/text-ui racket/match json
 (prefix-in m: "chapter05.rkt") (prefix-in p: "chapter05_cps.rkt")
 (prefix-in c: "chapter06.rkt") (prefix-in t: "chapter06_target.rkt")
 (prefix-in r: "chapter06_register.rkt") (prefix-in st: "chapter05_statements.rkt")
 (prefix-in x: "chapter06_transforms.rkt") (prefix-in a: "chapter06_algorithms.rkt")
 (only-in "chapter05_syntax.rkt" parse))
(define assertions 0)
(define (eq! actual expected) (set! assertions (add1 assertions)) (check-equal? actual expected))
(define (bad! thunk regex) (set! assertions (add1 assertions)) (check-exn regex thunk))
(define (M s . args) (m:result-value (apply m:run s args)))
(define (T s #:order [order 'left] #:exceptions? [ex? #f] #:implicit? [im? #f] #:immutable? [opt? #f]
           #:send [send 'let] #:share-if? [share? #t])
 (define out (c:cps-program s #:order order #:exceptions? ex? #:implicit? im? #:immutable? opt? #:send send #:share-if? share?))
 (define text (t:target-string out))
 (define reparsed (t:parse-target text)) (eq! reparsed out)
 (t:run-target reparsed #:numeric? #t))
(define fact "letrec fact(n) = if zero?(n) then 1 else *(n,(fact -(n,1))) in (fact 4)")
(define iter "letrec fact(n,a) = if zero?(n) then a else (fact -(n,1) *(n,a)) in (fact 4 1)")
(define (counter safe?)
 (format "let x = 0 in let mut = mutex() in let a = mutex() b = mutex() c = mutex() in let worker = proc(done) begin ~aset x = -(x,-1); ~asignal(done) end in begin wait(a); wait(b); wait(c); spawn(proc(d)(worker a)); spawn(proc(d)(worker b)); spawn(proc(d)(worker c)); wait(a); wait(b); wait(c); x end"
  (if safe? "wait(mut); " "") (if safe? "signal(mut); " "")))
(define suites
 (test-suite "EOPL chapters 5 and 6"
  (test-case "basic continuations, representations, one end and growth"
   (for ([s (list "-(-(44,11),3)" fact iter "let2 a = 7 b = 4 in -(a,b)" "let3 a = 7 b = 4 c = 2 in -(-(a,b),c)" "list(1,2,3)" "let x = 10 in let x = 2 y = x in -(y,x)")]
         [expected (list 30 24 24 3 1 '(1 2 3) 8)])
    (define r (m:run s #:trace? #t)) (eq! (m:result-value r) expected)
    (eq! (hash-ref (m:result-metrics r) 'end-count) 1)
    (for ([rep '(inline pair)]) (define-values (v metrics) (p:run-cps s #:representation rep))
     (eq! v expected) (eq! (hash-ref metrics 'end-count) 1))
    (eq! (m:result-trace (m:run s #:driver 'thunk #:trace? #t)) (m:result-trace r)))
   (eq! (hash-ref (m:result-metrics (m:run "-(-(44,11),3)")) 'max-continuation) 3)
   (for ([n '(1 2 4 8 16)])
    (define f (string-replace fact "in (fact 4)" (format "in (fact ~a)" n)))
    (define i (string-replace iter "in (fact 4 1)" (format "in (fact ~a 1)" n)))
    (eq! (m:result-value (m:run f)) (for/product ([j (in-range 1 (add1 n))]) j))
    (eq! (hash-ref (m:result-metrics (m:run f)) 'max-continuation) (+ n 3))
    (eq! (hash-ref (m:result-metrics (m:run i)) 'max-continuation) 3)))
  (test-case "implicit refs, sequencing, dynamic extent"
   (eq! (m:result-value (m:run "let x = 0 in begin set x = 9; x end" #:implicit? #t)) 9)
   (define s "let x = 10 in let f = proc(y) -(x,y) in let x = 3 in (f 1)")
   (eq! (M s) 9) (eq! (m:result-value (m:run s #:scope 'dynamic)) 2)
   (define r (m:run "begin print(1); print(2); 9 end"))
   (eq! (m:result-output r) '(1 2)) (eq! (m:result-value r) 9))
  (test-case "unwind, rethrow, arity, division, resume and capture"
   (for ([s '("try -(10,raise 99) catch(e) -(e,1)"
               "try try raise 7 catch(e) raise -(e,-1) catch(x) -(x,2)"
               "try (proc(x,y) x 1) catch(e) e"
               "try /(8,0) catch(e) e"
               "letcc out in -(1,throw 7 to out)")]
         [expected '(98 6 1001 1002 7)])
    (eq! (M s) expected)
    (define-values (v unused0) (p:run-cps s #:representation 'pair)) (eq! v expected))
   (eq! (m:result-value (m:run "try -(10,raise 99) catch(e) 3" #:exception-mode 'resume)) 7)
   (eq! (M "try -(10,raise 99) catch(e,k) (k 3)") 7)
   (eq! (M "try -(10,raise 99) catch(e,k) 3") 3)
   (bad! (lambda () (M "raise 5")) #rx"uncaught")
   (bad! (lambda () (M "(proc(x) x)")) #rx"uncaught.*1001"))
  (test-case "threads, lock handoff, join, identifiers and message blocking"
   (for ([q (in-range 1 31)])
    (define r (m:run (counter #t) #:implicit? #t #:quantum q))
    (eq! (m:result-value r) 3) (eq! (hash-ref (m:result-metrics r) 'blocked) 0))
   (define unsafe-values
    (remove-duplicates (for/list ([q (in-range 1 31)]) (m:result-value (m:run (counter #f) #:implicit? #t #:quantum q)))))
   (eq! (and (member 2 unsafe-values) #t) #t) (eq! (and (member 3 unsafe-values) #t) #t)
   (define msg "let p = self() in let c = spawn(proc(id) send(p,-(id,-40))) in receive()")
   (for ([q '(1 2 9 100)]) (eq! (m:result-value (m:run msg #:thread-ids? #t #:quantum q)) 41))
   (eq! (M "let c = spawn(proc(d) 9) in kill(c)") #f)
   (eq! (m:result-value (m:run "let c = spawn(proc(id) receive()) in kill(c)" #:thread-ids? #t)) #t)
   (define dead "let a = mutex() b = mutex() in begin spawn(proc(d)begin wait(a); yield(); wait(b) end); spawn(proc(d)begin wait(b); yield(); wait(a) end); 77 end")
   (define r (m:run dead #:quantum 100))
   (eq! (m:result-value r) 77) (eq! (hash-ref (m:result-metrics r) 'blocked) 2)
   (for ([preserve? '(#f #t)])
    (eq! (m:result-value (m:run "begin yield(); 99 end" #:quantum 1 #:preserve-ticks? preserve?)) 99)))
  (test-case "source and target syntax boundaries"
   (for ([s '("-((f -(x,1)),1)" "(f -(-(x,y),1))" "if zero?(x) then -(x,y) else -(-(x,y),1)" "let x = proc(y)(y x) in -(x,3)" "let f = proc(x) x in (f 3)")])
    (eq! (c:simple? (parse s)) #f))
   (eq! (c:tail-form? (parse "let f = proc(x) x in (f 3)")) #t)
   (eq! (c:tail-form? (parse fact)) #f) (eq! (c:tail-form? (parse iter)) #t)
   (bad! (lambda () (t:parse-target "-((f x),1)")) #rx"parsing"))
  (test-case "private thread stores, closure graphs and copied messages"
   (define isolation "let x = 100 in let child = spawn(proc(id) begin set x = 9; send(parent(),x) end) in list(receive(),x)")
   (define aliases "let r = newref(1) in let s = r in let child = spawn(proc(id) begin setref(r,9); send(parent(),list(deref(s),deref(r))) end) in let answer = receive() in list(answer,deref(r))")
   (define cycles "let r = newref(0) in begin setref(r,r); let child = spawn(proc(id) begin setref(deref(r),7); send(parent(),deref(r)) end) in list(receive(),number?(deref(r))) end")
   (define recursive "let x = 100 in letrec even(n) = if zero?(n) then x else (odd -(n,1)) odd(n) = if zero?(n) then x else (even -(n,1)) in let child = spawn(proc(id) begin set x = 8; send(parent(),(even 4)) end) in list(receive(),x)")
   (define closure-message "let r = newref(5) in let child = spawn(proc(id) let f = receive() in send(parent(),(f 1))) in begin send(child,proc(n) begin setref(r,-(deref(r),n)); deref(r) end); list(receive(),deref(r)) end")
   (define owner m:private-counter-program)
   (define producer "let child = spawn(proc(id) send(parent(),44)) in receive()")
   (for* ([q '(1 2 5 100)]
          [example (list (list isolation '(9 100)) (list aliases '((9 9) 1))
                         (list cycles '(7 #f)) (list recursive '(8 100))
                         (list closure-message '(4 5)) (list owner 3) (list producer 44))])
    (define result (m:run (car example) #:implicit? #t #:private-store? #t #:thread-ids? #t #:quantum q))
    (eq! (m:result-value result) (cadr example))
    (eq! (hash-ref (m:result-metrics result) 'blocked) 0))
   (eq! (m:result-value (m:run isolation #:implicit? #t #:thread-ids? #t #:quantum 100)) '(9 9))
   (eq! (m:result-value (m:run "let child = spawn(proc(id) send(parent(),newref(7))) in deref(receive())"
                             #:private-store? #t #:thread-ids? #t)) 7)
   (bad! (lambda () (m:run "let lock = mutex() in spawn(proc(id) lock)" #:private-store? #t))
         #rx"cannot transfer")
   (bad! (lambda () (m:run "letcc escape in spawn(proc(id) escape)" #:private-store? #t))
         #rx"cannot transfer")
   (bad! (lambda () (m:run "1" #:private-store? #t #:scope 'dynamic)) #rx"lexical scope")
   (eq! (m:result-value (m:run-private-counter 1)) 3))
  (test-case "four algorithm representations and independent mathematical oracles"
   (for ([rep '(data procedural inline register)])
    (for ([xs '(() (1) (1 2 3 4) (9 -2 6))])
     (define-values (v ends) (a:algorithm 'list-sum (list xs) #:representation rep))
     (eq! v (apply + xs)) (eq! ends 1))
    (for ([data '((remove-first (a (b a c a)) (b c a))
                 (remove-first (a ()) ())
                 (occurs-free? (x (lambda (x) (x y))) #f)
                 (occurs-free? (x (lambda (y) (y x))) #t)
                 (subst (a b ((b c) b () (d (b)))) ((a c) a () (d (a)))))])
     (match-define (list op args expected) data)
     (define-values (v ends) (a:algorithm op args #:representation rep)) (eq! v expected) (eq! ends 1)))
   (for ([n (in-range 0 12)])
    (define expected (for/product ([j (in-range 1 (add1 n))]) j))
    (eq! (a:fact/k n values) expected) (eq! (a:factorial-register n) expected)
    (eq! (a:factorial-register n #:omit-self-jumps? #t) expected))
   (eq! (a:factorial-register 4 #:broken? #t) 1)
   (define (fib n) (if (< n 2) 1 (+ (fib (sub1 n)) (fib (- n 2)))))
   (for* ([n (in-range 0 12)] [k (list values add1 (lambda (v) (* 3 v)))]) (eq! (a:fib/k n k) (k (fib n)))))
  (test-case "conversion, evaluation order, side effects and fresh binders"
   (for* ([s (list fact iter "-(7,3)" "let x = 8 in (proc(y) -(x,y) 3)" "let k = 10 in let var = 2 in -(k,var)" "letrec f(x) = if zero?(x) then 0 else (g -(x,1)) g(x) = if zero?(x) then 1 else (f -(x,1)) in (f 13)")]
          [order '(left right operands-first)] [send '(call let substitute)])
    (define-values (v unused1) (T s #:order order #:send send)) (eq! v (M s)))
   (define s "let f = proc(a,b) -(a,b) in (begin print(0); f end begin print(1); 8 end begin print(2); 3 end)")
   (for ([order '(left right operands-first)] [expected '((0 1 2) (2 1 0) (1 2 0))])
    (define-values (v metrics) (T s #:order order)) (eq! v 5) (eq! (hash-ref metrics 'output) expected))
   (define ref "let r = newref(0) in begin setref(r,9); -(deref(r),1) end")
   (define-values (v unused2) (T ref)) (eq! v 8)
   (for ([s '("let x = 0 in begin set x = 9; x end"
              "let x = 2 in let f = proc(y) begin set x = -(x,-1); -(x,y) end in -((f 1),(f 1))"
              "letrec f(n) = if zero?(n) then 7 else (f -(n,1)) in (f 5)")])
    (for ([opt? '(#f #t)]) (define-values (v unused3) (T s #:implicit? #t #:immutable? opt?))
     (eq! v (m:result-value (m:run s #:implicit? #t)))))
   (for ([s '("try -(10,raise 7) catch(e) -(e,1)"
              "try try raise 7 catch(e) raise -(e,-1) catch(x) x")])
    (define-values (v unused4) (T s #:exceptions? #t)) (eq! v (M s)))
   (define-values (v2 unused5) (T "letcc out in -(10,throw 7 to out)")) (eq! v2 7))
  (test-case "cached handlers, callcc translation, commands and ANF structure"
   (define deep
    (for/fold ([e '(raise (num 7))]) ([i (in-range 40)]) `(prim - (num 10) ,e)))
   (define source `(try ,deep (x) (var x)))
   (define search (m:run source))
   (define cached (m:run source #:handler-lookup 'cached))
   (eq! (m:result-value search) 7) (eq! (m:result-value cached) 7)
   (eq! (hash-ref (m:result-metrics cached) 'handler-hops) 1)
   (eq! (hash-ref (m:result-metrics search) 'handler-hops) 41)
   (eq! (M (m:translate-callcc "letcc out in -(1,throw 7 to out)")) 7)
   (eq! (M "(call-with-current-continuation proc(out) -(1,(out 7)))") 7)
   (eq! (M (m:translate-callcc "let call-with-current-continuation = 0 in letcc out in -(1,throw 7 to out)")) 7)
   (define notify "let buffer = 0 in let ready = mutex() in begin wait(ready); spawn(proc(d)begin set buffer = 44; signal(ready) end); wait(ready); buffer end")
   (for ([q '(1 2 5 100)]) (eq! (m:result-value (m:run notify #:implicit? #t #:quantum q)) 44))
   (for ([mode '(data procedural)])
    (eq! (st:run "var x; {x = 3; while not(zero?(x)) {print x; x = -(x,1)}}" #:commands mode) '(3 2 1))
    (bad! (lambda () (st:run "var x; print x" #:commands mode)) #rx"uninitialized"))
   (for ([source '("let f = proc(x) -(x,1) in -((f 5),(f 2))"
                   "letrec fib(n) = if less?(n,2) then 1 else +((fib -(n,1)),(fib -(n,2))) in (fib 5)"
                   "let x = 2 in if zero?(x) then 7 else -(x,1)")])
    (eq! (x:canonical-target (c:cps-program source))
         (x:canonical-target (c:cps-program (x:anf (parse source)))))))
  (test-case "implicit control binders and alpha-safe atomicization"
   (for* ([source '("letcc out in throw 7 to out"
                    "letcc out in begin set out = proc(x) -(x,1); (out 8) end"
                    "try raise 5 catch(e) e"
                    "try raise 5 catch(e) begin set e = -(e,-1); e end"
                    "let f = proc(x) raise x in try (f 9) catch(e) e"
                    "try try raise 7 catch(e) raise -(e,-1) catch(x) -(x,2)")]
          [opt? '(#f #t)] [send '(call let substitute)])
    (define-values (value metrics) (T source #:implicit? #t #:immutable? opt? #:exceptions? #t #:send send))
    (eq! value (m:result-value (m:run source #:implicit? #t))))
   (for ([n (in-range 1 13)])
    (define source (format "let atom = ~a in -(-(5,2),atom)" n))
    (define original (c:cps-program source))
    (define atomic (x:atomicize original))
    (define-values (value metrics) (t:run-target (t:parse-target (t:target-string atomic))))
    (eq! value (- 3 n))))
  (test-case "defunctionalization, atomicization, ANF and bounded generated programs"
   (for* ([n (in-range 0 30)] [a '(-2 0 5)])
    (define s (format "let f = proc(x) -(x,~a) in -((f ~a),(f -(~a,1)))" a n n))
    (define target (c:cps-program s))
    (for ([all? '(#f #t)])
     (define-values (d table) (x:defunctionalize target #:all? all?))
     (define-values (v unused6) (t:run-target (t:parse-target (t:target-string d)))) (eq! v 1)
     (define-values (rv rm) (r:run-register (r:compile-register d))) (eq! rv 1))
    (define-values (av unused7) (t:run-target (t:parse-target (t:target-string (x:atomicize target))))) (eq! av 1)
    (define an (x:anf (parse s))) (eq! (M an) 1)
    (define-values (v unused8) (T an)) (eq! v 1))
   (for ([s (list fact iter "let x = 8 in let f = proc(a) -(x,a) in (f 3)")])
    (define-values (d table) (x:defunctionalize (c:cps-program s)))
    (define-values (v unused9) (t:run-target (t:parse-target (t:target-string d)))) (eq! v (M s))))))
(module+ main
 (define failures (run-tests suites))
 (printf "~a\n" (jsexpr->string (hash 'status (if (zero? failures) "passed" "failed") 'groups 11 'assertions assertions 'failures failures)))
 (unless (zero? failures) (exit 1)))
