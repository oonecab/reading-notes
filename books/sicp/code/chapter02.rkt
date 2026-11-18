#lang racket
;; Executable chapter 2 examples, sections 2.1 through 2.5.
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

;; BEGIN sequence-tree
(define (fold-sequence combine empty-value items)
  (if (null? items) empty-value
      (combine (car items) (fold-sequence combine empty-value (cdr items)))))
(define (tree-map-leaves f tree)
  (cond [(null? tree) '()]
        [(pair? tree) (cons (tree-map-leaves f (car tree))
                            (tree-map-leaves f (cdr tree)))]
        [else (f tree)]))
(define (fringe tree)
  (define (visit node tail)
    (cond [(null? node) tail]
          [(pair? node) (visit (car node) (visit (cdr node) tail))]
          [else (cons node tail)]))
  (visit tree '()))
;; END sequence-tree

;; BEGIN symbolic-data
(define (ordered-union a b)
  (cond [(null? a) b] [(null? b) a]
        [(< (car a) (car b)) (cons (car a) (ordered-union (cdr a) b))]
        [(> (car a) (car b)) (cons (car b) (ordered-union a (cdr b)))]
        [else (cons (car a) (ordered-union (cdr a) (cdr b)))]))
(define (deriv expr variable)
  (define (sum a b) (cond [(equal? a 0) b] [(equal? b 0) a] [else (list '+ a b)]))
  (define (product a b)
    (cond [(or (equal? a 0) (equal? b 0)) 0] [(equal? a 1) b] [(equal? b 1) a]
          [else (list '* a b)]))
  (match expr
    [(? number?) 0] [(? symbol?) (if (eq? expr variable) 1 0)]
    [(list '+ a b) (sum (deriv a variable) (deriv b variable))]
    [(list '* a b) (sum (product a (deriv b variable)) (product (deriv a variable) b))]
    [_ (error 'deriv "unsupported expression: ~a" expr)]))
(struct leaf (symbol weight) #:transparent)
(struct branch (left right weight) #:transparent)
(define (node-weight n) (if (leaf? n) (leaf-weight n) (branch-weight n)))
(define (huffman frequencies)
  (unless (and (>= (length frequencies) 2)
               (andmap (lambda (p) (match p [(list (? symbol?) (? exact-positive-integer?)) #t] [_ #f])) frequencies)
               (not (check-duplicates (map car frequencies))))
    (error 'huffman "expected at least two distinct symbols with positive weights"))
  (let merge ([nodes (map (lambda (p) (apply leaf p)) frequencies)])
    (match (sort nodes < #:key node-weight)
      [(list root) root]
      [(list* a b rest) (merge (append rest (list (branch a b (+ (node-weight a) (node-weight b))))))])))
(define (huffman-encode symbols tree)
  (define codes (make-hash))
  (define (visit n path)
    (if (leaf? n) (hash-set! codes (leaf-symbol n) (reverse path))
        (begin (visit (branch-left n) (cons 0 path)) (visit (branch-right n) (cons 1 path)))))
  (visit tree '())
  (append-map (lambda (s) (hash-ref codes s)) symbols))
(define (huffman-decode bits tree)
  (let loop ([bits bits] [n tree] [out '()])
    (cond [(leaf? n) (loop bits tree (cons (leaf-symbol n) out))]
          [(null? bits) (unless (eq? n tree) (error 'decode "incomplete codeword")) (reverse out)]
          [else (loop (cdr bits) (case (car bits) [(0) (branch-left n)] [(1) (branch-right n)]
                                   [else (error 'decode "invalid bit")]) out)])))
;; END symbolic-data

;; BEGIN dispatch
(define (make-operation-table)
  (define methods (make-hash))
  (define (put op tags method) (hash-set! methods (cons op tags) method))
  (define (apply-op op . args)
    (define key (cons op (map car args)))
    (apply (hash-ref methods key (lambda () (error 'apply-op "no method: ~a" key))) (map cdr args)))
  (values put apply-op))
(define (make-polar-message radius angle)
  (lambda (op)
    (case op [(magnitude) radius] [(angle) angle]
      [(real-part) (* radius (cos angle))] [(imag-part) (* radius (sin angle))]
      [else (error 'polar "unknown selector: ~a" op)])))
;; END dispatch

;; BEGIN polynomials
;; Coefficients in ascending order. The empty list represents zero.
(define (poly-normal p)
  (unless (and (list? p) (andmap (lambda (v) (and (rational? v) (exact? v))) p))
    (error 'polynomial "expected exact rational coefficients"))
  (reverse (dropf (reverse p) zero?)))
(define (poly-add a b)
  (cond [(null? a) (poly-normal b)] [(null? b) (poly-normal a)]
        [else (poly-normal (cons (+ (car a) (car b)) (poly-add (cdr a) (cdr b))))]))
(define (poly-scale k p) (poly-normal (map (lambda (v) (* k v)) p)))
(define (poly-mul a b)
  (if (null? a) '() (poly-add (poly-scale (car a) b) (cons 0 (poly-mul (cdr a) b)))))
(define (poly-divmod a b)
  (define divisor (poly-normal b))
  (when (null? divisor) (error 'poly-divmod "zero divisor"))
  (let loop ([r (poly-normal a)] [q '()])
    (define gap (- (length r) (length divisor)))
    (if (< gap 0) (values q r)
        (let ([t (append (make-list gap 0) (list (/ (last r) (last divisor))))])
          (loop (poly-add r (poly-scale -1 (poly-mul t divisor))) (poly-add q t))))))
(define (poly-gcd a b)
  (let loop ([a (poly-normal a)] [b (poly-normal b)])
    (if (null? b) (if (null? a) '() (poly-scale (/ 1 (last a)) a))
        (let-values ([(q r) (poly-divmod a b)]) (loop b r)))))
(define (make-rational-function n d)
  (when (null? (poly-normal d)) (error 'rational-function "zero denominator"))
  (define g (poly-gcd n d))
  (define-values (num nr) (poly-divmod n g))
  (define-values (den dr) (poly-divmod d g))
  (define k (/ 1 (last den)))
  (cons (poly-scale k num) (poly-scale k den)))
(define (install-arithmetic! put)
  (for ([op '(add mul)] [scalar (list + *)] [poly (list poly-add poly-mul)])
    (put op '(scalar scalar) (lambda (a b) (cons 'scalar (scalar a b))))
    (put op '(polynomial polynomial) (lambda (a b) (cons 'polynomial (poly a b))))
    (put op '(scalar polynomial) (lambda (a b) (cons 'polynomial (poly (list a) b))))
    (put op '(polynomial scalar) (lambda (a b) (cons 'polynomial (poly a (list b)))))))
;; END polynomials
;; BEGIN rational-function-ops
(define (rf-add a b)
  (make-rational-function
   (poly-add (poly-mul (car a) (cdr b)) (poly-mul (car b) (cdr a)))
   (poly-mul (cdr a) (cdr b))))
(define (rf-mul a b)
  (make-rational-function (poly-mul (car a) (car b)) (poly-mul (cdr a) (cdr b))))
(define (install-rational-functions! put)
  (put 'add '(rational-function rational-function)
       (lambda (a b) (cons 'rational-function (rf-add a b))))
  (put 'mul '(rational-function rational-function)
       (lambda (a b) (cons 'rational-function (rf-mul a b)))))
;; END rational-function-ops

;; BEGIN queens
(define (queens size)
  (unless (exact-nonnegative-integer? size)
    (raise-argument-error 'queens "exact-nonnegative-integer?" size))
  ;; Most recent column first; distance in the list equals column distance.
  (define (extend placed)
    (for/list ([row (in-range 1 (add1 size))]
               #:when (for/and ([previous (in-list placed)] [distance (in-naturals 1)])
                        (and (not (= previous row))
                             (not (= (abs (- previous row)) distance)))))
      (cons row placed)))
  (for/fold ([boards (list '())]) ([_ (in-range size)])
    (append-map extend boards)))
;; END queens
;; BEGIN painter-geometry
;; A painter returns its directed line segments in the supplied frame.
(struct frame2 (origin edge1 edge2) #:transparent)
(define (v+ a b) (cons (+ (car a) (car b)) (+ (cdr a) (cdr b))))
(define (v* k a) (cons (* k (car a)) (* k (cdr a))))
(define (frame-point f v)
  (v+ (frame2-origin f)
      (v+ (v* (car v) (frame2-edge1 f)) (v* (cdr v) (frame2-edge2 f)))))
(define (segments-painter segments)
  (lambda (f)
    (for/list ([edge segments])
      (cons (frame-point f (car edge)) (frame-point f (cdr edge))))))
(define (transform p origin x-end y-end)
  (lambda (f)
    (define o (frame-point f origin))
    (p (frame2 o (v+ (frame-point f x-end) (v* -1 o))
                 (v+ (frame-point f y-end) (v* -1 o))))))
(define (beside left right)
  (define l (transform left '(0 . 0) '(1/2 . 0) '(0 . 1)))
  (define r (transform right '(1/2 . 0) '(1 . 0) '(1/2 . 1)))
  (lambda (frame) (append (l frame) (r frame))))
(define (below bottom top)
  (define lo (transform bottom '(0 . 0) '(1 . 0) '(0 . 1/2)))
  (define hi (transform top '(0 . 1/2) '(1 . 1/2) '(0 . 1)))
  (lambda (frame) (append (lo frame) (hi frame))))
(define (split outer inner)
  (define (recur painter depth)
    (if (zero? depth) painter
        (let ([smaller (recur painter (sub1 depth))])
          (outer painter (inner smaller smaller)))))
  recur)
(define (polyline points)
  (for/list ([from points] [to (cdr points)]) (cons from to)))
(define outline-painter
  (segments-painter (polyline '((0 . 0) (1 . 0) (1 . 1) (0 . 1) (0 . 0)))))
(define x-painter
  (segments-painter (list (cons '(0 . 0) '(1 . 1)) (cons '(0 . 1) '(1 . 0)))))
(define diamond-painter
  (segments-painter (polyline '((0 . 1/2) (1/2 . 1) (1 . 1/2) (1/2 . 0) (0 . 1/2)))))
(define wave-lines
  (append*
   (map polyline
        '(((0 . .85) (.15 . .62) (.28 . .70) (.40 . .66) (.43 . .78)
           (.39 . .90) (.43 . 1))
          ((.57 . 1) (.61 . .90) (.57 . .78) (.61 . .68) (.72 . .66) (1 . .34))
          ((1 . .17) (.65 . .48) (.60 . .41) (.75 . 0))
          ((.61 . 0) (.50 . .29) (.40 . 0))
          ((.27 . 0) (.39 . .53) (.31 . .58) (.16 . .42) (0 . .67))))))
(define wave-painter (segments-painter wave-lines))
(define smiling-wave
  (segments-painter (append wave-lines (polyline '((.46 . .86) (.50 . .84) (.54 . .86))))))
;; END painter-geometry

;; BEGIN tower
;; The exercise tower over finite Racket real numbers. Rationals are exact;
;; real and complex components may also be exact, preserving exact round trips.
(define tower-tags '(integer rational real complex))
(define (tower-raise z)
  (match z
    [(cons 'integer n) (cons 'rational n)]
    [(cons 'rational q) (cons 'real q)]
    [(cons 'real r) (cons 'complex (cons r 0))]
    [_ (error 'tower-raise "no next type: ~a" z)]))
(define (tower-project z)
  (match z
    [(cons 'complex (cons re im)) (cons 'real re)]
    [(cons 'real x) (cons 'rational (if (exact? x) x (inexact->exact x)))]
    [(cons 'rational q) (cons 'integer (round q))]
    [_ (error 'tower-project "no preceding type: ~a" z)]))
(define (tower-equal? a b)
  (and (eq? (car a) (car b))
       (if (eq? (car a) 'complex)
           (and (= (car (cdr a)) (car (cdr b))) (= (cdr (cdr a)) (cdr (cdr b))))
           (= (cdr a) (cdr b)))))
(define (tower-drop z)
  (if (eq? (car z) 'integer) z
      (let ([lower (tower-project z)])
        (if (tower-equal? z (tower-raise lower)) (tower-drop lower) z))))
(define (tower-apply methods op . values)
  (unless (pair? values) (error 'tower-apply "expected operands"))
  (define (lift-to target v)
    (cond [(eq? target (car v)) v]
          [(eq? (car v) 'complex) #f]
          [else (lift-to target (tower-raise v))]))
  (define (invoke method args)
    (define result (apply method (map cdr args)))
    (if (and (pair? result) (memq (car result) tower-tags)) (tower-drop result) result))
  (define direct (hash-ref methods (cons op (map car values)) #f))
  (if direct (invoke direct values)
      (let search ([tags tower-tags])
        (when (null? tags) (error 'tower-apply "no method for ~a and ~a" op (map car values)))
        (define tag (car tags))
        (define args (map (lambda (v) (lift-to tag v)) values))
        (define method (hash-ref methods (cons op (make-list (length args) tag)) #f))
        (if (and method (andmap pair? args)) (invoke method args) (search (cdr tags))))))
;; END tower

;; BEGIN term-representations
;; Both interfaces present (degree coefficient) in descending degree.
(define (dense->terms coefficients)
  (for/list ([c coefficients] [d (in-range (sub1 (length coefficients)) -1 -1)]
             #:unless (zero? c))
    (list d c)))
(define (terms->dense terms)
  (define mapping (make-hash))
  (for ([t terms])
    (match-define (list degree coefficient) t)
    (unless (exact-nonnegative-integer? degree) (error 'terms->dense "invalid degree"))
    (hash-update! mapping degree (lambda (c) (+ c coefficient)) 0))
  (define nonzero (filter (lambda (d) (not (zero? (hash-ref mapping d)))) (hash-keys mapping)))
  (if (null? nonzero) '()
      (for/list ([d (in-range (apply max nonzero) -1 -1)]) (hash-ref mapping d 0))))
(define (term-list-add left right output-tag)
  (define (to-sparse x)
    (match x [(cons 'dense cs) (dense->terms cs)] [(cons 'sparse ts) ts]
      [_ (error 'term-list-add "unknown representation")]))
  (define dense (terms->dense (append (to-sparse left) (to-sparse right))))
  (case output-tag
    [(dense) (cons 'dense dense)] [(sparse) (cons 'sparse (dense->terms dense))]
    [else (error 'term-list-add "unknown result representation")]))
;; END term-representations

;; BEGIN multivariate
;; A monomial key is a sorted list of variable names with multiplicity.
;; Missing keys represent zero. Inputs and results use immutable hashes.
(define (mono-key names) (sort names symbol<?))
(define (mv-insert polynomial key value)
  (define normalized (mono-key key))
  (define sum (+ value (hash-ref polynomial normalized 0)))
  (if (zero? sum) (hash-remove polynomial normalized) (hash-set polynomial normalized sum)))
(define (mv-add a b)
  (for/fold ([result a]) ([(powers coefficient) (in-hash b)])
    (mv-insert result powers coefficient)))
(define (mv-mul a b)
  (for*/fold ([result (hash)]) ([(left lc) (in-hash a)] [(right rc) (in-hash b)])
    (mv-insert result (append left right) (* lc rc))))
;; END multivariate

;; BEGIN pseudo-gcd
(define (pseudo-remainder a b)
  (define divisor (poly-normal b))
  (when (null? divisor) (error 'pseudo-remainder "zero divisor"))
  (define gap (- (length (poly-normal a)) (length divisor)))
  (if (negative? gap) (poly-normal a)
      (let-values ([(q r) (poly-divmod (poly-scale (expt (last divisor) (add1 gap)) a) divisor)])
        r)))
(define (primitive-part coefficients)
  (define p (poly-normal coefficients))
  (if (null? p) p
      (let ([content (apply gcd p)])
        (poly-scale (/ (if (negative? (last p)) -1 1) content) p))))
(define (integer-poly-gcd a b)
  (unless (and (andmap exact-integer? a) (andmap exact-integer? b))
    (error 'integer-poly-gcd "integer coefficients required"))
  (let loop ([a (primitive-part a)] [b (primitive-part b)])
    (if (null? b) a (loop b (primitive-part (pseudo-remainder a b))))))
;; END pseudo-gcd
