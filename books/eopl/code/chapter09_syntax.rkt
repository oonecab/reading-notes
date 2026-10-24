#lang racket
;; Concrete CLASSES / TYPED-OO syntax. No host eval is used.
(require racket/match)
(provide (all-defined-out))
(struct exn:fail:oo exn:fail (kind context) #:transparent)
(define (oo-error kind context fmt . args)
  (raise (exn:fail:oo (apply format fmt args) (current-continuation-marks) kind context)))
(struct pgm (decls body typed?) #:transparent)
(struct cdecl (name supers interfaces fields statics methods) #:transparent)
(struct idecl (name parents methods) #:transparent)
(struct fdecl (name type init visibility) #:transparent)
(struct mdecl (name params result body visibility final? static?) #:transparent)
(struct expr (tag args) #:transparent)
(define (E tag . args) (expr tag args))
(define (unique! names where)
  (unless (= (length names) (length (remove-duplicates names)))
    (oo-error 'duplicate where "duplicate names in ~a" where)))
(define (tokenize text)
  (let loop ([s text] [out '()])
    (cond [(string=? s "") (reverse (cons "<eof>" out))]
          [(regexp-match #px"^\\s+" s) => (lambda (m) (loop (substring s (string-length (car m))) out))]
          [(regexp-match #px"^%[^\n]*(?:\n|$)" s) => (lambda (m) (loop (substring s (string-length (car m))) out))]
          [(regexp-match #px"^(?:\"(?:[^\"\\\\]|\\\\.)*\"|->|\\.\\.\\.|-?[0-9]+|[A-Za-z][A-Za-z0-9_?@$-]*(?::@[0-9]+)?|[()+*,;=:_-])" s)
           => (lambda (m) (loop (substring s (string-length (car m))) (cons (car m) out)))]
          [else (oo-error 'parse s "invalid input near ~s" (substring s 0 (min 25 (string-length s))))])))
(define (parse source #:typed? [typed? #f])
  (if (pgm? source) source
      (let ()
        (define ts (list->vector (tokenize source))) (define i 0)
        (define (peek) (vector-ref ts i))
        (define (take!) (begin0 (peek) (set! i (add1 i))))
        (define (at? s) (equal? (peek) s))
        (define (accept! s) (and (at? s) (begin (take!) #t)))
        (define (expect! s) (unless (accept! s) (oo-error 'parse i "expected ~s; found ~s" s (peek))))
        (define (name!) (define s (take!))
          (unless (regexp-match? #px"^[A-Za-z][A-Za-z0-9_?@$-]*(?::@[0-9]+)?$" s) (oo-error 'parse i "expected identifier; found ~s" s))
          (string->symbol s))
        (define (typ)
          (cond [(accept! "listof") (list 'listof (typ))]
                [(accept! "(")
                 (define args
                   (if (at? "->") '()
                       (let loop ([xs (list (typ))])
                         (if (or (accept! "*") (accept! ",")) (loop (append xs (list (typ)))) xs))))
                 (expect! "->") (define result (typ)) (expect! ")") (list 'proc args result)]
                [else (name!)]))
        (define (params)
          (expect! "(")
          (define ps (if (at? ")") '()
                         (let loop ([xs '()])
                           (define n (name!))
                           (define t (cond [(accept! ":") (typ)] [typed? (oo-error 'annotation n "parameter ~a needs a type" n)] [else #f]))
                           (define next (append xs (list (cons n t))))
                           (if (accept! ",") (loop next) next))))
          (expect! ")") (unique! (map car ps) 'parameters) ps)
        (define (args)
          (expect! "(")
          (define xs (if (at? ")") '() (let loop ([xs (list (exp))]) (if (accept! ",") (loop (append xs (list (exp)))) xs))))
          (expect! ")") xs)
        (define (members stop)
          (let loop ([fields '()] [statics '()] [methods '()])
            (define vis 'public) (define final? #f)
            (when (member (peek) '("private" "protected" "public")) (set! vis (string->symbol (take!))))
            (when (accept! "final") (set! final? #t))
            (cond [(accept! "field")
                   (define t (and typed? (typ))) (define n (name!))
                   (define init (and (accept! "=") (exp)))
                   (loop (append fields (list (fdecl n t init vis))) statics methods)]
                  [(accept! "static")
                   (define t (and typed? (typ))) (define n (name!)) (expect! "=")
                   (loop fields (append statics (list (fdecl n t (exp) vis))) methods)]
                  [(or (at? "method") (at? "staticmethod"))
                   (define static? (equal? (take!) "staticmethod"))
                   (define result (and typed? (typ))) (define n (name!)) (define ps (params))
                   (define m (mdecl n ps result (exp) vis final? static?))
                   (loop fields statics (append methods (list m)))]
                  [(or (not (eq? vis 'public)) final?) (oo-error 'parse i "modifier needs a field or method")]
                  [else (values fields statics methods)])))
        (define (class-body name)
          (expect! "extends")
          (define supers (let loop ([ns (list (name!))]) (if (accept! ",") (loop (append ns (list (name!)))) ns)))
          (define interfaces (let loop ([ns '()]) (if (accept! "implements") (loop (append ns (list (name!)))) ns)))
          (define-values (fs ss ms) (members #f)) (cdecl name supers interfaces fs ss ms))
        (define (declaration)
          (cond [(accept! "class") (class-body (name!))]
                [else (expect! "interface") (define n (name!))
                      (define parents (if (accept! "extends") (let loop ([ns (list (name!))]) (if (accept! ",") (loop (append ns (list (name!)))) ns)) '()))
                      (define ms (let loop ([ms '()])
                                   (if (accept! "method")
                                       (let* ([t (typ)] [m (name!)] [ps (params)])
                                         (loop (append ms (list (mdecl m ps t #f 'public #f #f))))) ms)))
                      (idecl n parents ms)]))
        (define (exp)
          (define tok (take!))
          (cond
            [(regexp-match? #px"^-?[0-9]+$" tok) (E 'const (string->number tok))]
            [(string-prefix? tok "\"") (E 'const (read (open-input-string tok)))]
            [(equal? tok "true") (E 'const #t)] [(equal? tok "false") (E 'const #f)]
            [(equal? tok "unit") (E 'unit)] [(equal? tok "...") (E 'hole)]
            [(equal? tok "self") (E 'self)]
            [(equal? tok "if") (define c (exp)) (expect! "then") (define a (exp)) (expect! "else") (E 'if c a (exp))]
            [(equal? tok "proc") (define ps (params)) (E 'proc ps (exp))]
            [(equal? tok "let")
             (define bs (let loop ([bs '()]) (define n (name!)) (expect! "=") (define v (exp))
                          (define next (append bs (list (cons n v)))) (if (at? "in") next (loop next))))
             (unique! (map car bs) 'let) (expect! "in") (E 'let bs (exp))]
            [(equal? tok "letrec")
             (define ds (let loop ([ds '()]) (define t (and typed? (typ))) (define n (name!)) (define ps (params))
                          (expect! "=") (define b (exp)) (define next (append ds (list (list n ps t b))))
                          (if (at? "in") next (loop next))))
             (unique! (map car ds) 'letrec) (expect! "in") (E 'rec ds (exp))]
            [(equal? tok "letclass") (define n (name!)) (expect! "=") (define d (class-body n)) (expect! "in") (E 'local-class d (exp))]
            [(equal? tok "(") (define f (exp))
             (define xs (let loop ([xs '()]) (if (at? ")") xs (loop (append xs (list (exp)))))))
             (expect! ")") (E 'call f xs)]
            [(equal? tok "set") (define n (name!)) (expect! "=") (E 'set n (exp))]
            [(equal? tok "begin")
             (define xs (let loop ([xs (list (exp))]) (if (accept! ";") (if (at? "end") xs (loop (append xs (list (exp))))) xs)))
             (expect! "end") (expr 'begin xs)]
            [(equal? tok "new") (define c (name!)) (E 'new c (args))]
            [(equal? tok "send") (define o (exp)) (define m (name!)) (E 'send o m (args))]
            [(equal? tok "super") (define m (name!)) (E 'super m (args))]
            [(equal? tok "named-send") (define c (name!)) (define o (exp)) (define m (name!)) (E 'named-send c o m (args))]
            [(member tok '("cast" "instanceof")) (define o (exp)) (E (string->symbol tok) o (name!))]
            [(member tok '("fieldref" "fieldset" "named-fieldref" "named-fieldset" "superfieldref" "superfieldset"))
             (define named? (string-prefix? tok "named-")) (define super? (string-prefix? tok "super"))
             (define c (and named? (name!))) (define o (if super? (E 'self) (exp))) (define f (name!))
             (define value (and (string-suffix? tok "set") (begin (expect! "=") (exp))))
             (E 'field c super? o f value)]
            [(equal? tok "emptylist") (E 'emptylist (and (accept! "_") (typ)))]
            [(member tok '("+" "-" "*" "zero?" "equal?" "less?" "greater?" "cons" "car" "cdr" "null?" "list" "print" "concat" "number-to-string"))
             (E 'prim (string->symbol tok) (args))]
            [(equal? tok "getmethod") (expect! "(") (define o (exp)) (expect! ",") (define m (name!)) (expect! ")") (E 'getmethod o m)]
            [(equal? tok "emptyobject") (E 'emptyobject)]
            [(equal? tok "clone") (E 'clone (exp))]
            [(equal? tok "extend") (define p (exp)) (define-values (fs ss ms) (members "endextend"))
             (unless (null? ss) (oo-error 'parse i "prototype static fields not part of this extension"))
             (expect! "endextend") (E 'extend p fs ms)]
            [(equal? tok "newobject")
             (define parent (and (accept! "extends") (exp)))
             (define bs (let loop ([bs '()])
                          (if (at? "endnewobject") bs
                              (let ([n (name!)]) (expect! "=") (define f (exp)) (loop (append bs (list (cons n f))))))))
             (unique! (map car bs) 'newobject) (expect! "endnewobject") (E 'newobject parent bs)]
            [(regexp-match? #px"^[A-Za-z][A-Za-z0-9_?@$-]*(?::@[0-9]+)?$" tok) (E 'var (string->symbol tok))]
            [else (oo-error 'parse i "invalid expression token ~s" tok)]))
        (define ds (let loop ([ds '()]) (if (member (peek) '("class" "interface")) (loop (append ds (list (declaration)))) ds)))
        (define body (exp)) (expect! "<eof>") (pgm ds body typed?))))
