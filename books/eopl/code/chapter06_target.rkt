#lang racket
;; Independent CPS-OUT grammar and evaluator; no source-language eval.
(require (except-in eopl define) (only-in eopl [define eopl:define]) racket/match (only-in "chapter05_syntax.rkt" primitive truth unique! arity!))
(require "sllgen_guard.rkt")
(provide (all-defined-out))
(eopl:define lexical
 '((white-space (whitespace) skip)
   (identifier (letter (arbno (or letter digit "_" "-" "?" "%"))) symbol)
   (number (digit (arbno digit)) number) (number ("-" digit (arbno digit)) number)))
(eopl:define grammar
 '((program (tf) cps-program)
   (simple (number) n-exp) (simple (identifier) v-exp)
   (simple ("-" "(" simple "," simple ")") d-exp)
   (simple ("*" "(" simple "," simple ")") m-exp)
   (simple ("/" "(" simple "," simple ")") div-exp)
   (simple ("+" "(" (separated-list simple ",") ")") sum-exp)
   (simple ("zero?" "(" simple ")") z-exp)
   (simple ("null?" "(" simple ")") null-exp)
   (simple ("number?" "(" simple ")") num-exp)
   (simple ("car" "(" simple ")") car-exp) (simple ("cdr" "(" simple ")") cdr-exp)
   (simple ("add1" "(" simple ")") add1-exp) (simple ("sub1" "(" simple ")") sub1-exp)
   (simple ("cons" "(" simple "," simple ")") cons-exp)
   (simple ("equal?" "(" simple "," simple ")") equal-exp)
   (simple ("less?" "(" simple "," simple ")") less-exp)
   (simple ("greater?" "(" simple "," simple ")") greater-exp)
   (simple ("list" "(" (separated-list simple ",") ")") list-exp)
   (simple ("proc" "(" (separated-list identifier ",") ")" tf) p-exp)
   (tf (simple) ret-exp)
   (tf ("let" identifier "=" simple "in" tf) let-exp)
   (tf ("letrec" (arbno identifier "(" (separated-list identifier ",") ")" "=" tf) "in" tf) rec-exp)
   (tf ("if" simple "then" tf "else" tf) if-exp)
   (tf ("(" simple (arbno simple) ")") call-exp)
   (tf ("printk" "(" simple ")" ";" tf) print-exp)
   (tf ("newrefk" "(" simple "," simple ")") new-exp)
   (tf ("derefk" "(" simple "," simple ")") deref-exp)
   (tf ("setrefk" "(" simple "," simple ")" ";" tf) setref-exp)
   (tf ("uncaught" "(" simple ")") uncaught-exp)))
(sllgen:make-define-datatypes lexical grammar)
(define scan&parse (guard-sllgen (sllgen:make-string-parser lexical grammar) lexical grammar))
(define (parse-target text)
 (cases program (scan&parse text) (cps-program (t) (tf->ast t))))
(define (s->ast s)
 (cases simple s
  (n-exp (n) `(num ,n)) (v-exp (v) `(var ,v))
  (d-exp (a b) `(prim - ,(s->ast a) ,(s->ast b)))
  (m-exp (a b) `(prim * ,(s->ast a) ,(s->ast b)))
  (div-exp (a b) `(prim / ,(s->ast a) ,(s->ast b)))
  (sum-exp (ss) `(prim + ,@(map s->ast ss)))
  (z-exp (a) `(prim zero? ,(s->ast a))) (null-exp (a) `(prim null? ,(s->ast a)))
  (num-exp (a) `(prim number? ,(s->ast a))) (car-exp (a) `(prim car ,(s->ast a)))
  (cdr-exp (a) `(prim cdr ,(s->ast a))) (add1-exp (a) `(prim add1 ,(s->ast a)))
  (sub1-exp (a) `(prim sub1 ,(s->ast a)))
  (cons-exp (a b) `(prim cons ,(s->ast a) ,(s->ast b)))
  (equal-exp (a b) `(prim equal? ,(s->ast a) ,(s->ast b)))
  (less-exp (a b) `(prim less? ,(s->ast a) ,(s->ast b)))
  (greater-exp (a b) `(prim greater? ,(s->ast a) ,(s->ast b)))
  (list-exp (ss) `(list ,@(map s->ast ss)))
  (p-exp (xs b) `(proc ,xs ,(tf->ast b)))))
(define (tf->ast t)
 (cases tf t
  (ret-exp (s) `(return ,(s->ast s)))
  (let-exp (x s b) `(let1 ,x ,(s->ast s) ,(tf->ast b)))
  (rec-exp (ns pss bs b) `(letrec ,ns ,pss ,(map tf->ast bs) ,(tf->ast b)))
  (if-exp (s a b) `(if ,(s->ast s) ,(tf->ast a) ,(tf->ast b)))
  (call-exp (f ss) `(call ,(s->ast f) ,(map s->ast ss)))
  (print-exp (s b) `(printk ,(s->ast s) ,(tf->ast b)))
  (new-exp (s k) `(newrefk ,(s->ast s) ,(s->ast k)))
  (deref-exp (s k) `(derefk ,(s->ast s) ,(s->ast k)))
  (setref-exp (a b t) `(setrefk ,(s->ast a) ,(s->ast b) ,(tf->ast t)))
  (uncaught-exp (s) `(uncaught ,(s->ast s)))))
(define (simple-string s)
 (match s
  [`(num ,n) (number->string n)] [`(var ,x) (symbol->string x)]
  [`(prim ,op . ,es) (format "~a(~a)" op (string-join (map simple-string es) ","))]
  [`(list . ,ss) (format "list(~a)" (string-join (map simple-string ss) ","))]
  [`(proc ,xs ,b) (format "proc (~a) ~a" (string-join (map symbol->string xs) ",") (target-string b))]
  [_ (error 'simple-string "not a simple expression: ~s" s)]))
(define (target-string t)
 (match t
  [`(return ,s) (simple-string s)]
  [`(let1 ,x ,s ,b) (format "let ~a = ~a in ~a" x (simple-string s) (target-string b))]
  [`(letrec ,ns ,pss ,bs ,b)
   (format "letrec ~a in ~a"
    (string-join (map (lambda (n ps body) (format "~a(~a) = ~a" n (string-join (map symbol->string ps) ",") (target-string body))) ns pss bs) " ") (target-string b))]
  [`(if ,s ,a ,b) (format "if ~a then ~a else ~a" (simple-string s) (target-string a) (target-string b))]
  [`(call ,f ,ss) (format "(~a~a)" (simple-string f) (if (null? ss) "" (string-append " " (string-join (map simple-string ss) " "))))]
  [`(printk ,s ,b) (format "printk(~a); ~a" (simple-string s) (target-string b))]
  [`(newrefk ,s ,k) (format "newrefk(~a,~a)" (simple-string s) (simple-string k))]
  [`(derefk ,s ,k) (format "derefk(~a,~a)" (simple-string s) (simple-string k))]
  [`(setrefk ,a ,b ,t) (format "setrefk(~a,~a); ~a" (simple-string a) (simple-string b) (target-string t))]
  [`(uncaught ,s) (format "uncaught(~a)" (simple-string s))]
  [_ (error 'target-string "invalid target: ~s" t)]))
(struct target-closure (params body env) #:transparent)
(struct target-ref (cell) #:transparent)
(define (extend xs vs env)
 (unique! xs) (arity! xs vs) (append (map (lambda (x v) (cons x (box v))) xs vs) env))
(define (lookup env x)
 (define p (assq x env)) (unless p (error 'lookup "unbound: ~a" x)) (unbox (cdr p)))
;; BEGIN target-simple
(define (value-of-simple s env)
 (match s
  [`(num ,n) n] [`(var ,x) (lookup env x)]
  [`(prim ,op . ,ss) (primitive op (map (lambda (a) (value-of-simple a env)) ss))]
  [`(list . ,ss) (map (lambda (a) (value-of-simple a env)) ss)]
  [`(proc ,xs ,b) (target-closure xs b env)]
  [_ (error 'simple "not simple")]))
;; END target-simple
;; All inter-procedure transfers return state data. No source tail call uses a host return stack.
(struct target-state (exp env) #:transparent)
(struct done (value) #:transparent)
(define (run-target program #:numeric? [numeric? #f] #:fuel [fuel 2000000])
 (define output '()) (define steps 0) (define refs '())
 (define (invoke p vs)
  (unless (target-closure? p) (error 'call "procedure required"))
  (target-state (target-closure-body p) (extend (target-closure-params p) vs (target-closure-env p))))
 (define (step s)
  (set! steps (add1 steps)) (when (> steps fuel) (error 'target "fuel exhausted"))
  (match-define (target-state t env) s)
  (define (V a) (value-of-simple a env))
  (match t
   [`(return ,a) (done (V a))]
   [`(let1 ,x ,a ,b) (target-state b (extend (list x) (list (V a)) env))]
   [`(letrec ,ns ,pss ,bs ,b)
    (define rho (extend ns (map (lambda (_) #f) ns) env))
    (for ([n ns] [ps pss] [body bs]) (set-box! (cdr (assq n rho)) (target-closure ps body rho)))
    (target-state b rho)]
   [`(if ,a ,b ,c) (target-state (if (truth (V a) numeric?) b c) env)]
   [`(call ,f ,ss) (invoke (V f) (map V ss))]
   [`(printk ,a ,b) (set! output (cons (V a) output)) (target-state b env)]
   [`(newrefk ,a ,k) (define r (target-ref (box (V a)))) (set! refs (cons r refs)) (invoke (V k) (list r))]
   [`(derefk ,a ,k)
    (define r (V a)) (unless (memq r refs) (error 'deref "reference required"))
    (invoke (V k) (list (unbox (target-ref-cell r))))]
   [`(setrefk ,a ,b ,next)
    (define r (V a)) (unless (memq r refs) (error 'setref "reference required"))
    (set-box! (target-ref-cell r) (V b)) (target-state next env)]
   [`(uncaught ,v) (error 'raise "uncaught: ~s" (V v))]
   [_ (error 'target "not a TfExp ~s" t)]))
;; BEGIN target-driver
 (define initial (target-state (if (string? program) (parse-target program) program)
  (extend '(i v x) '(1 5 10) '())))
 (let trampoline ([pc initial])
  (if (done? pc)
   (values (done-value pc) (hash 'output (reverse output) 'steps steps 'locations (length refs)))
   (trampoline (step pc)))))
;; END target-driver
;; Readable output for the eight complete exercise 6.13 translations.
(define (target-pretty target)
 (define (pad n) (make-string n #\space))
 (define (S s n)
  (match s
   [`(proc ,ps ,body) (format "proc (~a)\n~a" (string-join (map symbol->string ps) ",") (T body (+ n 2)))]
   [`(prim ,op . ,ss) (format "~a(~a)" op (string-join (map (lambda (s) (S s n)) ss) ","))]
   [`(list . ,ss) (format "list(~a)" (string-join (map (lambda (s) (S s n)) ss) ","))]
   [_ (simple-string s)]))
 (define (T t n)
  (define prefix (pad n))
  (string-append prefix
   (match t
    [`(return ,s) (S s n)]
    [`(let1 ,x ,s ,b) (format "let ~a = ~a\n~ain\n~a" x (S s (+ n 2)) prefix (T b (+ n 2)))]
    [`(letrec ,ns ,pss ,bs ,b)
     (format "letrec\n~a\n~ain\n~a"
      (string-join (map (lambda (name ps body) (format "~a~a(~a) =\n~a" (pad (+ n 2)) name (string-join (map symbol->string ps) ",") (T body (+ n 4)))) ns pss bs) "\n")
      prefix (T b (+ n 2)))]
    [`(if ,s ,a ,b) (format "if ~a\n~athen\n~a\n~aelse\n~a" (S s n) prefix (T a (+ n 2)) prefix (T b (+ n 2)))]
    [`(call ,f ,ss) (format "(~a~a)" (S f n) (if (null? ss) "" (string-append "\n" (string-join (map (lambda (s) (string-append (pad (+ n 2)) (S s (+ n 2)))) ss) "\n"))))]
    [`(printk ,s ,b) (format "printk(~a);\n~a" (S s n) (T b n))]
    [`(newrefk ,s ,k) (format "newrefk(~a,~a)" (S s n) (S k n))]
    [`(derefk ,s ,k) (format "derefk(~a,~a)" (S s n) (S k n))]
    [`(setrefk ,a ,b ,next) (format "setrefk(~a,~a);\n~a" (S a n) (S b n) (T next n))]
    [`(uncaught ,s) (format "uncaught(~a)" (S s n))])))
 (T target 0))
