#lang racket
(require rackunit rackunit/text-ui json)
;; Exercise 6.3: known concrete witnesses for the otherwise unknown CPS functions.
(define (q y k) (k (* y y)))
(define p (case-lambda [(x k) (k (* 2 x))] [(x y k) (k (- x y))]))
(define f (case-lambda [(a k) (k (not a))] [(x y k) (k (- x y))]))
(define (g x y k) (k (+ x y)))
(define (h v k) (k (+ v 1)))
(define x 10) (define y 2) (define u 3) (define v 4) (define a #t) (define k values)
(define suite (test-suite "exercise 6.3 Scheme expressions"
(test-case "6.3/1" (check-equal? ((lambda (x y k)
  (q y (lambda (v) (p (+ 8 x) v k)))) 2 3 values) 1))
(test-case "6.3/2" (check-equal? ((lambda (x y u v k)
  (g x y (lambda (a) (f a (+ u v) (lambda (b) (k (+ 1 b))))))) 1 2 3 4 values) -3))
(test-case "6.3/3" (check-equal? (g x y (lambda (a)
  (h v (lambda (b)
    (f a (+ u b) (lambda (r) (k (+ 1 r)))))))) 5))
(test-case "6.3/4" (check-equal? (if a
  (p x (lambda (r) (k (zero? r))))
  (p y (lambda (r) (k (zero? r))))) #f))
(test-case "6.3/5" (check-equal? (f a (lambda (b)
  (if b
    (p x (lambda (r) (k (zero? r))))
    (p y (lambda (r) (k (zero? r))))))) #f))
(test-case "6.3/6" (check-equal? (let ((y 8)) (p y (lambda (x) (k x)))) 16))
(test-case "6.3/7" (check-equal? (if a (p x (lambda (x) (k x)))
      (p y (lambda (x) (k x)))) 20))
))
(module+ main
 (define failures (run-tests suite))
 (displayln (jsexpr->string (hash 'status (if (zero? failures) "passed" "failed") 'assertions 7 'failures failures)))
 (unless (zero? failures) (exit 1)))
