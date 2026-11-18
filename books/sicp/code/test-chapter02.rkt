#lang racket
;; I077 section 2.1 regression only; not the chapter completion gate yet.
(require rackunit rackunit/text-ui "chapter02.rkt")
(define suite
  (test-suite
   "SICP 2.1 data abstraction"
   (test-case "2.1 normalized rational invariants, signs and failure"
     (for* ([n (in-range -20 21)] [d (in-range -20 21)] #:unless (= d 0))
       (define r (make-rat n d))
       (check-true (> (denom r) 0))
       (check-equal? (gcd (numer r) (denom r)) 1)
       (check-equal? (/ (numer r) (denom r)) (/ n d)))
     (check-equal? (make-rat 0 -8) '(0 . 1))
     (check-exn exn:fail? (lambda () (make-rat 1 0))))
   (test-case "2.2 midpoint and source print-point output"
     (define p (midpoint-segment (make-segment (make-point -3 1) (make-point 4 6))))
     (check-equal? p '(1/2 . 7/2))
     (check-equal? (with-output-to-string (lambda () (print-point p))) "\n(1/2,7/2)"))
   (test-case "2.3 unchanged clients across rotated rectangle representations"
     (define a (make-rect-sides (make-point 0 0) 5 10))
     (define b (make-rect-edges (make-point 2 7) (make-point 3 4) (make-point -8 6)))
     (for ([r (list a b)]) (check-equal? (rect-perimeter r) 30) (check-equal? (rect-area r) 50))
     (check-exn exn:fail? (lambda () (make-rect-edges '(0 . 0) '(1 . 0) '(1 . 1))))
     (check-exn exn:fail? (lambda () (make-rect-sides '(0 . 0) 0 5))))
   (test-case "2.4 pair selectors preserve arbitrary object identity"
     (define object (box 'payload))
     (define pair (procedure-cons object '(a b)))
     (check-eq? (procedure-car pair) object)
     (check-equal? (procedure-cdr pair) '(a b)))
   (test-case "2.5 unique prime exponents including zero"
     (for* ([a (in-range 16)] [b (in-range 16)])
       (define p (integer-cons a b))
       (check-equal? (integer-car p) a) (check-equal? (integer-cdr p) b))
     (for ([bad '(0 -1 5 30 1/2)]) (check-exn exn:fail? (lambda () (integer-car bad)))))
   (test-case "2.6 Church values act on nonnumeric data"
     (check-equal? ((church-zero (lambda (x) (cons 'x x))) '()) '())
     (check-equal? (((church-add church-one church-two) (lambda (x) (cons 'x x))) '()) '(x x x))
     (check-equal? (church->integer (church-add1 church-two)) 3))
   (test-case "2.7-2.11 interval extrema, all signs and exact zero boundaries"
     (define intervals (for*/list ([a (in-range -4 5)] [b (in-range a 5)]) (make-interval a b)))
     (for* ([x intervals] [y intervals])
       (define products (for*/list ([u (list (car x) (cdr x))] [v (list (car y) (cdr y))]) (* u v)))
       (check-equal? (mul-interval x y) (cons (apply min products) (apply max products)))
       (check-equal? (width (add-interval x y)) (+ (width x) (width y)))
       (check-equal? (width (sub-interval x y)) (+ (width x) (width y))))
     (for ([y '((-1 . 1) (0 . 2) (-2 . 0) (0 . 0))])
       (check-exn exn:fail? (lambda () (div-interval '(1 . 2) y))))
     (check-equal? (div-interval '(2 . 4) '(-4 . -2)) '(-2 . -1/2))
     (check-exn exn:fail? (lambda () (make-interval 0.1 0.2))))
   (test-case "2.9 equal input widths do not determine product or quotient widths"
     (check-equal? (width '(1 . 3)) (width '(9 . 11)))
     (check-not-equal? (width (mul-interval '(1 . 3) '(1 . 3))) (width (mul-interval '(9 . 11) '(1 . 3))))
     (check-not-equal? (width (div-interval '(1 . 3) '(1 . 3))) (width (div-interval '(9 . 11) '(1 . 3)))))
   (test-case "2.12-2.13 percentage convention and product error term"
     (for ([c '(-10 10)] [p '(1 5)]) (check-equal? (percent (make-center-percent c p)) p))
     (check-exn exn:fail? (lambda () (percent '(-1 . 1))))
     (check-exn exn:fail? (lambda () (make-center-percent 10 -1)))
     (define product (mul-interval (make-center-percent 10 1) (make-center-percent 20 2)))
     (check-equal? (percent product) (/ 3 (+ 1 (* 1/100 2/100)))))
   (test-case "2.14-2.16 dependency loss and tight positive parallel range"
     (define a (make-center-percent 100 1)) (define b (make-center-percent 200 1))
     (check-equal? (div-interval a a) '(99/101 . 101/99))
     (check-equal? (div-interval a b) '(99/202 . 101/198))
     (check-equal? (par2 a b) '(66 . 202/3))
     (check-true (< (lower-bound (par1 a b)) 66))
     (check-true (> (upper-bound (par1 a b)) 202/3))
     (check-equal? (percent (par2 a b)) 1))))
(module+ main (exit (run-tests suite)))
