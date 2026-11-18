#lang racket
;; I077 work in progress: section 2.1 only. Not a completed chapter release.
;; Exact arithmetic adapters; original textbook snippets remain distinct.
(provide (all-defined-out))

(define (exact-rational who x)
  (unless (and (rational? x) (exact? x))
    (raise-argument-error who "exact rational" x)))

;; BEGIN rational
(define (make-rat n d)
  (unless (and (exact-integer? n) (exact-integer? d) (not (zero? d)))
    (error 'make-rat "integer numerator and nonzero integer denominator required"))
  (define g (gcd n d))
  (define sign (if (negative? d) -1 1))
  (cons (* sign (quotient n g)) (* sign (quotient d g))))
(define numer car)
(define denom cdr)
;; END rational

;; BEGIN geometry
(define (make-point x y)
  (exact-rational 'make-point x) (exact-rational 'make-point y)
  (cons x y))
(define x-point car)
(define y-point cdr)
(define make-segment cons)
(define start-segment car)
(define end-segment cdr)
(define (midpoint-segment s)
  (define a (start-segment s)) (define b (end-segment s))
  (make-point (/ (+ (x-point a) (x-point b)) 2)
              (/ (+ (y-point a) (y-point b)) 2)))
(define (print-point p)
  (newline) (display "(") (display (x-point p))
  (display ",") (display (y-point p)) (display ")"))
;; Both representations allow rotation; selectors form the abstraction barrier.
(struct rect-sides (origin width height angle) #:transparent)
(struct rect-edges (origin u v) #:transparent)
(define (make-rect-sides origin width height [angle 0])
  (unless (and (real? width) (real? height) (> width 0) (> height 0)
               (rational? width) (rational? height) (rational? angle))
    (error 'make-rect-sides "positive finite sides and finite angle required"))
  (rect-sides origin width height angle))
(define (make-rect-edges origin u v)
  (define dot (+ (* (x-point u) (x-point v)) (* (y-point u) (y-point v))))
  (unless (and (zero? dot) (not (equal? u '(0 . 0))) (not (equal? v '(0 . 0))))
    (error 'make-rect-edges "nonzero perpendicular edges required"))
  (rect-edges origin u v))
(define (vector-length v) (sqrt (+ (sqr (x-point v)) (sqr (y-point v)))))
(define (rect-width r)
  (if (rect-sides? r) (rect-sides-width r) (vector-length (rect-edges-u r))))
(define (rect-height r)
  (if (rect-sides? r) (rect-sides-height r) (vector-length (rect-edges-v r))))
(define (rect-perimeter r) (* 2 (+ (rect-width r) (rect-height r))))
(define (rect-area r) (* (rect-width r) (rect-height r)))
;; END geometry

;; BEGIN representations
(define (procedure-cons x y) (lambda (m) (m x y)))
(define (procedure-car z) (z (lambda (p q) p)))
(define (procedure-cdr z) (z (lambda (p q) q)))
(define (integer-cons a b)
  (unless (and (exact-nonnegative-integer? a) (exact-nonnegative-integer? b))
    (error 'integer-cons "nonnegative integer exponents required"))
  (* (expt 2 a) (expt 3 b)))
(define (integer-pair-components n)
  (unless (exact-positive-integer? n) (error 'integer-pair "positive encoding required"))
  (define (extract n p)
    (let loop ([n n] [k 0])
      (if (zero? (remainder n p)) (loop (quotient n p) (add1 k)) (values k n))))
  (define-values (a remainder2) (extract n 2))
  (define-values (b remainder3) (extract remainder2 3))
  (unless (= remainder3 1) (error 'integer-pair "encoding has factors other than 2 and 3"))
  (values a b))
(define (integer-car n) (define-values (a b) (integer-pair-components n)) a)
(define (integer-cdr n) (define-values (a b) (integer-pair-components n)) b)
(define church-zero (lambda (f) (lambda (x) x)))
(define church-one (lambda (f) (lambda (x) (f x))))
(define church-two (lambda (f) (lambda (x) (f (f x)))))
(define (church-add1 n) (lambda (f) (lambda (x) (f ((n f) x)))))
(define (church-add m n) (lambda (f) (lambda (x) ((m f) ((n f) x)))))
(define (church->integer n) ((n add1) 0))
;; END representations

;; BEGIN intervals
;; Exact endpoints avoid pretending ordinary floating point is outward rounded.
(define (make-interval a b)
  (exact-rational 'make-interval a) (exact-rational 'make-interval b)
  (cons (min a b) (max a b)))
(define lower-bound car)
(define upper-bound cdr)
(define (add-interval x y)
  (make-interval (+ (lower-bound x) (lower-bound y)) (+ (upper-bound x) (upper-bound y))))
(define (sub-interval x y)
  (make-interval (- (lower-bound x) (upper-bound y)) (- (upper-bound x) (lower-bound y))))
(define (mul-interval x y)
  (define a (lower-bound x)) (define b (upper-bound x))
  (define c (lower-bound y)) (define d (upper-bound y))
  (cond [(>= a 0) (cond [(>= c 0) (make-interval (* a c) (* b d))]
                        [(<= d 0) (make-interval (* b c) (* a d))]
                        [else (make-interval (* b c) (* b d))])]
        [(<= b 0) (cond [(>= c 0) (make-interval (* a d) (* b c))]
                        [(<= d 0) (make-interval (* b d) (* a c))]
                        [else (make-interval (* a d) (* a c))])]
        [else (cond [(>= c 0) (make-interval (* a d) (* b d))]
                    [(<= d 0) (make-interval (* b c) (* a c))]
                    [else (make-interval (min (* a d) (* b c))
                                         (max (* a c) (* b d)))])]))
(define (div-interval x y)
  (when (<= (lower-bound y) 0 (upper-bound y))
    (error 'div-interval "divisor interval contains zero"))
  (mul-interval x (make-interval (/ 1 (upper-bound y)) (/ 1 (lower-bound y)))))
(define (center i) (/ (+ (lower-bound i) (upper-bound i)) 2))
(define (width i) (/ (- (upper-bound i) (lower-bound i)) 2))
(define (make-center-width c w)
  (exact-rational 'make-center-width c) (exact-rational 'make-center-width w)
  (when (< w 0) (error 'make-center-width "nonnegative width required"))
  (make-interval (- c w) (+ c w)))
(define (make-center-percent c p)
  (exact-rational 'make-center-percent c) (exact-rational 'make-center-percent p)
  (when (< p 0) (error 'make-center-percent "nonnegative percentage required"))
  (make-center-width c (* (abs c) (/ p 100))))
(define (percent i)
  (when (zero? (center i)) (error 'percent "relative tolerance undefined at zero center"))
  (* 100 (/ (width i) (abs (center i)))))
(define (par1 r1 r2) (div-interval (mul-interval r1 r2) (add-interval r1 r2)))
(define (par2 r1 r2)
  (define one (make-interval 1 1))
  (div-interval one (add-interval (div-interval one r1) (div-interval one r2))))
;; END intervals
