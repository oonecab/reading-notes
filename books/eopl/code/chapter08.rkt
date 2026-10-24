#lang racket
;; A module checker and an independent call-by-value evaluator.
(require "chapter07_types.rkt" "chapter08_syntax.rkt")
(provide check run run/trace compare-interfaces (struct-out execution)
         (all-from-out "chapter07_types.rkt" "chapter08_syntax.rkt"))
(struct tenv (values types modules interfaces) #:transparent)
(struct module-type (key iface) #:transparent)
(struct interface-template (body environment) #:transparent)
(define empty-tenv (tenv '() '() '() '()))
(define current-inferred? (make-parameter #f))
(define current-unordered? (make-parameter #f))
(define current-dependencies (make-parameter 'none))
(define current-solver (make-parameter #f))
(define current-labels (make-parameter (make-hasheq)))
(define current-fresh (make-parameter (box 0)))
(define (lookup xs name [kind 'unbound])
  (cond [(assq name xs) => cdr] [else (type-error kind name "unbound ~a" name)]))
(define (fresh-key label)
  (define key (gensym label)) (hash-set! (current-labels) key label) key)
(define (fresh-type)
  (define n (unbox (current-fresh))) (set-box! (current-fresh) (add1 n)) (tv n))
(define (resolve t) (if (current-solver) ((solver-resolve (current-solver)) t) t))
(define (equate! a b context)
  (if (current-inferred?) ((solver-unify (current-solver)) a b context)
      (unless (equal? a b) (type-error 'mismatch context "type mismatch: ~a / ~a" (display-type a) (display-type b)))))
(define (iface? x) (or (simple-iface? x) (proc-iface? x)))
(define (component iface name kinds)
  (unless (simple-iface? iface) (type-error 'module-kind name "simple module required"))
  (or (for/first ([d (simple-iface-decls iface)] #:when (and (eq? name (decl-name d)) (memq (decl-kind d) kinds))) d)
      (type-error 'hidden name "component ~a is not exported" name)))
(define (module-path env path)
  (define entry (lookup (tenv-modules env) (car path) 'module-unbound))
  (for/fold ([i (module-type-iface entry)]) ([n (cdr path)])
    (decl-payload (component i n '(module)))))
;; BEGIN expanded-bindings
(define (expand-type t env)
  (match t
    [(named n) (lookup (tenv-types env) n 'type-unbound)]
    [(qualified path n)
     ;; Uninterned keys identify already expanded opaque atoms, never source names.
     (if (not (symbol-interned? (car path))) t
         (decl-payload (component (module-path env path) n '(type))))]
    [(ty tag children) (ty tag (map (lambda (x) (expand-type x env)) children))]
    [#f (if (current-inferred?) (fresh-type) (type-error 'annotation t "CHECKED requires a concrete annotation"))]
    [_ t]))
(define (bind-type env name raw)
  (struct-copy tenv env [types (cons (cons name (expand-type raw env)) (tenv-types env))]))
(define (bind-value env name raw)
  (struct-copy tenv env [values (cons (cons name (expand-type raw env)) (tenv-values env))]))
(define (bind-module env name key iface)
  (struct-copy tenv env [modules (cons (cons name (module-type key iface)) (tenv-modules env))]))
;; END expanded-bindings
(define (map-interface f iface)
  (match iface
    [(simple-iface ds)
     (simple-iface (map (lambda (d) (struct-copy decl d [payload
       (if (eq? (decl-kind d) 'module) (map-interface f (decl-payload d)) (f (decl-payload d)))])) ds))]
    [(proc-iface ps r)
     (proc-iface (map (lambda (p) (struct-copy parameter p [iface (map-interface f (parameter-iface p))])) ps)
                 (map-interface f r))]))
(define (rename-key iface old new)
  (define (go t)
    (match t
      [(qualified path n) (qualified (map (lambda (x) (if (eq? x old) new x)) path) n)]
      [(ty tag xs) (ty tag (map go xs))]
      [_ t]))
  (map-interface go iface))
(define (seal-view iface)
  (match iface
    [(simple-iface ds)
     (simple-iface (map (lambda (d)
                         (cond [(eq? (decl-kind d) 'opaque) (decl 'type (decl-name d) (decl-payload d))]
                               [(eq? (decl-kind d) 'module) (struct-copy decl d [payload (seal-view (decl-payload d))])]
                               [else (struct-copy decl d [payload (resolve (decl-payload d))])])) ds))]
    [_ iface]))
(define (normalize-interface raw env key)
  (match raw
    [(iface-name n)
     (define template (lookup (tenv-interfaces env) n 'interface-unbound))
     (normalize-interface (interface-template-body template) (interface-template-environment template) key)]
    [(simple-iface ds)
     (define local env)
     (simple-iface
       (for/list ([d ds])
         (match-define (decl kind n t) d)
         (case kind
           [(opaque) (define q (qualified (list key) n))
                     (set! local (bind-type local n q)) (decl 'opaque n q)]
           [(type) (define expanded (expand-type t local))
                   (set! local (bind-type local n expanded)) (decl 'type n expanded)]
           [(value) (decl 'value n (expand-type t local))]
           [(module) (define subkey (fresh-key n)) (define sub (normalize-interface t local subkey))
                     (set! local (bind-module local n subkey (seal-view sub))) (decl 'module n sub)])))]
    [(proc-iface ps result)
     (define local env)
     (define normalized
       (for/list ([p ps])
         (define k (fresh-key (parameter-name p)))
         (define i (normalize-interface (parameter-iface p) local k))
         (set! local (bind-module local (parameter-name p) k (seal-view i)))
         (parameter (parameter-name p) k i)))
     (proc-iface normalized (normalize-interface result local (fresh-key 'result)))]))
;; BEGIN interface-subtyping
(define (interface-subtype? actual expected)
  ;; Normalize solved variables before alpha-renaming bound module identities.
  (set! actual (map-interface resolve actual))
  (set! expected (map-interface resolve expected))
  (define equations (make-hash))
  (define (subst t)
    (define current (resolve t))
    (cond [(hash-has-key? equations current) (subst (hash-ref equations current))]
          [(ty? current) (map-type subst current)] [else current]))
  (define (equal-types? a b)
    (equate! (subst a) (subst b) (list a b)) #t)
  (define (match-decl a b)
    (match* ((decl-kind a) (decl-kind b))
      [((or 'type 'opaque) 'opaque)
       (define x (subst (decl-payload b))) (define y (subst (decl-payload a)))
       (unless (equal? x y) (hash-set! equations x y)) #t]
      [('type 'type) (equal-types? (decl-payload a) (decl-payload b))]
      [('value 'value) (equal-types? (decl-payload a) (decl-payload b))]
      [('module 'module) (go (decl-payload a) (decl-payload b))]
      [(_ _) #f]))
  (define (go a b)
    (match* (a b)
      [((simple-iface as) (simple-iface bs))
       (let loop ([rest as] [needs bs])
         (cond [(null? needs) #t] [(null? rest) #f]
               [(current-unordered?)
                (define hit (findf (lambda (d) (eq? (decl-name d) (decl-name (car needs)))) as))
                (and hit (match-decl hit (car needs)) (loop as (cdr needs)))]
               [(eq? (decl-name (car rest)) (decl-name (car needs)))
                (and (match-decl (car rest) (car needs)) (loop (cdr rest) (cdr needs)))]
               [else (loop (cdr rest) needs)]))]
      [((proc-iface aps ar) (proc-iface bps br))
       (and (= (length aps) (length bps))
            (let ([left ar] [right br] [arename '()] [brename '()])
              (define (renames iface pairs)
                (for/fold ([out iface]) ([p pairs]) (rename-key out (car p) (cdr p))))
              (and (for/and ([ap aps] [bp bps])
                     (define common (fresh-key 'parameter))
                     (set! arename (append arename (list (cons (parameter-key ap) common))))
                     (set! brename (append brename (list (cons (parameter-key bp) common))))
                     (define ai (renames (parameter-iface ap) arename))
                     (define bi (renames (parameter-iface bp) brename))
                     (set! left (rename-key left (parameter-key ap) common))
                     (set! right (rename-key right (parameter-key bp) common))
                     (go bi ai)) ; arguments contravariant
                   (go left right))))] ; results covariant
      [(_ _) #f]))
  (with-handlers ([exn:fail:typing? (lambda (_) #f)]) (go actual expected)))
;; END interface-subtyping
(define (scope-tenv env sc)
  (cond [sc
         (unless (or (eq? (current-dependencies) 'none) (eq? (car sc) (current-dependencies)))
           (type-error 'dependencies sc "wrong dependency clause"))
         (struct-copy tenv env [modules (for/list ([n (cdr sc)]) (cons n (lookup (tenv-modules env) n 'dependency)))])]
        [(eq? (current-dependencies) 'imports) (struct-copy tenv env [modules '()])]
        [(eq? (current-dependencies) 'depends-on) (type-error 'dependencies env "explicit dependency clause required")]
        [else env]))
(define (value-type e env)
  (match-define (node op es) e)
  (define (go x [where env]) (value-type x where))
  (match op
    ['num 'int]
    ['var (cond [(assq (car es) (tenv-values env)) => cdr]
                [else (module-type-iface (lookup (tenv-modules env) (car es) 'unbound))])]
    ['qualified (define i (module-path env (drop-right es 1)))
                (decl-payload (component i (last es) '(value module)))]
    ['proc (match-define (list ps body) es)
           (define argts (map (lambda (p) (expand-type (cdr p) env)) ps))
           (define local (for/fold ([v env]) ([p ps] [t argts]) (bind-value v (car p) t)))
           (define result (go body local))
           (when (iface? result) (type-error 'module-kind e "ordinary procedures cannot return modules"))
           (proc-t argts result)]
    ['let (match-define (list bs body) es)
          (define ts (map (lambda (b) (go (cdr b))) bs))
          (go body (for/fold ([v env]) ([b bs] [t ts])
                     (when (iface? t) (type-error 'module-kind b "let binds expressed values")) (bind-value v (car b) t)))]
    ['rec (match-define (list ds body) es) (go body (recursive-tenv ds env))]
    ['if (equate! (go (first es)) 'bool e)
         (define a (go (second es))) (define b (go (third es))) (equate! a b e) a]
    ['call (define f (go (first es))) (define args (map go (second es))) (define out (fresh-type))
           (if (current-inferred?) (equate! f (proc-t args out) e)
               (begin (unless (and (ty? f) (eq? (ty-tag f) 'proc)) (type-error 'rator e "procedure required"))
                      (unless (= (length (ty-parts f)) (add1 (length args))) (type-error 'arity e "argument count differs"))
                      (for ([a args] [t (drop-right (ty-parts f) 1)]) (equate! a t e))
                      (set! out (last (ty-parts f)))))
           out]
    ['unpair (match-define (list x y pair body) es)
             (define t (go pair)) (define a (fresh-type)) (define b (fresh-type))
             (if (current-inferred?) (equate! t (pair-t a b) pair)
                 (begin (unless (and (ty? t) (eq? (ty-tag t) 'pairof)) (type-error 'mismatch pair "pair required"))
                        (set! a (first (ty-parts t))) (set! b (second (ty-parts t)))))
             (go body (bind-value (bind-value env x a) y b))]
    ['begin (last (map go es))]
    [(or '- '+) (for ([x es]) (equate! (go x) 'int e)) 'int]
    ['zero? (equate! (go (car es)) 'int e) 'bool]
    ['print (equate! (go (car es)) 'int e) 'int]
    ['newpair (pair-t (go (first es)) (go (second es)))]
    [_ (type-error 'feature e "unknown expression form ~a" op)]))
(define (recursive-tenv ds env)
  (define entries
    (for/list ([d ds])
      (cons (first d) (proc-t (map (lambda (p) (expand-type (cdr p) env)) (second d)) (expand-type (third d) env)))))
  (define recenv (for/fold ([v env]) ([p entries]) (bind-value v (car p) (cdr p))))
  (for ([d ds] [entry entries])
    (define ts (ty-parts (cdr entry)))
    (define local (for/fold ([v recenv]) ([p (second d)] [t (drop-right ts 1)]) (bind-value v (car p) t)))
    (equate! (value-type (fourth d) local) (last ts) d))
  recenv)
(define (instantiate-result iface parameters arguments)
  (define replacements (map (lambda (p i) (cons (parameter-key p) i)) parameters arguments))
  (define (go t)
    (match t
      [(qualified path n)
       (define hit (assq (car path) replacements))
       (if hit
           (let ([i (for/fold ([i (cdr hit)]) ([part (cdr path)]) (decl-payload (component i part '(module))))])
             (decl-payload (component (seal-view i) n '(type)))) t)]
      [(ty tag xs) (ty tag (map go xs))]
      [_ t]))
  (define replaced (map-interface go iface))
  ;; Each anonymous application owns fresh result seals; dependent argument seals survive.
  (define (freshen i)
    (match i
      [(simple-iface ds)
       (for/fold ([out i]) ([d ds] #:when (eq? (decl-kind d) 'opaque))
         (rename-key out (car (qualified-path (decl-payload d))) (fresh-key 'instance)))]
      [_ i]))
  (freshen replaced))
;; BEGIN module-body-checking
(define (body-interface b env)
  (match (mbody-kind b)
    ['scope (body-interface (second (mbody-args b)) (scope-tenv env (first (mbody-args b))))]
    ['defs
     (define local env)
     (simple-iface
       (for/list ([d (mbody-args b)])
         (match-define (decl kind n e) d)
         (cond [(eq? kind 'type) (define t (expand-type e local))
                                (set! local (bind-type local n t)) (decl 'type n t)]
               [else (define t (value-type e local))
                     (if (iface? t)
                         (begin (set! local (bind-module local n (fresh-key n) t)) (decl 'module n t))
                         (begin (set! local (bind-value local n t)) (decl 'value n t)))])))]
    ['let (match-define (list bs rest) (mbody-args b))
          (define ts (map (lambda (x) (value-type (cdr x) env)) bs))
          (body-interface rest (for/fold ([v env]) ([p bs] [t ts]) (bind-value v (car p) t)))]
    ['rec (body-interface (second (mbody-args b)) (recursive-tenv (first (mbody-args b)) env))]
    ['local (body-interface (second (mbody-args b)) (check-module (first (mbody-args b)) env))]
    ['var (module-type-iface (lookup (tenv-modules env) (car (mbody-args b)) 'module-unbound))]
    ['proc
     (match-define (list ps rest) (mbody-args b)) (define local env)
     (define normalized
       (for/list ([p ps])
         (define k (fresh-key (parameter-name p))) (define i (normalize-interface (parameter-iface p) local k))
         (set! local (bind-module local (parameter-name p) k (seal-view i)))
         (parameter (parameter-name p) k i)))
     (proc-iface normalized (body-interface rest local))]
    ['app
     (match-define (list f args) (mbody-args b))
     (define fi (body-interface f env))
     (unless (proc-iface? fi) (type-error 'module-kind b "attempt to apply a simple module"))
     (unless (= (length args) (length (proc-iface-params fi))) (type-error 'arity b "module argument count differs"))
     (define is (map (lambda (x) (body-interface x env)) args))
     (for ([p (proc-iface-params fi)] [i is] [index (in-naturals)])
       (define expected (instantiate-result (parameter-iface p) (take (proc-iface-params fi) index) (take is index)))
       (unless (interface-subtype? i expected) (type-error 'interface b "bad module argument")))
     (instantiate-result (proc-iface-result fi) (proc-iface-params fi) is)]))
(define (check-module d env)
  (when (assq (mdef-name d) (tenv-modules env)) (type-error 'duplicate d "module name already in scope"))
  (define key (fresh-key (mdef-name d)))
  (define expected (normalize-interface (mdef-iface d) env key))
  (define b (mdef-body d))
  (when (and (eq? (current-dependencies) 'depends-on) (not (eq? (mbody-kind b) 'scope)))
    (type-error 'dependencies d "module body needs dependency clause"))
  (define actual (body-interface b (if (and (eq? (current-dependencies) 'imports) (not (eq? (mbody-kind b) 'scope)))
                                     (scope-tenv env #f) env)))
  (unless (interface-subtype? actual expected) (type-error 'interface d "module body does not satisfy interface: ~a" (mdef-name d)))
  (bind-module env (mdef-name d) key (seal-view expected)))
;; END module-body-checking
(define (check-program tree)
  (define env empty-tenv)
  (for ([d (program-definitions tree)])
    (cond [(mdef? d) (set! env (check-module d env))]
          [else
           (when (assq (idef-name d) (tenv-interfaces env)) (type-error 'duplicate d "duplicate named interface"))
           (normalize-interface (idef-iface d) env (fresh-key (idef-name d)))
           (set! env (struct-copy tenv env [interfaces (cons (cons (idef-name d) (interface-template (idef-iface d) env)) (tenv-interfaces env))]))]))
  (define t (value-type (program-body tree) (scope-tenv env (program-scope tree))))
  (when (iface? t) (type-error 'module-kind tree "program result must be an expressed value"))
  (resolve t))
(define (display-type t)
  (define (go x)
    (match x
      [(qualified path n) (append '(from) (add-between (map (lambda (k) (hash-ref (current-labels) k k)) path) 'take) (list 'take n))]
      [(ty tag xs) (ty tag (map go xs))] [_ x]))
  (external (go t)))
(define (check source #:unordered? [unordered? #f] #:inferred? [inferred? #f] #:dependencies [dependencies 'none])
  (parameterize ([current-inferred? inferred?] [current-unordered? unordered?] [current-dependencies dependencies]
                 [current-solver (make-solver)] [current-fresh (box 0)] [current-labels (make-hasheq)])
    (display-type (check-program (if (program? source) source (parse-program source))))))

;; Runtime values keep an independent environment and never consult type representations.
(struct renv (values modules interfaces) #:transparent)
(struct simple-module (bindings) #:transparent)
(struct module-closure (parameters body environment) #:transparent)
(struct module-proxy (implementation iface environment) #:transparent)
(struct closure (parameters body environment) #:transparent)
(struct delayed-module (definition environment state value) #:transparent)
(struct execution (type value output module-evaluations) #:transparent)
(define empty-renv (renv '() '() '()))
(define current-output (make-parameter (box '())))
(define current-evaluations (make-parameter (make-hasheq)))
(define current-fuel (make-parameter (box 100000)))
(define (tick!)
  (define fuel (current-fuel))
  (when (zero? (unbox fuel)) (type-error 'fuel #f "evaluation budget exhausted"))
  (set-box! fuel (sub1 (unbox fuel))))
(define (rbind-value env n v) (struct-copy renv env [values (cons (cons n (box v)) (renv-values env))]))
(define (rbind-module env n v) (struct-copy renv env [modules (cons (cons n v) (renv-modules env))]))
(define (force-module v)
  (if (delayed-module? v)
      (case (unbox (delayed-module-state v))
        [(done) (unbox (delayed-module-value v))]
        [(busy) (type-error 'import-cycle v "cyclic import")]
        [else
         (set-box! (delayed-module-state v) 'busy)
         (define result (evaluate-module (delayed-module-definition v) (delayed-module-environment v)))
         (set-box! (delayed-module-value v) result) (set-box! (delayed-module-state v) 'done) result]) v))
(define (rcomponent v n)
  (define m (force-module v))
  (unless (simple-module? m) (type-error 'runtime-module n "simple module required"))
  (lookup (simple-module-bindings m) n 'runtime-hidden))
(define (runtime-path env ns)
  (for/fold ([v (force-module (lookup (renv-modules env) (car ns) 'runtime-unbound))]) ([n (cdr ns)]) (rcomponent v n)))
(define (runtime-scope env sc)
  (cond [sc (struct-copy renv env [modules (for/list ([n (cdr sc)])
                           (cons n (force-module (lookup (renv-modules env) n 'runtime-dependency))))])]
        [(eq? (current-dependencies) 'imports) (struct-copy renv env [modules '()])]
        [else env]))
(define (project-module v iface env)
  (cond [(iface-name? iface)
         (define t (lookup (renv-interfaces env) (iface-name-name iface) 'runtime-interface))
         (project-module v (car t) (cdr t))]
        [(simple-iface? iface)
         (simple-module (for/list ([d (simple-iface-decls iface)] #:when (memq (decl-kind d) '(value module)))
           (define x (rcomponent v (decl-name d)))
           (cons (decl-name d) (if (eq? (decl-kind d) 'module) (project-module x (decl-payload d) env) x))))]
        [else (module-proxy v iface env)]))
(define (runtime-rec ds env)
  (define cells (for/list ([d ds]) (cons (car d) (box #f))))
  (define recenv (struct-copy renv env [values (append cells (renv-values env))]))
  (for ([d ds] [c cells]) (set-box! (cdr c) (closure (map car (second d)) (fourth d) recenv))) recenv)
(define (value-of e env)
  (tick!) (match-define (node op es) e)
  (define (go x [where env]) (value-of x where))
  (define (number! x) (unless (exact-integer? x) (type-error 'runtime-type e "integer required")) x)
  (define (boolean! x) (unless (boolean? x) (type-error 'runtime-type e "boolean required")) x)
  (match op
    ['num (car es)]
    ['var (cond [(assq (car es) (renv-values env)) => (lambda (p) (unbox (cdr p)))]
                [else (force-module (lookup (renv-modules env) (car es) 'runtime-unbound))])]
    ['qualified (runtime-path env es)]
    ['proc (closure (map car (first es)) (second es) env)]
    ['let (define bs (first es)) (define vs (map (lambda (b) (go (cdr b))) bs))
          (go (second es) (for/fold ([v env]) ([b bs] [x vs]) (rbind-value v (car b) x)))]
    ['rec (go (second es) (runtime-rec (first es) env))]
    ['if (if (boolean! (go (first es))) (go (second es)) (go (third es)))]
    ['call (define f (go (first es))) (define args (map go (second es)))
           (unless (closure? f) (type-error 'runtime-type e "procedure required"))
           (unless (= (length args) (length (closure-parameters f))) (type-error 'runtime-arity e "argument count differs"))
           (go (closure-body f) (for/fold ([v (closure-environment f)]) ([n (closure-parameters f)] [x args]) (rbind-value v n x)))]
    ['unpair (define p (go (third es)))
             (unless (and (vector? p) (= (vector-length p) 2)) (type-error 'runtime-type e "pair required"))
             (go (fourth es) (rbind-value (rbind-value env (first es) (vector-ref p 0)) (second es) (vector-ref p 1)))]
    ['begin (last (map go es))]
    ['- (- (number! (go (first es))) (number! (go (second es))))]
    ['+ (+ (number! (go (first es))) (number! (go (second es))))]
    ['zero? (zero? (number! (go (car es))))]
    ['print (define n (number! (go (car es))))
            (set-box! (current-output) (append (unbox (current-output)) (list n))) 1]
    ['newpair (vector (go (first es)) (go (second es)))]))
;; BEGIN module-evaluation
(define (module-value b env)
  (tick!)
  (match (mbody-kind b)
    ['scope (module-value (second (mbody-args b)) (runtime-scope env (first (mbody-args b))))]
    ['defs
     (define local env)
     (simple-module
       (for/list ([d (mbody-args b)] #:unless (eq? (decl-kind d) 'type))
         (define v (value-of (decl-payload d) local))
         (set! local (if (or (simple-module? v) (module-closure? v) (module-proxy? v))
                         (rbind-module local (decl-name d) v) (rbind-value local (decl-name d) v)))
         (cons (decl-name d) v)))]
    ['let (match-define (list bs rest) (mbody-args b))
          (define vs (map (lambda (p) (value-of (cdr p) env)) bs))
          (module-value rest (for/fold ([v env]) ([p bs] [x vs]) (rbind-value v (car p) x)))]
    ['rec (module-value (second (mbody-args b)) (runtime-rec (first (mbody-args b)) env))]
    ['local (define d (first (mbody-args b)))
            (module-value (second (mbody-args b)) (rbind-module env (mdef-name d) (evaluate-module d env)))]
    ['var (force-module (lookup (renv-modules env) (car (mbody-args b)) 'runtime-unbound))]
    ['proc (module-closure (first (mbody-args b)) (second (mbody-args b)) env)]
    ['app (match-define (list f args) (mbody-args b))
          (define fn (module-value f env)) (define vs (map (lambda (x) (module-value x env)) args))
          (apply-module-value fn vs b)]))
(define (apply-module-value fn vs context)
  (cond
    [(module-proxy? fn)
     (define i (module-proxy-iface fn))
     (unless (= (length vs) (length (proc-iface-params i))) (type-error 'runtime-arity context "module argument count differs"))
     (define local (module-proxy-environment fn))
     (define args (for/list ([p (proc-iface-params i)] [v vs])
                    (define x (project-module v (parameter-iface p) local))
                    (set! local (rbind-module local (parameter-name p) x)) x))
     (project-module (apply-module-value (module-proxy-implementation fn) args context) (proc-iface-result i) local)]
    [(module-closure? fn)
     (unless (= (length vs) (length (module-closure-parameters fn))) (type-error 'runtime-arity context "module argument count differs"))
     (define local (module-closure-environment fn))
     (for ([p (module-closure-parameters fn)] [v vs])
       (set! local (rbind-module local (parameter-name p) (project-module v (parameter-iface p) local))))
     (module-value (module-closure-body fn) local)]
    [else (type-error 'runtime-module context "module procedure required")]))
(define (evaluate-module d env)
  (hash-update! (current-evaluations) (mdef-name d) add1 0)
  (define body-env (if (and (eq? (current-dependencies) 'imports) (not (eq? (mbody-kind (mdef-body d)) 'scope)))
                       (runtime-scope env #f) env))
  (project-module (module-value (mdef-body d) body-env) (mdef-iface d) env))
;; END module-evaluation
(define (evaluate-program tree)
  (define env empty-renv)
  (for ([d (program-definitions tree)])
    (cond [(idef? d) (set! env (struct-copy renv env [interfaces (cons (cons (idef-name d) (cons (idef-iface d) env)) (renv-interfaces env))]))]
          [else (define v (if (eq? (current-dependencies) 'imports)
                             (delayed-module d env (box 'new) (box #f)) (evaluate-module d env)))
                (set! env (rbind-module env (mdef-name d) v))]))
  (value-of (program-body tree) (runtime-scope env (program-scope tree))))
(define (run/trace source #:unordered? [unordered? #f] #:inferred? [inferred? #f]
                   #:dependencies [dependencies 'none] #:check? [check? #t] #:fuel [fuel 100000])
  (unless (exact-positive-integer? fuel)
    (type-error 'fuel fuel "evaluation budget must be a positive exact integer"))
  (define tree (if (program? source) source (parse-program source)))
  (define type (and check? (check tree #:unordered? unordered? #:inferred? inferred? #:dependencies dependencies)))
  (parameterize ([current-dependencies dependencies] [current-output (box '())]
                 [current-evaluations (make-hasheq)] [current-fuel (box fuel)])
    (define v (evaluate-program tree))
    (execution type (if (closure? v) '<procedure> v) (unbox (current-output)) (hash-copy (current-evaluations)))))
(define (run source #:unordered? [unordered? #f] #:inferred? [inferred? #f]
             #:dependencies [dependencies 'none] #:check? [check? #t] #:fuel [fuel 100000])
  (execution-value (run/trace source #:unordered? unordered? #:inferred? inferred? #:dependencies dependencies #:check? check? #:fuel fuel)))
(define (compare-interfaces left right #:unordered? [unordered? #f])
  (define (read-one s) (mdef-iface (car (program-definitions (parse-program (string-append "module sample interface " s " body [] 0"))))))
  (parameterize ([current-unordered? unordered?] [current-labels (make-hasheq)])
    (interface-subtype? (normalize-interface (read-one left) empty-tenv (fresh-key 'left))
                        (normalize-interface (read-one right) empty-tenv (fresh-key 'right)))))
(module+ main
  (define sample "module m interface [a : int b : int c : int] body [a=33 x=-(a,1) b=-(a,x) c=-(x,b)] let a=10 in -(-(from m take a,from m take b),a)")
  (displayln (check sample)) (displayln (run sample)))
