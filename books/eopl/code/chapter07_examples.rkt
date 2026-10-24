#lang racket
(require "chapter07.rkt" json)
(provide (all-defined-out))
(define exercise-7-1
  (list "proc (x) -(x,3)"
        "proc (f) proc (x) -((f x),1)"
        "proc (x) x"
        "proc (x) proc (y) (x y)"
        "proc (x) (x 3)"
        "proc (x) (x x)"
        "proc (x) if x then 88 else 99"
        "proc (x) proc (y) if x then y else 99"
        "(proc (p) if p then 88 else 99 33)"
        "(proc (p) if p then 88 else 99 proc (z) z)"
        "proc (f) proc (g) proc (p) proc (x) if (p (f x)) then (g 1) else -((f x),1)"
        "proc (x) proc (p) proc (f) if (p x) then -(x,1) else (f p)"
        "proc (f) let d = proc (x) proc (z) ((f (x x)) z) in proc (n) ((f (d d)) n)"))
(define poly-id "let f = proc (x : ?) x in if (f zero?(0)) then (f 11) else (f 22)")
;; BEGIN polymorphic-map
(define polymorphic-map
  "let map = proc (f : ?)
     letrec ? foo (x : ?) =
       if null?(x) then emptylist
       else cons((f car(x)),(foo cdr(x)))
     in foo
   in letrec ? even (y : ?) =
        if zero?(y) then zero?(0)
        else if zero?(-(y,1)) then zero?(1)
        else (even -(y,2))
      in newpair(((map proc(x : int) -(x,1)) list(3,5)),
                 ((map even) list(3,5)))")
;; END polymorphic-map
;; BEGIN polymorphic-reference
(define unsafe-reference
  "let p = newref(proc (x : ?) x)
   in begin
     setref(p,proc (x : int) -(x,1));
     (deref(p) zero?(0))
   end")
;; END polymorphic-reference
(define mutual
  "letrec ? even(x : ?) = if zero?(x) then 1 else (odd -(x,1))
          ? odd(x : ?) = if zero?(x) then 0 else (even -(x,1))
   in (odd 13)")
(define higher-order-rec
  "letrec ? even(odd : ?) = proc (x : ?) if zero?(x) then 1 else (odd -(x,1))
   in letrec ? odd(x : ?) = if zero?(x) then 0 else ((even odd) -(x,1))
      in (odd 13)")
(define (example-results)
  (hash 'status "passed" 'failures 0
        'checked (format "~s" (check "proc(x : int) -(x,1)"))
        'inferred (format "~s" (infer "proc(f) proc(x) -((f 3),(f x))"))
        'mutual_type (format "~s" (infer mutual)) 'mutual_value (evaluate mutual)
        'higher_order_value (evaluate higher-order-rec)
        'polymorphic_id_type (format "~s" (infer poly-id #:polymorphism 'w))
        'polymorphic_id_value (run poly-id #:polymorphism 'w)
        'map_type (format "~s" (infer polymorphic-map #:polymorphism 'w))
        'map_value (format "~s" (datum (run polymorphic-map #:polymorphism 'w)))
        'unsafe_reference_type (format "~s" (infer unsafe-reference #:polymorphism 'w #:value-restriction? #f))
        'unsafe_reference_runtime (with-handlers ([exn:fail:object? (lambda (e) (symbol->string (exn:fail:object-kind e)))])
                                    (evaluate unsafe-reference) "unexpected_success")
        'restricted_reference (with-handlers ([exn:fail:typing? (lambda (e) (symbol->string (exn:fail:typing-kind e)))])
                                 (infer unsafe-reference #:polymorphism 'w) "unexpected_success")))
(module+ main (write-json (example-results)) (newline))
