#lang racket
(require rackunit rackunit/text-ui racket/runtime-path json)
(define-runtime-path code "../code")
(define (entry file name) (dynamic-require (build-path code file) name))
(define assertions 0)
(define (eq! a b) (set! assertions (add1 assertions)) (check-equal? a b))
(define (bad! f [rx #rx"."]) (set! assertions (add1 assertions)) (check-exn rx f))
(define suites
  (test-suite "EOPL review regressions"
    (test-case "every SLLGEN front end consumes the entire string"
      (for ([row '(("chapter03.rkt" scan&parse "1")
                   ("chapter03_variants.rkt" bool-parse "1")
                   ("chapter03_variants.rkt" named-parse "1")
                   ("chapter04.rkt" scan&parse "1")
                   ("chapter04_statements.rkt" scan&parse "print 1")
                   ("chapter05_syntax.rkt" parse "1")
                   ("chapter06_target.rkt" parse-target "1")
                   ("appendix_b.rkt" parse-statement "x := y")
                   ("appendix_b.rkt" parse-base "1"))])
        (define parse (entry (car row) (cadr row)))
        (define valid (caddr row))
        (check-not-exn (lambda () (parse valid)))
        (for ([suffix '("@2" " # junk" "_" " ?" " \\" " λ@" "\u0000")])
          (bad! (lambda () (parse (string-append valid suffix)))))))
    (test-case "comments, identifier boundaries and target-generated names"
      (define parse (entry "chapter05_syntax.rkt" 'parse))
      (eq! (parse "1 % @ # _ ? hidden until EOF") '(num 1))
      (eq! (parse "% @ hidden\nlet café = -2 in café")
           '(let (café) ((num -2)) (var café)))
      (bad! (lambda () (parse "1 % hidden\n@")) #rx"scanner")
      (eq! ((entry "chapter06_target.rkt" 'parse-target) "let k%1 = 3 in k%1")
           '(let1 k%1 (num 3) (return (var k%1))))
      (bad! (lambda () ((entry "chapter06_target.rkt" 'parse-target) "1 %not-comment"))
            #rx"scanner")
      (bad! (lambda () ((entry "chapter03.rkt" 'scan&parse) "1 =="))))
    (test-case "fuel is a positive exact integer"
      (define run (entry "chapter04.rkt" 'run/details))
      (for ([n (list 0 -1 1/2 1.0 #f +inf.0 +nan.0)])
        (bad! (lambda () (run "1" #:fuel n)) #rx"fuel"))
      (eq! ((entry "chapter04.rkt" 'datum)
            ((entry "chapter04.rkt" 'execution-value) (run "1" #:fuel 1))) 1)
      (bad! (lambda () (run "letrec loop(x)=(loop x) in (loop 0)" #:fuel 20))
            #rx"fuel exhausted"))
    (test-case "user k, h and join never acquire compiler continuation roles"
      (define cps (entry "chapter06.rkt" 'cps-program))
      (define transform (entry "chapter06_transforms.rkt" 'defunctionalize))
      (define target-run (entry "chapter06_target.rkt" 'run-target))
      (define serialize (entry "chapter06_target.rkt" 'target-string))
      (define parse-target (entry "chapter06_target.rkt" 'parse-target))
      (define compile (entry "chapter06_register.rkt" 'compile-register))
      (define register-run (entry "chapter06_register.rkt" 'run-register))
      (for* ([name '(k h join)] [send '(call let substitute)] [all? '(#f #t)])
        (define cases
          (list
            (cons (format "let ~a = proc(x) x in (~a 3)" name name) 3)
            (cons (format "letrec ~a(x) = if zero?(x) then 0 else -((~a -(x,1)),-1) in (~a 4)" name name name) 4)
            (cons (format "let apply = proc(~a) (~a 7) in (apply proc(x) -(x,2))" name name) 5)
            (cons (format "let ~a = (proc(x) x 7) in -(~a,2)" name name) 5)
            (cons (format "let ~a = 8 in let f = proc(x) -(~a,x) in (f 3)" name name) 5)))
        (for ([row cases])
          (define-values (data table) (transform (cps (car row) #:send send) #:all? all?))
          (define reparsed (parse-target (serialize data)))
          (define-values (actual metrics) (target-run reparsed))
          (eq! actual (cdr row))
          (define-values (register-value register-metrics) (register-run (compile reparsed)))
          (eq! register-value (cdr row)))))
    (test-case "THREADS parses and runs a counting semaphore"
      (define run (entry "chapter05.rkt" 'run))
      (eq! ((entry "chapter05.rkt" 'result-value)
            (run "let s = semaphore(1) in begin down(s); up(s); 42 end")) 42))))
(define run (entry "chapter05.rkt" 'run))
(define value (entry "chapter05.rkt" 'result-value))
(define output (entry "chapter05.rkt" 'result-output))
(define metrics (entry "chapter05.rkt" 'result-metrics))
(define threads (entry "chapter05.rkt" 'result-threads))
(define (M source #:q [q 1000000])
  (run source #:implicit? #t #:thread-ids? #t #:quantum q))
(define synchronization
 (test-suite "THREADS synchronization"
  (test-case "all mechanisms under 30 time slices"
   (for ([q (in-range 1 31)])
    (define sem (M (entry "chapter05.rkt" 'semaphore-program) #:q q))
    (eq! (value sem) '(2 0))
    (eq! (hash-ref (metrics sem) 'blocked) 0)
    (eq! (remove-duplicates (hash-values (threads sem))) '(done))
    (define c (M (entry "chapter05.rkt" 'condition-program) #:q q))
    (eq! (value c) 45) ; false signal must recheck; real signal must reacquire
    (eq! (hash-ref (metrics c) 'blocked) 0)
    (define b (M (entry "chapter05.rkt" 'barrier-program) #:q q))
    (eq! (value b) '(1 2))
    (eq! (sort (output b) < #:key (lambda (x) (+ (* 10 (car x)) (cadr x))))
         '((1 1) (1 2) (2 1) (2 2)))
    (eq! (hash-ref (metrics b) 'blocked) 0)))
  (test-case "FIFO handoff never creates a spare permit"
   (define r (M "let s = semaphore(0) in begin
     spawn(proc(id) begin down(s); print(id) end);
     spawn(proc(id) begin down(s); print(id) end);
     yield(); up(s);
     spawn(proc(id) begin down(s); print(id) end);
     yield(); up(s); yield(); 99 end"))
   (eq! (output r) '(1 2))
   (eq! (hash-ref (threads r) 3) 'semaphore)
   (eq! (hash-ref (metrics r) 'blocked) 1))
  (test-case "kill removes all waiting queues"
   (for ([setup '("semaphore(0)" "barrier(2)" "condition(m)")]
         [wait '("down(s)" "barrier-wait(s)" "begin wait(m); condition-wait(s); signal(m) end")]
         [wake '("up(s)" "begin spawn(proc(id) barrier-wait(s)); barrier-wait(s) end" "condition-signal(s)")])
    (define r (M (format "let m = mutex() in let s = ~a in
      let child = spawn(proc(id) begin ~a; print(999) end) in begin
        yield(); print(kill(child)); ~a; yield(); 42 end" setup wait wake)))
    (eq! (value r) 42) (eq! (output r) '(#t))
    (eq! (hash-ref (threads r) 1) 'killed)
    (eq! (hash-ref (metrics r) 'blocked) 0))
   (define r (M "let m = mutex() in let c = condition(m) in
     let child = spawn(proc(id) begin wait(m); condition-wait(c); print(999) end)
     in begin yield(); wait(m); condition-signal(c); yield();
       print(kill(child)); signal(m); yield(); 42 end"))
   (eq! (output r) '(#t)) (eq! (hash-ref (threads r) 1) 'killed))
  (test-case "blocking, generation and input boundaries"
   (for ([source '("down(semaphore(0))" "barrier-wait(barrier(2))"
                   "let m = mutex() in let c = condition(m) in begin wait(m); condition-wait(c) end"
                   "let m = mutex() in let c = condition(m) in begin condition-signal(c); wait(m); condition-wait(c) end"
                   "let b = barrier(2) in let child = spawn(proc(id) barrier-wait(b)) in begin yield(); kill(child); barrier-wait(b) end")])
    (bad! (lambda () (M source)) #rx"deadlock"))
   (eq! (value (M "let b = barrier(1) in list(barrier-wait(b),barrier-wait(b))")) '(1 2))
   (for ([source '("semaphore(-1)" "semaphore(zero?(0))" "barrier(0)" "barrier(-1)"
                   "barrier(zero?(0))" "down(mutex())" "up(1)" "condition(1)"
                   "condition-wait(1)" "condition-signal(1)" "barrier-wait(1)"
                   "condition-wait(condition(mutex()))")])
    (bad! (lambda () (M source))))
   (for ([n (list 0 -1 1/2 1.0 #f +inf.0 +nan.0)])
    (bad! (lambda () (run "1" #:fuel n)) #rx"fuel"))
   (for ([object '("semaphore(1)" "condition(mutex())" "barrier(2)")])
    (bad! (lambda () (run (format "let s = ~a in spawn(proc(id) s)" object)
                         #:private-store? #t)) #rx"cannot transfer")))))
(define failures (+ (run-tests suites) (run-tests synchronization)))

(displayln (jsexpr->string (hash 'status (if (zero? failures) "passed" "failed")
                               'assertions assertions 'failures failures)))
(exit (if (zero? failures) 0 1))
