#lang racket
;; SICP 1.1--1.46. The algorithm bodies use Scheme; module/guards are Racket adapters.
(provide (all-defined-out))
(define (square x) (* x x))
(define (cube x) (* x x x))
(define (inc x) (+ x 1))
(define (average x y) (+ (/ x 2.0) (/ y 2.0)))
(define (natural who n)
  (unless (exact-nonnegative-integer? n) (raise-argument-error who "exact-nonnegative-integer?" n)))
(define (finite-real? x) (and (real? x) (not (nan? x)) (not (infinite? x))))
;; BEGIN elementary
(define (two-largest-squares a b c)
  (- (+ (square a) (square b) (square c)) (square (min a b c))))
(define (a-plus-abs-b a b) ((if (> b 0) + -) a b))
(define (new-if predicate then-clause else-clause)
  (cond [predicate then-clause] [else else-clause]))
(define (sqrt-original x)
  (let loop ([guess 1.0] [remaining 2000])
    (cond [(< (abs (- (square guess) x)) 0.001) guess]
          [(zero? remaining) (error 'sqrt-original "iteration limit")]
          [else (loop (average guess (/ x guess)) (sub1 remaining))])))
;; END elementary
;; BEGIN roots
(define (relative-close? a b)
  (or (= a b) (<= (abs (- a b)) (* 1e-12 (max (abs a) (abs b))))))
(define (bounded-improve improve initial [close? relative-close?] [limit 2000])
  (let loop ([guess initial] [left limit])
    (when (zero? left) (error 'bounded-improve "iteration limit"))
    (let ([next (improve guess)])
      (unless (finite-real? next) (error 'bounded-improve "non-finite iterate"))
      (if (close? guess next) next (loop next (sub1 left))))))
(define (sqrt-relative x)
  (unless (and (finite-real? x) (>= x 0)) (error 'sqrt-relative "finite nonnegative input required"))
  (if (zero? x) 0.0
      (bounded-improve (lambda (y) (average y (/ x y))) 1.0)))
(define (cube-root x)
  (unless (finite-real? x) (error 'cube-root "finite real input required"))
  (cond [(zero? x) 0.0] [(negative? x) (- (cube-root (- x)))]
        [else (bounded-improve (lambda (y) (+ (/ (/ (/ x y) y) 3.0) (* 2/3 y))) 1.0)]))
;; END roots
;; BEGIN recursive-processes
(define (add-rec a b) (if (= a 0) b (inc (add-rec (sub1 a) b))))
(define (add-iter a b) (if (= a 0) b (add-iter (sub1 a) (inc b))))
(define (A x y)
  (cond [(= y 0) 0] [(= x 0) (* 2 y)] [(= y 1) 2]
        [else (A (sub1 x) (A x (sub1 y)))]))
(define (f-rec n)
  (if (< n 3) n (+ (f-rec (- n 1)) (* 2 (f-rec (- n 2))) (* 3 (f-rec (- n 3))))))
(define (f-iter n)
  (if (< n 3) n
      (let loop ([a 2] [b 1] [c 0] [k n])
        (if (= k 0) c (loop (+ a (* 2 b) (* 3 c)) a b (sub1 k))))))
(define (pascal row column)
  (natural 'pascal row)
  (unless (and (exact-nonnegative-integer? column) (<= column row)) (error 'pascal "column outside row"))
  (if (or (= column 0) (= column row)) 1
      (+ (pascal (sub1 row) (sub1 column)) (pascal (sub1 row) column))))
(define coins '#(0 1 5 10 25 50))
(define (cc amount kinds)
  (cond [(= amount 0) 1] [(or (< amount 0) (= kinds 0)) 0]
        [else (+ (cc amount (sub1 kinds)) (cc (- amount (vector-ref coins kinds)) kinds))]))
(define (sine-count angle)
  (if (<= (abs angle) 0.1) (values angle 0)
      (let-values ([(s count) (sine-count (/ angle 3.0))])
        (values (- (* 3 s) (* 4 (cube s))) (add1 count)))))
;; END recursive-processes
;; BEGIN logarithmic
(define (double-number x) (+ x x))
(define (fast-expt b n)
  (natural 'fast-expt n)
  (let loop ([a 1] [b b] [n n])
    (cond [(zero? n) a] [(even? n) (loop a (square b) (quotient n 2))]
          [else (loop (* a b) b (sub1 n))])))
(define (multiply-rec a b)
  (natural 'multiply-rec b)
  (cond [(zero? b) 0] [(even? b) (double-number (multiply-rec a (quotient b 2)))]
        [else (+ a (multiply-rec a (sub1 b)))]))
(define (multiply-iter a b)
  (unless (exact-integer? b) (error 'multiply-iter "integer multiplier required"))
  (let loop ([sum 0] [a (if (negative? b) (- a) a)] [b (abs b)])
    (cond [(zero? b) sum] [(even? b) (loop sum (+ a a) (quotient b 2))]
          [else (loop (+ sum a) a (sub1 b))])))
(define (fib-fast n)
  (natural 'fib-fast n)
  (let loop ([a 1] [b 0] [p 0] [q 1] [n n])
    (cond [(zero? n) b]
          [(even? n) (loop a b (+ (square p) (square q)) (+ (* 2 p q) (square q)) (quotient n 2))]
          [else (loop (+ (* b q) (* a q) (* a p)) (+ (* b p) (* a q)) p q (sub1 n))])))
(define (gcd-count a b)
  (let loop ([a a] [b b] [count 0])
    (if (= b 0) (values a count) (loop b (remainder a b) (add1 count)))))
;; END logarithmic
;; BEGIN primes
(define (next-odd d) (if (= d 2) 3 (+ d 2)))
(define (smallest-divisor n [next add1])
  (unless (and (exact-integer? n) (>= n 2)) (error 'smallest-divisor "integer >= 2 required"))
  (let loop ([d 2])
    (cond [(> (* d d) n) n] [(zero? (remainder n d)) d] [else (loop (next d))])))
(define (prime? n [next add1])
  (and (exact-integer? n) (>= n 2) (= n (smallest-divisor n next))))
(define (runtime) (inexact->exact (floor (* 1000 (current-inexact-monotonic-milliseconds)))))
(define (timed-prime-test n [predicate prime?])
  (newline) (display n)
  (let* ([start (runtime)] [result (predicate n)])
    (when result (display " *** ") (display (- (runtime) start)))
    result))
(define (search-for-primes lower [count 3] [upper +inf.0])
  (natural 'search-for-primes count)
  (let loop ([n (if (even? lower) (add1 lower) (+ lower 2))] [left count] [found '()])
    (cond [(or (zero? left) (> n upper)) (reverse found)]
          [(prime? n next-odd) (loop (+ n 2) (sub1 left) (cons n found))]
          [else (loop (+ n 2) left found)])))
(define (expmod base exponent modulus)
  (cond [(zero? exponent) 1]
        [(even? exponent) (modulo (square (expmod base (quotient exponent 2) modulus)) modulus)]
        [else (modulo (* base (expmod base (sub1 exponent) modulus)) modulus)]))
(define (fermat-base? n a) (= (expmod a n n) a))
(define (fermat-all? n)
  (for/and ([a (in-range 1 n)]) (fermat-base? n a)))
;; The benchmark uses n <= 1,000,037, within Racket's single-argument random bound.
(define (fermat-prime? n [rounds 20])
  (and (exact-integer? n) (>= n 2)
       (for/and ([i (in-range rounds)]) (fermat-base? n (add1 (random (sub1 n)))))))
(define (expmod-duplicated base exponent modulus)
  (cond [(zero? exponent) 1]
        [(even? exponent) (modulo (* (expmod-duplicated base (quotient exponent 2) modulus)
                                    (expmod-duplicated base (quotient exponent 2) modulus)) modulus)]
        [else (modulo (* base (expmod-duplicated base (sub1 exponent) modulus)) modulus)]))
;; END primes
;; BEGIN miller-rabin
(define (mr-expmod base exponent modulus)
  (define (checked-square x)
    (let ([r (modulo (square x) modulus)])
      (if (and (= r 1) (not (= x 1)) (not (= x (sub1 modulus)))) 0 r)))
  (cond [(zero? exponent) 1]
        [(even? exponent) (checked-square (mr-expmod base (quotient exponent 2) modulus))]
        [else (modulo (* base (mr-expmod base (sub1 exponent) modulus)) modulus)]))
(define (mr-base? n a)
  (unless (and (exact-integer? n) (>= n 2) (exact-integer? a) (<= 1 a (sub1 n)))
    (error 'mr-base? "require n >= 2 and 1 <= a < n"))
  (= (mr-expmod a (sub1 n) n) 1))
(define (miller-rabin? n bases)
  (and (exact-integer? n) (>= n 2)
       (or (= n 2) (and (odd? n) (for/and ([a bases]) (mr-base? n (+ 1 (modulo (sub1 a) (sub1 n)))))))))
(define (miller-rabin/random? n [rounds 20] [choose random])
  (unless (exact-positive-integer? rounds) (error 'miller-rabin/random? "positive round count required"))
  (and (exact-integer? n) (>= n 2)
       (or (= n 2)
           (and (odd? n)
                (for/and ([i (in-range rounds)])
                  (mr-base? n (add1 (choose (sub1 n)))))))))
;; END miller-rabin
;; BEGIN accumulation
(define (advance next a)
  (let ([b (next a)]) (unless (> b a) (error 'advance "next must strictly increase")) b))
(define (accumulate-rec combiner null-value term a next b)
  (if (> a b) null-value
      (combiner (term a) (accumulate-rec combiner null-value term (advance next a) next b))))
(define (accumulate-iter combiner null-value term a next b)
  (let loop ([a a] [result null-value])
    (if (> a b) result (loop (advance next a) (combiner result (term a))))))
(define (sum-rec term a next b) (accumulate-rec + 0 term a next b))
(define (sum-iter term a next b) (accumulate-iter + 0 term a next b))
(define (product-rec term a next b) (accumulate-rec * 1 term a next b))
(define (product-iter term a next b) (accumulate-iter * 1 term a next b))
(define (factorial n) (natural 'factorial n) (product-iter values 1 add1 n))
(define (wallis n)
  (* 4.0 (product-iter (lambda (i) (/ (* (* 2.0 i) (+ (* 2.0 i) 2)) (square (+ (* 2.0 i) 1)))) 1 add1 n)))
(define (filtered-accumulate predicate combiner null-value term a next b)
  (let loop ([a a] [result null-value])
    (if (> a b) result
        (loop (advance next a) (if (predicate a) (combiner result (term a)) result)))))
(define (prime-square-sum a b) (filtered-accumulate prime? + 0 square a add1 b))
(define (coprime-product n)
  (unless (exact-positive-integer? n) (error 'coprime-product "positive integer required"))
  (filtered-accumulate (lambda (i) (= (gcd i n) 1)) * 1 values 1 add1 (sub1 n)))
;; END accumulation
;; BEGIN integration
(define (midpoint-integral f a b dx)
  (unless (> dx 0) (error 'midpoint-integral "positive dx required"))
  (* dx (sum-iter f (+ a (/ dx 2)) (lambda (x) (+ x dx)) b)))
(define (simpson f a b n)
  (unless (and (exact-positive-integer? n) (even? n)) (error 'simpson "positive even n required"))
  (let* ([h (/ (- b a) n)]
         [term (lambda (k) (* (cond [(or (= k 0) (= k n)) 1] [(odd? k) 4] [else 2]) (f (+ a (* k h)))))])
    (* (/ h 3) (sum-iter term 0 add1 n))))
;; END integration
;; BEGIN fixed-point
(define (fixed-point/trace f initial [tolerance 1e-5] [limit 2000])
  (let loop ([guess initial] [trace (list initial)] [left limit])
    (when (zero? left) (error 'fixed-point "iteration limit"))
    (let ([next (f guess)])
      (unless (finite-real? next) (error 'fixed-point "non-finite iterate"))
      (if (< (abs (- next guess)) tolerance)
          (values next (reverse (cons next trace)))
          (loop next (cons next trace) (sub1 left))))))
(define (fixed-point f initial)
  (let-values ([(result trace) (fixed-point/trace f initial)]) result))
(define (average-damp f) (lambda (x) (average x (f x))))
(define (half-interval f a b [tolerance 0.001])
  (define (search lo hi)
    (let* ([mid (average lo hi)] [v (f mid)])
      (cond [(or (= v 0) (< (abs (- hi lo)) tolerance)) mid]
            [(positive? v) (search lo mid)] [else (search mid hi)])))
  (let ([fa (f a)] [fb (f b)])
    (cond [(= fa 0) a] [(= fb 0) b] [(and (< fa 0) (> fb 0)) (search a b)]
          [(and (> fa 0) (< fb 0)) (search b a)] [else (error 'half-interval "endpoints must bracket a root")])) )
;; END fixed-point
;; BEGIN continued-fractions
(define (cont-frac-rec n d k)
  (natural 'cont-frac-rec k)
  (define (walk i) (if (> i k) 0 (/ (n i) (+ (d i) (walk (add1 i))))))
  (walk 1))
(define (cont-frac-iter n d k)
  (natural 'cont-frac-iter k)
  (let loop ([i k] [tail 0]) (if (= i 0) tail (loop (sub1 i) (/ (n i) (+ (d i) tail))))))
(define (e-approx k)
  (+ 2 (cont-frac-iter (lambda (i) 1.0) (lambda (i) (if (= (modulo i 3) 2) (* 2 (/ (add1 i) 3)) 1)) k)))
(define (tan-cf x k)
  (cont-frac-iter (lambda (i) (if (= i 1) x (- (square x)))) (lambda (i) (sub1 (* 2 i))) k))
;; END continued-fractions
;; BEGIN transformations
(define dx 1e-5)
(define (deriv g) (lambda (x) (/ (- (g (+ x dx)) (g x)) dx)))
(define (newton-transform g)
  (let ([dg (deriv g)])
    (lambda (x) (let ([slope (dg x)])
                  (when (< (abs slope) 1e-14) (error 'newton-transform "derivative too small"))
                  (- x (/ (g x) slope))))))
(define (newtons-method g guess) (fixed-point (newton-transform g) guess))
(define (cubic a b c) (lambda (x) (+ (cube x) (* a (square x)) (* b x) c)))
(define (double f) (lambda (x) (f (f x))))
(define (compose f g) (lambda (x) (f (g x))))
(define (repeated f n)
  (natural 'repeated n)
  (let loop ([i n] [result values])
    (if (= i 0) result (loop (sub1 i) (compose f result)))))
(define (smooth f [step dx])
  (lambda (x) (/ (+ (f (- x step)) (f x) (f (+ x step))) 3)))
(define (n-fold-smooth f n [step dx]) ((repeated (lambda (g) (smooth g step)) n) f))
(define (damping-count n)
  (unless (exact-positive-integer? n) (error 'damping-count "positive degree required"))
  (sub1 (integer-length n)))
(define (nth-root x n)
  (unless (and (exact-positive-integer? n) (finite-real? x)) (error 'nth-root "finite x and positive integer n required"))
  (cond [(zero? x) 0.0] [(= n 1) x]
        [(negative? x) (if (odd? n) (- (nth-root (- x) n)) (error 'nth-root "negative even root"))]
        [else (bounded-improve ((repeated average-damp (damping-count n))
                               (lambda (y) (/ x (expt y (sub1 n))))) 1.0)]))
;; END transformations
;; BEGIN iterative-improve
(define (iterative-improve good? improve [limit 2000])
  (lambda (initial)
    (let loop ([guess initial] [left limit])
      (cond [(good? guess) guess] [(zero? left) (error 'iterative-improve "iteration limit")]
            [else (let ([next (improve guess)])
                    (unless (finite-real? next) (error 'iterative-improve "non-finite iterate"))
                    (loop next (sub1 left)))]))))
(define (sqrt-via-improve x)
  (unless (and (finite-real? x) (>= x 0)) (error 'sqrt-via-improve "finite nonnegative input required"))
  (if (zero? x) 0.0
      (let ([improve (lambda (y) (average y (/ x y)))])
        ((iterative-improve (lambda (y) (relative-close? y (improve y))) improve) 1.0))))
(define (fixed-point-via-improve f first)
  ((iterative-improve (lambda (y) (< (abs (- y (f y))) 1e-5)) f) first))
;; END iterative-improve
