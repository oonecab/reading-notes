#lang racket
;; A direct checker, online/two-phase inference, let polymorphism, and an evaluator.
(require "chapter07_types.rkt" "chapter07_syntax.rkt")
(provide (all-defined-out) (all-from-out "chapter07_types.rkt" "chapter07_syntax.rkt"))
(define initial-tenv '((i . int) (v . int) (x . int)))
(define (lookup env x)
  (cond [(assq x env) => cdr] [else (type-error 'unbound x "unbound variable ~a" x)]))
(define (extend-many names values env) (append (map cons names values) env))
(define (require-equal actual expected context [kind 'mismatch])
  (unless (equal? actual expected)
    (type-error kind context "expected ~a, received ~a" (external expected) (external actual))))
(define (components t tag size context)
  (unless (and (ty? t) (eq? (ty-tag t) tag) (= (length (ty-parts t)) size))
    (type-error 'mismatch context "expected ~a, received ~a" tag (external t)))
  (ty-parts t))
(define (checked-type source #:early-if? [early? #t] #:mutable-pairs? [mutable? #f])
  (define tree (if (node? source) source (parse source #:checked? #t)))
  (define (go e env)
    (match-define (node op es) e)
    (match op
      ['num 'int]
      ['var (lookup env (car es))]
      ['proc (match-define (list params body) es)
             (proc-t (map cdr params) (go body (append params env)))]
      ['let (match-define (list bs body) es)
            (go body (extend-many (map car bs) (map (lambda (b) (go (cdr b) env)) bs) env))]
      ['rec (match-define (list ds body) es)
            (define renv (extend-many (map car ds) (map (lambda (d) (proc-t (map cdr (second d)) (third d))) ds) env))
            (for ([d ds]) (require-equal (go (fourth d) (append (second d) renv)) (third d) (fourth d)))
            (go body renv)]
      ['if (define ct (go (first es) env))
           (when early? (require-equal ct 'bool (first es) 'condition))
           (define at (go (second es) env)) (define bt (go (third es) env))
           (unless early? (require-equal ct 'bool (first es) 'condition))
           (require-equal at bt e) at]
      ['call (match-define (list f args) es)
             (define ft (go f env)) (define ts (map (lambda (a) (go a env)) args))
             (unless (and (ty? ft) (eq? (ty-tag ft) 'proc)) (type-error 'rator f "operator is not a procedure"))
             (define ps (drop-right (ty-parts ft) 1))
             (unless (= (length ps) (length ts)) (type-error 'arity e "procedure argument count differs"))
             (for ([a ps] [b ts]) (require-equal b a e)) (last (ty-parts ft))]
      ['unpair (match-define (list x y pair body) es)
               (define parts (components (go pair env) 'pairof 2 pair))
               (go body (extend-many (list x y) parts env))]
      ['set (require-equal (go (second es) env) (lookup env (first es)) e) 'int]
      ['begin (last (map (lambda (x) (go x env)) es))]
      ['emptylist (list-t (car es))]
      [_
       (define ts (map (lambda (x) (go x env)) es))
       (match op
         [(or '- '+) (for ([t ts]) (require-equal t 'int e)) 'int]
         ['zero? (require-equal (car ts) 'int e) 'bool]
         ['newpair (apply pair-t ts)]
         ['list (for ([t (cdr ts)]) (require-equal t (car ts) e)) (list-t (car ts))]
         ['cons (require-equal (second ts) (list-t (first ts)) e) (second ts)]
         [(or 'null? 'car 'cdr)
          (define a (car (components (first ts) 'listof 1 e)))
          (case op [(null?) 'bool] [(car) a] [else (first ts)])]
         ['newref (ref-t (first ts))]
         ['deref (car (components (first ts) 'refto 1 e))]
         ['setref (require-equal (first ts) (ref-t (second ts)) e) 'void]
         [(or 'left 'right 'setleft 'setright)
          (unless mutable? (type-error 'feature e "enable mutable-pairs mode"))
          (define parts (components (first ts) 'pairof 2 e))
          (case op [(left) (first parts)] [(right) (second parts)]
            [else (require-equal (second ts) ((if (eq? op 'setleft) first second) parts) e) 'int])]
         [_ (type-error 'feature e "unknown checker form ~a" op)])]))
  (go tree initial-tenv))
(define (check source #:early-if? [early? #t] #:mutable-pairs? [mutable? #f])
  (external (checked-type source #:early-if? early? #:mutable-pairs? mutable?)))

(struct copy-binding (expression environment) #:transparent)
(struct inference (type equations substitution statistics) #:transparent)
(define (nonexpansive? e mutable?)
  (match e
    [(node (or 'num 'var 'proc 'emptylist) _) #t]
    [(node 'newpair es) (and (not mutable?) (andmap (lambda (e) (nonexpansive? e mutable?)) es))]
    [(node 'list es) (andmap (lambda (e) (nonexpansive? e mutable?)) es)]
    [_ #f]))
(define (infer-details source #:engine [engine 'eager] #:two-phase? [two-phase? #f]
                       #:polymorphism [poly 'mono] #:value-restriction? [restriction? #t]
                       #:mutable-pairs? [mutable? #f] #:omitted? [omitted? #t])
  (unless (memq poly '(mono copy w)) (error 'infer-details "unknown polymorphism mode"))
  (when (and two-phase? (not (eq? poly 'mono)))
    (type-error 'feature source "two-phase mode implements monomorphic constraints"))
  (define tree (if (node? source) source (parse source #:omitted? omitted?)))
  (define next 0) (define equations '()) (define rhs-analyses 0)
  (define solve (make-solver engine)) (define resolve (solver-resolve solve))
  (define (fresh) (begin0 (tv next) (set! next (add1 next))))
  (define (annotate a) (if a (map-type annotate a) (fresh)))
  (define (emit a b context)
    (set! equations (cons (list a b context) equations))
    (unless two-phase? ((solver-unify solve) a b context)))
  (define (instantiate s)
    (define replacements (map (lambda (v) (cons v (fresh))) (scheme-variables s)))
    (define (go t) (cond [(tv? t) (cond [(assoc t replacements) => cdr] [else t])]
                         [else (map-type go t)]))
    (go (scheme-body s)))
  (define (env-free env)
    (for/fold ([out (set)]) ([p env])
      (define binding (cdr p))
      (set-union out
        (if (scheme? binding)
            (set-subtract (free-tvars (resolve (scheme-body binding))) (list->set (scheme-variables binding)))
            (if (copy-binding? binding) (env-free (copy-binding-environment binding)) (free-tvars (resolve binding)))))))
;; BEGIN algorithm-w-let
  (define (generalize t env)
    (define normalized (resolve t))
    (scheme (sort (set->list (set-subtract (free-tvars normalized) (env-free env))) < #:key tv-id) normalized))
  (define (let-binding e t env)
    (cond
      [(or (eq? poly 'mono) (and restriction? (not (nonexpansive? e mutable?)))) t]
      [(eq? poly 'w) (generalize t env)]
      ;; Each use is analyzed in the defining environment: lexical capture is impossible.
      [else (copy-binding e env)]))
;; END algorithm-w-let
  (define (go e env)
    (match-define (node op es) e)
    (match op
      ['num 'int]
      ['var (define b (lookup env (car es)))
            (cond [(scheme? b) (instantiate b)]
                  [(copy-binding? b) (set! rhs-analyses (add1 rhs-analyses))
                                     (go (copy-binding-expression b) (copy-binding-environment b))]
                  [else b])]
      ['proc (match-define (list params body) es)
             (define pts (map (lambda (p) (annotate (cdr p))) params))
             (proc-t pts (go body (extend-many (map car params) pts env)))]
      ['let (match-define (list bs body) es)
            ;; Check each RHS even if its variable is unused (call-by-value safety).
            (define ts (for/list ([b bs]) (set! rhs-analyses (add1 rhs-analyses)) (go (cdr b) env)))
            (define bindings (map (lambda (b t) (let-binding (cdr b) t env)) bs ts))
            (go body (extend-many (map car bs) bindings env))]
      ['rec (match-define (list ds body) es)
            (define argss (map (lambda (d) (map (lambda (p) (annotate (cdr p))) (second d))) ds))
            (define results (map (lambda (d) (annotate (third d))) ds))
            (define renv (extend-many (map car ds) (map proc-t argss results) env))
            (for ([d ds] [args argss] [res results])
              (emit (go (fourth d) (extend-many (map car (second d)) args renv)) res (fourth d)))
            ;; Recursive groups are monomorphic; polymorphic recursion is not inferred.
            (go body renv)]
      ['if (emit (go (first es) env) 'bool (first es))
           (define a (go (second es) env)) (define b (go (third es) env)) (emit a b e) a]
      ['call (match-define (list f args) es)
             (define ft (go f env)) (define ats (map (lambda (a) (go a env)) args))
             (define result (fresh)) (emit ft (proc-t ats result) e) result]
      ['unpair (match-define (list x y pair body) es)
               (define a (fresh)) (define b (fresh)) (emit (go pair env) (pair-t a b) pair)
               (go body (extend-many (list x y) (list a b) env))]
      ['set (define target (lookup env (first es)))
            (when (or (copy-binding? target) (and (scheme? target) (pair? (scheme-variables target))))
              (type-error 'poly-assignment e "a generalized let binding is immutable"))
            (emit (go (second es) env) (if (scheme? target) (scheme-body target) target) e) 'int]
      ['begin (last (map (lambda (x) (go x env)) es))]
      ['emptylist (list-t (annotate (car es)))]
      [_
       (define ts (map (lambda (x) (go x env)) es))
       (match op
         [(or '- '+) (for ([t ts]) (emit t 'int e)) 'int]
         ['zero? (emit (first ts) 'int e) 'bool]
         ['newpair (apply pair-t ts)]
         ['list (for ([t (cdr ts)]) (emit t (first ts) e)) (list-t (first ts))]
         ['cons (emit (second ts) (list-t (first ts)) e) (second ts)]
         [(or 'null? 'car 'cdr) (define a (fresh)) (emit (first ts) (list-t a) e)
                              (case op [(null?) 'bool] [(car) a] [else (list-t a)])]
         ['newref (ref-t (first ts))]
         ['deref (define a (fresh)) (emit (first ts) (ref-t a) e) a]
         ['setref (emit (first ts) (ref-t (second ts)) e) 'void]
         [(or 'left 'right 'setleft 'setright)
          (unless mutable? (type-error 'feature e "enable mutable-pairs mode"))
          (define a (fresh)) (define b (fresh)) (emit (first ts) (pair-t a b) e)
          (case op [(left) a] [(right) b]
            [else (emit (second ts) (if (eq? op 'setleft) a b) e) 'int])]
         [_ (type-error 'feature e "unknown inference form ~a" op)])]))
  (define result (go tree initial-tenv))
  (define ordered (reverse equations))
  (when two-phase? (for ([q ordered]) (apply (solver-unify solve) q)))
  (define statistics ((solver-statistics solve)))
  (hash-set! statistics 'rhs-analyses rhs-analyses)
  (inference (resolve result) ordered ((solver-snapshot solve)) statistics))
(define (infer source #:engine [engine 'eager] #:two-phase? [two-phase? #f]
               #:polymorphism [poly 'mono] #:value-restriction? [restriction? #t]
               #:mutable-pairs? [mutable? #f] #:omitted? [omitted? #t])
  (external (inference-type (infer-details source #:engine engine #:two-phase? two-phase?
                        #:polymorphism poly #:value-restriction? restriction?
                        #:mutable-pairs? mutable? #:omitted? omitted?))))

(struct closure (parameters body environment) #:transparent)
(struct reference (cell) #:transparent)
(struct pair-value (left right mutable?) #:transparent)
(struct exn:fail:object exn:fail (kind) #:transparent)
(define (object-error kind message) (raise (exn:fail:object message (current-continuation-marks) kind)))
(define (evaluate source #:fuel [fuel 100000] #:mutable-pairs? [mutable? #f])
  (unless (exact-positive-integer? fuel)
    (object-error 'fuel "evaluation budget must be a positive exact integer"))
  (define tree (if (node? source) source (parse source)))
  (define (runtime-lookup env x)
    (cond [(assq x env) => cdr] [else (object-error 'runtime-type (format "unbound variable ~a" x))]))
  (define (number! x) (unless (exact-integer? x) (object-error 'runtime-type "integer required")) x)
  (define (boolean! x) (unless (boolean? x) (object-error 'runtime-type "boolean required")) x)
  (define (list! x) (unless (list? x) (object-error 'runtime-type "list required")) x)
  (define (pair! x) (unless (pair-value? x) (object-error 'runtime-type "pair required")) x)
  (define (ref! x) (unless (reference? x) (object-error 'runtime-type "reference required")) (reference-cell x))
  (define (go e env)
    (when (zero? fuel) (object-error 'fuel "evaluation budget exhausted")) (set! fuel (sub1 fuel))
    (match-define (node op es) e)
    (match op
      ['num (car es)] ['var (unbox (runtime-lookup env (car es)))]
      ['proc (closure (map car (first es)) (second es) env)]
      ['let (match-define (list bs body) es)
            (go body (extend-many (map car bs) (map (lambda (b) (box (go (cdr b) env))) bs) env))]
      ['rec (match-define (list ds body) es)
            (define slots (map (lambda (_) (box #f)) ds))
            (define renv (extend-many (map car ds) slots env))
            (for ([d ds] [slot slots]) (set-box! slot (closure (map car (second d)) (fourth d) renv)))
            (go body renv)]
      ['if (if (boolean! (go (first es) env)) (go (second es) env) (go (third es) env))]
      ['call (define f (go (first es) env)) (define args (map (lambda (e) (go e env)) (second es)))
             (unless (closure? f) (object-error 'runtime-type "operator is not a procedure"))
             (unless (= (length args) (length (closure-parameters f))) (object-error 'runtime-type "procedure arity differs"))
             (go (closure-body f) (extend-many (closure-parameters f) (map box args) (closure-environment f)))]
      ['unpair (match-define (list x y e body) es) (define p (pair! (go e env)))
               (go body (extend-many (list x y) (list (box (unbox (pair-value-left p))) (box (unbox (pair-value-right p)))) env))]
      ['set (define cell (runtime-lookup env (first es))) (define value (go (second es) env)) (set-box! cell value) 27]
      ['begin (last (map (lambda (e) (go e env)) es))]
      ['emptylist '()]
      [_
       (define vs (map (lambda (e) (go e env)) es))
       (case op
         [(-) (- (number! (first vs)) (number! (second vs)))]
         [(+) (+ (number! (first vs)) (number! (second vs)))]
         [(zero?) (zero? (number! (first vs)))]
         [(newpair) (pair-value (box (first vs)) (box (second vs)) mutable?)]
         [(list) vs] [(cons) (cons (first vs) (list! (second vs)))]
         [(null?) (null? (list! (first vs)))]
         [(car cdr) (define ls (list! (first vs)))
                    (when (null? ls) (object-error 'empty-list "empty list access")) ((if (eq? op 'car) car cdr) ls)]
         [(newref) (reference (box (first vs)))] [(deref) (unbox (ref! (first vs)))]
         [(setref) (set-box! (ref! (first vs)) (second vs)) 'unit]
         [(left right) (define p (pair! (first vs)))
                       (unbox ((if (eq? op 'left) pair-value-left pair-value-right) p))]
         [(setleft setright) (define p (pair! (first vs)))
                            (unless (pair-value-mutable? p) (object-error 'runtime-type "immutable pair"))
                            (set-box! ((if (eq? op 'setleft) pair-value-left pair-value-right) p) (second vs))
                            (if (eq? op 'setleft) 82 83)]
         [else (object-error 'runtime-type "unknown expression")])]))
  (go tree (list (cons 'i (box 1)) (cons 'v (box 5)) (cons 'x (box 10)))))
(define (datum x)
  (cond [(closure? x) '<procedure>] [(reference? x) '<reference>]
        [(pair-value? x) (list 'pair (datum (unbox (pair-value-left x))) (datum (unbox (pair-value-right x))))]
        [(list? x) (map datum x)] [else x]))
(define (run source #:polymorphism [poly 'mono] #:value-restriction? [restriction? #t] #:mutable-pairs? [mutable? #f])
  (infer source #:polymorphism poly #:value-restriction? restriction? #:mutable-pairs? mutable?)
  (evaluate source #:mutable-pairs? mutable?))
(module+ main
  (displayln (check "proc (x : int) -(x,1)"))
  (displayln (infer "proc (f : ?) proc (x : ?) -((f 3),(f x))"))
  (displayln (infer "proc (x : ?) x"))
  (displayln (run "let f = proc (x : ?) x in if (f zero?(0)) then (f 11) else (f 22)" #:polymorphism 'w)))
