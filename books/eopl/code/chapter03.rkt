#lang racket
;; EOPL third edition chapter 3: original companion implementation.
;; Source syntax is parsed by the installed eopl SLLGEN, not Racket eval.
(require eopl)
(provide (all-defined-out))

;; BEGIN grammar
(define lexical-spec
  '((white-space (whitespace) skip)
    (comment ("%" (arbno (not #\newline))) skip)
    (identifier (letter (arbno (or letter digit "_" "-" "?" "*"))) symbol)
    (number (digit (arbno digit)) number)
    (number ("-" digit (arbno digit)) number)))
(define grammar
  '((program (expression) a-program)
    (expression (number) const-exp)
    (expression (identifier) var-exp)
    (expression (unary-op "(" expression ")") unary-exp)
    (expression (binary-op "(" expression "," expression ")") binary-exp)
    (expression ("emptylist") emptylist-exp)
    (expression ("list" "(" (separated-list expression ",") ")") list-exp)
    (expression ("pack" "(" (separated-list expression ",") ")") pack-exp)
    (expression ("if" expression "then" expression "else" expression) if-exp)
    (expression ("cond" (arbno expression "==>" expression) "end") cond-exp)
    (expression ("let" (arbno identifier "=" expression) "in" expression) let-exp)
    (expression ("let*" (arbno identifier "=" expression) "in" expression) letstar-exp)
    (expression ("unpack" (arbno identifier) "=" expression "in" expression) unpack-exp)
    (expression ("proc" "(" (separated-list identifier ",") ")" expression) proc-exp)
    (expression ("traceproc" "(" (separated-list identifier ",") ")" expression) traceproc-exp)
    (expression ("letproc" identifier "(" (separated-list identifier ",") ")" "=" expression "in" expression) letproc-exp)
    (expression ("(" expression (arbno expression) ")") call-exp)
    (expression ("letrec" (arbno identifier "(" (separated-list identifier ",") ")" "=" expression) "in" expression) letrec-exp)
    (unary-op ("minus") minus-op) (unary-op ("zero?") zero-op)
    (unary-op ("add1") add1-op) (unary-op ("car") car-op)
    (unary-op ("cdr") cdr-op) (unary-op ("null?") null-op)
    (unary-op ("print") print-op)
    (binary-op ("-") diff-op) (binary-op ("+") add-op)
    (binary-op ("*") times-op) (binary-op ("quotient") quotient-op)
    (binary-op ("equal?") equal-op) (binary-op ("greater?") greater-op)
    (binary-op ("less?") less-op) (binary-op ("cons") cons-op)))
(sllgen:make-define-datatypes lexical-spec grammar)
(define scan&parse (sllgen:make-string-parser lexical-spec grammar))
;; END grammar

;; BEGIN values
(struct num-val (n) #:transparent)
(struct bool-val (b) #:transparent)
(struct list-val (elements) #:transparent)
(struct proc-val (p) #:transparent)
(define (expval? v) (or (num-val? v) (bool-val? v) (list-val? v) (proc-val? v)))
(define (expval->num v)
  (if (num-val? v) (num-val-n v) (error 'expval->num "number required: ~s" v)))
(define (expval->bool v)
  (if (bool-val? v) (bool-val-b v) (error 'expval->bool "boolean required: ~s" v)))
(define (expval->list v)
  (if (list-val? v) (list-val-elements v) (error 'expval->list "list required: ~s" v)))
(define (expval->proc v)
  (if (proc-val? v) (proc-val-p v) (error 'expval->proc "procedure required: ~s" v)))
(define (datum v)
  (cond [(num-val? v) (num-val-n v)] [(bool-val? v) (bool-val-b v)]
        [(list-val? v) (map datum (list-val-elements v))]
        [(proc-val? v) '<procedure>] [else (error 'datum "invalid expressed value")]))
(define numeric-booleans? (make-parameter #f))
(define (boolean-value b) (if (numeric-booleans?) (num-val (if b 1 0)) (bool-val b)))
(define (true-value? v)
  (if (numeric-booleans?) (not (zero? (expval->num v))) (expval->bool v)))
;; END values

(define scope-mode (make-parameter 'lexical))
(define env-mode (make-parameter 'data))
(define proc-mode (make-parameter 'data))
(define rec-mode (make-parameter 'fresh))
(define trim-mode (make-parameter #f))
(define metrics (make-parameter #f))
(define (bump! key)
  (when (metrics) (hash-update! (metrics) key add1 0)))
(define (unique! names who)
  (unless (= (length names) (length (remove-duplicates names)))
    (error who "duplicate names: ~s" names)))

;; BEGIN environments
(struct binding (name value saved) #:transparent)
(struct recursive-env (names paramss bodies saved) #:transparent)
(define (empty-environment)
  (if (eq? (env-mode) 'host) (lambda (v) (error 'lookup "unbound variable: ~a" v)) '()))
(define (extend-environment name value saved)
  (if (eq? (env-mode) 'host)
      (lambda (v) (if (eq? v name) (unbox-value value) (lookup saved v)))
      (binding name value saved)))
(define (extend-many names vals env)
  (unless (= (length names) (length vals)) (error 'extend-many "arity mismatch"))
  (foldr (lambda (p acc) (extend-environment (car p) (cdr p) acc)) env (map cons names vals)))
(define (unbox-value v)
  (define answer (if (vector? v) (vector-ref v 0) v))
  (unless (expval? answer) (error 'lookup "uninitialized recursive binding")) answer)
(define (lookup env name)
  (bump! 'named-lookups)
  (cond [(procedure? env) (env name)]
        [(null? env) (error 'lookup "unbound variable: ~a" name)]
        [(binding? env) (if (eq? (binding-name env) name) (unbox-value (binding-value env))
                            (lookup (binding-saved env) name))]
        [(recursive-env? env)
         (define pos (index-of (recursive-env-names env) name))
         (if pos (make-procedure (list-ref (recursive-env-paramss env) pos)
                                 (list-ref (recursive-env-bodies env) pos) env #f #f)
             (lookup (recursive-env-saved env) name))]
        [else (error 'lookup "bad environment")]))
(define (initial-environment)
  (extend-many '(i v x) (map num-val '(1 5 10)) (empty-environment)))
(define (extend-rec names paramss bodies saved)
  (unique! names 'letrec)
  (for ([ps paramss]) (unique! ps 'letrec-parameters))
  (cond [(eq? (rec-mode) 'cached)
         (define cells (map (lambda (_) (vector #f)) names))
         (define env (extend-many names cells saved))
         (for ([cell cells] [ps paramss] [body bodies])
           (vector-set! cell 0 (make-procedure ps body env #f #f))) env]
        [(eq? (env-mode) 'host)
         (letrec ([self (lambda (name)
                          (define pos (index-of names name))
                          (if pos (make-procedure (list-ref paramss pos) (list-ref bodies pos) self #f #f)
                              (lookup saved name)))]) self)]
        [else (recursive-env names paramss bodies saved)]))
;; END environments

;; BEGIN free-vars
(define (unions . sets) (remove-duplicates (apply append sets)))
(define (without xs bound) (filter (lambda (x) (not (memq x bound))) xs))
(define (free-vars exp)
  (cases expression exp
    (const-exp (n) '()) (var-exp (v) (list v)) (emptylist-exp () '())
    (unary-exp (op e) (free-vars e))
    (binary-exp (op l r) (unions (free-vars l) (free-vars r)))
    (list-exp (es) (apply unions (map free-vars es)))
    (pack-exp (es) (apply unions (map free-vars es)))
    (if-exp (t y n) (unions (free-vars t) (free-vars y) (free-vars n)))
    (cond-exp (ts bs) (apply unions (map free-vars (append ts bs))))
    (let-exp (vs es b) (unions (apply unions (map free-vars es)) (without (free-vars b) vs)))
    (letstar-exp (vs es b)
      (let loop ([vs vs] [es es])
        (if (null? vs) (free-vars b)
            (unions (free-vars (car es)) (without (loop (cdr vs) (cdr es)) (list (car vs)))))))
    (unpack-exp (vs e b) (unions (free-vars e) (without (free-vars b) vs)))
    (proc-exp (vs b) (without (free-vars b) vs))
    (traceproc-exp (vs b) (without (free-vars b) vs))
    (call-exp (f es) (apply unions (map free-vars (cons f es))))
    (letproc-exp (name vs p b) (unions (without (free-vars p) vs) (without (free-vars b) (list name))))
    (letrec-exp (ns vss bs b)
      (without (apply unions (free-vars b) (map (lambda (vs p) (without (free-vars p) vs)) vss bs)) ns))))
;; END free-vars

;; BEGIN procedures
(struct closure (params body saved traced?) #:transparent)
(struct host-closure (invoke params saved traced?) #:transparent)
(define (make-procedure params body env traced? [may-trim? #t])
  (unique! params 'procedure)
  (define saved
    (if (eq? (scope-mode) 'dynamic) (empty-environment)
        (if (and may-trim? (trim-mode))
            (let ([names (without (free-vars body) params)])
              (extend-many names (map (lambda (n) (lookup env n)) names) (empty-environment))) env)))
  (bump! 'closures)
  (proc-val
   (if (eq? (proc-mode) 'host)
       (host-closure (lambda (args caller)
                       (value-of body (extend-many params args
                         (if (eq? (scope-mode) 'dynamic) caller saved)))) params saved traced?)
       (closure params body saved traced?))))
(struct builtin (name arity invoke) #:transparent)
(define (apply-procedure p args caller)
  (if (builtin? p)
      (begin
        (unless (or (not (builtin-arity p)) (= (builtin-arity p) (length args)))
          (error 'apply-procedure "primitive arity mismatch"))
        (apply (builtin-invoke p) args))
      (apply-closure p args caller)))
(define (apply-closure p args caller)
  (define params (if (closure? p) (closure-params p) (host-closure-params p)))
  (define traced? (if (closure? p) (closure-traced? p) (host-closure-traced? p)))
  (unless (= (length params) (length args)) (error 'apply-procedure "arity mismatch"))
  (when traced? (printf "enter ~s\n" (map datum args)))
  (define answer
    (if (host-closure? p) ((host-closure-invoke p) args caller)
        (value-of (closure-body p)
          (extend-many params args (if (eq? (scope-mode) 'dynamic) caller (closure-saved p))))))
  (when traced? (printf "exit ~s\n" (datum answer))) answer)
;; END procedures

;; BEGIN primitives
(define (unary-name op)
  (cases unary-op op (minus-op () 'minus) (zero-op () 'zero?) (add1-op () 'add1)
    (car-op () 'car) (cdr-op () 'cdr) (null-op () 'null?) (print-op () 'print)))
(define (binary-name op)
  (cases binary-op op (diff-op () '-) (add-op () '+) (times-op () '*)
    (quotient-op () 'quotient) (equal-op () 'equal?) (greater-op () 'greater?)
    (less-op () 'less?) (cons-op () 'cons)))
(define unary-table
  (hash 'minus (lambda (v) (num-val (- (expval->num v))))
        'add1 (lambda (v) (num-val (add1 (expval->num v))))
        'zero? (lambda (v) (boolean-value (zero? (expval->num v))))
        'null? (lambda (v) (boolean-value (null? (expval->list v))))
        'car (lambda (v) (define xs (expval->list v))
               (if (null? xs) (error 'car "empty list") (car xs)))
        'cdr (lambda (v) (define xs (expval->list v))
               (if (null? xs) (error 'cdr "empty list") (list-val (cdr xs))))
        'print (lambda (v) (displayln (datum v)) (num-val 1))))
(define binary-table
  (hash '- (lambda (a b) (num-val (- (expval->num a) (expval->num b))))
        '+ (lambda (a b) (num-val (+ (expval->num a) (expval->num b))))
        '* (lambda (a b) (num-val (* (expval->num a) (expval->num b))))
        'quotient (lambda (a b) (num-val (quotient (expval->num a) (expval->num b))))
        'equal? (lambda (a b) (boolean-value (= (expval->num a) (expval->num b))))
        'greater? (lambda (a b) (boolean-value (> (expval->num a) (expval->num b))))
        'less? (lambda (a b) (boolean-value (< (expval->num a) (expval->num b))))
        'cons (lambda (a b) (list-val (cons a (expval->list b))))))
;; END primitives

;; BEGIN evaluator
(define (value-of exp env)
  (bump! 'evaluations)
  (cases expression exp
    (const-exp (n) (num-val n))
    (var-exp (v) (lookup env v))
    (unary-exp (op e) ((hash-ref unary-table (unary-name op)) (value-of e env)))
    (binary-exp (op a b)
      (define left (value-of a env))
      (define right (value-of b env))
      ((hash-ref binary-table (binary-name op)) left right))
    (if-exp (t y n) (if (true-value? (value-of t env)) (value-of y env) (value-of n env)))
    (let-exp (vs es b)
      (unique! vs 'let)
      (define vals (for/list ([e es]) (value-of e env)))
      (value-of b (extend-many vs vals env)))
    (letstar-exp (vs es b)
      (define final (for/fold ([acc env]) ([v vs] [e es])
                      (extend-environment v (value-of e acc) acc)))
      (value-of b final))
    (emptylist-exp () (list-val '()))
    (list-exp (es) (list-val (for/list ([e es]) (value-of e env))))
    (pack-exp (es) (list-val (for/list ([e es]) (value-of e env))))
    (cond-exp (ts bs)
      (let loop ([ts ts] [bs bs])
        (cond [(null? ts) (error 'cond "no test succeeds")]
              [(true-value? (value-of (car ts) env)) (value-of (car bs) env)]
              [else (loop (cdr ts) (cdr bs))])))
    (unpack-exp (vs e b)
      (unique! vs 'unpack)
      (define vals (expval->list (value-of e env)))
      (unless (= (length vs) (length vals)) (error 'unpack "list length mismatch"))
      (value-of b (extend-many vs vals env)))
    (proc-exp (vs b) (make-procedure vs b env #f))
    (traceproc-exp (vs b) (make-procedure vs b env #t))
    (call-exp (f es)
      (define p (expval->proc (value-of f env)))
      (define args (for/list ([e es]) (value-of e env)))
      (apply-procedure p args env))
    (letproc-exp (name vs pb b) (value-of b (extend-environment name (make-procedure vs pb env #f) env)))
    (letrec-exp (ns vss bs b) (value-of b (extend-rec ns vss bs env)))))
;; END evaluator

(define (integer-syntax! exp)
  (cases expression exp
    (const-exp (n) (void)) (var-exp (v) (void))
    (unary-exp (op e)
      (unless (memq (unary-name op) '(minus add1 zero?)) (error 'integers "noninteger operation"))
      (integer-syntax! e))
    (binary-exp (op a b)
      (when (eq? (binary-name op) 'cons) (error 'integers "noninteger operation"))
      (integer-syntax! a) (integer-syntax! b))
    (if-exp (t y n) (for-each integer-syntax! (list t y n)))
    (let-exp (vs es b) (for-each integer-syntax! (cons b es)))
    (else (error 'integers "form outside the integer-only LET variant"))))
(define (parse-expression text) (cases program (scan&parse text) (a-program (e) e)))
(define (run text #:scope [scope 'lexical] #:environment [env-repr 'data]
             #:procedures [proc-repr 'data] #:recursion [rec 'fresh]
             #:trim [trim? #f] #:integers [integers? #f])
  (unless (memq scope '(lexical dynamic)) (error 'run "invalid scope mode"))
  (unless (memq env-repr '(data host)) (error 'run "invalid environment mode"))
  (unless (memq proc-repr '(data host)) (error 'run "invalid procedure mode"))
  (unless (memq rec '(fresh cached)) (error 'run "invalid recursion mode"))
  (when (and trim? (eq? scope 'dynamic)) (error 'run "trimming requires lexical binding"))
  (parameterize ([scope-mode scope] [env-mode env-repr] [proc-mode proc-repr]
                 [rec-mode rec] [trim-mode trim?] [numeric-booleans? integers?])
    (define e (parse-expression text))
    (when integers? (integer-syntax! e))
    (value-of e (initial-environment))))
(define (run/datum text) (datum (run text)))

;; BEGIN examples
(define closure-example
  "let x = 200 in let f = proc (z) -(z,x) in let x = 100 in let g = proc (z) -(z,x) in -((f 1),(g 1))")
(define double-example
  "letrec double(x) = if zero?(x) then 0 else -((double -(x,1)),-2) in (double 6)")
(define dynamic-factorial-example
  "let fact = proc (n) add1(n) in let fact = proc (n) if zero?(n) then 1 else *(n,(fact -(n,1))) in (fact 5)")
(define self-times-example
  "let makemult = proc (maker) proc (x) if zero?(x) then 0 else -(((maker maker) -(x,1)),-4) in let times4 = proc (x) ((makemult makemult) x) in (times4 3)")
(define fixed-point-example
  "let makerec = proc (f) let d = proc (x) proc (z) ((f (x x)) z) in proc (n) ((f (d d)) n) in let maketimes4 = proc (f) proc (x) if zero?(x) then 0 else -((f -(x,1)),-4) in let times4 = (makerec maketimes4) in (times4 3)")
(define proc-factorial-example
  (string-append
   "let mt = proc (self) proc (a) proc (b) if zero?(b) then 0 else -(a,-(0,(((self self) a) -(b,1)))) "
   "in let times = (mt mt) "
   "in let mf = proc (self) proc (n) if zero?(n) then 1 else ((times n) ((self self) -(n,1))) "
   "in ((mf mf) 5)"))
(define proc-mutual-example
  (string-append
   "let maker = proc (self) proc (tag) proc (n) if zero?(n) then tag "
   "else (((self self) -(1,tag)) -(n,1)) "
   "in let even = ((maker maker) 1) in let odd = ((maker maker) 0) in (odd 13)"))
;; END examples

(module+ main
  (for ([s (list "-(-(x,3),-(v,i))" "if zero?(-(33,11)) then -(22,2) else -(22,4)"
                 "let x = 7 in let y = 2 in let y = let x = -(x,1) in -(x,y) in -(-(x,8),y)"
                 closure-example double-example proc-factorial-example)])
    (displayln (run/datum s))))
