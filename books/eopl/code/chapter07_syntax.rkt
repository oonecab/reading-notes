#lang racket
(require "chapter07_types.rkt")
(provide (all-defined-out))
(struct node (op args) #:transparent)
(define reserved '("let" "in" "letrec" "proc" "if" "then" "else" "begin" "end"
                   "int" "bool" "void" "pairof" "listof" "refto"))
(define (identifier? s)
  (and (string? s) (regexp-match? #px"^[A-Za-z][A-Za-z0-9?\\-]*$" s) (not (member s reserved))))
(define (tokenize source)
  (define rx #px"\\s+|%[^\n]*|->|-?[0-9]+|[A-Za-z][A-Za-z0-9?\\-]*|[():,=*?;_]|[-+]" )
  (let loop ([pos 0] [out '()])
    (cond [(= pos (string-length source)) (reverse out)]
          [else
           (define m (regexp-match-positions rx source pos))
           (unless (and m (= (caar m) pos)) (type-error 'parse pos "unrecognized input at character ~a" pos))
           (define tok (substring source pos (cdar m)))
           (loop (cdar m) (if (or (regexp-match? #px"^\\s" tok) (string-prefix? tok "%")) out (cons tok out)))])))
(define (parse source #:checked? [checked? #f] #:omitted? [omitted? #t])
  (define tokens (list->vector (append (tokenize source) '("<eof>"))))
  (define cursor 0)
  (define (peek) (vector-ref tokens cursor))
  (define (take!) (begin0 (peek) (set! cursor (add1 cursor))))
  (define (expect! token)
    (unless (equal? token (peek)) (type-error 'parse cursor "expected ~a, received ~a" token (peek))) (take!))
  (define (name!)
    (unless (identifier? (peek)) (type-error 'parse cursor "expected identifier, received ~a" (peek)))
    (string->symbol (take!)))
  (define (type-start? x) (member x '("int" "bool" "void" "pairof" "listof" "refto" "(" "?")))
  (define (read-type)
    (match (take!)
      ["?" (when checked? (type-error 'annotation cursor "CHECKED requires a concrete type")) #f]
      [(and word (or "int" "bool" "void")) (string->symbol word)]
      ["pairof" (define a (read-type)) (expect! "*") (pair-t a (read-type))]
      ["listof" (list-t (read-type))]
      ["refto" (ref-t (read-type))]
      ["(" (define args (if (equal? (peek) "->") '()
                            (let loop ([out (list (read-type))])
                              (if (equal? (peek) "*") (begin (take!) (loop (append out (list (read-type))))) out))))
             (expect! "->") (define result (read-type)) (expect! ")") (proc-t args result)]
      [x (type-error 'parse cursor "invalid type syntax ~a" x)]))
  (define (parameters)
    (expect! "(")
    (define result
      (if (equal? (peek) ")") '()
          (let loop ([out '()])
            (define x (name!))
            (define annotation
              (cond [(equal? (peek) ":") (take!) (read-type)]
                    [(or checked? (not omitted?)) (type-error 'annotation x "missing type annotation for ~a" x)]
                    [else #f]))
            (define next (append out (list (cons x annotation))))
            (if (equal? (peek) ",") (begin (take!) (loop next)) next))))
    (expect! ")")
    (unless (= (length result) (length (remove-duplicates (map car result))))
      (type-error 'duplicate result "duplicate formal parameter")) result)
  (define (arguments)
    (expect! "(")
    (define result
      (if (equal? (peek) ")") '()
          (let loop ([out (list (expression))])
            (if (equal? (peek) ",") (begin (take!) (loop (append out (list (expression))))) out))))
    (expect! ")") result)
  (define (expression)
    (define tok (take!))
    (cond
      [(regexp-match? #px"^-?[0-9]+$" tok) (node 'num (list (string->number tok)))]
      [(equal? tok "if") (define c (expression)) (expect! "then") (define a (expression))
                         (expect! "else") (node 'if (list c a (expression)))]
      [(equal? tok "proc") (define ps (parameters)) (node 'proc (list ps (expression)))]
      [(equal? tok "let")
       (define bs (let loop ([out '()])
                    (define x (name!)) (expect! "=") (define e (expression))
                    (define next (append out (list (cons x e))))
                    (if (equal? (peek) "in") next (loop next))))
       (unless (= (length bs) (length (remove-duplicates (map car bs)))) (type-error 'duplicate bs "duplicate parallel let name"))
       (expect! "in") (node 'let (list bs (expression)))]
      [(equal? tok "letrec")
       (define ds
         (let loop ([out '()])
           (define result (cond [(type-start? (peek)) (read-type)]
                                [(or checked? (not omitted?)) (type-error 'annotation cursor "missing recursive result type")]
                                [else #f]))
           (define name (name!)) (define ps (parameters)) (expect! "=")
           (define body (expression))
           (define next (append out (list (list name ps result body))))
           (if (equal? (peek) "in") next (loop next))))
       (unless (= (length ds) (length (remove-duplicates (map car ds)))) (type-error 'duplicate ds "duplicate recursive name"))
       (expect! "in") (node 'rec (list ds (expression)))]
      [(equal? tok "(")
       (define rator (expression))
       (define rands (let loop ([out '()]) (if (equal? (peek) ")") out (loop (append out (list (expression)))))))
       (expect! ")") (node 'call (list rator rands))]
      [(equal? tok "unpair") (define x (name!)) (define y (name!))
                             (when (eq? x y) (type-error 'duplicate x "duplicate unpair name"))
                             (expect! "=") (define pair (expression)) (expect! "in")
                             (node 'unpair (list x y pair (expression)))]
      [(equal? tok "set") (define x (name!)) (expect! "=") (node 'set (list x (expression)))]
      [(equal? tok "begin")
       (define es (let loop ([out (list (expression))])
                    (cond [(equal? (peek) "end") out]
                          [else (expect! ";") (if (equal? (peek) "end") out (loop (append out (list (expression)))))])))
       (expect! "end") (node 'begin es)]
      [(equal? tok "emptylist")
       (define annotation (cond [(equal? (peek) "_") (take!) (read-type)]
                                [checked? (type-error 'annotation cursor "CHECKED emptylist needs _Type")]
                                [else #f]))
       (node 'emptylist (list annotation))]
      [(member tok '("-" "+" "zero?" "newpair" "pair" "cons" "list" "null?" "car" "cdr"
                    "newref" "deref" "setref" "left" "right" "setleft" "setright"))
       (define args (arguments))
       (define arity (hash-ref (hash "-" 2 "+" 2 "zero?" 1 "newpair" 2 "pair" 2 "cons" 2 "null?" 1 "car" 1 "cdr" 1
                                    "newref" 1 "deref" 1 "setref" 2 "left" 1 "right" 1 "setleft" 2 "setright" 2) tok #f))
       (unless (if arity (= arity (length args)) (positive? (length args))) (type-error 'arity tok "invalid primitive arity: ~a" tok))
       (node (if (equal? tok "pair") 'newpair (string->symbol tok)) args)]
      [(identifier? tok) (node 'var (list (string->symbol tok)))]
      [else (type-error 'parse cursor "invalid expression token ~a" tok)]))
  (define result (expression))
  (expect! "<eof>") result)
