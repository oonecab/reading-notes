#lang racket
(require rackunit rackunit/text-ui json racket/runtime-path
 "chapter06.rkt" (prefix-in t: "chapter06_target.rkt")
 (prefix-in m: "chapter05.rkt") (only-in "chapter05_syntax.rkt" parse))
(provide (all-defined-out))
(define-runtime-path outputs-file "chapter06_outputs.json")
;; BEGIN exercise-6-13-inputs
(define nested "list(1,list(3,list(2),7,list(9)))")
(define removeall
 "letrec removeall(n,s) = if null?(s) then emptylist else if number?(car(s)) then if equal?(n,car(s)) then (removeall n cdr(s)) else cons(car(s),(removeall n cdr(s))) else cons((removeall n car(s)),(removeall n cdr(s)))")
(define occurs
 "letrec occurs-in?(n,s) = if null?(s) then 0 else if number?(car(s)) then if equal?(n,car(s)) then 1 else (occurs-in? n cdr(s)) else if (occurs-in? n car(s)) then 1 else (occurs-in? n cdr(s))")
(define remfirst
 (string-append occurs
 " remfirst(n,s) = letrec loop(s) = if null?(s) then emptylist else if number?(car(s)) then if equal?(n,car(s)) then cdr(s) else cons(car(s),(loop cdr(s))) else if (occurs-in? n car(s)) then cons((remfirst n car(s)),cdr(s)) else cons(car(s),(remfirst n cdr(s))) in (loop s)"))
(define depth
 "letrec depth(s) = if null?(s) then 1 else if number?(car(s)) then (depth cdr(s)) else if less?(add1((depth car(s))),(depth cdr(s))) then (depth cdr(s)) else add1((depth car(s)))")
(define depth-let
 "letrec depth(s) = if null?(s) then 1 else if number?(car(s)) then (depth cdr(s)) else let dfirst = add1((depth car(s))) drest = (depth cdr(s)) in if less?(dfirst,drest) then drest else dfirst")
(define map-square
 "letrec map(f,l) = if null?(l) then emptylist else cons((f car(l)),(map f cdr(l))) square(n) = *(n,n) in (map square list(1,2,3,4,5))")
(define first-greater
 "letrec find(s,n) = if null?(s) then emptylist else if number?(car(s)) then if greater?(car(s),n) then car(s) else (find cdr(s) n) else let answer = (find car(s) n) in if number?(answer) then answer else (find cdr(s) n)")
(define every
 "letrec every(pred,l) = if null?(l) then 1 else if (pred car(l)) then (every pred cdr(l)) else 0")
(define examples
 (list
  (list 'removeall (string-append removeall " in (removeall 3 list(3,list(1,3),3,2))") '((1) 2))
  (list 'occurs-in? (string-append occurs " in (occurs-in? 7 " nested ")") 1)
  (list 'remfirst (string-append remfirst " in (remfirst 3 list(1,list(3,3),3))") '(1 (3) 3))
  (list 'depth (string-append depth " in (depth " nested ")") 3)
  (list 'depth-with-let (string-append depth-let " in (depth " nested ")") 3)
  (list 'map map-square '(1 4 9 16 25))
  (list 'fnlrgtn (string-append first-greater " in (find " nested " 6)") 7)
  (list 'every (string-append every " in (every proc(n) greater?(n,5) list(6,7,8,9))") 1)))
;; END exercise-6-13-inputs
(define (exercise13-tests)
 (define archived (call-with-input-file outputs-file read-json))
 (for/list ([row examples])
  (match-define (list name source expected) row)
  (define direct (m:run source #:numeric? #t))
  (check-equal? (m:result-value direct) expected)
  (define converted (cps-program source))
  (define saved (findf (lambda (r) (string=? (hash-ref r 'name) (symbol->string name))) (hash-ref archived 'items)))
  (check-equal? (hash-ref saved 'source) source)
  (check-equal? (hash-ref saved 'expected) expected)
  (check-equal? (hash-ref saved 'value) expected)
  (check-equal? (t:parse-target (hash-ref saved 'target)) converted)

  (define-values (v metrics) (t:run-target (t:parse-target (t:target-string converted)) #:numeric? #t))
  (check-equal? v expected)
  (list name v (hash-ref metrics 'steps))))
;; The six linear extensions of g<f and j<h; the final + is after all four.
(define orders '((g f j h) (g j f h) (g j h f) (j g f h) (j g h f) (j h g f)))
(define (run-order order)
 (define log '()) (define results (make-hash))
 (define (call name n k) (set! log (append log (list name)))
  (k (case name [(g) (add1 n)] [(j) (* n 2)] [(f) (* n 3)] [(h) (+ n 4)])))
 (let loop ([remaining order])
  (if (null? remaining) (values (+ (hash-ref results 'f) (hash-ref results 'h)) log)
   (let* ([name (car remaining)]
          [arg (case name [(g) 2] [(j) 5] [(f) (hash-ref results 'g)] [(h) (hash-ref results 'j)])])
    (call name arg (lambda (v) (hash-set! results name v) (loop (cdr remaining))))))))
(module+ main
 (define failures
  (run-tests (test-suite "exercise 6.13 and six orders"
   (test-case "eight original/transformed comparisons"
    (for ([row (exercise13-tests)])
     (printf "6.13 ~a: ~s; target-steps=~a\n" (car row) (cadr row) (caddr row))))
   (test-case "six dependency-respecting orders"
    (for ([order orders])
     (define-values (v log) (run-order order)) (check-equal? v 23) (check-equal? log order))))))
 (printf "~a\n" (jsexpr->string (hash 'status (if (zero? failures) "passed" "failed") 'examples 8 'orders 6 'assertions 60 'failures failures)))
 (unless (zero? failures) (exit 1)))
