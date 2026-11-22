#lang racket
(require rackunit rackunit/text-ui "chapter03.rkt")
(define suite
  (test-suite "section 3.1"
    (test-case "independent accumulators"
      (define a (make-accumulator 5)) (define b (make-accumulator 5))
      (check-equal? (list (a 10) (a 10) (b 0)) '(15 25 5)))
    (test-case "monitor commands do not count"
      (define s (make-monitored sqrt))
      (check-equal? (s 100) 10) (check-equal? (s 'how-many-calls?) 1)
      (s 'reset-count) (check-equal? (s 'how-many-calls?) 0))
    (test-case "failed transactions preserve funds"
      (define a (make-account 100 'key))
      (check-equal? ((a 'key 'withdraw) 40) 60)
      (check-equal? ((a 'bad 'deposit) 50) "Incorrect password")
      (check-equal? ((a 'key 'withdraw) 61) "Insufficient funds")
      (check-equal? ((a 'key 'deposit) 0) 60))
    (test-case "alarm after eight consecutive misses"
      (define alarms 0)
      (define a (make-account 10 'key (lambda () (set! alarms (add1 alarms)))))
      (define (miss) ((a 'bad 'withdraw) 1))
      (for ([i 7]) (miss)) ((a 'key 'deposit) 0)
      (for ([i 7]) (miss)) (check-equal? alarms 0)
      (miss) (check-equal? alarms 1))
    (test-case "rectangular area times fraction"
      (define samples '(0 0 1/2 1/2))
      (define (draw) (begin0 (car samples) (set! samples (cdr samples))))
      (check-equal? (estimate-integral (lambda (x y) (<= (+ (sqr x) (sqr y)) 1))
                                       -1 1 -1 1 2 draw) 2)
      (check-exn exn:fail? (lambda () (estimate-integral < 0 1 0 1 0))))
    (test-case "reset replays sequence"
      (define r (make-rand 1))
      (define first (list (r 'generate) (r 'generate)))
      ((r 'reset) 1) (check-equal? (list (r 'generate) (r 'generate)) first))
    (test-case "joint access shares original balance"
      (define a (make-account 100 'old)) (define j (make-joint a 'old 'new))
      (check-exn exn:fail? (lambda () (make-joint a 'wrong 'other)))
      (check-equal? ((j 'new 'withdraw) 40) 60)
      (check-equal? ((a 'old 'deposit) 5) 65))
    (test-case "explicit argument evaluation orders"
      (define f (make-first-factor)) (define g (make-first-factor))
      (check-equal? (let* ([a (f 0)] [b (f 1)]) (+ a b)) 0)
      (check-equal? (let* ([b (g 1)] [a (g 0)]) (+ a b)) 1))))
(define more
  (test-suite "mutable data, interleavings and streams"
    (test-case "destructive reverse keeps original head as final node"
      (define a (mcons 'a (mcons 'b '())))
      (define b (mcdr a))
      (check-eq? (reverse-chain! a) b)
      (check-eq? (mcdr b) a)
      (check-equal? (mcdr a) '()))
    (test-case "shared nodes and cyclic tails"
      (define a (mcons 'x '()))
      (define b (mcons a a))
      (check-equal? (distinct-pairs b) 2)
      (check-false (tail-cycle? b))
      (set-mcdr! a b)
      (check-true (tail-cycle? a))
      (check-equal? (distinct-pairs b) 2))
    (test-case "empty, single and shared rear cases"
      (define q (make-fifo))
      (q 'insert! 'a) (q 'insert! 'b)
      (check-equal? (q 'items) '(a b))
      (check-equal? (list (q 'delete!) (q 'delete!)) '(a b))
      (check-exn exn:fail? (lambda () (q 'delete!)))
      (q 'insert! 'c) (check-equal? (q 'items) '(c)))
    (test-case "a key may be both leaf and prefix"
      (define t (make-path-table equal?))
      (t 'put! '(a b) 4) (t 'put! '(a) #f)
      (check-false (t 'get '(a)))
      (check-equal? (t 'get '(a b)) 4)
      (check-exn exn:fail? (lambda () (t 'get '(b)))))
    (test-case "same-time gate events retain insertion order"
      (check-equal? (schedule-and '((1 1) (1 0))) '(1 0)))
    (test-case "enumerate all reads and writes of square/cube"
      (check-equal? (transitions '(2 3)) (set 100 1000 10000 100000 1000000)))
    (test-case "RLC simultaneous Euler updates"
      (define (slope state)
        (match-define (list v i) state)
        (list (* -5 i) (- v i)))
      (check-equal? (prefix (integrate-states slope 1/10 '(10 0)) 3)
                    '((10 0) (10 1) (19/2 19/10))))
    (test-case "requests replay without assignment"
      (check-equal? (prefix (request-states add1 0 '(generate generate (reset 0) generate)) 8)
                    '(1 2 1)))
    (test-case "one-element prefix does not force the tail"
      (check-equal? (prefix (cons 'head (delay (error "tail forced"))) 1) '(head)))))
(define streams
  (test-suite "finite prefixes of delayed solutions"
    (test-case "factorials, partial sums and smooth numbers"
      (check-equal? (prefix factorials 6) '(1 2 6 24 120 720))
      (check-equal? (prefix (sums ints) 5) '(1 3 6 10 15))
      (check-equal? (prefix smooth-numbers 10) '(1 2 3 4 5 6 8 9 10 12)))
    (test-case "independent Taylor coefficients and trig identity"
      (check-equal? (prefix exp-series 5) '(1 1 1/2 1/6 1/24))
      (check-equal? (prefix (div-series sin-series cos-series) 6) '(0 1 0 1/3 0 2/15))
      (check-equal? (prefix (smap + (mul-series sin-series sin-series)
                                  (mul-series cos-series cos-series)) 6) '(1 0 0 0 0 0))
      (check-exn exn:fail? (lambda () (div-series cos-series sin-series))))
    (test-case "weights preserve distinct equal-weight pairs"
      (check-equal? (map car (prefix (power-representations 3 2) 6))
                    '(1729 4104 13832 20683 32832 39312))
      (check-equal? (car (prefix (power-representations 2 3) 1))
                    '(325 (1 18) (6 17) (10 15))))
    (test-case "feedback streams start before derivative demand"
      (define response ((RLC 1 1 1/5 1/10) 10 0))
      (check-equal? (prefix (car response) 3) '(10 10 19/2))
      (check-equal? (prefix (cdr response) 3) '(0 1 19/10))
      (check-equal? (prefix (solve-second (lambda (v y) 0) 1/2 1 4) 4) '(1 3 5 7))
      (check-equal? (prefix ((RC 5 1 1/2) (smap (lambda (_) 1) ints) 0) 3) '(5 11/2 6)))
    (test-case "area estimates normalize after every sample"
      (define points (scons '(0 0) (scons '(1 1) '())))
      (check-equal? (prefix (area-estimates (lambda (x y) (<= (+ (sqr x) (sqr y)) 1))
                                            4 points) 2) '(4 2)))))
(define networks
  (test-suite "constraint and digital networks, deques and acceleration"
    (test-case "two-bit addition with final carry"
      (define-values (wire or! demorgan! ripple! run!) (make-logic-network 3 5 2))
      (define as (list (wire) (wire))) (define bs (list (wire) (wire)))
      (define ss (list (wire) (wire))) (define carry (wire))
      (ripple! as bs ss carry)
      (for ([w as]) (w 'write 1)) ((car bs) 'write 1)
      (run!) (check-equal? (map (lambda (w) (w 'read)) (cons carry ss)) '(1 0 0))
      (define x (wire)) (define y (wire)) (define p (wire)) (define q (wire))
      (or! x y p) (demorgan! x y q)
      (for* ([a '(0 1)] [b '(0 1)])
        (x 'write a) (y 'write b) (run!)
        (check-equal? (list (p 'read) (q 'read)) (make-list 2 (max a b)))))
    (test-case "withdraw information and infer in reverse"
      (define a (make-connector)) (define b (make-connector)) (define c (make-connector))
      (averager a b c) (a 'set! 4 'user) (b 'set! 8 'user)
      (check-equal? (c 'get) 6)
      (b 'forget! 'other) (check-true (b 'has?))
      (b 'forget! 'user) (check-false (c 'has?))
      (c 'set! 7 'user) (check-equal? (b 'get) 10)
      (check-exn exn:fail? (lambda () (b 'set! 12 'user))))
    (test-case "primitive square root and negative boundary"
      (define a (make-connector)) (define b (make-connector))
      (void (make-squarer a b)) (b 'set! 9 'user)
      (check-equal? (a 'get) 3)
      (b 'forget! 'user) (check-exn exn:fail? (lambda () (b 'set! -1 'user))))
    (test-case "deque splices correctly at both ends"
      (define q (make-deque))
      (q 'front-insert! 'b) (q 'rear-insert! 'c) (q 'front-insert! 'a)
      (check-equal? (list (q 'rear-delete!) (q 'front-delete!) (q 'rear-delete!)) '(c a b))
      (check-true (q 'empty?)) (check-exn exn:fail? (lambda () (q 'front))))
    (test-case "accelerated logarithm and first Pythagorean triple"
      (define estimates (prefix (accelerated-stream ln2-stream) 3))
      (check-equal? (take estimates 2) '(1 7/10))
      (check-= (third estimates) (log 2) 0.0002)
      (check-equal? (prefix (sfilter (match-lambda [(list i j k) (= (+ (sqr i) (sqr j)) (sqr k))])
                                    (triples ints ints ints)) 1) '((3 4 5))))))
(define locks
  (test-suite "synchronization"
    (test-case "capacity, release and over-release on both implementations"
      (for ([make-limiter (list semaphore-counter semaphore-cas)])
        (define lim (make-limiter 2))
        (lim 'acquire) (lim 'acquire) (lim 'release) (lim 'release)
        (check-exn exn:fail? (lambda () (lim 'release)))))
    (test-case "same account and opposite lock orders terminate with balances preserved"
      (define a (ordered-account 10)) (define b (ordered-account 20))
      (serialized-exchange a a)
      (define p (thread (lambda () (serialized-exchange a b))))
      (define q (thread (lambda () (serialized-exchange b a))))
      (check-not-false (sync/timeout 3 p))
      (check-not-false (sync/timeout 3 q))
      (check-equal? (list (account-snapshot a) (account-snapshot b)) '(10 20)))))
(exit (+ (run-tests suite) (run-tests more) (run-tests streams) (run-tests networks) (run-tests locks)))
