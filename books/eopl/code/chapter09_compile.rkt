#lang racket
(require racket/match "chapter09_syntax.rkt" "chapter09_runtime.rkt")
(provide (all-defined-out))
(define (mangled name n) (string->symbol (format "~a:@~a" name n)))
;; Scope-aware transformation: both reads and assignments use depth/index.
(define (translate body names classes host #:lexical? [lexical? #f] #:direct-super? [direct? #f] #:named-slots? [slots? #f])
  (define (address name frames)
    (let loop ([frames frames] [depth 0])
      (when (null? frames) (oo-error 'unbound name "lexical address cannot find ~a" name))
      (define index (index-of (car frames) name))
      (if index (list depth index) (loop (cdr frames) (add1 depth)))))
  (define (resolve name) (if (and host (eq? name (rclass-name host))) host (lookup-class classes name)))
  (define (walk-data x frames)
    (cond [(expr? x) (walk x frames)] [(pair? x) (cons (walk-data (car x) frames) (walk-data (cdr x) frames))] [else x]))
  (define (walk e frames)
    (match e
      [(expr 'var (list n)) (if lexical? (expr 'lexref (address n frames)) e)]
      [(expr 'set (list n rhs)) (define r (walk rhs frames)) (if lexical? (expr 'lexset (append (address n frames) (list r))) (E 'set n r))]
      [(expr 'proc (list ps b)) (E 'proc ps (walk b (cons (map car ps) frames)))]
      [(expr 'let (list bs b)) (E 'let (map (lambda (p) (cons (car p) (walk (cdr p) frames))) bs) (walk b (cons (map car bs) frames)))]
      [(expr 'rec (list ds b))
       (define next (cons (map car ds) frames))
       (E 'rec (map (lambda (d) (list (car d) (cadr d) (caddr d) (walk (cadddr d) (cons (map car (cadr d)) next)))) ds) (walk b next))]
      [(expr 'super (list name operands))
       (if direct?
           (let* ([parent (parent-of host)] [method (hash-ref (rclass-table parent) (method-key name (length operands))
                                                            (lambda () (oo-error 'method name "no static super method")))])
             (E 'direct-super method (map (lambda (x) (walk x frames)) operands)))
           (E 'super name (map (lambda (x) (walk x frames)) operands)))]
      [(expr (and tag (or 'named-send 'static-send)) (list name receiver method operands))
       (if slots?
           (let* ([class (resolve name)] [index (for/first ([m (in-vector (rclass-slots class))] [i (in-naturals)] #:when (equal? (rmethod-key m) (method-key method (length operands)))) i)])
             (unless index (oo-error 'method method "no named method slot"))
             (E 'named-slot class index (walk receiver frames) (map (lambda (x) (walk x frames)) operands)))
           (expr tag (list name (walk receiver frames) method (map (lambda (x) (walk x frames)) operands))))]
      [(expr 'local-class (list declaration b)) (E 'local-class declaration (walk b frames))]
      [(expr 'extend _) (when lexical? (oo-error 'compile e "prototype lexical fields require runtime templates; lexical-address mode covers CLASSES")) e]
      [(expr tag args) (expr tag (walk-data args frames))]))
  (walk body names))
(define (mangle-program program)
  (define (data x) (cond [(expr? x) (walk x)] [(pair? x) (cons (data (car x)) (data (cdr x)))] [else x]))
  (define (method d) (struct-copy mdecl d [name (mangled (mdecl-name d) (length (mdecl-params d)))] [body (and (mdecl-body d) (walk (mdecl-body d)))]))
  (define (decl d)
    (if (idecl? d) (struct-copy idecl d [methods (map method (idecl-methods d))])
        (struct-copy cdecl d [methods (cons (mdecl 'initialize '() 'int (E 'const 1) 'public #f #f) (map method (cdecl-methods d)))]
                     [fields (map (lambda (f) (struct-copy fdecl f [init (and (fdecl-init f) (walk (fdecl-init f)))])) (cdecl-fields d))]
                     [statics (map (lambda (f) (struct-copy fdecl f [init (walk (fdecl-init f))])) (cdecl-statics d))])))
  (define (walk e)
    (match e
      [(expr 'send (list receiver name operands)) (E 'send (walk receiver) (mangled name (length operands)) (map walk operands))]
      [(expr (and tag (or 'named-send 'static-send)) (list c receiver name operands)) (expr tag (list c (walk receiver) (mangled name (length operands)) (map walk operands)))]
      [(expr 'super (list name operands)) (E 'super (mangled name (length operands)) (map walk operands))]
      [(expr 'new (list c operands))
       ;; The preprocessor targets the original interpreter: a zero-argument
       ;; constructor bridge allocates C, then an explicit mangled initializer runs.
       (define temporaries (for/list ([e operands]) (gensym 'constructor-arg)))
       (define receiver (gensym 'constructor-object))
       (define finish
         (E 'let (list (cons receiver (E 'new c '())))
            (expr 'begin (list (E 'send (E 'var receiver) (mangled 'initialize (length operands))
                                  (map (lambda (n) (E 'var n)) temporaries))
                               (E 'var receiver)))))
       (if (null? operands) finish
           (E 'let (map (lambda (n e) (cons n (walk e))) temporaries operands) finish))]
      [(expr 'local-class (list d b)) (E 'local-class (decl d) (walk b))]
      [(expr 'call (list (expr 'getmethod (list receiver name)) operands)) (E 'call (E 'getmethod (walk receiver) (mangled name (length operands))) (map walk operands))]
      [(expr 'newobject (list parent bs))
       (E 'newobject (and parent (walk parent))
          (for/list ([b bs]) (match (cdr b) [(expr 'proc (list ps _)) (cons (mangled (car b) (length ps)) (walk (cdr b)))] [_ (oo-error 'compile b "mangling needs literal closure method")])))]
      [(expr tag args) (expr tag (data args))]))
  (pgm (map decl (pgm-decls program)) (walk (pgm-body program)) (pgm-typed? program)))
