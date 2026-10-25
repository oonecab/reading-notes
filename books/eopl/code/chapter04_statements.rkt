#lang racket
;; Exercises 4.22–4.27: a statement language with a separate expression front end.
(require eopl (prefix-in s: "chapter04.rkt"))
(require "sllgen_guard.rkt")
(provide (all-defined-out))

;; BEGIN statement-grammar
(define lexical
  '((space (whitespace) skip) (comment ("%" (arbno (not #\newline))) skip)
    (identifier (letter (arbno (or letter digit "_" "-" "?"))) symbol)
    (number (digit (arbno digit)) number) (number ("-" digit (arbno digit)) number)))
(define grammar
  '((st-program (statement) st-pgm)
    (statement (identifier "=" sx) st-assign)
    (statement ("print" sx) st-print)
    (statement ("read" identifier) st-read)
    (statement ("{" (separated-list statement ";") "}") st-sequence)
    (statement ("if" sx statement statement) st-if)
    (statement ("while" sx statement) st-while)
    (statement ("do" statement "while" sx) st-do)
    (statement ("var" (separated-list identifier ",") ";" statement) st-vars)
    (statement ("varinit" (arbno identifier "=" sx) ";" statement) st-initialized)
    (statement ("block" (arbno identifier "=" sx)
                (arbno "procedure" identifier "(" (separated-list identifier ",") ")" "=" sx)
                (arbno "subroutine" identifier "(" (separated-list identifier ",") ")" "=" statement)
                "in" statement "end") st-block)
    (statement ("call" identifier "(" (separated-list sx ",") ")") st-call)
    (sx (number) sx-number) (sx (identifier) sx-variable)
    (sx ("-" "(" sx "," sx ")") sx-difference)
    (sx ("+" "(" sx "," sx ")") sx-addition)
    (sx ("*" "(" sx "," sx ")") sx-multiplication)
    (sx ("zero?" "(" sx ")") sx-zero)
    (sx ("not" "(" sx ")") sx-not)
    (sx ("if" sx "then" sx "else" sx) sx-if)
    (sx ("let" (arbno identifier "=" sx) "in" sx) sx-let)
    (sx ("proc" "(" (separated-list identifier ",") ")" sx) sx-proc)
    (sx ("(" sx (arbno sx) ")") sx-call)
    (sx ("begin" sx (arbno ";" sx) "end") sx-begin)
    (sx ("set" identifier "=" sx) sx-set)))
(sllgen:make-define-datatypes lexical grammar)
(define scan&parse (guard-sllgen (sllgen:make-string-parser lexical grammar) lexical grammar))
;; END statement-grammar

(define (expression->core e)
  (cases sx e
    (sx-number (n) (s:const-exp n)) (sx-variable (v) (s:var-exp v))
    (sx-difference (a b) (s:binary-exp (s:diff-op) (expression->core a) (expression->core b)))
    (sx-addition (a b) (s:binary-exp (s:add-op) (expression->core a) (expression->core b)))
    (sx-multiplication (a b) (s:binary-exp (s:times-op) (expression->core a) (expression->core b)))
    (sx-zero (e) (s:unary-exp (s:zero-op) (expression->core e)))
    (sx-not (e) (s:unary-exp (s:not-op) (expression->core e)))
    (sx-if (t y n) (s:if-exp (expression->core t) (expression->core y) (expression->core n)))
    (sx-let (names rhss body) (s:let-exp names (map expression->core rhss) (expression->core body)))
    (sx-proc (ps body) (s:proc-exp (s:default-kind) ps (expression->core body)))
    (sx-call (f args) (s:call-exp (expression->core f) (map expression->core args)))
    (sx-begin (first rest) (s:begin-exp (expression->core first) (map expression->core rest)))
    (sx-set (v e) (s:assign-exp v (expression->core e)))))
(define (value-of-expression e env) (s:value-of (expression->core e) env))

;; BEGIN statement-blocks
(define (initialize-sequential names rhss env)
  (s:unique! names)
  (for/fold ([current env]) ([v names] [e rhss])
    ;; Evaluate this initializer BEFORE adding its own binding; earlier ones are visible.
    (define val (value-of-expression e current))
    (s:binding v (s:newref! val) current)))
(define (declaration-environment names rhss pnames paramss pbodies snames sparamss sbodies env)
  (s:unique! (append names pnames snames))
  (define variable-env (initialize-sequential names rhss env))
  (define all-names (append pnames snames))
  (define locs (map (lambda (_) (s:newref! 'uninitialized)) all-names))
  (define self (s:extend-many all-names locs variable-env))
  (for ([l locs] [params (append paramss sparamss)]) (s:unique! params))
  (for ([l (take locs (length pnames))] [ps paramss] [body pbodies])
    (s:setref! l (s:make-closure ps (expression->core body) self 'value)))
  (for ([l (drop locs (length pnames))] [ps sparamss] [body sbodies])
    (s:setref! l (s:sub-val ps body self))) self)
;; END statement-blocks

;; BEGIN statement-evaluation
(define (result-of stmt env)
  (s:tick!)
  (cases statement stmt
    (st-assign (v e)
      (define loc (s:mutable-location env v))
      (s:setref! loc (value-of-expression e env)))
    (st-print (e) (displayln (s:datum (value-of-expression e env))))
    (st-read (v)
      (define loc (s:mutable-location env v))
      (define val (parameterize ([read-accept-reader #f] [read-accept-lang #f]
                                 [read-accept-compiled #f]) (read)))
      (unless (exact-nonnegative-integer? val) (error 'read-statement "nonnegative integer required"))
      (s:setref! loc (s:num-val val)))
    (st-sequence (stmts) (for ([st stmts]) (result-of st env)))
    (st-if (t y n) (result-of (if (s:bool (value-of-expression t env)) y n) env))
    (st-while (test body)
      (let loop ()
        (when (s:bool (value-of-expression test env)) (result-of body env) (loop))))
    (st-do (body test)
      (let loop () (result-of body env) (when (s:bool (value-of-expression test env)) (loop))))
    (st-vars (names body)
      (define locs (map (lambda (_) (s:newref! 'uninitialized)) names))
      (result-of body (s:extend-many names locs env)))
    (st-initialized (names rhss body) (result-of body (initialize-sequential names rhss env)))
    (st-block (names rhss pnames paramss pbodies snames sparamss sbodies body)
      (result-of body (declaration-environment names rhss pnames paramss pbodies
                                             snames sparamss sbodies env)))
    (st-call (name args)
      (define sub (s:read-variable env name))
      (unless (s:sub-val? sub) (error 'subroutine-call "subroutine required"))
      (s:arity! (s:sub-val-params sub) args)
      (define vals (for/list ([e args]) (value-of-expression e env)))
      (define locs (map s:newref! vals))
      (result-of (s:sub-val-body sub) (s:extend-many (s:sub-val-params sub) locs (s:sub-val-env sub)))))
  (void))
;; END statement-evaluation

(struct statement-result (output store) #:transparent)
(define (run text #:input [input ""] #:fuel [limit 100000])
  (define out (open-output-string))
  (parameterize ([s:current-store (s:make-store)] [s:parameter-mode 'value]
                 [s:rec-mode 'cached] [s:fuel (box limit)]
                 [current-output-port out] [current-input-port (open-input-string input)])
    (define env (s:initial-environment))
    (cases st-program (scan&parse text) (st-pgm (stmt) (result-of stmt env)))
    (statement-result (get-output-string out) (s:store-snapshot))))
(module+ main
  (for ([text (list "var x,y; {x = 3; y = 4; print +(x,y)}"
                    "var x,y,z; {x = 3; y = 4; z = 0; while not(zero?(x)) {z = +(z,y); x = -(x,1)}; print z}"
                    "var x; {x = 3; print x; var x; {x = 4; print x}; print x}"
                    "var f,x; {f = proc(x,y) *(x,y); x = 3; print (f 4 x)}")])
    (display (statement-result-output (run text)))))
