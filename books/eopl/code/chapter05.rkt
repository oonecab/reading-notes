#lang racket
;; CEK snapshots, register driver, exceptions, preemptive THREADS and mailboxes.
(require racket/match "chapter05_syntax.rkt")
(provide (all-defined-out))
(struct closure (params body env) #:mutable #:transparent)
(struct reference (cell) #:transparent)
(struct captured (frames) #:transparent)
(struct callcc-primitive () #:transparent)
(struct mutex-value (closed? waiting) #:mutable #:transparent)
;; BEGIN snapshots
(struct state (pc exp env frames value) #:transparent)
(struct thread (id parent state ticks status mailbox store) #:mutable #:transparent)
(struct result (value output metrics trace threads) #:transparent)
(define (E e env k) (state 'eval e env k #f))
(define (A k v) (state 'apply #f #f k v))
(define (I p vs env k) (state 'invoke p env k vs))
(define (R k v) (state 'raise #f #f k v))
;; END snapshots
(define (run source #:implicit? [implicit? #f] #:private-store? [private? #f] #:quantum [quantum 1000000]
             #:preserve-ticks? [preserve-ticks? #f] #:thread-ids? [ids? #f]
             #:exception-mode [exception-mode 'abort] #:scope [scope 'lexical]
             #:driver [driver 'loop] #:handler-lookup [handler-lookup 'search] #:numeric? [numeric? #f]
             #:trace? [trace? #f] #:fuel [fuel 2000000])
 (unless (exact-positive-integer? quantum) (error 'scheduler "positive quantum required"))
 (when (and private? (eq? scope 'dynamic)) (error 'run "private stores require lexical scope"))
 (define all (make-hash)) (define ready '()) (define current #f)
 (define next-id 0) (define final #f) (define final? #f) (define output '())
 (define log '()) (define max-depth 0) (define steps 0) (define switches 0) (define ends 0)
 (define mutexes '()) (define locations '())
 (define handler-cache (make-hasheq))
 (define handler-hops 0)
 (define (nearest k)
  (hash-ref! handler-cache k (lambda ()
   (cond [(null? k) '()] [(eq? (caar k) 'try) k] [else (nearest (cdr k))]))))
 (define (newref-for th v)
  (define b (box v))
  (if private? (set-thread-store! th (cons b (thread-store th)))
      (set! locations (cons b locations)))
  (reference b))
 (define (newref v) (newref-for current v))
 (define (readref r)
  (unless (and (reference? r) (memq (reference-cell r)
          (if private? (thread-store current) locations))) (error 'deref "reference required"))
  (unbox (reference-cell r)))
 (define (writeref r v) (readref r) (set-box! (reference-cell r) v))
 ;; Copy each graph edge once; placeholders preserve aliases and recursive closures.
 (define (copy-between value sender receiver)
  (define memo (make-hasheq))
  (define (cell old)
   (cond [(hash-ref memo old #f) => values]
    [else (define new (box #f)) (hash-set! memo old new)
     (set-box! new (copy (unbox old))) new]))
  (define (environment env)
   (map (lambda (entry) (cons (car entry) (cell (cdr entry)))) env))
  (define (copy v)
   (cond
    [(reference? v)
     (define old (reference-cell v))
     (unless (memq old (thread-store sender)) (error 'copy "foreign reference"))
     (cond [(hash-ref memo v #f) => values]
      [(hash-ref memo old #f) => (lambda (b) (reference b))]
      [else (define r (newref-for receiver #f))
       (hash-set! memo old (reference-cell r)) (hash-set! memo v r)
       (set-box! (reference-cell r) (copy (unbox old))) r])]
    [(closure? v)
     (cond [(hash-ref memo v #f) => values]
      [else (define p (closure (closure-params v) (closure-body v) #f))
       (hash-set! memo v p) (set-closure-env! p (environment (closure-env v))) p])]
    [(or (captured? v) (mutex-value? v))
     (error 'copy "cannot transfer a mutex or captured continuation between private stores")]
    [(pair? v) (cons (copy (car v)) (copy (cdr v)))]
    [else v]))
  (copy value))
 (define (extend xs vs env)
  (unique! xs) (arity! xs vs)
  (append (map (lambda (x v) (cons x (box (if implicit? (newref v) v)))) xs vs) env))
 (define (binding env x)
  (or (assq x env) (error 'lookup "unbound variable: ~a" x)))
 (define (lookup env x)
  (define v (unbox (cdr (binding env x)))) (if implicit? (readref v) v))
 (define (enqueue! th [reset? #t])
  (when (eq? (thread-status th) 'ready) (error 'scheduler "duplicate enqueue"))
  (when reset? (set-thread-ticks! th quantum))
  (set-thread-status! th 'ready) (set! ready (append ready (list th))))
 (define (new-thread! parent s)
  (define id next-id) (set! next-id (add1 next-id))
  (define th (thread id parent s quantum 'new '() '())) (hash-set! all id th)
  (when trace? (set! log (cons `(create ,id parent ,parent) log))) th)
 (define (suspend! s status)
  (set-thread-state! current s) (set-thread-status! current status) #f)
 (define (next!)
  (cond [(null? ready) #f]
   [else (set! current (car ready)) (set! ready (cdr ready))
    (set-thread-status! current 'running) (set! switches (add1 switches))
    (thread-state current)]))
 (define (collect es env k kind data)
  (if (null? es) (finish kind data '() env k)
   (E (car es) env (cons `(collect ,kind ,data ,(cdr es) () ,env) k))))
 (define (invoke p vs env k)
  (cond [(callcc-primitive? p) (arity! '(p) vs) (invoke (car vs) (list (captured k)) env k)]
   [(captured? p) (arity! '(v) vs) (A (captured-frames p) (car vs))]
   [(closure? p)
    (if (= (length (closure-params p)) (length vs))
     (E (closure-body p) (extend (closure-params p) vs
       (if (eq? scope 'dynamic) env (closure-env p))) k)
     (R k 1001))]
   [else (error 'call "procedure required")]))
 (define (finish kind data vs env k)
  (case kind
   [(prim) (if (and (eq? data '/) (zero? (cadr vs))) (R k 1002) (A k (primitive data vs)))]
   [(list) (A k vs)]
   [(let) (E (cadr data) (extend (car data) vs env) k)]
   [(call) (I (car vs) (cdr vs) env k)]
   [(throw) (unless (captured? (cadr vs)) (error 'throw "continuation required"))
             (A (captured-frames (cadr vs)) (car vs))]
   [(setref) (writeref (car vs) (cadr vs)) (A k 23)]
   [(send)
    (define dest (hash-ref all (car vs) #f))
    (unless (and dest (not (memq (thread-status dest) '(done killed)))) (error 'send "live thread required"))
    (define delivered (if private? (copy-between (cadr vs) current dest) (cadr vs)))
    (if (eq? (thread-status dest) 'receive)
     (begin (set-thread-state! dest (A (state-frames (thread-state dest)) delivered)) (enqueue! dest))
     (set-thread-mailbox! dest (append (thread-mailbox dest) (list delivered))))
    (A k 54)]
   [else (error 'collect "unknown collection ~a" kind)]))
;; BEGIN exception-unwind
 (define (handle k v)
  (define resume k)
  (let search ([frames (if (eq? handler-lookup 'cached) (nearest k) k)])
   (set! handler-hops (add1 handler-hops))
   (cond [(null? frames) (error 'raise "uncaught exception: ~s" v)]
    [else
     (match (car frames)
      [`(try ,xs ,handler ,saved-env)
       (define outer (cdr frames))
       (define vals (if (= (length xs) 2) (list v (captured resume)) (list v)))
       (E handler (extend xs vals saved-env)
         (if (eq? exception-mode 'resume) resume outer))]
      [_ (search (cdr frames))])])) )
;; END exception-unwind
 (define (step s)
  (set! steps (add1 steps)) (when (> steps fuel) (error 'run "fuel exhausted"))
  (define k (state-frames s))
  (when (eq? handler-lookup 'cached) (nearest k))
  (set! max-depth (max max-depth (add1 (length k))))
  (when trace? (set! log (cons (list (thread-id current) (state-pc s)
    (if (eq? (state-pc s) 'eval) (car (state-exp s)) (state-value s)) k) log)))
  (match s
   [(state 'eval e env k _)
    (match e
     [`(num ,n) (A k n)] [`(var ,x) (A k (lookup env x))]
     [`(proc ,xs ,b) (unique! xs) (A k (closure xs b env))]
     [`(prim ,op . ,es) (collect es env k 'prim op)]
     [`(list . ,es) (collect es env k 'list #f)]
     [`(if ,t ,a ,b) (E t env (cons `(if ,a ,b ,env) k))]
     [`(let ,xs ,es ,b) (unique! xs) (collect es env k 'let (list xs b))]
     [`(letrec ,ns ,pss ,bs ,b)
      (define rho (extend ns (map (lambda (_) #f) ns) env))
      (for ([n ns] [ps pss] [body bs])
       (define slot (cdr (binding rho n))) (define p (closure ps body rho))
       (if implicit? (writeref (unbox slot) p) (set-box! slot p)))
      (E b rho k)]
     [`(call ,f ,es) (collect (cons f es) env k 'call #f)]
     [`(begin ,e1 . ,rest)
      (E e1 env (if (null? rest) k (cons `(begin ,rest ,env) k)))]
     [`(set ,x ,rhs)
      (unless implicit? (error 'set "requires implicit references"))
      (E rhs env (cons `(set ,(unbox (cdr (binding env x)))) k))]
     [`(try ,body ,xs ,handler)
      (unless (memv (length xs) '(1 2)) (error 'try "one or two handler parameters required"))
      (E body env (cons `(try ,xs ,handler ,env) k))]
     [`(raise ,arg) (E arg env (cons '(raise) k))]
     [`(letcc ,x ,body) (E body (extend (list x) (list (captured k)) env) k)]
     [`(throw ,arg ,target) (collect (list arg target) env k 'throw #f)]
     [`(newref ,arg) (E arg env (cons '(newref) k))]
     [`(deref ,arg) (E arg env (cons '(deref) k))]
     [`(setref ,a ,b) (collect (list a b) env k 'setref #f)]
     [`(print ,arg) (E arg env (cons '(print) k))]
     [`(spawn ,arg) (E arg env (cons '(spawn) k))]
     [`(yield)
      (suspend! (A k 99) 'yielded) (enqueue! current (not preserve-ticks?)) #f]
     [`(mutex) (define m (mutex-value #f '())) (set! mutexes (cons m mutexes)) (A k m)]
     [`(wait ,arg) (E arg env (cons '(wait) k))]
     [`(signal ,arg) (E arg env (cons '(signal) k))]
     [`(kill ,arg) (E arg env (cons '(kill) k))]
     [`(send ,a ,b) (collect (list a b) env k 'send #f)]
     [`(receive)
      (if (pair? (thread-mailbox current))
       (let ([v (car (thread-mailbox current))])
        (set-thread-mailbox! current (cdr (thread-mailbox current))) (A k v))
       (suspend! (A k #f) 'receive))]
     [`(self) (A k (thread-id current))] [`(parent) (A k (thread-parent current))]
     [_ (error 'eval "unknown form ~s" e)])]
   [(state 'invoke p env k vs) (invoke p vs env k)]
   [(state 'raise _ _ k v) (handle k v)]
   [(state 'apply _ _ k v)
    (cond [(zero? (thread-ticks current))
           (suspend! s 'expired) (enqueue! current) #f]
     [else
      (set-thread-ticks! current (sub1 (thread-ticks current)))
      (cond [(null? k)
       (when (= (thread-id current) 0) (set! final v) (set! final? #t) (set! ends (add1 ends)))
       (suspend! s 'done)]
       [else
        (define rest (cdr k))
        (match (car k)
         [`(collect ,kind ,data ,es ,rev ,saved-env)
          (define vals (cons v rev))
          (if (null? es) (finish kind data (reverse vals) saved-env rest)
           (E (car es) saved-env (cons `(collect ,kind ,data ,(cdr es) ,vals ,saved-env) rest)))]
         [`(if ,a ,b ,saved-env) (E (if (truth v numeric?) a b) saved-env rest)]
         [`(begin ,es ,saved-env) (E `(begin ,@es) saved-env rest)]
         [`(set ,loc) (writeref loc v) (A rest 27)]
         [`(try . ,_) (A rest v)] [(list 'raise) (R rest v)]
         [(list 'newref) (A rest (newref v))] [(list 'deref) (A rest (readref v))]
         [(list 'print) (set! output (cons v output)) (A rest 38)]
         [(list 'spawn)
          (unless (closure? v) (error 'spawn "procedure required"))
          (define child (new-thread! (thread-id current) #f))
          (define child-procedure (if private? (copy-between v current child) v))
          (set-thread-state! child (I child-procedure (list (if ids? (thread-id child) 28)) '() '()))
          (enqueue! child) (A rest (if ids? (thread-id child) 73))]
         [(list 'wait)
          (unless (mutex-value? v) (error 'wait "mutex required"))
          (if (mutex-value-closed? v)
           (begin
            (set-mutex-value-waiting! v (append (mutex-value-waiting v) (list current)))
            (suspend! (A rest 52) 'mutex))
           (begin (set-mutex-value-closed?! v #t) (A rest 52)))]
         [(list 'signal)
          (unless (mutex-value? v) (error 'signal "mutex required"))
          (when (mutex-value-closed? v)
           (if (null? (mutex-value-waiting v)) (set-mutex-value-closed?! v #f)
            (let ([th (car (mutex-value-waiting v))])
             (set-mutex-value-waiting! v (cdr (mutex-value-waiting v)))
             (enqueue! th)))) ; handoff: keep the mutex closed
          (A rest 53)]
         [(list 'kill)
          (define victim (hash-ref all v #f))
          (define found? (and victim (memq (thread-status victim) '(ready mutex receive))))
          (when found?
           (set! ready (remq victim ready))
           (for ([m mutexes]) (set-mutex-value-waiting! m (remq victim (mutex-value-waiting m))))
           (set-thread-status! victim 'killed))
          (A rest (and found? #t))]
         [_ (error 'apply "unknown frame ~s" (car k))])])])]
   [_ (error 'machine "invalid state")]))
 (define main (new-thread! -1 #f)) (set! current main)
 (set-thread-status! main 'running)
 (define initial-env (extend '(i v x call-with-current-continuation) (list 1 5 10 (callcc-primitive)) '()))
 (define initial (E (if (string? source) (parse source) source) initial-env '()))
;; BEGIN register-driver
 (define (continue s)
  (define next (or s (next!)))
  (cond [(not next) (void)]
   [(eq? driver 'thunk)
    (let trampoline ([bounce (lambda () (step next))])
     (define b (bounce))
     (define ns (or b (next!)))
     (when ns (trampoline (lambda () (step ns)))))]
   [else (continue (step next))]))
 (continue initial)
;; END register-driver
 (define blocked (filter (lambda (th) (memq (thread-status th) '(mutex receive))) (hash-values all)))
 (unless final? (if (pair? blocked) (error 'scheduler "deadlock before main result")
                    (error 'scheduler "main thread terminated without value")))
 (result final (reverse output)
  (hash 'steps steps 'max-continuation max-depth 'end-count ends 'switches switches
        'blocked (length blocked) 'handler-hops handler-hops
        'locations (if private? (for/sum ([th (in-hash-values all)]) (length (thread-store th))) (length locations))
        'private-stores private?)
  (reverse log) (for/hash ([(id th) (in-hash all)]) (values id (thread-status th)))))
;; BEGIN private-store-example
(define private-counter-program
 "let owner = spawn(proc(id)
    let x = 0 in begin
      set x = +(x,receive());
      set x = +(x,receive());
      set x = +(x,receive());
      send(parent(),x)
    end)
  in begin
    spawn(proc(id) send(owner,1));
    spawn(proc(id) send(owner,1));
    spawn(proc(id) send(owner,1));
    receive()
  end")
(define (run-private-counter [quantum 100])
 (run private-counter-program #:implicit? #t #:private-store? #t
      #:thread-ids? #t #:quantum quantum))
;; END private-store-example
(define (translate-callcc source)
 (define count 0)
 (define (fresh prefix) (set! count (add1 count)) (string->symbol (format "~a%cc~a" prefix count)))
 (define primitive-name (fresh 'callcc))
 (define (go e)
  (match e
   [`(letcc ,x ,body) `(call (var ,primitive-name) ((proc (,x) ,(go body))))]
   [`(throw ,a ,b)
    (define v (fresh 'value)) (define target (fresh 'target))
    `(let (,v) (,(go a)) (let (,target) (,(go b)) (call (var ,target) ((var ,v)))))]
   [`(call ,f ,es) `(call ,(go f) ,(map go es))]
   [`(proc ,ps ,b) `(proc ,ps ,(go b))]
   [`(let ,xs ,es ,b) `(let ,xs ,(map go es) ,(go b))]
   [`(letrec ,ns ,pss ,bs ,b) `(letrec ,ns ,pss ,(map go bs) ,(go b))]
   [`(try ,b ,xs ,h) `(try ,(go b) ,xs ,(go h))]
   [(? pair?) (map go e)] [_ e]))
 `(let (,primitive-name) ((var call-with-current-continuation))
    ,(go (if (string? source) (parse source) source))))
(module+ main
 (define r (run "-(-(44,11),3)" #:trace? #t))
 (printf "machine: ~s; max-continuation=~a; end-count=~a\n" (result-value r)
  (hash-ref (result-metrics r) 'max-continuation) (hash-ref (result-metrics r) 'end-count)))
