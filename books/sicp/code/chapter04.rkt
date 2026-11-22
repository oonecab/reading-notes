#lang racket
(require racket/stream)
(provide fresh-environment evaluate actual amb-values query instantiate unify)

;; A frame maps names to cells. A closure retains its defining frame chain.
(struct closure (parameters body environment))
(struct delayed (expression environment state value) #:mutable)
(define unassigned (gensym 'unassigned))
(define primitives
  (hash '+ + '- - '* * '/ / '= = '< < '> > '<= <= '>= >=
        'cons cons 'car car 'cdr cdr 'cadr cadr 'null? null? 'list list 'eq? eq?
        'equal? equal? 'not not 'remainder remainder 'abs abs))
(define (fresh-environment)
  (list (make-hasheq (for/list ([(name proc) (in-hash primitives)])
                       (cons name (box proc))))))
(define (cell name env)
  (or (for/or ([frame env]) (hash-ref frame name #f))
      (error 'lookup "unbound: ~a" name)))
(define (bind! name value frame)
  (set-box! (hash-ref! frame name (lambda () (box unassigned))) value))
(define (extend names values env)
  (unless (= (length names) (length values)) (error 'apply "arity mismatch"))
  (cons (make-hasheq (map cons names (map box values))) env))
(define (force-value v)
  (match v
    [(delayed exp env 'by-name _) (actual exp env 'mixed)]
    [(delayed exp env 'waiting _)
     (set-delayed-state! v 'forcing)
     (with-handlers ([exn? (lambda (e) (set-delayed-state! v 'waiting) (raise e))])
       (define result (actual exp env (if (eq? (delayed-value v) 'mixed) 'mixed 'lazy)))
       (set-delayed-value! v result)
       (set-delayed-environment! v #f)
       (set-delayed-expression! v #f)
       (set-delayed-state! v 'done)
       result)]
    [(delayed _ _ 'forcing _) (error 'force "recursive demand")]
    [(delayed _ _ 'done result) result]
    [_ v]))
(define (actual exp env [mode 'strict]) (force-value (evaluate exp env mode)))
(define (evaluate exp env [mode 'strict])
  (define (ev x) (evaluate x env mode))
  (define (value x) (actual x env mode))
  (match (expand-form exp)
    [(? symbol?) (define v (unbox (cell exp env)))
                 (when (eq? v unassigned) (error 'lookup "unassigned: ~a" exp)) v]
    [(or (? number?) (? string?) (? boolean?)) exp]
    [`(quote ,datum) datum]
    [`(if ,p ,yes ,no) (ev (if (value p) yes no))]
    [`(lambda ,names ,body ...) (closure names (scan-out-defines body) env)]
    [`(make-unbound! ,name)
     (unless (hash-has-key? (car env) name) (error 'make-unbound! "no local binding"))
     (hash-remove! (car env) name) 'ok]
    [`(begin ,first ,rest ...) (for/last ([x (cons first rest)]) (ev x))]
    [`(define (,name . ,params) . ,body) (ev `(define ,name (lambda ,params ,@body)))]
    [`(define ,name ,rhs) (bind! name (ev rhs) (car env)) 'ok]
    [`(set! ,name ,rhs) (set-box! (cell name env) (ev rhs)) 'ok]
    [`(let ,bindings . ,body)
     (ev `((lambda ,(map car bindings) ,@body) ,@(map cadr bindings)))]
    [`(letrec ,bindings . ,body)
     (define inner (extend (map car bindings) (map (lambda (_) unassigned) bindings) env))
     (for ([b bindings]) (evaluate `(set! ,@b) inner mode))
     (evaluate `(begin ,@body) inner mode)]
    [(cons operator operands)
     (match (value operator)
       [(closure names body outer)
        (unless (= (length names) (length operands)) (error 'apply "arity mismatch"))
        (define args
          (for/list ([name names] [x operands])
            (cond [(eq? mode 'lazy) (delayed x env 'waiting 'lazy)]
                  [(and (eq? mode 'mixed) (pair? name))
                   (match name
                     [(list _ 'lazy) (delayed x env 'by-name #f)]
                     [(list _ 'lazy-memo) (delayed x env 'waiting 'mixed)]
                     [_ (error 'apply "unknown evaluation strategy")])]
                  [else (value x)])))
        (evaluate `(begin ,@body) (extend (map (lambda (n) (if (pair? n) (car n) n)) names) args outer) mode)]
       [(? procedure? primitive) (apply primitive (map value operands))]
       [_ (error 'apply "not a procedure")])]
    [_ (error 'evaluate "invalid expression: ~a" exp)]))

;; Success receives a result and the continuation for the remaining search.
;; Every ordinary assignment installs its own restoration on that failure path.
(define (amb-values expression [env (fresh-environment)] #:limit [limit +inf.0])
  (define (search exp env yes no)
    (define (args xs success fail)
      (if (null? xs) (success '() fail)
          (search (car xs) env
                  (lambda (v next)
                    (args (cdr xs) (lambda (vs again) (success (cons v vs) again)) next))
                  fail)))
    (match (expand-form exp)
      [`(amb . ,options)
       (let try ([xs options])
         (if (null? xs) (no) (search (car xs) env yes (lambda () (try (cdr xs))))))]
      [`(ramb . ,options) (search (cons 'amb (shuffle options)) env yes no)]
      [`(require ,p) (search p env (lambda (v next) (if v (yes 'ok next) (next))) no)]
      [`(if ,p ,a ,b) (search p env (lambda (v next) (search (if v a b) env yes next)) no)]
      [`(if-fail ,a ,b) (search a env yes (lambda () (search b env yes no)))]
      [`(begin ,a) (search a env yes no)]
      [`(begin ,a ,b . ,rest)
       (search a env (lambda (_ next) (search `(begin ,b ,@rest) env yes next)) no)]
      [`(letrec ,bs . ,body)
       (define next-env (extend (map car bs) (map (lambda (_) unassigned) bs) env))
       (search `(begin ,@(map (lambda (b) `(set! ,@b)) bs) ,@body) next-env yes no)]
      [`(let ,bs . ,body) (search `((lambda ,(map car bs) ,@body) ,@(map cadr bs)) env yes no)]
      [`(define (,name . ,params) . ,body)
       (search `(define ,name (lambda ,params ,@body)) env yes no)]
      [`(define ,name ,x)
       (search x env (lambda (v next) (bind! name v (car env)) (yes 'ok next)) no)]
      [`(,(and op (or 'set! 'permanent-set!)) ,name ,x)
       (search x env (lambda (v next)
                       (define place (cell name env)) (define old (unbox place))
                       (set-box! place v)
                       (yes 'ok (if (eq? op 'set!)
                                    (lambda () (set-box! place old) (next)) next))) no)]
      [(or `(quote ,_) `(lambda . ,_) (? symbol?) (? number?) (? string?) (? boolean?))
       (yes (evaluate exp env) no)]
      [(cons f xs)
       (search f env (lambda (proc next)
                       (args xs (lambda (vals again)
                                  (match proc
                                    [(closure names body outer)
                                     (search `(begin ,@body) (extend names vals outer) yes again)]
                                    [(? procedure?) (yes (apply proc vals) again)])) next)) no)]))
  (let/ec stop
    (define found '())
    (when (zero? limit) (stop '()))
    (search expression env
            (lambda (v next) (set! found (cons v found))
              (when (= (length found) limit) (stop (reverse found))) (next))
            (lambda () (reverse found)))))

;; Logic variables start with ?. Frames are immutable; #f represents failure.
(define (variable? x) (and (symbol? x) (string-prefix? (symbol->string x) "?")))
(define (instantiate x frame)
  (cond [(and (variable? x) (hash-has-key? frame x)) (instantiate (hash-ref frame x) frame)]
        [(pair? x) (cons (instantiate (car x) frame) (instantiate (cdr x) frame))]
        [else x]))
(define (occurs? x y)
  (or (eq? x y) (and (pair? y) (or (occurs? x (car y)) (occurs? x (cdr y))))))
(define (unify x y frame)
  (and frame
       (let ([a (instantiate x frame)] [b (instantiate y frame)])
         (cond [(equal? a b) frame]
               [(variable? a) (and (not (occurs? a b)) (hash-set frame a b))]
               [(variable? b) (unify b a frame)]
               [(and (pair? a) (pair? b))
                (unify (cdr a) (cdr b) (unify (car a) (car b) frame))]
               [else #f]))))
(define (interleave left right)
  (stream-lazy (if (stream-empty? left) (force right)
                   (stream-cons (stream-first left)
                                (interleave (force right) (delay (stream-rest left)))))))
(define (flat-search f xs)
  (stream-lazy (if (stream-empty? xs) empty-stream
                   (interleave (f (stream-first xs)) (delay (flat-search f (stream-rest xs)))))))
(define (fresh-rule rule)
  (define mapping (make-hasheq))
  (define (rename x)
    (cond [(variable? x) (hash-ref! mapping x (lambda () (gensym x)))]
          [(pair? x) (cons (rename (car x)) (rename (cdr x)))] [else x]))
  (rename rule))
(define (query goal database [frame (hash)])
  (define (ask g fr) (query g database fr))
  (match goal
    ['(always-true) (stream frame)]
    [`(and . ,goals) (for/fold ([states (stream frame)]) ([g goals])
                        (flat-search (lambda (fr) (ask g fr)) states))]
    [`(or . ,goals) (flat-search (lambda (g) (ask g frame)) goals)]
    [`(not ,g) (if (stream-empty? (ask g frame)) (stream frame) empty-stream)]
    [`(unique ,g)
     (define answers (ask g frame))
     (if (and (not (stream-empty? answers)) (stream-empty? (stream-rest answers)))
         answers empty-stream)]
    [`(lisp-value ,op . ,args)
     (define values (instantiate args frame))
     (define (ground? x) (if (pair? x) (and (ground? (car x)) (ground? (cdr x))) (not (variable? x))))
     (unless (ground? values) (error 'lisp-value "unbound argument"))
     (define pred (hash-ref (hash '< < '> > '= = 'equal? equal?) op))
     (if (apply pred values) (stream frame) empty-stream)]
    [_ (flat-search
        (lambda (entry)
          (match (fresh-rule entry)
            [`(rule ,head ,body ...) (define fr (unify goal head frame))
                                     (if fr (ask `(and ,@body) fr) empty-stream)]
            [fact (define fr (unify goal fact frame)) (if fr (stream fr) empty-stream)]))
        database)]))
(provide analyze-expression operands-left operands-right scan-out-defines)

;; Evaluate one argument before recursing. Building the result list never
;; changes positional argument order, even for a right-to-left traversal.
(define (operands-left expressions run)
  (if (null? expressions) '()
      (let ([first (run (car expressions))])
        (cons first (operands-left (cdr expressions) run)))))
(define (operands-right expressions run)
  (if (null? expressions) '()
      (let ([rest (operands-right (cdr expressions) run)])
        (cons (run (car expressions)) rest))))
(define (scan-out-defines body)
  (define-values (defs expressions)
    (partition (lambda (x) (and (pair? x) (eq? (car x) 'define))) body))
  (define bindings
    (for/list ([d defs])
      (match d
        [`(define (,name . ,params) . ,actions) (list name `(lambda ,params ,@actions))]
        [`(define ,name ,exp) (list name exp)])))
  (if (null? defs) body (list `(letrec ,bindings ,@expressions))))

;; The analyzer returns an environment procedure. The host calls only compiled
;; closures and explicitly installed primitives, never evaluates guest syntax.
(struct compiled (names run env))
(define (analyze-expression exp)
  (define (seq body)
    (define parts (map analyze-expression body))
    (lambda (env) (for/last ([p parts]) (p env))))
  (match exp
    [(? symbol?) (lambda (env) (unbox (cell exp env)))]
    [(or (? number?) (? string?) (? boolean?)) (lambda (_) exp)]
    [`(quote ,x) (lambda (_) x)]
    [`(lambda ,names . ,body)
     (define run (seq body)) (lambda (env) (compiled names run env))]
    [`(if ,p ,a ,b)
     (define test (analyze-expression p))
     (define yes (analyze-expression a)) (define no (analyze-expression b))
     (lambda (env) ((if (test env) yes no) env))]
    [`(begin . ,body) (seq body)]
    [`(define (,name . ,params) . ,body)
     (analyze-expression `(define ,name (lambda ,params ,@body)))]
    [`(define ,name ,x)
     (define rhs (analyze-expression x))
     (lambda (env) (bind! name (rhs env) (car env)) 'ok)]
    [`(set! ,name ,x)
     (define rhs (analyze-expression x))
     (lambda (env) (set-box! (cell name env) (rhs env)) 'ok)]
    [`(let ,bs . ,body) (analyze-expression `((lambda ,(map car bs) ,@body) ,@(map cadr bs)))]
    [(cons f xs)
     (define op (analyze-expression f)) (define args (map analyze-expression xs))
     (lambda (env)
       (define proc (op env)) (define vals (map (lambda (run) (run env)) args))
       (match proc
         [(compiled names run outer) (run (extend names vals outer))]
         [(? procedure?) (apply proc vals)]
         [_ (error 'analyzed-apply "not a procedure")]))]))
(define (expand-form exp)
  (match exp
    [`(and) #t] [`(and ,x) x]
    [`(and ,x . ,xs) `(if ,x (and ,@xs) #f)]
    [`(or) #f] [`(or ,x) x]
    [`(or ,x . ,xs) (define v (gensym)) `(let ((,v ,x)) (if ,v ,v (or ,@xs)))]
    [`(cond) #f]
    [`(cond (else . ,body)) `(begin ,@body)]
    [`(cond (,test => ,receiver) . ,tail)
     (define v (gensym)) `(let ((,v ,test)) (if ,v (,receiver ,v) (cond ,@tail)))]
    [`(cond (,test . ,body) . ,tail)
     (when (eq? test 'else) (error 'cond "else must be last"))
     (if (null? body) `(or ,test (cond ,@tail)) `(if ,test (begin ,@body) (cond ,@tail)))]
    [`(let* () . ,body) `(let () ,@body)]
    [`(let* (,b . ,bs) . ,body) `(let (,b) (let* ,bs ,@body))]
    [`(let ,(? symbol? name) ,bs . ,body)
     `((letrec ((,name (lambda ,(map car bs) ,@body))) ,name) ,@(map cadr bs))]
    [`(unless ,condition ,usual ,exception) `(if ,condition ,exception ,usual)]
    [`(while ,condition . ,body)
     (define loop (gensym)) `(let ,loop () (if ,condition (begin ,@body (,loop)) 'done))]
    [_ exp]))
(provide scoped-answers)
;; Depth-first query adapter (4.78–79). A term carries the lexical scope of
;; its occurrence. Rule text is reused unchanged in every rule invocation.
(struct scoped (term scope) #:transparent)
(define (scoped-answers goal projection database #:limit [limit +inf.0])
  (define top (gensym 'top))
  (define (lookup term frame)
    (if (and (variable? (scoped-term term)) (hash-has-key? frame term))
        (lookup (hash-ref frame term) frame) term))
  (define (part t selector) (scoped (selector (scoped-term t)) (scoped-scope t)))
  (define (contains? var term fr)
    (define v (lookup term fr))
    (or (equal? var v) (and (pair? (scoped-term v))
                            (or (contains? var (part v car) fr) (contains? var (part v cdr) fr)))))
  (define (merge left right fr)
    (and fr (let* ([a (lookup left fr)] [b (lookup right fr)]
                   [x (scoped-term a)] [y (scoped-term b)])
              (cond [(equal? a b) fr]
                    [(variable? x) (and (not (contains? a b fr)) (hash-set fr a b))]
                    [(variable? y) (merge b a fr)]
                    [(and (pair? x) (pair? y))
                     (merge (part a cdr) (part b cdr) (merge (part a car) (part b car) fr))]
                    [(equal? x y) fr] [else #f]))))
  (define (materialize term fr)
    (define t (lookup term fr))
    (if (pair? (scoped-term t))
        (cons (materialize (part t car) fr) (materialize (part t cdr) fr))
        (scoped-term t)))
  (define (choose xs attempt fail)
    (if (null? xs) (fail) (attempt (car xs) (lambda () (choose (cdr xs) attempt fail)))))
  (define (search g scope fr succeed fail)
    (match g
      ['(and) (succeed fr fail)]
      [`(and ,first . ,rest) (search first scope fr (lambda (next again)
                                                     (search `(and ,@rest) scope next succeed again)) fail)]
      [`(or . ,choices) (choose choices (lambda (x next) (search x scope fr succeed next)) fail)]
      [`(not ,test) (search test scope fr (lambda _ (fail)) (lambda () (succeed fr fail)))]
      [_ (choose database
                 (lambda (entry again)
                   (define local (gensym 'frame))
                   (define-values (head body)
                     (match entry [`(rule ,h . ,goals) (values h goals)] [_ (values entry '())]))
                   (define new (merge (scoped g scope) (scoped head local) fr))
                   (if new (search `(and ,@body) local new succeed again) (again))) fail)]))
  (let/ec stop
    (define out '())
    (when (zero? limit) (stop '()))
    (search goal top (hash)
            (lambda (fr again)
              (set! out (cons (materialize (scoped projection top) fr) out))
              (if (= (length out) limit) (stop (reverse out)) (again)))
            (lambda () (reverse out)))))
(provide floors rank-puzzle yachts queen-boards)
(define (floors #:neighbor [neighbor? #t] #:cheap-first [cheap-first? #t])
  (define candidates 0)
  (define checked 0)
  (define choices
    (for*/list ([b (in-range 1 6)] [c (in-range 1 6)] [f (in-range 1 6)]
                [m (in-range 1 6)] [s (in-range 1 6)]
                #:when
                (let* ([v (list b c f m s)]
                       [bounds (lambda () (and (< b 5) (> c 1) (< 1 f 5) (> m c)))]
                       [apart (lambda () (and (not (= (abs (- f c)) 1))
                                              (or (not neighbor?) (not (= (abs (- s f)) 1)))))]
                       [distinct (lambda () (= 5 (length (remove-duplicates v))))]
                       [preds (if cheap-first? (list bounds apart distinct) (list distinct apart bounds))])
                  (set! candidates (add1 candidates))
                  (for/and ([p preds]) (set! checked (add1 checked)) (p))))
      (list b c f m s)))
  (values choices candidates checked))
(define (rank-puzzle)
  (for/list ([v (in-permutations '(1 2 3 4 5))]
             #:when (match v
                      [(list b e j k m)
                       (and (xor (= k 2) (= b 3)) (xor (= e 1) (= j 2))
                            (xor (= j 3) (= e 5)) (xor (= k 2) (= m 4))
                            (xor (= m 4) (= b 1)))])) v))
(define (yachts known?)
  ;; Slots are Moore, Downing, Hall, Hood, Parker; daughter codes are
  ;; 0 Mary Ann, 1 Lorna, 2 Rosalind, 3 Gabrielle, 4 Melissa.
  (amb-values
   `(begin
      (define (pick xs) (require (not (null? xs))) (amb (car xs) (pick (cdr xs))))
      (define (select xs used forbidden)
        (let ((n (pick xs))) (require (not (= n forbidden)))
          (define (fresh? u) (if (null? u) #t (if (= n (car u)) #f (fresh? (cdr u)))))
          (require (fresh? used)) n))
      (let ((m (select '(0 1 2 3) '() 1)))
        (require (if ,known? (= m 0) #t))
        (let ((d (select '(0 1 2 3) (list m) 4)))
          (let ((h (select '(0 1 2 3) (list m d) 2)))
            (let ((p (select '(0 1 2 3) (list m d h) 0)))
              (require (= p (if (= m 3) 1 (if (= d 3) 4 (if (= h 3) 2 0)))))
              (list m d h 4 p))))))))
(define (queen-boards n)
  (amb-values
   `(begin
      (define (row lo hi) (require (<= lo hi)) (amb lo (row (+ lo 1) hi)))
      (define (safe r others distance)
        (if (null? others) #t
            (if (= r (car others)) #f
                (if (= distance (abs (- r (car others)))) #f
                    (safe r (cdr others) (+ distance 1))))))
      (define (place col rows)
        (if (> col ,n) rows
            (let ((r (row 1 ,n))) (require (safe r rows 1)) (place (+ col 1) (cons r rows)))))
      (place 1 '()))))
(provide bounded-triples parse-words generate-words)
(define (bounded-triples lo hi)
  (amb-values
   `(begin
      (define (between a b) (require (<= a b)) (amb a (between (+ a 1) b)))
      (let ((i (between ,lo ,hi)))
        (let ((j (between i ,hi)))
          (let ((k (between j ,hi)))
            (require (= (+ (* i i) (* j j)) (* k k))) (list i j k)))))))
;; Both modes consume one position per word. Search restores the cursor
;; through amb-values' assignment continuation when a phrase fails.
(define (grammar words generate? limit)
  (amb-values
   `(begin
      (define remaining ',words)
      (define (pick xs) (require (not (null? xs))) (amb (car xs) (pick (cdr xs))))
      (define (word allowed)
        (require (not (null? remaining)))
        (let ((w (pick allowed)))
          (require (if ,generate? #t (eq? w (car remaining))))
          (set! remaining (cdr remaining)) w))
      (define (adjectives)
        (amb '() (let ((a (word '(small busy)))) (cons a (adjectives)))))
      (define (noun)
        (let ((article (word '(the a))))
          (let ((adjs (adjectives)))
            (extend-phrase (list 'noun article adjs (word '(professor student class cat)))))))
      (define (extend-phrase base)
        (amb base
             (let ((prep (word '(to in with))))
               (extend-phrase (list 'modified base prep (noun))))))
      (define (verb) (extend-phrase (list 'verb (word '(lectures sleeps)))))
      (let ((subject (noun))) (let ((predicate (verb)))
        (require (null? remaining)) (list subject predicate))))
   #:limit limit))
(define (parse-words words) (grammar words #f +inf.0))
(define (generate-words length limit) (grammar (make-list length 'slot) #t limit))
(provide join-frames scheduled-query reify-quoted-pairs lazy-preview)
(define (join-frames left right)
  (for/fold ([combined left]) ([(k v) (in-hash right)] #:break (not combined))
    (unify k v combined)))
;; In this conjunction adapter, variables shared with generators are external
;; dependencies of NOT. Variables occurring only inside NOT are existential.
(define (scheduled-query goals db [initial (hash)])
  (define (vars x)
    (cond [(variable? x) (set x)] [(pair? x) (set-union (vars (car x)) (vars (cdr x)))]
          [else (set)]))
  (define (filter-goal? g) (and (pair? g) (memq (car g) '(not lisp-value))))
  (define available
    (for/fold ([names (list->set (hash-keys initial))]) ([g goals] #:unless (filter-goal? g))
      (set-union names (vars g))))
  (define (ready? g frame)
    (or (not (filter-goal? g))
        (for/and ([v (if (eq? (car g) 'not) (set-intersect available (vars g)) (vars g))])
          (set-empty? (vars (instantiate v frame))))))
  (define (schedule remaining frame)
    (cond [(null? remaining) (stream frame)]
          [else (define g (findf (lambda (x) (ready? x frame)) remaining))
                (unless g (error 'schedule "suspended predicate has no grounding goal"))
                (flat-search (lambda (fr) (schedule (remove g remaining) fr)) (query g db frame))]))
  (schedule goals initial))
(define (reify-quoted-pairs datum)
  (if (pair? datum)
      `(lazy-cons ,(reify-quoted-pairs (car datum)) ,(reify-quoted-pairs (cdr datum)))
      `(quote ,datum)))
;; The guest pair constructor stores a selector closure in a tagged record.
;; Never force the tail of the final displayed pair just to decide truncation.
(define (lazy-preview exp env limit)
  (define (show value budget)
    (cond [(not (and (pair? value) (eq? (car value) 'guest-pair))) value]
          [(zero? budget) '…]
          [else
           (define local (extend '(pair-selector) (list (cdr value)) env))
           (define head (actual '(pair-selector (lambda (a b) a)) local 'lazy))
           (cons (show head (sub1 budget))
                 (if (= budget 1) '…
                     (show (actual '(pair-selector (lambda (a b) b)) local 'lazy) (sub1 budget))))]))
  (show (actual exp env 'lazy) limit))
