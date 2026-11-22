#lang racket
(provide make-accumulator make-monitored make-account make-joint estimate-integral make-rand make-first-factor)

(define (make-accumulator sum)
  (lambda (x) (set! sum (+ sum x)) sum))

(define (make-monitored f)
  (define calls 0)
  (lambda (x)
    (case x
      [(how-many-calls?) calls]
      [(reset-count) (set! calls 0)]
      [else (set! calls (add1 calls)) (f x)])))

(define (make-account balance password [alarm (lambda () "Call the cops")])
  (define failures 0)
  (lambda (key message)
    (cond
      [(not (eq? key password))
       (set! failures (add1 failures))
       (define response (if (> failures 7) (alarm) "Incorrect password"))
       (lambda (_) response)]
      [else
       (set! failures 0)
       (case message
         [(authenticated?) #t]
         [(deposit) (lambda (x) (set! balance (+ balance x)) balance)]
         [(withdraw) (lambda (x)
                       (if (>= balance x)
                           (begin (set! balance (- balance x)) balance)
                           "Insufficient funds"))]
         [else (error 'account "unknown request")])])))

(define (make-joint account old new)
  (unless (eq? #t (account old 'authenticated?)) (error 'make-joint "incorrect password"))
  (lambda (key request)
    (if (eq? key new) (account old request) (lambda (_) "Incorrect password"))))

(define (monte-carlo trials experiment)
  (unless (exact-positive-integer? trials) (error 'monte-carlo "expected positive trial count"))
  (/ (for/sum ([i (in-range trials)]) (if (experiment) 1 0)) trials))

(define (estimate-integral predicate x1 x2 y1 y2 trials [draw random])
  (define (sample lo hi) (+ lo (* (- hi lo) (draw))))
  (* (- x2 x1) (- y2 y1)
     (monte-carlo trials (lambda () (predicate (sample x1 x2) (sample y1 y2))))))

(define (make-rand state)
  (lambda (message)
    (case message
      [(generate) (set! state (modulo (+ (* 1664525 state) 1013904223) (expt 2 32))) state]
      [(reset) (lambda (seed) (set! state seed))]
      [else (error 'rand "unknown request")])))

(define (make-first-factor)
  (define previous 1)
  (lambda (x) (set! previous (* previous x)) previous))
;; Racket's ordinary pairs are immutable. These operations model textbook
;; car/cdr mutation only on mpairs. Immutable lists below are snapshots.
(provide reverse-chain! distinct-pairs tail-cycle? make-fifo make-path-table
         schedule-and transitions integrate-states request-states prefix)
(define (reverse-chain! chain)
  (let loop ([rest chain] [reversed '()])
    (if (null? rest) reversed
        (let ([next (mcdr rest)])
          (set-mcdr! rest reversed)
          (loop next rest)))))

(define (distinct-pairs root)
  (define visited (make-hasheq))
  (define (visit node)
    (unless (or (not (mpair? node)) (hash-has-key? visited node))
      (hash-set! visited node #t)
      (visit (mcar node))
      (visit (mcdr node))))
  (visit root)
  (hash-count visited))

(define (tail-cycle? chain)
  (define (next p) (and (mpair? p) (mcdr p)))
  (let loop ([slow chain] [fast chain])
    (define one (next slow))
    (define two (next (next fast)))
    (and (mpair? two) (or (eq? one two) (loop one two)))))

(define (make-fifo)
  (define front '())
  (define rear '())
  (lambda (message . args)
    (case message
      [(empty?) (null? front)]
      [(insert!)
       (define node (mcons (car args) '()))
       (if (null? front) (set! front node) (set-mcdr! rear node))
       (set! rear node)]
      [(delete!)
       (when (null? front) (error 'queue "empty queue"))
       (begin0 (mcar front)
         (set! front (mcdr front))
         (when (null? front) (set! rear '())))]
      [(items) (let loop ([p front])
                 (if (null? p) '() (cons (mcar p) (loop (mcdr p)))))]
      [else (error 'queue "unknown message")])))

(define (make-path-table same-key?)
  (struct branch (children value present?) #:mutable)
  (define root (branch '() #f #f))
  (define (find path insert?)
    (for/fold ([node root]) ([key path] #:break (not node))
      (define found (assoc key (branch-children node) same-key?))
      (cond [found (cdr found)]
            [insert?
             (define child (branch '() #f #f))
             (set-branch-children! node (cons (cons key child) (branch-children node)))
             child]
            [else #f])))
  (lambda (message keys . args)
    (case message
      [(put!)
       (define node (find keys #t))
       (set-branch-value! node (car args))
       (set-branch-present?! node #t)]
      [(get)
       (define node (find keys #f))
       (unless (and node (branch-present? node)) (error 'table "no value"))
       (branch-value node)]
      [else (error 'table "unknown message")])))

;; One time segment of the AND gate agenda. Sample at input change time.
(define (schedule-and inputs)
  (define agenda (make-fifo))
  (for ([sample inputs])
    (define bit (bitwise-and (car sample) (cadr sample)))
    (agenda 'insert! (lambda () bit)))
  (let fire ()
    (if (agenda 'empty?) '()
        (cons ((agenda 'delete!)) (fire)))))

;; Deterministic read/write interleavings; no hardware scheduling assumptions.
;; Each process reads x once per factor, then writes the product.
(define (transitions factors)
  (define (search value states)
    (if (andmap not states) (set value)
        (for/fold ([results (set)]) ([s states] [index (in-naturals)] #:when s)
          (define reads (car s))
          (define product (cdr s))
          (define reading? (positive? reads))
          (set-union results
                     (search (if reading? value product)
                             (list-set states index
                                       (and reading? (cons (sub1 reads) (* value product)))))))))
  (search 10 (map (lambda (n) (cons n 1)) factors)))

;; A stream cell has an eager head and a memoized promise for its tail.
(define (integrate-states deriv dt initial)
  (cons initial
        (delay (integrate-states deriv dt
                                 (map (lambda (x dx) (+ x (* dt dx)))
                                      initial (deriv initial))))))

(define (request-states update seed requests)
  (match requests
    ['() '()]
    [(cons 'generate rest)
     (define next (update seed))
     (cons next (delay (request-states update next rest)))]
    [(cons (list 'reset value) rest) (request-states update value rest)]))

(define (prefix stream count)
  (cond [(or (zero? count) (null? stream)) '()]
        [(= count 1) (list (car stream))]
        [else (cons (car stream) (prefix (force (cdr stream)) (sub1 count)))]))
;; Stream exercises. Only stream-cons delays the tail; procedure arguments are eager.
(define-syntax-rule (scons head tail) (cons head (delay tail)))
(define (stail s) (force (cdr s)))
(define (smap f . streams)
  (if (ormap null? streams) '()
      (scons (apply f (map car streams))
             (apply smap f (map stail streams)))))
(define (sfilter pred s)
  (cond [(null? s) '()]
        [(pred (car s)) (scons (car s) (sfilter pred (stail s)))]
        [else (sfilter pred (stail s))]))
(define (naturals n) (scons n (naturals (add1 n))))
(define ints (naturals 1))
(define (scale s k) (smap (lambda (x) (* x k)) s))
(define factorials (scons 1 (smap * (stail ints) factorials)))
(define (sums s)
  (if (null? s) '()
      (letrec ([out (scons (car s) (smap + (stail s) out))]) out)))
(define (merge-numbers s t)
  (define a (car s)) (define b (car t))
  (cond [(< a b) (scons a (merge-numbers (stail s) t))]
        [(> a b) (scons b (merge-numbers s (stail t)))]
        [else (scons a (merge-numbers (stail s) (stail t)))]))
(define smooth-numbers
  (scons 1 (merge-numbers (scale smooth-numbers 2)
                          (merge-numbers (scale smooth-numbers 3) (scale smooth-numbers 5)))))
(define (integrate-series s) (smap / s ints))
(define exp-series (scons 1 (integrate-series exp-series)))
(define cos-series (scons 1 (scale (integrate-series sin-series) -1)))
(define sin-series (scons 0 (integrate-series cos-series)))
(define (mul-series a b)
  (scons (* (car a) (car b))
         (smap + (scale (stail b) (car a)) (mul-series (stail a) b))))
(define (inverse-unit s)
  (unless (= 1 (car s)) (error 'inverse-unit "expected constant one"))
  (letrec ([x (scons 1 (scale (mul-series (stail s) x) -1))]) x))
(define (div-series a b)
  (when (zero? (car b)) (error 'div-series "zero constant term"))
  (define factor (/ 1 (car b)))
  (mul-series (scale a factor) (inverse-unit (scale b factor))))
(define (stream-limit s tol)
  (unless (positive? tol) (error 'stream-limit "nonpositive tolerance"))
  (let loop ([s s])
    (define tail (stail s))
    (if (< (abs (- (car s) (car tail))) tol) (car tail) (loop tail))))
(define (interleave s t)
  (if (null? s) t (scons (car s) (interleave t (stail s)))))
(define (all-pairs s t)
  (scons (list (car s) (car t))
         (interleave (smap (lambda (x) (list (car s) x)) (stail t))
                     (interleave (smap (lambda (x) (list x (car t))) (stail s))
                                 (all-pairs (stail s) (stail t))))))
(define (merge-weighted s t weight)
  (if (<= (weight (car s)) (weight (car t)))
      (scons (car s) (merge-weighted (stail s) t weight))
      (scons (car t) (merge-weighted s (stail t) weight))))
(define (weighted-pairs s t weight)
  (scons (list (car s) (car t))
         (merge-weighted (smap (lambda (x) (list (car s) x)) (stail t))
                         (weighted-pairs (stail s) (stail t) weight) weight)))
(define (sum-powers power)
  (lambda (pair) (apply + (map (lambda (x) (expt x power)) pair))))
(define (power-representations power minimum)
  (define weight (sum-powers power))
  (define (collect s)
    (define k (weight (car s)))
    (let group ([rest s] [found '()])
      (if (= (weight (car rest)) k)
          (group (stail rest) (cons (car rest) found))
          (if (>= (length found) minimum)
              (scons (cons k (reverse found)) (collect rest))
              (collect rest)))))
  (collect (weighted-pairs ints ints weight)))
(define (integral delayed initial dt)
  (scons initial
         (let ([s (force delayed)])
           (if (null? s) '()
               (integral (delay (stail s)) (+ initial (* dt (car s))) dt)))))
(define ((RC r c dt) i initial)
  (smap + (scale i r) (integral (delay (scale i (/ 1 c))) initial dt)))
(define (solve-second acceleration dt y0 v0)
  (define y (integral (delay v) y0 dt))
  (define v (integral (delay (smap acceleration v y)) v0 dt))
  y)
(define ((RLC r l c dt) v0 i0)
  (define v (integral (delay (scale i (- (/ 1 c)))) v0 dt))
  (define i (integral (delay (smap (lambda (v i) (/ (- v (* r i)) l)) v i)) i0 dt))
  (cons v i))
(define (area-estimates pred area points)
  (define hits (smap (lambda (point) (if (apply pred point) 1 0)) points))
  (scale (smap / (sums hits) ints) area))
(provide scons stail smap sfilter naturals ints factorials sums smooth-numbers
         exp-series cos-series sin-series mul-series div-series stream-limit all-pairs
         weighted-pairs power-representations integral RC solve-second RLC area-estimates)
;; Additional constructive solutions and boundary checks.
(provide append-chain! cyclic-tail/seen? make-deque make-squarer semaphore-counter
         ln2-stream accelerated-stream triples sign-change smooth-stream)
(define (append-chain! xs ys)
  (unless (mpair? xs) (error 'append-chain! "empty prefix"))
  (let loop ([p xs])
    (if (null? (mcdr p)) (set-mcdr! p ys) (loop (mcdr p))))
  xs)
(define (cyclic-tail/seen? xs)
  (define seen (make-hasheq))
  (let loop ([p xs])
    (cond [(not (mpair? p)) #f] [(hash-ref seen p #f) #t]
          [else (hash-set! seen p #t) (loop (mcdr p))])))

;; Node = (value . (previous . next)); the sentinel closes both ends.
(define (make-deque)
  (define sentinel (mcons #f (mcons #f #f)))
  (define (back n) (mcar (mcdr n)))
  (define (forward n) (mcdr (mcdr n)))
  (define (link! a b)
    (set-mcdr! (mcdr a) b)
    (set-mcar! (mcdr b) a))
  (link! sentinel sentinel)
  (lambda (op . args)
    (define first (forward sentinel))
    (define last (back sentinel))
    (case op
      [(empty?) (eq? first sentinel)]
      [(front-insert! rear-insert!)
       (define right (if (eq? op 'front-insert!) first sentinel))
       (define node (mcons (car args) (mcons #f #f)))
       (link! (back right) node)
       (link! node right)]
      [(front rear front-delete! rear-delete!)
       (when (eq? first sentinel) (error 'deque "empty deque"))
       (define n (if (memq op '(front front-delete!)) first last))
       (when (memq op '(front-delete! rear-delete!)) (link! (back n) (forward n)))
       (mcar n)]
      [else (error 'deque "unknown request")])))

;; The connectors supply the textbook messages has?, get, set!, forget!, connect!.
(define (make-squarer a b)
  (define (update)
    (cond [(b 'has?)
           (when (< (b 'get) 0) (error 'squarer "negative square"))
           (a 'set! (sqrt (b 'get)) self)]
          [(a 'has?) (b 'set! (sqr (a 'get)) self)]))
  (define (self message)
    (case message
      [(new) (update)]
      [(lost) (a 'forget! self) (b 'forget! self) (update)]))
  (a 'connect! self)
  (b 'connect! self)
  self)

;; Counting semaphore using Racket's atomic semaphore for the guard and wakeup.
(define (semaphore-counter n)
  (unless (exact-positive-integer? n) (error 'semaphore-counter "expected positive capacity"))
  (define guard (make-semaphore 1))
  (define wake (make-semaphore 0))
  (define free n)
  (define (acquire)
    (define ok? (call-with-semaphore guard (lambda ()
                  (and (> free 0) (begin (set! free (sub1 free)) #t)))))
    (unless ok? (semaphore-wait wake) (acquire)))
  (lambda (message)
    (case message
      [(acquire) (acquire)]
      [(release)
       (call-with-semaphore guard
         (lambda ()
           (when (= free n) (error 'semaphore-counter "unmatched release"))
           (set! free (add1 free))
           (semaphore-post wake)))]
      [else (error 'semaphore-counter "unknown request")])))

(define ln2-stream (sums (smap (lambda (n) (/ (if (odd? n) 1 -1) n)) ints)))
(define (euler s)
  (define a (car s)) (define b (car (stail s))) (define c (car (stail (stail s))))
  (scons (- c (/ (sqr (- c b)) (+ a (* -2 b) c))) (euler (stail s))))
(define (accelerated-stream s) (scons (car s) (accelerated-stream (euler s))))
(define (ordered-pairs s t)
  (scons (list (car s) (car t))
         (interleave (smap (lambda (j) (list (car s) j)) (stail t))
                     (ordered-pairs (stail s) (stail t)))))
(define (triples s t u)
  (scons (list (car s) (car t) (car u))
         (interleave (smap (lambda (pair) (cons (car s) pair)) (stail (ordered-pairs t u)))
                     (triples (stail s) (stail t) (stail u)))))
(define (sign-change now previous)
  (cond [(and (negative? previous) (not (negative? now))) 1]
        [(and (not (negative? previous)) (negative? now)) -1]
        [else 0]))
(define (smooth-stream s) (smap (lambda (a b) (/ (+ a b) 2)) s (scons 0 s)))
;; Textbook-style wire and agenda interface, injected so the gates can be tested
;; on simulated time. An agenda event captures the sampled bit before scheduling.
(provide make-logic-network make-connector averager c-constant c-product c-sum
         c-difference c-quotient)
(define (make-logic-network and-delay or-delay not-delay)
  (define clock 0)
  (define events '())
  (define (later delay action)
    ;; Stable sort keeps previously inserted events first when times tie.
    (set! events (sort (append events (list (cons (+ clock delay) action))) < #:key car)))
  (define (wire)
    (define bit 0)
    (define actions '())
    (lambda (message . args)
      (case message
        [(read) bit]
        [(write)
         (unless (= bit (car args))
           (set! bit (car args))
           (for-each (lambda (act) (act)) actions))]
        [(attach) (set! actions (cons (car args) actions)) ((car args))])))
  (define (gate f delay ins out)
    (define (act)
      (define next (apply f (map (lambda (w) (w 'read)) ins)))
      (later delay (lambda () (out 'write next))))
    (for-each (lambda (w) (w 'attach act)) ins))
  (define (and! a b out) (gate bitwise-and and-delay (list a b) out))
  (define (or! a b out) (gate bitwise-ior or-delay (list a b) out))
  (define (not! a out) (gate (lambda (x) (- 1 x)) not-delay (list a) out))
  (define (or-via-not! a b out)
    (define x (wire)) (define y (wire)) (define z (wire))
    (not! a x) (not! b y) (and! x y z) (not! z out))
  (define (half! a b sum carry)
    (define d (wire)) (define e (wire))
    (or! a b d) (and! a b carry) (not! carry e) (and! d e sum))
  (define (full! a b cin sum cout)
    (define mid (wire)) (define c1 (wire)) (define c2 (wire))
    (half! b cin mid c1) (half! a mid sum c2) (or! c1 c2 cout))
  (define (ripple! as bs ss carry)
    ;; Wires are listed least significant first.
    (unless (= (length as) (length bs) (length ss)) (error 'ripple! "unequal widths"))
    (let loop ([as as] [bs bs] [ss ss] [cin (wire)])
      (unless (null? as)
        (define cout (if (null? (cdr as)) carry (wire)))
        (full! (car as) (car bs) cin (car ss) cout)
        (loop (cdr as) (cdr bs) (cdr ss) cout))))
  (define (propagate)
    (unless (null? events)
      (define event (car events))
      (set! events (cdr events)) (set! clock (car event))
      ((cdr event)) (propagate)))
  (values wire or! or-via-not! ripple! propagate))

(define (make-connector)
  (define source #f) (define value #f) (define constraints '())
  (define (notify except message)
    (for ([c constraints] #:unless (eq? c except)) (c message)))
  (lambda (message . args)
    (case message
      [(has?) (and source #t)] [(get) value]
      [(set!)
       (match-define (list x who) args)
       (cond [(not source) (set! value x) (set! source who) (notify who 'new)]
             [(not (= x value)) (error 'connector "conflicting values")])]
      [(forget!)
       (when (eq? source (car args)) (set! source #f) (set! value #f) (notify (car args) 'lost))]
      [(connect!)
       (unless (memq (car args) constraints)
         (set! constraints (cons (car args) constraints))
         (when source ((car args) 'new)))])))

(define (relation op reverse-op a b c product?)
  (define (infer)
    (cond [(and product? (or (and (a 'has?) (zero? (a 'get)))
                             (and (b 'has?) (zero? (b 'get))))) (c 'set! 0 self)]
          [(and (a 'has?) (b 'has?)) (c 'set! (op (a 'get) (b 'get)) self)]
          [(and (a 'has?) (c 'has?)) (b 'set! (reverse-op (c 'get) (a 'get)) self)]
          [(and (b 'has?) (c 'has?)) (a 'set! (reverse-op (c 'get) (b 'get)) self)]))
  (define (self message)
    (when (eq? message 'lost)
      (for ([x (list a b c)]) (x 'forget! self)))
    (infer))
  (for ([x (list a b c)]) (x 'connect! self)))
(define (c-constant x) (define z (make-connector)) (z 'set! x 'constant) z)
(define (c-sum a b) (define z (make-connector)) (relation + - a b z #f) z)
(define (c-difference a b) (define z (make-connector)) (relation + - b z a #f) z)
(define (c-product a b) (define z (make-connector)) (relation * / a b z #t) z)
(define (c-quotient a b) (define z (make-connector)) (relation * / b z a #t) z)
(define (averager a b c) (relation * / c (c-constant 2) (c-sum a b) #t))
;; Atomic test-and-set alternative for exercise 3.47. The only shared update
;; of the guard is box-cas!; waiting takes place after releasing that guard.
(provide semaphore-cas serialized-exchange ordered-account)
(define (semaphore-cas n)
  (unless (exact-positive-integer? n) (error 'semaphore-cas "invalid capacity"))
  (define busy (box #f))
  (define free n)
  (define (with-guard proc)
    (let retry ()
      (if (box-cas! busy #f #t)
          (dynamic-wind void proc (lambda () (set-box! busy #f)))
          (begin (sleep 0) (retry)))))
  (lambda (message)
    (case message
      [(acquire)
       (let retry ()
         (unless (with-guard (lambda () (and (> free 0) (begin (set! free (sub1 free)) #t))))
           (sleep 0) (retry)))]
      [(release)
       (with-guard (lambda ()
                     (when (= free n) (error 'semaphore-cas "unmatched release"))
                     (set! free (add1 free))))]
      [else (error 'semaphore-cas "unknown request")])))

(struct numbered (id lock balance))
(define ordered-account
  (let ([counter 0] [guard (make-semaphore 1)])
    (lambda (balance)
      (call-with-semaphore guard
        (lambda ()
          (set! counter (add1 counter))
          (numbered counter (make-semaphore 1) (box balance)))))))
(define (serialized-exchange a b)
  (unless (eq? a b)
    (define first (if (< (numbered-id a) (numbered-id b)) a b))
    (define other (if (eq? first a) b a))
    (call-with-semaphore (numbered-lock first)
      (lambda ()
        (call-with-semaphore (numbered-lock other)
          (lambda ()
            (define old (unbox (numbered-balance a)))
            (set-box! (numbered-balance a) (unbox (numbered-balance b)))
            (set-box! (numbered-balance b) old)))))))
(define (account-snapshot a)
  (call-with-semaphore (numbered-lock a) (lambda () (unbox (numbered-balance a)))))
(provide account-snapshot)
