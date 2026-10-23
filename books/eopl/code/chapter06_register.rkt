#lang racket
;; Exercise 6.33: CPS-OUT -> labelled register instructions -> iterative execution.
(require racket/match (only-in "chapter05_syntax.rkt" primitive truth unique! arity!))
(provide (all-defined-out))
(struct register-program (entry instructions) #:transparent)
(struct code-closure (label params env) #:transparent)
(define (compile-register target)
 (define code (make-hash)) (define next 0)
 (define (label!) (set! next (add1 next)) next)
 (define (S s)
  (match s
   [`(proc ,ps ,b) `(code ,(T b) ,ps)]
   [`(prim ,op . ,ss) `(prim ,op ,@(map S ss))]
   [`(list . ,ss) `(list ,@(map S ss))] [_ s]))
 (define (T t)
  (define label (label!))
  (define instruction
   (match t
    [`(return ,s) `(return ,(S s))]
    [`(let1 ,x ,s ,b) `(bind ,x ,(S s) ,(T b))]
    [`(if ,s ,a ,b) `(branch ,(S s) ,(T a) ,(T b))]
    [`(letrec ,ns ,pss ,bs ,b) `(rec ,ns ,pss ,(map T bs) ,(T b))]
    [`(call ,f ,ss) `(call ,(S f) ,(map S ss))]
    [`(printk ,s ,b) `(print ,(S s) ,(T b))]
    [`(newrefk ,s ,k) `(newref ,(S s) ,(S k))]
    [`(derefk ,s ,k) `(deref ,(S s) ,(S k))]
    [`(setrefk ,a ,b ,next) `(setref ,(S a) ,(S b) ,(T next))]
    [`(uncaught ,s) `(uncaught ,(S s))]))
  (hash-set! code label instruction) label)
 (define entry (T target)) (register-program entry code))
(define (run-register program #:fuel [fuel 2000000] #:numeric? [numeric? #f])
 (define pc (register-program-entry program)) (define env '()) (define val #f)
 (define output '()) (define steps 0) (define refs '())
 (define (extend xs vs saved)
  (unique! xs) (arity! xs vs) (append (map (lambda (x v) (cons x (box v))) xs vs) saved))
 (set! env (extend '(i v x) '(1 5 10) '()))
 (define (V s)
  (match s
   [`(num ,n) n] [`(var ,x) (define pair (assq x env))
     (unless pair (error 'lookup "unbound: ~a" x)) (unbox (cdr pair))]
   [`(prim ,op . ,ss) (primitive op (map V ss))]
   [`(list . ,ss) (map V ss)]
   [`(code ,label ,ps) (code-closure label ps env)]))
 (define (call! p args)
  (unless (code-closure? p) (error 'call "closure required"))
  (set! env (extend (code-closure-params p) args (code-closure-env p)))
  (set! pc (code-closure-label p)))
;; BEGIN labelled-driver
 (let loop ()
  (set! steps (add1 steps)) (when (> steps fuel) (error 'register "fuel exhausted"))
  (match (hash-ref (register-program-instructions program) pc)
   [`(return ,s) (set! val (V s)) (set! pc #f)]
   [`(bind ,x ,s ,next) (set! env (extend (list x) (list (V s)) env)) (set! pc next)]
   [`(branch ,s ,yes ,no) (set! pc (if (truth (V s) numeric?) yes no))]
   [`(rec ,ns ,pss ,labels ,next)
    (define rho (extend ns (map (lambda (_) #f) ns) env))
    (for ([n ns] [ps pss] [label labels]) (set-box! (cdr (assq n rho)) (code-closure label ps rho)))
    (set! env rho) (set! pc next)]
   [`(call ,f ,ss) (call! (V f) (map V ss))]
   [`(print ,s ,next) (set! output (cons (V s) output)) (set! pc next)]
   [`(newref ,s ,k) (define r (box (V s))) (set! refs (cons r refs)) (call! (V k) (list r))]
   [`(deref ,s ,k) (define r (V s)) (unless (memq r refs) (error 'deref "reference required")) (call! (V k) (list (unbox r)))]
   [`(setref ,a ,b ,next) (define r (V a)) (unless (memq r refs) (error 'setref "reference required"))
     (set-box! r (V b)) (set! pc next)]
   [`(uncaught ,s) (error 'raise "uncaught: ~s" (V s))])
  (when pc (loop)))
;; END labelled-driver
 (values val (hash 'steps steps 'output (reverse output))))
