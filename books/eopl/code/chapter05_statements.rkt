#lang racket
;; Exercise 5.16: expression continuations take one value; command continuations take none.
(require racket/match (only-in eopl cases) (prefix-in s: "chapter04_statements.rkt")
 (only-in "chapter05_syntax.rkt" primitive truth unique! arity!))
(provide (all-defined-out))
(struct closure (params body env) #:transparent)
(define (expression e)
 (cases s:sx e
  (s:sx-number (n) `(num ,n)) (s:sx-variable (x) `(var ,x))
  (s:sx-difference (a b) `(prim - ,(expression a) ,(expression b)))
  (s:sx-addition (a b) `(prim + ,(expression a) ,(expression b)))
  (s:sx-multiplication (a b) `(prim * ,(expression a) ,(expression b)))
  (s:sx-zero (a) `(prim zero? ,(expression a))) (s:sx-not (a) `(not ,(expression a)))
  (s:sx-if (t a b) `(if ,(expression t) ,(expression a) ,(expression b)))
  (s:sx-let (xs es b) `(let ,xs ,(map expression es) ,(expression b)))
  (s:sx-proc (xs b) `(proc ,xs ,(expression b)))
  (s:sx-call (f es) `(call ,(expression f) ,(map expression es)))
  (s:sx-begin (a bs) `(begin ,@(map expression (cons a bs))))
  (s:sx-set (x e) `(set ,x ,(expression e)))))
(define (command st)
 (cases s:statement st
  (s:st-assign (x e) `(assign ,x ,(expression e)))
  (s:st-print (e) `(print ,(expression e)))
  (s:st-sequence (ss) `(sequence ,@(map command ss)))
  (s:st-if (e a b) `(if ,(expression e) ,(command a) ,(command b)))
  (s:st-while (e b) `(while ,(expression e) ,(command b)))
  (s:st-vars (xs b) `(var ,xs ,(command b)))
  (else (error 'command "exercise 5.16 covers the base exercise 4.22 grammar"))))
(define (run source #:commands [mode 'data] #:fuel [fuel 200000])
 (define output '()) (define steps 0)
 (define (tick!) (set! steps (add1 steps)) (when (> steps fuel) (error 'run "fuel exhausted")))
 (define (slot env x) (define p (assq x env)) (unless p (error 'lookup "unbound")) (cdr p))
 (define (extend xs vs env) (unique! xs) (arity! xs vs) (append (map (lambda (x v) (cons x (box v))) xs vs) env))
 (define (evs es env k)
  (if (null? es) (k '()) (ev (car es) env (lambda (v) (evs (cdr es) env (lambda (vs) (k (cons v vs))))))))
 (define (ev e env k)
  (tick!)
  (match e
   [`(num ,n) (k n)] [`(var ,x) (define v (unbox (slot env x)))
     (when (eq? v 'uninitialized) (error 'read "uninitialized variable")) (k v)]
   [`(prim ,op . ,es) (evs es env (lambda (vs) (k (primitive op vs))))]
   [`(not ,e) (ev e env (lambda (v) (k (not (truth v)))))]
   [`(if ,t ,a ,b) (ev t env (lambda (v) (ev (if (truth v) a b) env k)))]
   [`(let ,xs ,es ,b) (evs es env (lambda (vs) (ev b (extend xs vs env) k)))]
   [`(proc ,xs ,b) (k (closure xs b env))]
   [`(call ,f ,es) (ev f env (lambda (p) (evs es env (lambda (vs)
    (ev (closure-body p) (extend (closure-params p) vs (closure-env p)) k)))))]
   [`(begin ,a . ,rest) (if (null? rest) (ev a env k) (ev a env (lambda (_) (ev `(begin ,@rest) env k))))]
   [`(set ,x ,rhs) (ev rhs env (lambda (v) (set-box! (slot env x) v) (k 27)))]))
;; BEGIN command-continuations
 (define (apply-command-cont cc)
  (if (procedure? cc) (cc)
   (match cc
    ['() (void)]
    [`(sequence ,ss ,saved-env ,rest) (result-of `(sequence ,@ss) saved-env rest)]
    [`(while ,test ,body ,saved-env ,rest) (result-of `(while ,test ,body) saved-env rest)])))
 (define (sequence-cont ss env cc)
  (if (eq? mode 'procedural) (lambda () (result-of `(sequence ,@ss) env cc)) `(sequence ,ss ,env ,cc)))
 (define (while-cont t b env cc)
  (if (eq? mode 'procedural) (lambda () (result-of `(while ,t ,b) env cc)) `(while ,t ,b ,env ,cc)))
 (define (result-of st env cc)
  (tick!)
  (match st
   [`(assign ,x ,rhs) (ev rhs env (lambda (v) (set-box! (slot env x) v) (apply-command-cont cc)))]
   [`(print ,e) (ev e env (lambda (v) (set! output (cons v output)) (apply-command-cont cc)))]
   [`(sequence) (apply-command-cont cc)]
   [`(sequence ,s . ,ss) (result-of s env (sequence-cont ss env cc))]
   [`(if ,t ,a ,b) (ev t env (lambda (v) (result-of (if (truth v) a b) env cc)))]
   [`(while ,t ,b) (ev t env (lambda (v)
     (if (truth v) (result-of b env (while-cont t b env cc)) (apply-command-cont cc))))]
   [`(var ,xs ,b) (result-of b (extend xs (map (lambda (_) 'uninitialized) xs) env) cc)]))
;; END command-continuations
 (define ast (cases s:st-program (s:scan&parse source) (s:st-pgm (st) (command st))))
 (result-of ast '() (if (eq? mode 'procedural) (lambda () (void)) '()))
 (reverse output))
(module+ main
 (for ([mode '(data procedural)])
  (printf "commands/~a: ~s\n" mode (run "var x; {x = 3; while not(zero?(x)) {print x; x = -(x,1)}}" #:commands mode))))
