#lang racket
(require eopl (prefix-in s: "chapter03.rkt"))
(require "sllgen_guard.rkt")
(provide (all-defined-out))

;; BEGIN separate-boolean-grammar
(define bool-grammar
  '((b-program (b-exp) bp)
    (b-exp (number) bn) (b-exp (identifier) bv)
    (b-exp ("-" "(" b-exp "," b-exp ")") bd)
    (b-exp ("if" bool-exp "then" b-exp "else" b-exp) bi)
    (b-exp ("let" identifier "=" b-exp "in" b-exp) bl)
    (bool-exp ("zero?" "(" b-exp ")") bz)
    (bool-exp ("equal?" "(" b-exp "," b-exp ")") be)
    (bool-exp ("greater?" "(" b-exp "," b-exp ")") bg)
    (bool-exp ("less?" "(" b-exp "," b-exp ")") bs)))
;; The lexical rules are duplicated literally because SLLGEN grammar macros
;; inspect module-local literal bindings at expansion time.
(define bool-lexical
  '((space (whitespace) skip)
    (identifier (letter (arbno (or letter digit "_" "-" "?"))) symbol)
    (number (digit (arbno digit)) number)
    (number ("-" digit (arbno digit)) number)))
(sllgen:make-define-datatypes bool-lexical bool-grammar)
(define bool-parse (guard-sllgen (sllgen:make-string-parser bool-lexical bool-grammar) bool-lexical bool-grammar))
(define (value-of-bool-exp e env)
  (cases bool-exp e
    (bz (e) (zero? (value-of-b-exp e env)))
    (be (a b) (= (value-of-b-exp a env) (value-of-b-exp b env)))
    (bg (a b) (> (value-of-b-exp a env) (value-of-b-exp b env)))
    (bs (a b) (< (value-of-b-exp a env) (value-of-b-exp b env)))))
(define (value-of-b-exp e env)
  (cases b-exp e
    (bn (n) n)
    (bv (v) (define p (assq v env)) (if p (cdr p) (error 'bool-language "unbound variable")))
    (bd (a b) (- (value-of-b-exp a env) (value-of-b-exp b env)))
    (bi (t y n) (if (value-of-bool-exp t env) (value-of-b-exp y env) (value-of-b-exp n env)))
    (bl (v rhs b) (value-of-b-exp b (cons (cons v (value-of-b-exp rhs env)) env)))))
(define (run/bool text)
  (cases b-program (bool-parse text) (bp (e) (value-of-b-exp e '((i . 1) (v . 5) (x . 10))))))
;; END separate-boolean-grammar

;; BEGIN named-procedure-grammar
;; Exercise 3.19: a separate PROC front end has letproc, but no anonymous proc.
(define named-grammar
  '((lp-program (lp-exp) lp-program-node)
    (lp-exp (number) lp-number) (lp-exp (identifier) lp-variable)
    (lp-exp ("-" "(" lp-exp "," lp-exp ")") lp-difference)
    (lp-exp ("zero?" "(" lp-exp ")") lp-zero)
    (lp-exp ("if" lp-exp "then" lp-exp "else" lp-exp) lp-if)
    (lp-exp ("let" identifier "=" lp-exp "in" lp-exp) lp-let)
    (lp-exp ("letproc" identifier "(" identifier ")" "=" lp-exp "in" lp-exp) lp-procedure)
    (lp-exp ("(" lp-exp lp-exp ")") lp-call)))
(sllgen:make-define-datatypes bool-lexical named-grammar)
(define named-parse (guard-sllgen (sllgen:make-string-parser bool-lexical named-grammar) bool-lexical named-grammar))
(define (named->ast e)
  (cases lp-exp e
    (lp-number (n) (s:const-exp n))
    (lp-variable (v) (s:var-exp v))
    (lp-difference (a b) (s:binary-exp (s:diff-op) (named->ast a) (named->ast b)))
    (lp-zero (e) (s:unary-exp (s:zero-op) (named->ast e)))
    (lp-if (t y n) (s:if-exp (named->ast t) (named->ast y) (named->ast n)))
    (lp-let (v rhs b) (s:let-exp (list v) (list (named->ast rhs)) (named->ast b)))
    (lp-procedure (f x pbody body)
      (s:letproc-exp f (list x) (named->ast pbody) (named->ast body)))
    (lp-call (f a) (s:call-exp (named->ast f) (list (named->ast a))))))
(define (run/letproc text)
  (parameterize ([s:scope-mode 'lexical] [s:env-mode 'data] [s:proc-mode 'data]
                 [s:numeric-booleans? #f] [s:trim-mode #f])
    (cases lp-program (named-parse text)
      (lp-program-node (e) (s:value-of (named->ast e) (s:initial-environment))))))
;; END named-procedure-grammar

;; BEGIN uniform-calls
;; Exercise 3.22 adopts a fully parenthesized front end. Both built-in and
;; user procedures use (operator operand ...), and primitive names are bindings.
(define (uniform->ast d)
  (match d
    [(? exact-integer? n) (s:const-exp n)]
    [(? symbol? v) (s:var-exp v)]
    [(list 'if t y n) (s:if-exp (uniform->ast t) (uniform->ast y) (uniform->ast n))]
    [(list 'proc (list (? symbol? vs) ...) body) (s:proc-exp vs (uniform->ast body))]
    [(list 'let (list (list (? symbol? vs) es) ...) body)
     (s:let-exp vs (map uniform->ast es) (uniform->ast body))]
    [(list f es ...) (s:call-exp (uniform->ast f) (map uniform->ast es))]
    [_ (error 'uniform-parser "invalid expression: ~s" d)]))
(define (uniform-parse text)
  (parameterize ([read-accept-reader #f] [read-accept-lang #f] [read-accept-compiled #f])
    (define input (open-input-string text))
    (define d (read input))
    (unless (eof-object? (read input)) (error 'uniform-parser "trailing expression"))
    (uniform->ast d)))
(define (uniform-environment)
  (define names (append (hash-keys s:unary-table) (hash-keys s:binary-table) '(list)))
  (define vals
    (for/list ([name names])
      (s:proc-val
       (cond [(hash-has-key? s:unary-table name) (s:builtin name 1 (hash-ref s:unary-table name))]
             [(hash-has-key? s:binary-table name) (s:builtin name 2 (hash-ref s:binary-table name))]
             [else (s:builtin 'list #f (lambda vals (s:list-val vals)))]))))
  (s:extend-many names vals (s:initial-environment)))
(define (run/uniform text)
  (parameterize ([s:scope-mode 'lexical] [s:env-mode 'data] [s:proc-mode 'data]
                 [s:numeric-booleans? #f] [s:trim-mode #f])
    (s:value-of (uniform-parse text) (uniform-environment))))
;; END uniform-calls
(module+ main
  (displayln (run/bool "if less?(3,4) then 7 else 9"))
  (displayln (s:datum (run/uniform "(let ((f (proc (x) (- x 1)))) (+ (f 9) 2))"))))
