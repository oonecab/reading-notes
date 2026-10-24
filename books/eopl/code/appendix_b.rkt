#lang racket
;; Appendix B: real SLLGEN scanning/parsing and exercises B.1-B.5.
(require eopl)
(provide (all-defined-out))
(define scanner-spec
  '((white-sp (whitespace) skip)
    (comment ("%" (arbno (not #\newline))) skip)
    (identifier (letter (arbno (or letter digit))) symbol)
    (number (digit (arbno digit)) number)))
(define base-grammar
  '((arith-expr (arith-term (arbno additive-op arith-term)) an-expr)
    (arith-term (arith-factor (arbno multiplicative-op arith-factor)) a-term)
    (arith-factor (number) number-factor)
    (arith-factor ("(" arith-expr ")") group-factor)
    (additive-op ("+") plus-op) (additive-op ("-") minus-op)
    (multiplicative-op ("*") times-op) (multiplicative-op ("/") divide-op)))
(define variable-grammar
  '((arith-expr (arith-term (arbno additive-op arith-term)) an-expr)
    (arith-term (arith-factor (arbno multiplicative-op arith-factor)) a-term)
    (arith-factor (number) number-factor)
    (arith-factor ("(" arith-expr ")") group-factor)
    (arith-factor (identifier) variable-factor)
    (additive-op ("+") plus-op) (additive-op ("-") minus-op)
    (multiplicative-op ("*") times-op) (multiplicative-op ("/") divide-op)))
(define unary-grammar
  '((arith-expr (arith-term (arbno additive-op arith-term)) an-expr)
    (arith-term (arith-factor (arbno multiplicative-op arith-factor)) a-term)
    (arith-factor (number) number-factor)
    (arith-factor ("(" arith-expr ")") group-factor)
    (arith-factor (identifier) variable-factor)
    (arith-factor ("-" arith-factor) negative-factor)
    (additive-op ("+") plus-op) (additive-op ("-") minus-op)
    (multiplicative-op ("*") times-op) (multiplicative-op ("/") divide-op)))
;; All three grammars share constructors; extensions add variable/negative forms.
(sllgen:make-define-datatypes scanner-spec unary-grammar)
(define raw-scan-arithmetic (sllgen:make-string-scanner scanner-spec unary-grammar))
(define raw-parse-base (sllgen:make-string-parser scanner-spec base-grammar))
(define raw-parse-variables (sllgen:make-string-parser scanner-spec variable-grammar))
(define raw-parse-unary (sllgen:make-string-parser scanner-spec unary-grammar))
;; The installed SLLGEN scanner can stop at an unsupported character. Guard the
;; entire arithmetic input so a valid prefix is never silently accepted.
(define (check-characters text)
  (for/fold ([comment? #f]) ([c (in-string text)])
    (cond [(char=? c #\newline) #f] [comment? #t] [(char=? c #\%) #t]
          [(or (char-whitespace? c) (char-alphabetic? c) (char-numeric? c)
               (memv c '(#\( #\) #\+ #\- #\* #\/))) #f]
          [else (error 'scanner "unsupported arithmetic character ~s" c)]))
  text)
(define (scan-arithmetic text) (raw-scan-arithmetic (check-characters text)))
(define (parse-base text) (raw-parse-base (check-characters text)))
(define (parse-variables text) (raw-parse-variables (check-characters text)))
(define (parse-unary text) (raw-parse-unary (check-characters text)))
(define (parse-arithmetic text #:mode [mode 'unary])
  ((case mode [(base) parse-base] [(variables) parse-variables] [(unary) parse-unary]
     [else (error 'parse-arithmetic "unknown mode ~a" mode)]) text))
;; BEGIN arithmetic-fold
(define (eval-arithmetic tree [env '()])
  (define (lookup name)
    (cond [(assq name env) => cdr]
          [else (error 'unbound "unbound arithmetic variable ~a" name)]))
  (define (add op a b)
    (cases additive-op op (plus-op () (+ a b)) (minus-op () (- a b))))
  (define (mul op a b)
    (cases multiplicative-op op
      (times-op () (* a b))
      (divide-op () (when (zero? b) (error 'division "division by zero")) (/ a b))))
  (define (expr e)
    (cases arith-expr e
      (an-expr (first ops rest)
        (for/fold ([acc (term first)]) ([op ops] [t rest]) (add op acc (term t))))))
  (define (term t)
    (cases arith-term t
      (a-term (first ops rest)
        (for/fold ([acc (factor first)]) ([op ops] [f rest]) (mul op acc (factor f))))))
  (define (factor f)
    (cases arith-factor f
      (number-factor (n) n)
      (group-factor (e) (expr e))
      (variable-factor (name) (lookup name))
      (negative-factor (f) (- (factor f)))))
  (expr tree))
;; END arithmetic-fold
(define (calculate text [env '()] #:mode [mode 'unary])
  (unless (and (list? env) (andmap (lambda (p) (and (pair? p) (symbol? (car p)) (rational? (cdr p)) (exact? (cdr p)))) env))
    (error 'environment "expected symbol/exact-rational bindings"))
  (eval-arithmetic (parse-arithmetic text #:mode mode) env))
(define (arithmetic-datum tree)
  (define (a op) (cases additive-op op (plus-op () '+) (minus-op () '-)))
  (define (m op) (cases multiplicative-op op (times-op () '*) (divide-op () '/)))
  (define (e x) (cases arith-expr x (an-expr (first ops rest) (list 'expr (t first) (map a ops) (map t rest)))))
  (define (t x) (cases arith-term x (a-term (first ops rest) (list 'term (f first) (map m ops) (map f rest)))))
  (define (f x) (cases arith-factor x (number-factor (n) n) (variable-factor (x) x)
                         (group-factor (x) (list 'group (e x))) (negative-factor (x) (list 'neg (f x)))))
  (e tree))

;; Original appendix examples: concrete tokens, two statements, repeated fields.
(define statement-grammar
  '((statement ("{" statement ";" statement "}") compound-statement)
    (statement ("while" expression "do" statement) while-statement)
    (statement (identifier ":=" expression) assign-statement)
    (expression (identifier) var-exp)
    (expression ("(" expression "-" expression ")") diff-exp)))
(sllgen:make-define-datatypes scanner-spec statement-grammar)
(define scan-statement (sllgen:make-string-scanner scanner-spec statement-grammar))
(define parse-statement (sllgen:make-string-parser scanner-spec statement-grammar))
(define (statement-datum tree)
  (define (e x) (cases expression x (var-exp (x) (list 'var x)) (diff-exp (a b) (list '- (e a) (e b)))))
  (define (s x) (cases statement x
    (compound-statement (a b) (list 'block (s a) (s b)))
    (while-statement (test body) (list 'while (e test) (s body)))
    (assign-statement (name rhs) (list 'assign name (e rhs)))))
  (s tree))
(define terminated-grammar
  '((block ("{" (arbno item ";") "}") terminated-block)
    (item (identifier ":=" identifier) assign-item)))
(define separated-grammar
  '((block ("{" (separated-list item ";") "}") separated-block)
    (item (identifier ":=" identifier) assign-item)))
(sllgen:make-define-datatypes scanner-spec terminated-grammar)
;; Only the block constructor differs in the separated grammar.
(define-datatype separated separated? (separated-block (items (list-of item?))))
(define parse-terminated (sllgen:make-string-parser scanner-spec terminated-grammar))
(define parse-separated (sllgen:make-string-parser scanner-spec separated-grammar))
(define (block-datum b)
  (define (items->data xs) (map (lambda (x) (cases item x (assign-item (a b) (list a b)))) xs))
  (if (block? b) (cases block b (terminated-block (xs) (items->data xs)))
      (cases separated b (separated-block (xs) (items->data xs)))))
(define bindings-grammar
  '((binding-expression (identifier) binding-var)
    (binding-expression ("let" (arbno identifier "=" binding-expression) "in" binding-expression) binding-let)))
(sllgen:make-define-datatypes scanner-spec bindings-grammar)
(define parse-bindings (sllgen:make-string-parser scanner-spec bindings-grammar))
(define (bindings-datum b)
  (cases binding-expression b
    (binding-var (name) (list 'var name))
    (binding-let (names rhss body) (list 'let names (map bindings-datum rhss) (bindings-datum body)))))
(define parallel-grammar
  '((parallel-statement
     ("{" (separated-list (separated-list identifier ",") ":=" (separated-list parallel-expression ",") ";") "}")
     parallel-block)
    (parallel-expression (number) parallel-number)
    (parallel-expression (identifier) parallel-var)))
(sllgen:make-define-datatypes scanner-spec parallel-grammar)
(define parse-parallel (sllgen:make-string-parser scanner-spec parallel-grammar))
(define (parallel-datum b)
  (define (e x) (cases parallel-expression x (parallel-number (n) n) (parallel-var (name) name)))
  (cases parallel-statement b (parallel-block (names rhss) (list names (map (lambda (xs) (map e xs)) rhss)))))
(define (arithmetic-datatypes) (sllgen:list-define-datatypes scanner-spec unary-grammar))
(define repl-grammar
  '((repl-program (arith-expr ";") arithmetic-program)
    (arith-expr (arith-term (arbno additive-op arith-term)) an-expr)
    (arith-term (arith-factor (arbno multiplicative-op arith-factor)) a-term)
    (arith-factor (number) number-factor)
    (arith-factor ("(" arith-expr ")") group-factor)
    (arith-factor (identifier) variable-factor)
    (arith-factor ("-" arith-factor) negative-factor)
    (additive-op ("+") plus-op) (additive-op ("-") minus-op)
    (multiplicative-op ("*") times-op) (multiplicative-op ("/") divide-op)))
(define-datatype repl-program repl-program? (arithmetic-program (body arith-expr?)))
(define raw-arithmetic-repl
  (sllgen:make-rep-loop "--> "
    (lambda (p) (cases repl-program p (arithmetic-program (body) (eval-arithmetic body))))
    (sllgen:make-stream-parser scanner-spec repl-grammar)))
(define (checked-arithmetic-port source)
  ;; make-input-port buffers peeks for us. Validate characters as the scanner
  ;; consumes them, retaining interactive streaming and arbitrary comment text.
  (define comment? #f)
  (define pending #"")
  (make-input-port
   'checked-arithmetic
   (lambda (dest)
     (when (zero? (bytes-length pending))
       (define c (read-char source))
       (unless (eof-object? c)
         (cond [(char=? c #\newline) (set! comment? #f)]
               [comment? (void)] [(char=? c #\%) (set! comment? #t)]
               [(or (char-whitespace? c) (char-alphabetic? c) (char-numeric? c)
                    (memv c '(#\( #\) #\+ #\- #\* #\/ #\;))) (void)]
               [else (error 'scanner "unsupported arithmetic character ~s" c)])
         (set! pending (string->bytes/utf-8 (string c)))))
     (if (zero? (bytes-length pending)) eof
         (let ([n (min (bytes-length dest) (bytes-length pending))])
           (bytes-copy! dest 0 pending 0 n)
           (set! pending (subbytes pending n))
           n)))
   #f void))
(define (arithmetic-repl)
  ;; This SLLGEN release reports a start-symbol error on clean stream EOF.
  ;; Only that exact boundary is normal completion; incomplete expressions fail.
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (unless (regexp-match? #rx"nonterminal <repl-program> can't begin with end-marker #f$" (exn-message e))
                       (raise e)))])
    (parameterize ([current-input-port (checked-arithmetic-port (current-input-port))])
      (raw-arithmetic-repl))))
(module+ main
  (displayln (arithmetic-datum (parse-base "3+2*66-5")))
  (displayln (calculate "3+2*66-5" #:mode 'base))
  (displayln (calculate "20-5-3" #:mode 'base))
  (displayln (calculate "48/4/3" #:mode 'base))
  (displayln (calculate "x-y*3" '((x . 7) (y . 2)) #:mode 'variables))
  (displayln (calculate "3*-2")))
