#lang racket
;; Nominal object/interface types and elaboration for static dispatch/field access.
(require racket/match "chapter09_syntax.rkt" "chapter09_runtime.rkt")
(provide (all-defined-out))
(struct sfield (name owner type init visibility) #:transparent)
(struct smethod (decl owner) #:transparent)
(struct sclass (name interface? parents interfaces fields view statics methods) #:transparent)
(struct checked (type program classes) #:transparent)
(define primitives '(int bool void string))
(define (nominal? t classes) (and (symbol? t) (hash-has-key? classes t)))
(define (static-class classes name [require-class? #f])
  (define c (hash-ref classes name (lambda () (oo-error 'class name "unknown class/interface type ~a" name))))
  (when (and require-class? (sclass-interface? c)) (oo-error 'class name "expected concrete class, found interface")) c)
(define (nominal-below? a b classes)
  (or (eq? a b) (eq? b 'object)
      (let ([c (static-class classes a)])
        (or (for/or ([p (sclass-parents c)]) (nominal-below? p b classes))
            (for/or ([p (sclass-interfaces c)]) (nominal-below? p b classes))))))
(define (subtype? a b classes)
  (or (equal? a b)
      (and (nominal? a classes) (nominal? b classes) (nominal-below? a b classes))
      (match* (a b)
        [((list 'proc as ar) (list 'proc bs br))
         (and (= (length as) (length bs))
              (for/and ([expected bs] [accepted as]) (subtype? expected accepted classes))
              (subtype? ar br classes))]
        [(_ _) #f])))
(define (require-subtype! a b classes where)
  (unless (subtype? a b classes) (oo-error 'type where "~s is not a subtype of ~s" a b)))
(define (valid-type! t headers)
  (match t
    [(list 'proc args result) (for-each (lambda (t) (valid-type! t headers)) args) (valid-type! result headers)]
    [(list 'listof element) (valid-type! element headers)]
    [_ (unless (and t (or (memq t primitives) (hash-has-key? headers t))) (oo-error 'annotation t "unknown or missing type ~a" t))]))
(define (signature m) (list 'proc (map cdr (mdecl-params m)) (mdecl-result m)))
(define (smethod-key m) (method-key (mdecl-name (smethod-decl m)) (length (mdecl-params (smethod-decl m)))))
(define (method-type class name arity)
  (hash-ref (sclass-methods class) (method-key name arity) (lambda () (oo-error 'method name "method ~a absent from static type ~a" name (sclass-name class)))))
(define (static-access! vis owner host classes where)
  (unless (or (eq? vis 'public) (and host (if (eq? vis 'private) (eq? owner host) (nominal-below? host owner classes))))
    (oo-error 'access where "member is not visible from host ~a" host)))
(define (static-fields c host classes)
  (filter (lambda (p) (define f (cdr p))
            (and (or (not (option 'host-fields-only?)) (eq? (sfield-owner f) host))
                 (or (not (eq? (sfield-visibility f) 'private)) (eq? (sfield-owner f) host)))) (sclass-view c)))
(define (static-statics c host)
  (filter (lambda (f) (or (not (eq? (sfield-visibility f) 'private)) (eq? (sfield-owner f) host))) (sclass-statics c)))
(define (lookup-type env name)
  (cond [(null? env) (oo-error 'unbound name "unbound type variable ~a" name)]
        [(assq name (car env)) => cdr] [else (lookup-type (cdr env) name)]))
(define (build-static declarations)
  (define headers (hash 'object 'class))
  (for ([d declarations])
    (define n (if (cdecl? d) (cdecl-name d) (idecl-name d)))
    (when (or (hash-has-key? headers n) (memq n primitives)) (oo-error 'duplicate n "duplicate/reserved class or interface name"))
    (set! headers (hash-set headers n (if (cdecl? d) 'class 'interface))))
  ;; Nominal relationships are known before any inherited signature is compared.
  ;; Method annotations can mention classes declared later, although extends stays ordered.
  (define hierarchy
    (for/fold ([h (hash 'object (sclass 'object #f '() '() '() '() '() (hash)))]) ([d declarations])
      (define n (if (cdecl? d) (cdecl-name d) (idecl-name d)))
      ;; Validate the ordered hierarchy before signature comparison can traverse
      ;; forward annotation types. Otherwise a later illegal cycle can make an
      ;; earlier inherited-interface comparison recurse forever.
      (define (parent! p interface?)
        (define c (static-class h p (not interface?)))
        (when (and interface? (not (sclass-interface? c)))
          (oo-error 'interface p "interface inheritance requires an interface")))
      (if (cdecl? d)
          (begin
            (unless (= (length (cdecl-supers d)) 1)
              (oo-error 'inheritance n "TYPED-OO keeps single class inheritance"))
            (for ([p (cdecl-supers d)]) (parent! p #f))
            (for ([p (cdecl-interfaces d)]) (parent! p #t)))
          (for ([p (idecl-parents d)]) (parent! p #t)))
      (hash-set h n (if (cdecl? d)
                       (sclass n #f (cdecl-supers d) (cdecl-interfaces d) '() '() '() (hash))
                       (sclass n #t (idecl-parents d) '() '() '() '() (hash))))))
  (define classes (hash 'object (sclass 'object #f '() '() '() '() '() (hash))))
  (define (declare-methods! ms)
    (unique! (map (lambda (m) (method-key (mdecl-name m) (length (mdecl-params m)))) ms) 'typed-methods)
    (for ([m ms]) (valid-type! (signature m) headers)))
  (for ([d declarations])
    (cond
      [(idecl? d)
       (define n (idecl-name d)) (define parents (idecl-parents d)) (unique! parents 'interface-parents)
       (for ([p parents]) (unless (sclass-interface? (static-class classes p)) (oo-error 'interface p "interface parent must be interface")))
       (declare-methods! (idecl-methods d))
       (define own (for/hash ([m (idecl-methods d)]) (values (method-key (mdecl-name m) (length (mdecl-params m))) (smethod m n))))
       (define ms own)
       (for ([p parents])
         (for ([(k old) (in-hash (sclass-methods (static-class classes p)))])
           (define current (hash-ref ms k #f))
           (cond [(not current) (set! ms (hash-set ms k old))]
                 [(subtype? (signature (smethod-decl current)) (signature (smethod-decl old)) hierarchy) (void)]
                 [(and (not (hash-has-key? own k)) (subtype? (signature (smethod-decl old)) (signature (smethod-decl current)) hierarchy)) (set! ms (hash-set ms k old))]
                 [else (oo-error 'interface k "incompatible inherited interface methods")])))
       (set! classes (hash-set classes n (sclass n #t parents '() '() '() '() ms)))]
      [else
       (match-define (cdecl n parent-names interfaces fs ss ms) d)
       (unless (= (length parent-names) 1) (oo-error 'inheritance n "TYPED-OO keeps single class inheritance"))
       (define parent (static-class classes (car parent-names) #t))
       (unique! interfaces 'implements)
       (for ([p interfaces]) (unless (sclass-interface? (static-class classes p)) (oo-error 'interface p "implements requires interface")))
       (unique! (append (map fdecl-name fs) (map fdecl-name ss)) 'typed-fields) (declare-methods! ms)
       (for ([f (append fs ss)]) (valid-type! (fdecl-type f) headers))
       (define fields (map (lambda (f) (sfield (fdecl-name f) n (fdecl-type f) (fdecl-init f) (fdecl-visibility f))) fs))
       (define static-fields* (map (lambda (f) (sfield (fdecl-name f) n (fdecl-type f) (fdecl-init f) (fdecl-visibility f))) ss))
       (define own-names (map fdecl-name fs))
       (define view (append (for/list ([p (sclass-view parent)]) (cons (if (memq (car p) own-names) (gensym (car p)) (car p)) (cdr p)))
                            (map (lambda (f) (cons (sfield-name f) f)) fields)))
       (define methods (sclass-methods parent))
       (for ([m ms]) (set! methods (hash-set methods (method-key (mdecl-name m) (length (mdecl-params m))) (smethod m n))))
       (define c (sclass n #f parent-names (remove-duplicates (append interfaces (sclass-interfaces parent)))
                         (append (sclass-fields parent) fields) view
                         (append static-fields* (filter (lambda (f) (not (memq (sfield-name f) (map fdecl-name ss)))) (sclass-statics parent))) methods))
       (unless (for/or ([(k m) (in-hash methods)]) (eq? (mdecl-name (smethod-decl m)) 'initialize)) (oo-error 'initialize n "class requires initialize method"))
       (set! classes (hash-set classes n c))]))
  (values classes headers))
(define (infer-expression e env classes headers host)
  (define (infer e [env env] [host host]) (infer-expression e env classes headers host))
  (define (same t expected where) (require-subtype! t expected classes where))
  (define (call m operands where)
    (define t (if (smethod? m) (signature (smethod-decl m)) m))
    (match t
      [(list 'proc args result)
       (unless (= (length args) (length operands)) (oo-error 'arity where "typed call arity mismatch"))
       (define checked-operands (for/list ([e operands] [a args]) (define-values (t e*) (infer e)) (same t a e) e*))
       (values result checked-operands)]
      [_ (oo-error 'procedure where "operator is not a procedure")]))
  (define (constructor-use! name where)
    (when (and (eq? name 'initialize) (eq? (option 'initialization 'textbook) 'new-only)) (oo-error 'initialize where "initialize can only be invoked by new")))
  (match e
    [(expr 'const (list v)) (values (cond [(exact-integer? v) 'int] [(boolean? v) 'bool] [(string? v) 'string]) e)]
    [(expr 'unit _) (values 'void e)]
    [(expr 'var (list n)) (values (lookup-type env n) e)]
    [(expr 'self _) (unless host (oo-error 'self e "self outside method")) (values host e)]
    [(expr 'set (list n rhs)) (define-values (t r) (infer rhs)) (same t (lookup-type env n) e) (values 'void (E 'set n r))]
    [(expr 'if (list c a b))
     (define-values (ct c*) (infer c)) (same ct 'bool c)
     (define-values (at a*) (infer a)) (define-values (bt b*) (infer b))
     (define result (cond [(subtype? at bt classes) bt] [(subtype? bt at classes) at] [else (oo-error 'type e "incompatible conditional branch types")]))
     (values result (E 'if c* a* b*))]
    [(expr 'proc (list ps body))
     (for ([p ps]) (valid-type! (cdr p) headers))
     (define-values (t b) (infer body (cons ps env))) (values (list 'proc (map cdr ps) t) (E 'proc ps b))]
    [(expr 'let (list bindings body))
     (define ns '()) (define bs '())
     (for ([p bindings]) (define-values (t e*) (infer (cdr p))) (set! ns (append ns (list (cons (car p) t)))) (set! bs (append bs (list (cons (car p) e*)))))
     (define-values (t b) (infer body (cons ns env))) (values t (E 'let bs b))]
    [(expr 'rec (list ds body))
     (define types (for/list ([d ds]) (define t (list 'proc (map cdr (cadr d)) (caddr d))) (valid-type! t headers) (cons (car d) t)))
     (define next (cons types env))
     (define ds* (for/list ([d ds]) (define-values (t b) (infer (cadddr d) (cons (cadr d) next))) (same t (caddr d) d) (list (car d) (cadr d) (caddr d) b)))
     (define-values (t b) (infer body next)) (values t (E 'rec ds* b))]
    [(expr 'call (list f operands)) (define-values (ft f*) (infer f)) (define-values (result es) (call ft operands e)) (values result (E 'call f* es))]
    [(expr 'begin es) (define result 'void) (define es* (for/list ([e es]) (define-values (t x) (infer e)) (set! result t) x)) (values result (expr 'begin es*))]
    [(expr 'emptylist (list t)) (valid-type! t headers) (values (list 'listof t) e)]
    [(expr 'prim (list name operands))
     (define ts '()) (define es (for/list ([e operands]) (define-values (t e*) (infer e)) (set! ts (append ts (list t))) e*))
     (define arity (hash-ref primitive-arities name #f))
     (when (and arity (not (= arity (length ts)))) (oo-error 'arity e "primitive arity mismatch"))
     (define result
       (case name
         [(+ - * zero? equal? less? greater? number-to-string) (for ([t ts]) (same t 'int e))
          (case name [(zero? equal? less? greater?) 'bool] [(number-to-string) 'string] [else 'int])]
         [(concat) (for ([t ts]) (same t 'string e)) 'string]
         [(print) (same (car ts) 'int e) 'int]
         [(list) (when (null? ts) (oo-error 'annotation e "typed list requires at least one element"))
          (define first (car ts)) (for ([t ts]) (unless (equal? t first) (oo-error 'type e "list literal element types must be equal"))) (list 'listof first)]
         [(cons) (match (cadr ts) [(list 'listof t) (same (car ts) t e) (cadr ts)] [_ (oo-error 'type e "cons tail must be a list")])]
         [(car cdr null?) (match (car ts) [(list 'listof t) (case name [(car) t] [(cdr) (car ts)] [else 'bool])] [_ (oo-error 'type e "list operation needs list")])]
         [else (oo-error 'primitive name "unknown primitive")]))
     (values result (E 'prim name es))]
    [(expr 'new (list name operands))
     (define c (static-class classes name #t)) (define m (method-type c 'initialize (length operands)))
     (static-access! (mdecl-visibility (smethod-decl m)) (smethod-owner m) host classes e)
     (define-values (_ args) (call m operands e)) (values name (E 'new name args))]
    [(expr (and tag (or 'send 'named-send 'super 'static-send)) data)
     (define named? (memq tag '(named-send static-send))) (define super? (eq? tag 'super))
     (define qualifier (and named? (car data)))
     (define receiver (cond [super? (E 'self)] [named? (cadr data)] [else (car data)]))
     (define name (if super? (car data) (if named? (caddr data) (cadr data))))
     (define operands (last data)) (constructor-use! name e)
     (define-values (rt r*) (infer receiver))
     (unless (nominal? rt classes) (oo-error 'object e "method target is not an object"))
     (define target (cond [named? qualifier] [super? (car (sclass-parents (static-class classes host #t)))] [else rt]))
     (when named? (static-class classes target #t) (same rt target e))
     (define m (method-type (static-class classes target) name (length operands)))
     (static-access! (mdecl-visibility (smethod-decl m)) (smethod-owner m) host classes e)
     (define-values (result args) (call m operands e))
     (values result (cond [super? (E 'super name args)]
                          [(or named? (mdecl-static? (smethod-decl m)) (and (option 'static-self?) (eq? (expr-tag receiver) 'self))) (E 'static-send target r* name args)]
                          [else (E 'send r* name args)]))]
    [(expr (and tag (or 'cast 'instanceof)) (list receiver target))
     (define-values (t e*) (infer receiver)) (unless (nominal? t classes) (oo-error 'object e "cast/instanceof operand must be object"))
     (static-class classes target #t)
     (when (and (eq? (option 'casts 'runtime) 'related) (not (sclass-interface? (static-class classes t)))
                (not (or (nominal-below? t target classes) (nominal-below? target t classes))))
       (oo-error 'cast e "unrelated concrete classes cannot pass cast/instanceof"))
     (values (if (eq? tag 'cast) target 'bool) (E tag e* target))]
    [(expr 'field (list named super? receiver name rhs))
     (define-values (rt r*) (infer receiver))
     (unless (nominal? rt classes) (oo-error 'object e "field target must be class object"))
     (define qualifier (cond [named named] [super? (unless host (oo-error 'super e "super outside method")) (car (sclass-parents (static-class classes host #t)))] [else rt]))
     (define c (static-class classes qualifier #t)) (same rt qualifier e)
     (define pair (assq name (sclass-view c))) (unless pair (oo-error 'field e "unknown or hidden field"))
     (define f (cdr pair)) (static-access! (sfield-visibility f) (sfield-owner f) host classes e)
     ;; Freeze the statically selected class, so descendant field shadowing cannot change the type.
     (if rhs (let-values ([(t x) (infer rhs)]) (same t (sfield-type f) e) (values 'void (E 'field qualifier #f r* name x)))
         (values (sfield-type f) (E 'field qualifier #f r* name #f)))]
    [_ (oo-error 'typed-extension e "expression is outside TYPED-OO; use untyped CLASSES for classless/prototype extensions")]))
(define (check-program program options)
  (parameterize ([current-options options])
    (define-values (classes headers) (build-static (pgm-decls program)))
    (define declarations
      (for/list ([d (pgm-decls program)])
        (if (idecl? d) d
            (let* ([name (cdecl-name d)] [c (static-class classes name #t)] [parent (static-class classes (car (cdecl-supers d)) #t)]
                   [fields (static-fields c name classes)] [statics (static-statics c name)])
              (define earlier-statics (sclass-statics parent))
              (define statics* (for/list ([s (cdecl-statics d)])
                (define-values (t initializer*) (infer-expression (fdecl-init s) (list (map (lambda (s) (cons (sfield-name s) (sfield-type s))) earlier-statics)) classes headers #f))
                (require-subtype! t (fdecl-type s) classes s)
                (set! earlier-statics (cons (sfield (fdecl-name s) name (fdecl-type s) (fdecl-init s) (fdecl-visibility s)) earlier-statics))
                (struct-copy fdecl s [init initializer*])))
              (define fields* (for/list ([f (cdecl-fields d)])
                (when (and (option 'field-initializers?) (not (fdecl-init f))) (oo-error 'initialization f "every field needs an initializer"))
                (define initializer* #f)
                (when (fdecl-init f)
                  (define sf (cdr (assq (fdecl-name f) (sclass-view c))))
                  (define before (takef (sclass-fields c) (lambda (x) (not (eq? x sf)))))
                  (define names (for/list ([p fields] #:when (memq (cdr p) before)) (cons (car p) (sfield-type (cdr p)))))
                  (define-values (t rewritten) (infer-expression (fdecl-init f) (list names (map (lambda (s) (cons (sfield-name s) (sfield-type s))) statics)) classes headers #f))
                  (require-subtype! t (fdecl-type f) classes f)
                  (set! initializer* rewritten))
                (struct-copy fdecl f [init initializer*])))
              (define methods
                (for/list ([m (cdecl-methods d)])
                  (define inherited (hash-ref (sclass-methods parent) (method-key (mdecl-name m) (length (mdecl-params m))) #f))
                  (when inherited
                    (define old (smethod-decl inherited))
                    (when (mdecl-final? old) (oo-error 'final m "cannot override final method"))
                    (unless (eq? (mdecl-static? m) (mdecl-static? old)) (oo-error 'dispatch m "static/dynamic method kind changed"))
                    (unless (or (eq? (mdecl-name m) 'initialize) (subtype? (signature m) (signature old) classes)) (oo-error 'override m "override method type is not a subtype"))
                    (define (visibility-rank v) (index-of '(private protected public) v))
                    (when (< (visibility-rank (mdecl-visibility m)) (visibility-rank (mdecl-visibility old))) (oo-error 'access m "override narrows visibility")))
                  (when (and (eq? (mdecl-name m) 'initialize) (mdecl-static? m)) (oo-error 'initialize m "initializer cannot be static"))
                  (define env (list (mdecl-params m) (map (lambda (p) (cons (car p) (sfield-type (cdr p)))) fields)
                                    (map (lambda (s) (cons (sfield-name s) (sfield-type s))) statics)))
                  (define-values (t b) (infer-expression (mdecl-body m) env classes headers name))
                  (require-subtype! t (mdecl-result m) classes m) (struct-copy mdecl m [body b])))
              (for ([interface (sclass-interfaces c)])
                (for ([(k required) (in-hash (sclass-methods (static-class classes interface)))])
                  (define provided (hash-ref (sclass-methods c) k (lambda () (oo-error 'interface interface "missing required interface method"))))
                  (define pm (smethod-decl provided))
                  (unless (and (eq? (mdecl-visibility pm) 'public) (not (mdecl-static? pm))) (oo-error 'interface pm "interface needs public dynamic method"))
                  (require-subtype! (signature pm) (signature (smethod-decl required)) classes interface)))
              (struct-copy cdecl d [methods methods] [fields fields*] [statics statics*])))))
    (define-values (type body) (infer-expression (pgm-body program) (list '((i . int) (v . int) (x . int))) classes headers #f))
    (checked type (pgm declarations body #t) classes)))
