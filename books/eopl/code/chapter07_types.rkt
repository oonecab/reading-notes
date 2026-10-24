#lang racket
;; Types, substitutions, and finite-tree unification for EOPL chapter 7.
(provide (all-defined-out))
(struct tv (id) #:transparent)
(struct ty (tag parts) #:transparent)
(struct scheme (variables body) #:transparent)
(struct exn:fail:typing exn:fail (kind context) #:transparent)
(define (type-error kind context fmt . args)
  (raise (exn:fail:typing (apply format fmt args) (current-continuation-marks) kind context)))
(define (proc-t args result) (ty 'proc (append args (list result))))
(define (pair-t a b) (ty 'pairof (list a b)))
(define (list-t a) (ty 'listof (list a)))
(define (ref-t a) (ty 'refto (list a)))
(define (type-children t) (if (ty? t) (ty-parts t) '()))
(define (map-type f t) (if (ty? t) (ty (ty-tag t) (map f (ty-parts t))) t))
(define (free-tvars t)
  (cond [(tv? t) (set t)] [(ty? t) (for/fold ([r (set)]) ([x (ty-parts t)]) (set-union r (free-tvars x)))] [else (set)]))
(define (occurs? variable t) (set-member? (free-tvars t) variable))
;; BEGIN substitution-core
(define (apply-one t variable replacement)
  (cond [(equal? t variable) replacement]
        [else (map-type (lambda (x) (apply-one x variable replacement)) t)]))
(define (apply-eager t subst)
  (cond [(tv? t) (cond [(assoc t subst) => cdr] [else t])]
        [else (map-type (lambda (x) (apply-eager x subst)) t)]))
(define (extend-eager subst variable replacement)
  (cons (cons variable replacement)
        (for/list ([binding subst])
          (cons (car binding) (apply-one (cdr binding) variable replacement)))))
;; Lazy bindings may mention previously bound variables. They must remain acyclic.
(define (apply-lazy t subst #:memo? [memo? #f] #:visits [visits (lambda (_) (void))])
  (define memo (make-hash))
  (define active (mutable-set))
  (define (walk t)
    (cond
      [(tv? t)
       (cond [(and memo? (hash-has-key? memo t)) (hash-ref memo t)]
             [else
              (when (set-member? active t) (type-error 'occurs t "cyclic substitution at ~a" t))
              (visits t) (set-add! active t)
              (define answer (cond [(assoc t subst) => (lambda (p) (walk (cdr p)))] [else t]))
              (set-remove! active t) (when memo? (hash-set! memo t answer)) answer])]
      [else (map-type walk t)]))
  (walk t))
;; END substitution-core
(define (no-bound-variable-on-rhs? subst)
  (define bound (list->set (map car subst)))
  (for/and ([p subst]) (set-empty? (set-intersect bound (free-tvars (cdr p))))))
(define global-substitution '())
(struct solver (unify resolve snapshot statistics) #:transparent)
(define (make-solver [engine 'eager])
  (unless (memq engine '(eager lazy memo walk global vector))
    (error 'make-solver "unknown engine ~a" engine))
  (when (eq? engine 'global) (set! global-substitution '()))
  (define subst '())
  (define cells (make-vector 16 #f))
  (define stats (make-hasheq '((lookups . 0) (bindings . 0) (equations . 0))))
  (define (count! key) (hash-update! stats key add1 0))
  (define (alist) (if (eq? engine 'global) global-substitution subst))
  (define (capacity! n)
    (when (>= n (vector-length cells))
      (define next (make-vector (max (add1 n) (* 2 (vector-length cells))) #f))
      (vector-copy! next 0 cells) (set! cells next)))
  (define (binding v)
    (count! 'lookups)
    (if (eq? engine 'vector)
        (begin (capacity! (tv-id v)) (vector-ref cells (tv-id v)))
        (cond [(assoc v (alist)) => cdr] [else #f])))
  (define (root t)
    (if (tv? t)
        (let ([b (binding t)])
          (if b
              (let ([r (root b)])
                (when (eq? engine 'vector) (vector-set! cells (tv-id t) r)) r)
              t)) t))
  (define (resolve t)
    (cond [(eq? engine 'eager) (apply-eager t subst)]
          [(memq engine '(lazy memo global))
           (apply-lazy t (alist) #:memo? (eq? engine 'memo)
                       #:visits (lambda (_) (count! 'lookups)))]
          [else (define r (root t)) (map-type resolve r)]))
  (define (bind! v t)
    (count! 'bindings)
    (case engine
      [(eager) (set! subst (extend-eager subst v t))]
      [(vector) (capacity! (tv-id v)) (vector-set! cells (tv-id v) t)]
      [(global) (set! global-substitution (cons (cons v t) global-substitution))]
      [else (set! subst (cons (cons v t) subst))]))
;; BEGIN unifier-core
  (define (unify! a b [context #f])
    (count! 'equations)
    ;; 'walk' and 'vector' dereference only a root variable, then recurse.
    (define left ((if (memq engine '(walk vector)) root resolve) a))
    (define right ((if (memq engine '(walk vector)) root resolve) b))
    (cond
      [(equal? left right) (void)]
      [(tv? left)
       (when (occurs? left (resolve right))
         (type-error 'occurs context "occurrence check: ~a in ~a" left right))
       (bind! left right)]
      [(tv? right) (unify! right left context)]
      [(and (ty? left) (ty? right) (eq? (ty-tag left) (ty-tag right))
            (= (length (ty-parts left)) (length (ty-parts right))))
       ;; Every later child uses the substitution updated by earlier children.
       (for ([x (ty-parts left)] [y (ty-parts right)]) (unify! x y context))]
      [else (type-error 'mismatch context "cannot unify ~a and ~a" (external left) (external right))]))
;; END unifier-core
  (define (snapshot)
    (if (eq? engine 'vector)
        (for/list ([b (in-vector cells)] [i (in-naturals)] #:when b) (cons (tv i) b))
        (alist)))
  (solver unify! resolve snapshot (lambda () (hash-copy stats))))
(define (external t #:canonical? [canonical? #t])
  (define table (make-hash))
  (define (go t)
    (match t
      [(tv n) (if canonical?
                  (hash-ref! table t (lambda () (string->symbol (format "a~a" (hash-count table)))))
                  (string->symbol (format "ty~a" n)))]
      [(ty 'proc children)
       (define args (drop-right children 1))
       (append (if (null? args) '() (add-between (map go args) '*)) (list '-> (go (last children))))]
      [(ty tag children) (cons tag (map go children))]
      [_ t]))
  (go t))
(define (type-alpha=? a b) (equal? (external a) (external b)))
