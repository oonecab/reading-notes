#lang racket
;; Independent procedural-continuation interpreter, including two observers.
(require racket/match "chapter05_syntax.rkt")
(provide (all-defined-out))
(struct closure (params body env) #:transparent)
(struct continuation-pair (normal exceptional) #:transparent)
(struct captured (k h) #:transparent)
(define (lookup env x)
 (define p (assq x env))
 (unless p (error 'lookup "unbound variable: ~a" x)) (unbox (cdr p)))
(define (extend xs vs env)
 (unique! xs) (arity! xs vs) (append (map (lambda (x v) (cons x (box v))) xs vs) env))
(define (run-cps source #:representation [representation 'inline] #:numeric? [numeric? #f])
 (define ends 0) (define output '())
 (define (normal k v) (if (continuation-pair? k) ((continuation-pair-normal k) v) (k v)))
 (define (mk k h) (if (eq? representation 'pair) (continuation-pair k h) k))
 (define (evs es env k h)
  (if (null? es) (normal k '())
   (ev (car es) env
    (mk (lambda (v)
     (evs (cdr es) env
      (mk (lambda (vs) (normal k (cons v vs))) h) h)) h)
    h)))
 (define (invoke p vs k h)
  (cond [(captured? p) (arity! '(value) vs) (normal (captured-k p) (car vs))]
   [(closure? p)
    (if (= (length (closure-params p)) (length vs))
     (ev (closure-body p) (extend (closure-params p) vs (closure-env p)) k h)
     (h 1001))]
   [else (error 'call "procedure required")]))
;; BEGIN procedural-evaluator
 (define (ev e env k h)
  (match e
   [`(num ,n) (normal k n)] [`(var ,x) (normal k (lookup env x))]
   [`(proc ,xs ,b) (unique! xs) (normal k (closure xs b env))]
   [`(prim ,op . ,es)
    (evs es env (mk (lambda (vs)
     (if (and (eq? op '/) (zero? (cadr vs))) (h 1002)
         (normal k (primitive op vs)))) h) h)]
   [`(list . ,es) (evs es env k h)]
   [`(if ,t ,a ,b) (ev t env (mk (lambda (v) (ev (if (truth v numeric?) a b) env k h)) h) h)]
   [`(let ,xs ,es ,b)
    (evs es env (mk (lambda (vs) (ev b (extend xs vs env) k h)) h) h)]
   [`(letrec ,ns ,pss ,bs ,b)
    (define rho (extend ns (map (lambda (_) #f) ns) env))
    (for ([n ns] [ps pss] [body bs])
     (set-box! (cdr (assq n rho)) (closure ps body rho)))
    (ev b rho k h)]
   [`(call ,f ,es)
    (ev f env (mk (lambda (p) (evs es env (mk (lambda (vs) (invoke p vs k h)) h) h)) h) h)]
   [`(begin ,e1 . ,rest)
    (if (null? rest) (ev e1 env k h)
     (ev e1 env (mk (lambda (_) (ev `(begin ,@rest) env k h)) h) h))]
   [`(print ,arg)
    (ev arg env (mk (lambda (v) (set! output (cons v output)) (normal k 38)) h) h)]
   [`(try ,body (,x) ,handler)
    (ev body env k (lambda (v) (ev handler (extend (list x) (list v) env) k h)))]
   [`(raise ,arg) (ev arg env (mk (lambda (v) (h v)) h) h)]
   [`(letcc ,x ,body) (ev body (extend (list x) (list (captured k h)) env) k h)]
   [`(throw ,arg ,target)
    (ev arg env (mk (lambda (v) (ev target env (mk (lambda (c) (invoke c (list v) k h)) h) h)) h) h)]
   [_ (error 'run-cps "unsupported procedural-core form: ~s" e)]))
;; END procedural-evaluator
 (define result
  (ev (if (string? source) (parse source) source) (extend '(i v x) '(1 5 10) '())
   (mk (lambda (v) (set! ends (add1 ends)) v) (lambda (v) (error 'raise "uncaught: ~s" v)))
   (lambda (v) (error 'raise "uncaught: ~s" v))))
 (values result (hash 'end-count ends 'output (reverse output))))
(module+ main
 (define-values (v m) (run-cps "-(-(44,11),3)" #:representation 'pair))
 (printf "procedural-pair: ~s; end-count=~a\n" v (hash-ref m 'end-count)))
