#lang racket
;; CEK snapshots, register driver, exceptions, preemptive THREADS and mailboxes.
(require racket/match "chapter05_syntax.rkt")
(provide (all-defined-out))
(struct closure (params body env) #:mutable #:transparent)
(struct reference (cell) #:transparent)
(struct captured (frames) #:transparent)
(struct callcc-primitive () #:transparent)
(struct mutex-value (closed? waiting) #:mutable #:transparent)
(struct semaphore-value (permits waiting) #:mutable #:transparent)
(struct condition-value (mutex waiting) #:mutable #:transparent)
(struct barrier-value (parties generation waiting) #:mutable #:transparent)
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
 (unless (exact-positive-integer? fuel) (error 'fuel "positive exact integer required"))
 (when (and private? (eq? scope 'dynamic)) (error 'run "private stores require lexical scope"))
 (define all (make-hash)) (define ready '()) (define current #f)
 (define next-id 0) (define final #f) (define final? #f) (define output '())
 (define log '()) (define max-depth 0) (define steps 0) (define switches 0) (define ends 0)
 (define mutexes '()) (define locations '())
 (define semaphores '()) (define conditions '()) (define barriers '())
 (define blocked-states '(mutex receive semaphore condition barrier))
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
    [(or (captured? v) (mutex-value? v) (semaphore-value? v)
         (condition-value? v) (barrier-value? v))
     (error 'copy "cannot transfer a mutex, synchronization object or captured continuation between private stores")]
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
;; BEGIN thread-synchronization
 ;; Each helper is one machine transition: no preemption inside queue updates.
 (define (acquire-mutex! m k)
  (if (mutex-value-closed? m)
   (begin
    (set-mutex-value-waiting! m (append (mutex-value-waiting m) (list current)))
    (suspend! (A k 52) 'mutex))
   (begin (set-mutex-value-closed?! m #t) (A k 52))))
 (define (release-mutex! m)
  (when (mutex-value-closed? m)
   (if (null? (mutex-value-waiting m))
    (set-mutex-value-closed?! m #f)
    (let ([th (car (mutex-value-waiting m))])
     (set-mutex-value-waiting! m (cdr (mutex-value-waiting m)))
     (enqueue! th))))) ; direct handoff keeps the mutex closed
 (define (synchronize op v k)
  (case op
   [(semaphore)
    (unless (exact-nonnegative-integer? v)
     (error op "nonnegative exact permit count required"))
    (define sem (semaphore-value v '()))
    (set! semaphores (cons sem semaphores)) (A k sem)]
   [(down)
    (unless (semaphore-value? v) (error op "semaphore required"))
    (if (positive? (semaphore-value-permits v))
     (begin
      (set-semaphore-value-permits! v (sub1 (semaphore-value-permits v)))
      (A k 52))
     (begin
      (set-semaphore-value-waiting! v (append (semaphore-value-waiting v) (list current)))
      (suspend! (A k 52) 'semaphore)))]
   [(up)
    (unless (semaphore-value? v) (error op "semaphore required"))
    (if (null? (semaphore-value-waiting v))
     (set-semaphore-value-permits! v (add1 (semaphore-value-permits v)))
     (let ([th (car (semaphore-value-waiting v))])
      (set-semaphore-value-waiting! v (cdr (semaphore-value-waiting v)))
      (enqueue! th))) ; transferred permit must not also increment the count
    (A k 53)]
   [(condition)
    (unless (mutex-value? v) (error op "mutex required"))
    (define c (condition-value v '()))
    (set! conditions (cons c conditions)) (A k c)]
   [(condition-wait)
    (unless (condition-value? v) (error op "condition required"))
    (define m (condition-value-mutex v))
    (unless (mutex-value-closed? m) (error op "associated mutex must be held"))
    (set-condition-value-waiting! v (append (condition-value-waiting v) (list current)))
    (release-mutex! m)
    (suspend! (state 'reacquire #f #f k m) 'condition)]
   [(condition-signal)
    (unless (condition-value? v) (error op "condition required"))
    (unless (null? (condition-value-waiting v))
     (define th (car (condition-value-waiting v)))
     (set-condition-value-waiting! v (cdr (condition-value-waiting v)))
     (enqueue! th)) ; Mesa: make ready; reacquire the mutex when scheduled
    (A k 53)]
   [(barrier)
    (unless (exact-positive-integer? v) (error op "positive exact party count required"))
    (define b (barrier-value v 0 '()))
    (set! barriers (cons b barriers)) (A k b)]
   [(barrier-wait)
    (unless (barrier-value? v) (error op "barrier required"))
    (define waiting (barrier-value-waiting v))
    (if (= (add1 (length waiting)) (barrier-value-parties v))
     (let ([generation (add1 (barrier-value-generation v))])
      (set-barrier-value-generation! v generation)
      (set-barrier-value-waiting! v '()) ; detach this generation before waking it
      (for ([th waiting])
       (set-thread-state! th (A (state-frames (thread-state th)) generation))
       (enqueue! th))
      (A k generation))
     (begin
      (set-barrier-value-waiting! v (append waiting (list current)))
      (suspend! (A k #f) 'barrier)))]))
;; END thread-synchronization
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
     [`(,(and op (or 'semaphore 'down 'up 'condition 'condition-wait
                       'condition-signal 'barrier 'barrier-wait)) ,arg)
      (E arg env (cons `(synchronize ,op) k))]
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
   [(state 'reacquire _ _ k m) (acquire-mutex! m k)]
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
          (acquire-mutex! v rest)]
         [(list 'signal)
          (unless (mutex-value? v) (error 'signal "mutex required"))
          (release-mutex! v) (A rest 53)]
         [`(synchronize ,op) (synchronize op v rest)]
         [(list 'kill)
          (define victim (hash-ref all v #f))
          (define found? (and victim (memq (thread-status victim) (cons 'ready blocked-states))))
          (when found?
           (set! ready (remq victim ready))
           (for ([m mutexes]) (set-mutex-value-waiting! m (remq victim (mutex-value-waiting m))))
           (for ([sem semaphores])
            (set-semaphore-value-waiting! sem (remq victim (semaphore-value-waiting sem))))
           (for ([c conditions])
            (set-condition-value-waiting! c (remq victim (condition-value-waiting c))))
           (for ([b barriers])
            (set-barrier-value-waiting! b (remq victim (barrier-value-waiting b))))
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
 (define blocked (filter (lambda (th) (memq (thread-status th) blocked-states)) (hash-values all)))
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
;; BEGIN synchronization-programs
(define semaphore-program
 "let s = semaphore(2) m = mutex() active = 0 peak = 0 in
  let worker = proc(id) begin
    down(s); wait(m);
    set active = add1(active);
    if greater?(active,peak) then set peak = active else 0;
    signal(m); yield();
    wait(m); set active = sub1(active); signal(m);
    up(s); send(parent(),id)
  end in begin
    spawn(worker); spawn(worker); spawn(worker); spawn(worker); spawn(worker);
    receive(); receive(); receive(); receive(); receive();
    list(peak,active)
  end")
(define condition-program
 "let m = mutex() buffer = 0 in let c = condition(m) in
  let consumer = proc(id)
    letrec await(dummy) =
      if zero?(buffer) then begin
        send(parent(),0); condition-wait(c); (await 0)
      end else buffer
    in begin
      wait(m);
      let value = (await 0) in begin signal(m); send(parent(),value) end
    end
  in begin
    spawn(consumer); receive();
    wait(m); condition-signal(c); signal(m);
    receive();
    wait(m); set buffer = 44; condition-signal(c);
    yield(); set buffer = 45; signal(m);
    receive()
  end")
(define barrier-program
 "let b = barrier(3) in let worker = proc(id) begin
    print(list(id,barrier-wait(b)));
    print(list(id,barrier-wait(b)));
    send(parent(),id)
  end in begin
    spawn(worker); spawn(worker);
    let first = barrier-wait(b) in let second = barrier-wait(b) in begin
      receive(); receive(); list(first,second)
    end
  end")
;; END synchronization-programs
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
