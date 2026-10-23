#lang racket
;; Four representations for exercise 6.4, over the original Scheme data domains.
(require racket/match)
(provide (all-defined-out))
(define (fact/k n k) (if (zero? n) (k 1) (fact/k (sub1 n) (lambda (v) (k (* n v))))))
(define (fib/k n k)
 (if (< n 2) (k 1)
  (fib/k (sub1 n) (lambda (a) (fib/k (- n 2) (lambda (b) (k (+ a b))))))))
(define (factorial-register n #:broken? [broken? #f] #:omit-self-jumps? [omit? #f])
 (define k '()) (define val #f) (define pc 'fact)
 (let loop ()
  (case pc
   [(fact) (if (zero? n) (begin (set! val 1) (set! pc 'apply))
    (begin (set! k (cons n k)) (set! n (sub1 n)) (unless omit? (set! pc 'fact))))]
   [(apply) (if (null? k) (set! pc #f)
    (begin (if broken? (set! n (car k)) (set! val (* (car k) val)))
     (set! k (cdr k)) (unless omit? (set! pc 'apply))))])
  (if pc (loop) val)))
(define (algorithm op input #:representation [representation 'register])
 (define ends 0)
 (define (end v) (set! ends (add1 ends)) v)
;; BEGIN inline-algorithms
 (define (rf s xs k)
  (cond [(null? xs) (k '())] [(eq? s (car xs)) (k (cdr xs))]
   [else (rf s (cdr xs) (lambda (v) (k (cons (car xs) v))))]))
 (define (ls xs k)
  (if (null? xs) (k 0) (ls (cdr xs) (lambda (v) (k (+ (car xs) v))))))
 (define (of s e k)
  (cond [(symbol? e) (k (eq? s e))]
   [(eq? (car e) 'lambda) (if (eq? s (caadr e)) (k #f) (of s (caddr e) k))]
   [else (of s (car e) (lambda (v) (if v (k #t) (of s (cadr e) k))))]))
 (define (su new old e k)
  (cond [(symbol? e) (k (if (eq? e old) new e))] [(null? e) (k '())]
   [else (su new old (car e) (lambda (a) (su new old (cdr e) (lambda (b) (k (cons a b))))))]))
;; END inline-algorithms
 (define (invoke op args k apply-k make-k)
  (match (cons op args)
   [`(remove-first ,s ,xs)
    (cond [(null? xs) (apply-k k '())] [(eq? s (car xs)) (apply-k k (cdr xs))]
     [else (invoke op (list s (cdr xs)) (make-k `(cons ,(car xs)) k) apply-k make-k)])]
   [`(list-sum ,xs)
    (if (null? xs) (apply-k k 0)
     (invoke op (list (cdr xs)) (make-k `(sum ,(car xs)) k) apply-k make-k))]
   [`(occurs-free? ,s ,e)
    (cond [(symbol? e) (apply-k k (eq? s e))]
     [(eq? (car e) 'lambda)
      (if (eq? s (caadr e)) (apply-k k #f) (invoke op (list s (caddr e)) k apply-k make-k))]
     [else (invoke op (list s (car e)) (make-k `(or ,s ,(cadr e)) k) apply-k make-k)])]
   [`(subst ,new ,old ,e)
    (cond [(symbol? e) (apply-k k (if (eq? old e) new e))] [(null? e) (apply-k k '())]
     [else (invoke op (list new old (car e)) (make-k `(subst ,new ,old ,(cdr e)) k) apply-k make-k)])]))
 (define (dispatch frame k v apply-k make-k)
  (match frame
   [`(cons ,a) (apply-k k (cons a v))] [`(sum ,a) (apply-k k (+ a v))]
   [`(or ,s ,e) (if v (apply-k k #t) (invoke 'occurs-free? (list s e) k apply-k make-k))]
   [`(subst ,new ,old ,rest)
    (invoke 'subst (list new old rest) (make-k `(cons ,v) k) apply-k make-k)]))
 (define (data-apply k v)
  (if (null? k) (end v) (dispatch (car k) (cdr k) v data-apply cons)))
 (define (procedure-make frame k) (lambda (v) (dispatch frame k v (lambda (k v) (k v)) procedure-make)))
 (define (register)
  (define task (cons op input)) (define k '()) (define v #f) (define pc 'visit)
  (define (return! value) (set! v value) (set! pc 'apply))
  (define (visit! task1 frame)
   (when frame (set! k (cons frame k))) (set! task task1) (set! pc 'visit))
  (let loop ()
   (case pc
    [(visit)
     (match task
      [`(remove-first ,s ,xs)
       (cond [(null? xs) (return! '())] [(eq? s (car xs)) (return! (cdr xs))]
        [else (visit! `(remove-first ,s ,(cdr xs)) `(cons ,(car xs)))])]
      [`(list-sum ,xs)
       (if (null? xs) (return! 0) (visit! `(list-sum ,(cdr xs)) `(sum ,(car xs))))]
      [`(occurs-free? ,s ,e)
       (cond [(symbol? e) (return! (eq? s e))]
        [(eq? (car e) 'lambda) (if (eq? s (caadr e)) (return! #f) (visit! `(occurs-free? ,s ,(caddr e)) #f))]
        [else (visit! `(occurs-free? ,s ,(car e)) `(or ,s ,(cadr e)))])]
      [`(subst ,new ,old ,e)
       (cond [(symbol? e) (return! (if (eq? e old) new e))] [(null? e) (return! '())]
        [else (visit! `(subst ,new ,old ,(car e)) `(subst ,new ,old ,(cdr e)))])])]
    [(apply)
     (if (null? k) (begin (set! v (end v)) (set! pc #f))
      (let ([frame (car k)])
       (set! k (cdr k))
       (match frame
        [`(cons ,a) (return! (cons a v))] [`(sum ,a) (return! (+ a v))]
        [`(or ,s ,e) (if v (return! #t) (visit! `(occurs-free? ,s ,e) #f))]
        [`(subst ,new ,old ,e) (visit! `(subst ,new ,old ,e) `(cons ,v))])))])
   (if pc (loop) v)))
 (define value
  (case representation
   [(inline) (case op
    [(remove-first) (rf (car input) (cadr input) end)] [(list-sum) (ls (car input) end)]
    [(occurs-free?) (of (car input) (cadr input) end)] [(subst) (su (car input) (cadr input) (caddr input) end)])]
   [(procedural) (invoke op input end (lambda (k v) (k v)) procedure-make)]
   [(data) (invoke op input '() data-apply cons)] [(register) (register)]
   [else (error 'algorithm "unknown representation")]))
 (values value ends))
(module+ main
 (printf "factorial-register: fixed=~a original=~a self-jumps-omitted=~a\n"
  (factorial-register 4) (factorial-register 4 #:broken? #t)
  (factorial-register 4 #:omit-self-jumps? #t)))
