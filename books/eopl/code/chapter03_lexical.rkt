#lang racket
;; Lexical translation, flat/rib frames, compact closures and safe known calls.
(require eopl (prefix-in s: "chapter03.rkt"))
(provide (all-defined-out))

;; BEGIN target
(struct translated (layout body) #:transparent)
(struct nconst (n) #:transparent)
(struct nref (depth position) #:transparent)
(struct nrec-ref (depth position) #:transparent)
(struct nprim (name args) #:transparent)
(struct nif (test yes no) #:transparent)
(struct ncond (tests bodies) #:transparent)
(struct nlet (rhss body) #:transparent)
(struct nunpack (count rhs body) #:transparent)
(struct nproc (arity body captures) #:transparent)
(struct ncall (operator operands) #:transparent)
(struct nrec (arities bodies body) #:transparent)
(struct nclosure (arity body saved) #:transparent)
(struct rec-description (arity body saved) #:transparent)
(struct slot (name identity recursive? known) #:transparent)
(struct known (params body saved-scope) #:transparent)
(define frame-layout (make-parameter 'flat))
(define compact? (make-parameter #f))
(define optimize-level (make-parameter 0))
(define uses (make-parameter #f))
(define (fresh-slot name [rec? #f] [info #f]) (slot name (gensym name) rec? info))
(define (static-extend xs env)
  (if (eq? (frame-layout) 'rib) (cons xs env) (append (map list xs) env)))
(define (runtime-extend vals env)
  (if (eq? (frame-layout) 'rib) (cons (list->vector vals) env)
      (append (map vector vals) env)))
(define (find-name env name)
  (or (for*/first ([frame env] [v frame] #:when (eq? (slot-name v) name)) v)
      (error 'translation "unbound variable: ~a" name)))
(define (find-address runtime-env v)
  (or (for*/first ([(frame d) (in-indexed runtime-env)]
                   [(item p) (in-indexed frame)]
                   #:when (eq? (slot-identity item) (slot-identity v)))
        (if (slot-recursive? v) (nrec-ref d p) (nref d p)))
      (error 'translation "binding missing from runtime layout: ~a" (slot-name v))))
(define (note-value-use! v)
  (when (and (uses) (slot-known v))
    (hash-update! (uses) (slot-identity v) add1 0)))
;; END target

;; BEGIN translator
(define (translate exp scope runtime)
  (define (tr e) (translate e scope runtime))
  (define (body-with ps body [saved-scope scope] [saved-runtime runtime])
    (s:unique! ps 'parameters)
    (define slots (map fresh-slot ps))
    (translate body (static-extend slots saved-scope) (static-extend slots saved-runtime)))
  (cases s:expression exp
    (s:const-exp (n) (nconst n))
    (s:var-exp (name)
      (define v (find-name scope name)) (note-value-use! v) (find-address runtime v))
    (s:unary-exp (op e) (nprim (s:unary-name op) (list (tr e))))
    (s:binary-exp (op a b) (nprim (s:binary-name op) (map tr (list a b))))
    (s:emptylist-exp () (nprim 'list '()))
    (s:list-exp (es) (nprim 'list (map tr es)))
    (s:pack-exp (es) (nprim 'list (map tr es)))
    (s:if-exp (t y n) (nif (tr t) (tr y) (tr n)))
    (s:cond-exp (ts bs) (ncond (map tr ts) (map tr bs)))
;; BEGIN known-binding-elimination
    (s:let-exp (vs es b)
      (s:unique! vs 'let)
      (define slots
        (map (lambda (v e)
               (fresh-slot v #f
                 (cases s:expression e
                   (s:proc-exp (ps body) (known ps body scope))
                   (else #f)))) vs es))
      (define rhs (map tr es))
      (define scope+ (static-extend slots scope))
      (define body1 (translate b scope+ (static-extend slots runtime)))
      (define keep
        (map (lambda (v) (not (and (= (optimize-level) 2) (slot-known v)
                                   (= (hash-ref (uses) (slot-identity v) 0) 0)))) slots))
      (define retained (for/list ([v slots] [k keep] #:when k) v))
      (if (andmap values keep) (nlet rhs body1)
          (nlet (for/list ([e rhs] [k keep] #:when k) e)
                (translate b scope+ (static-extend retained runtime)))))
;; END known-binding-elimination
    (s:letstar-exp (vs es b)
      (let loop ([vs vs] [es es] [sc scope] [rt runtime])
        (if (null? vs) (translate b sc rt)
            (let ([v (fresh-slot (car vs))])
              (nlet (list (translate (car es) sc rt))
                    (loop (cdr vs) (cdr es) (static-extend (list v) sc)
                          (static-extend (list v) rt)))))))
    (s:unpack-exp (vs e b)
      (s:unique! vs 'unpack)
      (nunpack (length vs) (tr e) (body-with vs b)))
    (s:proc-exp (ps b)
      (if (compact?)
          (let* ([names (s:without (s:free-vars b) ps)]
                 [slots (map (lambda (name) (find-name scope name)) names)]
                 [captures (map (lambda (v) (find-address runtime v)) slots)]
                 [compact-env (static-extend slots '())])
            (nproc (length ps) (body-with ps b compact-env compact-env) captures))
          (nproc (length ps) (body-with ps b) #f)))
;; BEGIN known-call
    (s:call-exp (f es)
      (define candidate (cases s:expression f
                          (s:var-exp (name) (find-name scope name)) (else #f)))
      (define info (and candidate (slot-known candidate)))
      (if (and (> (optimize-level) 0) info
               (= (length es) (length (known-params info))))
          ;; Operands are evaluated once in the caller. Free names in the body
          ;; resolve in its creation scope; UIDs locate those bindings in the
          ;; current runtime layout even when an intervening name shadows them.
          (nlet (map tr es)
                (body-with (known-params info) (known-body info)
                           (known-saved-scope info) runtime))
          (ncall (tr f) (map tr es))))
;; END known-call
    (s:letproc-exp (name ps pb b)
      (tr (s:let-exp (list name) (list (s:proc-exp ps pb)) b)))
    (s:letrec-exp (ns pss bs b)
      (s:unique! ns 'letrec)
      (define slots (map (lambda (n) (fresh-slot n #t)) ns))
      (define sc (static-extend slots scope)) (define rt (static-extend slots runtime))
      (nrec (map length pss)
            (map (lambda (ps pbody) (body-with ps pbody sc rt)) pss bs)
            (translate b sc rt)))
    (s:traceproc-exp (ps b) (error 'translation "traceproc is a named-interpreter variant"))))
(define (translation-of-program text #:layout [layout 'flat] #:trim [trim? #f] #:optimize [level 0])
  (unless (memq layout '(flat rib)) (error 'translation "unknown layout"))
  (unless (memv level '(0 1 2)) (error 'translation "unknown optimization level"))
  (when (and trim? (> level 0)) (error 'translation "compact and known-call variants are separate experiments"))
  (parameterize ([frame-layout layout] [compact? trim?] [optimize-level level] [uses (make-hasheq)])
    (define init (static-extend (map fresh-slot '(i v x)) '()))
    (translated layout (translate (s:parse-expression text) init init))))
;; END translator

;; BEGIN nameless-evaluator
(define (raw-reference env d p)
  (s:bump! 'lexical-lookups)
  (unless (and (exact-nonnegative-integer? d) (< d (length env)))
    (error 'lexref "depth out of bounds"))
  (define frame (list-ref env d))
  (unless (and (exact-nonnegative-integer? p) (< p (vector-length frame)))
    (error 'lexref "position out of bounds"))
  (vector-ref frame p))
(define (capture-reference ref env)
  (match ref [(nref d p) (raw-reference env d p)]
             [(nrec-ref d p) (raw-reference env d p)]
             [_ (error 'capture "not an address")]))
(define (nvalue-of exp env)
  (s:bump! 'evaluations)
  (define (ev e) (nvalue-of e env))
  (match exp
    [(nconst n) (s:num-val n)]
    [(nref d p)
     (define v (raw-reference env d p))
     (unless (s:expval? v) (error 'lexref "recursive slot requires letrec reference")) v]
    [(nrec-ref d p)
     (define code (raw-reference env d p))
     (unless (rec-description? code) (error 'letrec-ref "slot is not recursive"))
     (s:bump! 'closures)
     (s:proc-val (nclosure (rec-description-arity code) (rec-description-body code) (rec-description-saved code)))]
    [(nprim op args)
     (define vals (for/list ([a args]) (ev a)))
     (cond [(eq? op 'list) (s:list-val vals)]
           [(hash-has-key? s:unary-table op) (apply (hash-ref s:unary-table op) vals)]
           [else (apply (hash-ref s:binary-table op) vals)])]
    [(nif t y n) (if (s:true-value? (ev t)) (ev y) (ev n))]
    [(ncond ts bs)
     (let loop ([ts ts] [bs bs])
       (cond [(null? ts) (error 'cond "no test succeeds")]
             [(s:true-value? (ev (car ts))) (ev (car bs))]
             [else (loop (cdr ts) (cdr bs))]))]
    [(nlet es b)
     (define vals (for/list ([e es]) (ev e)))
     (nvalue-of b (runtime-extend vals env))]
    [(nunpack count e b)
     (define vals (s:expval->list (ev e)))
     (unless (= (length vals) count) (error 'unpack "list length mismatch"))
     (nvalue-of b (runtime-extend vals env))]
    [(nproc arity body captures)
     (define saved (if captures
                      (runtime-extend (map (lambda (r) (capture-reference r env)) captures) '()) env))
     (s:bump! 'closures) (s:proc-val (nclosure arity body saved))]
    [(ncall operator operands)
     (define p (s:expval->proc (ev operator)))
     (define vals (for/list ([e operands]) (ev e)))
     (unless (and (nclosure? p) (= (nclosure-arity p) (length vals)))
       (error 'nameless-call "arity mismatch or invalid procedure"))
     (nvalue-of (nclosure-body p) (runtime-extend vals (nclosure-saved p)))]
    [(nrec arities bodies b)
     (define count (length arities))
     (define placeholders (make-list count #f))
     (define new-env (runtime-extend placeholders env))
     (for ([arity arities] [body bodies] [i (in-naturals)])
       (define frame (list-ref new-env (if (eq? (frame-layout) 'rib) 0 i)))
       (vector-set! frame (if (eq? (frame-layout) 'rib) i 0) (rec-description arity body new-env)))
     (nvalue-of b new-env)]
    [_ (error 'nvalue-of "invalid translated expression: ~s" exp)]))
(define (value-of-translated p)
  (unless (translated? p) (error 'value-of-translated "translated program required"))
  (parameterize ([frame-layout (translated-layout p)] [s:numeric-booleans? #f])
    (nvalue-of (translated-body p) (runtime-extend (map s:num-val '(1 5 10)) '()))))
(define (run/nameless text #:layout [layout 'flat] #:trim [trim? #f] #:optimize [level 0])
  (value-of-translated (translation-of-program text #:layout layout #:trim trim? #:optimize level)))
;; END nameless-evaluator

(define (ir->datum p)
  (define layout (translated-layout p))
  (define (walk e)
    (match e
      [(nconst n) n] [(nref d pos) (if (eq? layout 'flat) (list '%lexref d) (list '%lexref d pos))]
      [(nrec-ref d pos) (list '%letrec-ref d pos)]
      [(nprim op es) (cons op (map walk es))]
      [(nif t y n) (list 'if (walk t) (walk y) (walk n))]
      [(ncond ts bs) (list 'cond (map (lambda (a b) (list (walk a) '==> (walk b))) ts bs))]
      [(nlet es b) (list '%let (map walk es) (walk b))]
      [(nunpack n e b) (list '%unpack n (walk e) (walk b))]
      [(nproc n b captures) (list '%proc n (and captures (map walk captures)) (walk b))]
      [(ncall f es) (cons (walk f) (map walk es))]
      [(nrec as bs b) (list '%letrec as (map walk bs) (walk b))]))
  (walk (translated-body p)))
(module+ main
  (define text "let x = 37 in proc (y) let z = -(y,x) in -(x,y)")
  (pretty-write (ir->datum (translation-of-program text)))
  (displayln (s:datum (run/nameless s:closure-example)))
  (displayln (s:datum (run/nameless s:double-example))))
