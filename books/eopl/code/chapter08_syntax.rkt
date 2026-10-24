#lang racket
;; Concrete syntax for modules, interfaces and the CHECKED expression language.
(require "chapter07_types.rkt" (only-in "chapter07_syntax.rkt" node node? node-op node-args))
(provide (all-defined-out) (all-from-out "chapter07_syntax.rkt"))
(struct qualified (path name) #:transparent)
(struct named (name) #:transparent)
(struct iface-name (name) #:transparent)
(struct simple-iface (decls) #:transparent)
(struct proc-iface (params result) #:transparent)
(struct parameter (name key iface) #:transparent)
(struct decl (kind name payload) #:transparent)
(struct mbody (kind args) #:transparent)
(struct mdef (name iface body) #:transparent)
(struct idef (name iface) #:transparent)
(struct program (definitions scope body) #:transparent)
(define keywords
  '("module" "interface" "body" "module-proc" "opaque" "transparent" "type"
    "from" "take" "let" "letrec" "in" "proc" "if" "then" "else" "int" "bool"
    "pairof" "begin" "end" "depends-on" "import" "imports"))
(define (identifier? s)
  (and (regexp-match? #px"^[A-Za-z][A-Za-z0-9?\\-]*$" s) (not (member s keywords))))
(define (tokens source)
  (define rx #px"\\s+|%[^\n]*|->|=>|-?[0-9]+|[A-Za-z][A-Za-z0-9?\\-]*|[][():,=*?;.]+|[-+]")
  ;; Punctuation is split separately; identifiers and arrows remain whole.
  (let loop ([pos 0] [out '()])
    (if (= pos (string-length source)) (reverse out)
        (let ([m (regexp-match-positions rx source pos)])
          (unless (and m (= (caar m) pos)) (type-error 'parse pos "invalid token at ~a" pos))
          (define t (substring source pos (cdar m)))
          (define skip? (or (regexp-match? #px"^\\s" t) (string-prefix? t "%")))
          (define pieces (if (regexp-match? #px"^[][():,=*?;.]+$" t) (map string (string->list t)) (list t)))
          (loop (cdar m) (if skip? out (append (reverse pieces) out)))))))
(define (unique! names context)
  (unless (= (length names) (length (remove-duplicates names)))
    (type-error 'duplicate context "duplicate binding: ~a" names)))
(define (parse-program source)
  (define ts (list->vector (append (tokens source) '("<eof>")))); cursor is local to one parse.
  (define pos 0)
  (define (peek [offset 0]) (vector-ref ts (min (+ pos offset) (sub1 (vector-length ts)))))
  (define (take!) (begin0 (peek) (set! pos (add1 pos))))
  (define (expect! s)
    (unless (equal? (peek) s) (type-error 'parse pos "expected ~a, received ~a" s (peek))) (take!))
  (define (name!)
    (unless (identifier? (peek)) (type-error 'parse pos "identifier required, received ~a" (peek)))
    (string->symbol (take!)))
  (define (path-tail root)
    (let loop ([out (list root)])
      (if (member (peek) '("take" ".")) (begin (take!) (loop (append out (list (name!))))) out)))
  (define (read-type [allow-arrow? #t])
    (define atom
      (match (take!)
        [(or "int" "bool") (string->symbol (vector-ref ts (sub1 pos)))]
        ["?" #f]
        ["pairof" (define a (read-type #f)) (expect! "*") (pair-t a (read-type #f))]
        ["from" (define root (name!)) (expect! "take")
                (define path (path-tail (name!))) (qualified (cons root (drop-right path 1)) (last path))]
        ["(" (define first (read-type #f))
             (define args (let loop ([out (list first)])
                            (if (equal? (peek) "*") (begin (take!) (loop (append out (list (read-type #f))))) out)))
             (define t (if (equal? (peek) "->") (begin (take!) (proc-t args (read-type)))
                           (if (= (length args) 1) first (type-error 'parse pos "arrow required"))))
             (expect! ")") t]
        [(? identifier? s) (if (equal? (peek) ".")
                              (let ([p (path-tail (string->symbol s))]) (qualified (drop-right p 1) (last p)))
                              (named (string->symbol s)))]
        [s (type-error 'parse pos "invalid type: ~a" s)]))
    ;; Also accepts the source's unparenthesized arrows in8.5 and8.27.
    (if (and allow-arrow? (equal? (peek) "->")) (begin (take!) (proc-t (list atom) (read-type))) atom))
  (define (read-interface)
    (match (take!)
      ["[" (define ds
             (let loop ([out '()])
               (cond [(equal? (peek) "]") out]
                     [(equal? (peek) "opaque") (take!) (loop (append out (list (decl 'opaque (name!) #f))))]
                     [(equal? (peek) "transparent") (take!) (define n (name!)) (expect! "=")
                      (loop (append out (list (decl 'type n (read-type)))))]
                     [else (define n (name!)) (expect! ":")
                           (define component? (or (equal? (peek) "[") (and (equal? (peek) "(") (equal? (peek 1) "("))))
                           (define v (if component? (read-interface) (read-type)))
                           (loop (append out (list (decl (if component? 'module 'value) n v))))])))
           (expect! "]") (unique! (map decl-name ds) ds) (simple-iface ds)]
      ["(" (expect! "(") (define ps (interface-parameters ")")) (expect! ")") (expect! "=>")
           (define result (read-interface)) (expect! ")") (proc-iface ps result)]
      [(? identifier? s) (iface-name (string->symbol s))]
      [s (type-error 'parse pos "invalid interface: ~a" s)]))
  (define (interface-parameters stop)
    (define ps
      (let loop ([out '()])
        (define n (name!)) (expect! ":") (define i (read-interface))
        (define next (append out (list (parameter n n i))))
        (cond [(equal? (peek) stop) next]
              [(equal? (peek) ",") (take!) (loop next)]
              [else (loop next)])))
    (unique! (map parameter-name ps) ps) ps)
  (define (parameters)
    (expect! "(")
    (define ps
      (if (equal? (peek) ")") '()
          (let loop ([out '()])
            (define n (name!)) (define t (if (equal? (peek) ":") (begin (take!) (read-type)) #f))
            (define next (append out (list (cons n t))))
            (if (equal? (peek) ",") (begin (take!) (loop next)) next))))
    (expect! ")") (unique! (map car ps) ps) ps)
  (define (bindings)
    (define out
      (let loop ([bs '()])
        (define n (name!)) (expect! "=") (define e (expression))
        (define next (append bs (list (cons n e))))
        (if (equal? (peek) "in") next (loop next))))
    (unique! (map car out) out) (expect! "in") out)
  (define (rec-bindings)
    (define out
      (let loop ([ds '()])
        (define result (read-type)) (define n (name!)) (define ps (parameters))
        (expect! "=") (define e (expression))
        (define next (append ds (list (list n ps result e))))
        (if (equal? (peek) "in") next (loop next))))
    (unique! (map car out) out) (expect! "in") out)
  (define (scope-clause)
    (if (member (peek) '("depends-on" "imports" "import"))
        (let* ([s (take!)] [kind (if (equal? s "depends-on") 'depends-on 'imports)])
          (define ns (if (identifier? (peek))
                         (let loop ([out (list (name!))])
                           (if (equal? (peek) ",") (begin (take!) (loop (append out (list (name!))))) out))
                         '()))
          (unique! ns ns) (cons kind ns)) #f))
  (define (module-definition)
    (expect! "module") (define n (name!)) (expect! "interface") (define i (read-interface))
    (expect! "body") (mdef n i (module-body)))
  (define (module-body)
    (define sc (scope-clause))
    (if sc (mbody 'scope (list sc (module-body)))
        (match (take!)
          ["[" (define ds
                 (let loop ([out '()])
                   (cond [(equal? (peek) "]") out]
                         [(equal? (peek) "type") (take!) (define n (name!)) (expect! "=")
                          (loop (append out (list (decl 'type n (read-type)))))]
                         [else (define n (name!)) (expect! "=")
                               (loop (append out (list (decl 'value n (expression)))))])))
               (expect! "]") (unique! (map decl-name ds) ds) (mbody 'defs ds)]
          ["let" (define bs (bindings)) (mbody 'let (list bs (module-body)))]
          ["letrec" (define ds (rec-bindings)) (mbody 'rec (list ds (module-body)))]
          ["module" (set! pos (sub1 pos)) (define d (module-definition)) (mbody 'local (list d (module-body)))]
          ["module-proc" (expect! "(") (define ps (interface-parameters ")")) (expect! ")")
                         (mbody 'proc (list ps (module-body)))]
          ["(" (define f (module-body))
               (define args (let loop ([out '()]) (if (equal? (peek) ")") out (loop (append out (list (module-body)))))))
               (expect! ")") (when (null? args) (type-error 'parse pos "module application needs an argument"))
               (mbody 'app (list f args))]
          [(? identifier? s) (mbody 'var (list (string->symbol s)))]
          [s (type-error 'parse pos "invalid module body: ~a" s)])))
  (define (expression)
    (define s (take!))
    (cond
      [(regexp-match? #px"^-?[0-9]+$" s) (node 'num (list (string->number s)))]
      [(equal? s "from") (define root (name!)) (expect! "take")
                         (node 'qualified (cons root (path-tail (name!))))]
      [(equal? s "proc") (define ps (parameters)) (node 'proc (list ps (expression)))]
      [(equal? s "if") (define c (expression)) (expect! "then") (define a (expression))
                       (expect! "else") (node 'if (list c a (expression)))]
      [(equal? s "let") (define bs (bindings)) (node 'let (list bs (expression)))]
      [(equal? s "letrec") (define ds (rec-bindings)) (node 'rec (list ds (expression)))]
      [(equal? s "(") (define f (expression))
                      (define args (let loop ([out '()])
                                     (if (equal? (peek) ")") out (loop (append out (list (expression)))))))
                      (expect! ")") (node 'call (list f args))]
      [(equal? s "unpair") (define x (name!)) (define y (name!)) (unique! (list x y) s)
                           (expect! "=") (define p (expression)) (expect! "in")
                           (node 'unpair (list x y p (expression)))]
      [(equal? s "begin") (define es
                            (let loop ([out (list (expression))])
                              (if (equal? (peek) "end") out
                                  (begin (expect! ";") (loop (append out (list (expression))))))))
                         (expect! "end") (node 'begin es)]
      [(member s '("-" "+" "zero?" "print" "newpair"))
       (expect! "(")
       (define es (let loop ([out (list (expression))])
                    (if (equal? (peek) ",") (begin (take!) (loop (append out (list (expression))))) out)))
       (expect! ")")
       (unless (= (length es) (if (member s '("zero?" "print")) 1 2)) (type-error 'arity s "primitive arity differs"))
       (node (string->symbol s) es)]
      [(identifier? s)
       (define path (path-tail (string->symbol s)))
       (if (= (length path) 1) (node 'var path) (node 'qualified path))]
      [else (type-error 'parse pos "invalid expression: ~a" s)]))
  (define definitions
    (let loop ([out '()])
      (cond [(equal? (peek) "module") (loop (append out (list (module-definition))))]
            [(equal? (peek) "interface") (take!) (define n (name!)) (expect! "=")
             (loop (append out (list (idef n (read-interface)))))]
            [else out])))
  (define sc (scope-clause)) (define e (expression)) (expect! "<eof>")
  (program definitions sc e))
