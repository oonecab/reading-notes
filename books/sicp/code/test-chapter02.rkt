#lang racket
;; Executable regression for chapter 2 data abstractions.
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


(define extended-suite
  (test-suite "SICP 2.2-2.5"
    (test-case "tree structure and right-fold order"
      (check-equal? (tree-map-leaves sqr '(1 (2 . 3) ())) '(1 (4 . 9) ()))
      (check-equal? (fringe '(1 (2 . 3) ())) '(1 2 3))
      (check-equal? (fold-sequence / 1 '(1 2 3)) 3/2))
    (test-case "symbolic differentiation and ordered union"
      (check-equal? (deriv '(* x (+ x 3)) 'x) '(+ x (+ x 3)))
      (check-exn exn:fail? (lambda () (deriv '(unknown x) 'x)))
      (check-equal? (ordered-union '(1 3 7) '(3 4 8)) '(1 3 4 7 8)))
    (test-case "prefix code, invalid and truncated inputs"
      (define t (huffman '((a 4) (b 2) (c 1) (d 1))))
      (check-equal? (huffman-encode '(a d a b) t) '(0 1 1 1 0 1 0))
      (check-equal? (huffman-decode '(0 1 1 0 1 0) t) '(a c b))
      (check-exn exn:fail? (lambda () (huffman-decode '(1) t)))
      (check-exn exn:fail? (lambda () (huffman-decode '(2) t)))
      (check-exn exn:fail? (lambda () (huffman '((a 1) (a 2))))))
    (test-case "message selection and mixed type dispatch"
      (define-values (put apply-op) (make-operation-table))
      (install-arithmetic! put)
      (check-equal? (apply-op 'mul '(scalar . 3) '(polynomial 1 2)) '(polynomial 3 6))
      (check-equal? (apply-op 'add '(polynomial 1 2) '(scalar . 2)) '(polynomial 3 2))
      (check-exn exn:fail? (lambda () (apply-op 'unknown '(scalar . 2))))
      (check-equal? ((make-polar-message 5 0) 'real-part) 5)
      (check-exn exn:fail? (lambda () ((make-polar-message 5 0) 'missing))))
    (test-case "polynomial long division and rational function cancellation"
      (define-values (q r) (poly-divmod '(-1 0 0 1) '(-1 0 1)))
      (check-equal? q '(0 1)) (check-equal? r '(-1 1))
      (check-equal? (make-rational-function '(-1 0 1) '(-1 1)) '((1 1) 1))
      (check-equal? (make-rational-function '() '(3 4)) '(() 1))
      (check-exn exn:fail? (lambda () (poly-divmod '(1) '(0 0))))
      (check-exn exn:fail? (lambda () (make-rational-function '(1) '()))))))

(define integration-suite
  (test-suite "exercise integration"
    (test-case "2.82-2.85 multi-argument dispatch and reversible projection"
      (define methods (hash '(add rational rational rational)
                            (lambda (a b c) (cons 'rational (+ a b c)))))
      (check-equal? (tower-apply methods 'add '(integer . 2) '(rational . 1/3) '(rational . 2/3))
                    '(integer . 3))
      (check-equal? (tower-drop '(complex 2 . 3)) '(complex 2 . 3))
      (check-equal? (tower-drop '(complex 3/2 . 0)) '(rational . 3/2))
      (check-exn exn:fail? (lambda () (tower-apply methods 'absent '(integer . 1)))))
    (test-case "2.89-2.92 sparse, dense and multivariable polynomials"
      (check-equal? (term-list-add '(dense 2 0 3) '(sparse (2 -2) (1 5)) 'sparse)
                    '(sparse (1 5) (0 3)))
      (check-equal? (terms->dense '((3 2) (1 4))) '(2 0 4 0))
      (check-exn exn:fail? (lambda () (terms->dense '((-1 2)))))
      (define x (hash '(x) 1)) (define y (hash '(y) 1))
      (check-equal? (mv-mul (mv-add x y) x) (hash '(x x) 1 '(x y) 1))
      (check-equal? (mv-mul x y) (mv-mul y x)))
    (test-case "2.95-2.96 pseudo-division and primitive GCD over integers"
      (define factor '(1 -2 1))
      (define a (poly-mul factor '(7 0 11)))
      (define b (poly-mul factor '(5 13)))
      (check-equal? (pseudo-remainder a b) '(1458 -2916 1458))
      (check-equal? (integer-poly-gcd a b) factor)
      (check-equal? (integer-poly-gcd '(-2 -4) '()) '(1 2))
      (check-exn exn:fail? (lambda () (integer-poly-gcd '(1/2) '(1)))))
    (test-case "2.44-2.52 paint into an asymmetric frame"
      (define f (frame2 '(2 . 3) '(4 . 0) '(1 . 2)))
      (check-equal? (first (outline-painter f)) (cons '(2 . 3) '(6 . 3)))
      (check-equal? (first (diamond-painter f)) (cons '(5/2 . 4) '(5 . 5)))
      (check-equal? (length (((split below beside) x-painter 2) f)) 14)
      (check-equal? (length (smiling-wave f)) (+ 2 (length (wave-painter f)))))
    (test-case "2.42 queens, empty and unsatisfiable boards"
      (check-equal? (queens 0) '(()))
      (check-equal? (queens 2) '())
      (check-equal? (sort (queens 4) < #:key car) '((2 4 1 3) (3 1 4 2)))
      (check-equal? (length (queens 8)) 92)
      (check-exn exn:fail? (lambda () (queens -1))))
    (test-case "2.97 polynomial fractions through operation dispatch"
      (define-values (put dispatch) (make-operation-table))
      (install-rational-functions! put)
      (define (rf n d) (cons 'rational-function (make-rational-function n d)))
      (define a (rf '(1 1) '(-1 0 0 1)))
      (define b (rf '(0 1) '(-1 0 1)))
      (check-equal? (dispatch 'add a b) (rf '(1 3 2 1) '(-1 -1 0 1 1)))
      (check-equal? (dispatch 'mul a (rf '(-1 0 0 1) '(1 1))) (rf '(1) '(1)))
      (check-exn exn:fail? (lambda () (rf '(1) '(0)))))))
(module+ main (exit (run-tests (test-suite "Chapter 2" suite extended-suite integration-suite))))
