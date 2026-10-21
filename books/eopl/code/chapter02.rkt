#lang racket/base
;; EOPL 3e chapter 2. Racket hosts the Scheme examples; eopl supplies
;; define-datatype and cases. No evaluation of reader-provided code.
(require (only-in eopl define-datatype cases))
(provide (all-defined-out))

;; BEGIN ex-2-1
(struct number-api (zero zero? succ pred encode decode) #:transparent)
;; Canonical little-endian base-N digits; zero is (). N >= 2.
(define (make-bigits base)
  (unless (and (exact-integer? base) (>= base 2)) (error 'make-bigits "base >= 2 required"))
  (define (successor ds)
    (cond [(null? ds) '(1)]
          [(= (car ds) (- base 1)) (cons 0 (successor (cdr ds)))]
          [else (cons (+ 1 (car ds)) (cdr ds))]))
  (define (predecessor ds)
    (cond [(null? ds) (error 'predecessor "zero is outside the contract")]
          [(zero? (car ds)) (cons (- base 1) (predecessor (cdr ds)))]
          [(and (= (car ds) 1) (null? (cdr ds))) '()]
          [else (cons (- (car ds) 1) (cdr ds))]))
  (define (encode n)
    (if (zero? n) '() (cons (remainder n base) (encode (quotient n base)))))
  (define (decode ds)
    (if (null? ds) 0 (+ (car ds) (* base (decode (cdr ds))))))
  (number-api (lambda () '()) null? successor predecessor encode decode))
;; Clients use only the four abstract operations. The loops are tail calls.
(define (nat-plus a x y)
  (if ((number-api-zero? a) x) y
      (nat-plus a ((number-api-pred a) x) ((number-api-succ a) y))))
(define (nat-times a x y)
  (let loop ([k x] [acc ((number-api-zero a))])
    (if ((number-api-zero? a) k) acc
        (loop ((number-api-pred a) k) (nat-plus a y acc)))))
(define (nat-factorial a n)
  (let loop ([k n] [acc ((number-api-succ a) ((number-api-zero a)))])
    (if ((number-api-zero? a) k) acc
        (loop ((number-api-pred a) k) (nat-times a k acc)))))
;; END ex-2-1

;; BEGIN ex-2-2
(define unary-api
  (number-api (lambda () '()) null? (lambda (xs) (cons #t xs)) cdr
              (lambda (n) (make-list/true n)) length))
(define (make-list/true n)
  (if (= n 0) '() (cons #t (make-list/true (- n 1)))))
(define native-api (number-api (lambda () 0) zero? add1 sub1 values values))
;; END ex-2-2

;; BEGIN ex-2-3
;; DiffTree = (one) | (diff DiffTree DiffTree); may represent any integer.
(define (dt-zero) '(diff (one) (one)))
(define (dt-value t)
  (if (eqv? (car t) 'one) 1 (- (dt-value (cadr t)) (dt-value (caddr t)))))
(define (dt-zero? t) (zero? (dt-value t)))
(define (dt-succ t) (list 'diff t (list 'diff (dt-zero) '(one))))
(define (dt-pred t) (list 'diff t '(one)))
(define (diff-tree-plus a b) (list 'diff a (list 'diff (dt-zero) b)))
;; END ex-2-3

;; BEGIN ex-2-4
;; Stack equations: top(push(v,s))=v; pop(push(v,s))=s;
;; empty?(empty)=#t; empty?(push(v,s))=#f. Empty top/pop are errors here.
(define (empty-stack) '())
(define (push v s) (cons v s))
(define (empty-stack? s) (null? s))
(define (top s) (if (null? s) (error 'top "empty stack") (car s)))
(define (pop s) (if (null? s) (error 'pop "empty stack") (cdr s)))
;; END ex-2-4

;; BEGIN ex-2-5
(struct env-api (empty extend lookup empty? has? extend*) #:transparent)
(define (missing who v) (error who "no binding for ~s" v))
(define (alist-empty) '())
(define (alist-extend v val env) (cons (cons v val) env))
(define (alist-lookup env v)
  (cond [(null? env) (missing 'apply-env v)]
        [(eqv? (caar env) v) (cdar env)]
        [else (alist-lookup (cdr env) v)]))
;; END ex-2-5

;; BEGIN ex-2-8
(define (alist-empty? env) (null? env))
;; END ex-2-8

;; BEGIN ex-2-9
(define (alist-has? env v)
  (and (pair? env) (or (eqv? (caar env) v) (alist-has? (cdr env) v))))
;; END ex-2-9

;; BEGIN ex-2-10
;; Lists must have equal lengths. Leftmost duplicate wins (explicit extension
;; to the book's equations, which are ambiguous for conflicting duplicates).
(define (extend-many extend vars vals env)
  (cond [(and (null? vars) (null? vals)) env]
        [(or (null? vars) (null? vals)) (error 'extend-env* "unequal lengths")]
        [else (extend (car vars) (car vals)
                      (extend-many extend (cdr vars) (cdr vals) env))]))
(define (alist-extend* vs vals e) (extend-many alist-extend vs vals e))
(define alist-api
  (env-api alist-empty alist-extend alist-lookup alist-empty? alist-has? alist-extend*))
;; END ex-2-10

;; BEGIN ex-2-6
;; Three additional persistent representations; all keep #f as a legal value.
;; Parallel variable/value lists.
(define (parallel-empty) (list '() '()))
(define (parallel-extend v x e) (list (cons v (car e)) (cons x (cadr e))))
(define (parallel-find e v found absent)
  (let loop ([vs (car e)] [xs (cadr e)])
    (cond [(null? vs) (absent)] [(eqv? v (car vs)) (found (car xs))]
          [else (loop (cdr vs) (cdr xs))])))
(define parallel-api
  (env-api parallel-empty parallel-extend
           (lambda (e v) (parallel-find e v values (lambda () (missing 'parallel v))))
           (lambda (e) (null? (car e)))
           (lambda (e v) (parallel-find e v (lambda (_) #t) (lambda () #f)))
           (lambda (vs xs e) (extend-many parallel-extend vs xs e))))
;; Flat alternating sequence: (var value var value ...).
(define (flat-extend v x e) (cons v (cons x e)))
(define (flat-find e v found absent)
  (cond [(null? e) (absent)] [(eqv? v (car e)) (found (cadr e))]
        [else (flat-find (cddr e) v found absent)]))
(define flat-api
  (env-api (lambda () '()) flat-extend
           (lambda (e v) (flat-find e v values (lambda () (missing 'flat v)))) null?
           (lambda (e v) (flat-find e v (lambda (_) #t) (lambda () #f)))
           (lambda (vs xs e) (extend-many flat-extend vs xs e))))
;; Immutable hash table: old environments retain their bindings.
(define (hash-extend v x e) (hash-set e v x))
(define hash-api
  (env-api hasheqv hash-extend
           (lambda (e v) (hash-ref e v (lambda () (missing 'hash v))))
           hash-empty? hash-has-key?
           (lambda (vs xs e) (extend-many hash-extend vs xs e))))
;; END ex-2-6

;; BEGIN ex-2-7
;; Figure 2.1's tagged representation, with full original environment context.
(define (tag-empty) '(empty-env))
(define (tag-extend v x e) (list 'extend-env v x e))
(define (tag-lookup env v)
  (define (walk e searched)
    (cond [(equal? e '(empty-env))
           (error 'apply-env "no binding for ~s; searched ~s; original environment ~s"
                  v (reverse searched) env)]
          [(and (list? e) (= (length e) 4) (eqv? (car e) 'extend-env))
           (if (eqv? v (cadr e)) (caddr e)
               (walk (cadddr e) (cons (cadr e) searched)))]
          [else (error 'apply-env "invalid frame ~s in original environment ~s" e env)]))
  (walk env '()))
;; END ex-2-7

;; BEGIN ex-2-11
;; Rib = (variable-list . value-list). Proper lists of equal lengths are
;; a PRECONDITION: checking lengths here would break O(1) construction.
(define (rib-empty) '())
(define (rib-extend* vs xs e) (cons (cons vs xs) e))
(define (rib-extend v x e) (rib-extend* (list v) (list x) e))
(define (rib-find e v found absent)
  (if (null? e) (absent)
      (let search ([vs (caar e)] [xs (cdar e)])
        (cond [(null? vs) (rib-find (cdr e) v found absent)]
              [(eqv? v (car vs)) (found (car xs))]
              [else (search (cdr vs) (cdr xs))]))))
(define rib-api
  (env-api rib-empty rib-extend
           (lambda (e v) (rib-find e v values (lambda () (missing 'rib v))))
           (lambda (e) (or (null? e) (and (null? (caar e)) ((env-api-empty? rib-api) (cdr e)))))
           (lambda (e v) (rib-find e v (lambda (_) #t) (lambda () #f))) rib-extend*))
;; END ex-2-11

;; BEGIN ex-2-12
;; A stack is a procedure responding to the three observers.
(define (proc-empty-stack)
  (lambda (message)
    (case message [(empty?) #t] [(top pop) (error message "empty stack")]
      [else (error 'stack "unknown message")])) )
(define (proc-push v saved)
  (lambda (message)
    (case message [(empty?) #f] [(top) v] [(pop) saved]
      [else (error 'stack "unknown message")])))
(define (proc-top s) (s 'top))
(define (proc-pop s) (s 'pop))
(define (proc-empty-stack? s) (s 'empty?))
;; END ex-2-12

;; BEGIN ex-2-13
;; Two procedures: lookup and empty?.
(define (env2-empty) (list (lambda (v) (missing 'env2 v)) (lambda () #t)))
(define (env2-extend v x e)
  (list (lambda (w) (if (eqv? v w) x ((car e) w))) (lambda () #f)))
(define (env2-lookup e v) ((car e) v))
(define (env2-empty? e) ((cadr e)))
;; END ex-2-13

;; BEGIN ex-2-14
;; Third procedure answers membership; it does not infer membership from value.
(define (env3-empty)
  (list (lambda (v) (missing 'env3 v)) (lambda () #t) (lambda (v) #f)))
(define (env3-extend v x e)
  (list (lambda (w) (if (eqv? v w) x ((car e) w)))
        (lambda () #f) (lambda (w) (or (eqv? v w) ((caddr e) w)))))
(define env3-api
  (env-api env3-empty env3-extend (lambda (e v) ((car e) v))
           (lambda (e) ((cadr e))) (lambda (e v) ((caddr e) v))
           (lambda (vs xs e) (extend-many env3-extend vs xs e))))
;; END ex-2-14

;; BEGIN lc-client
(struct lc-api (var lam app var? lam? app? name bound body rator rand) #:transparent)
;; The same client works with every representation below.
(define (free?/api a v e)
  (cond [((lc-api-var? a) e) (eqv? v ((lc-api-name a) e))]
        [((lc-api-lam? a) e) (and (not (eqv? v ((lc-api-bound a) e)))
                                 (free?/api a v ((lc-api-body a) e)))]
        [else (or (free?/api a v ((lc-api-rator a) e))
                  (free?/api a v ((lc-api-rand a) e)))]))
;; END lc-client

;; BEGIN ex-2-15
(define (list-lam? e) (and (pair? e) (eqv? (car e) 'lambda)))
(define (list-app? e) (and (pair? e) (not (list-lam? e))))
(define list-lc-api
  (lc-api values (lambda (v b) (list 'lambda (list v) b)) list
          symbol? list-lam? list-app? values caadr caddr car cadr))
;; END ex-2-15

;; BEGIN ex-2-16
(define flat-lc-api
  (lc-api values (lambda (v b) (list 'lambda v b)) list
          symbol? list-lam? list-app? values cadr caddr car cadr))
;; END ex-2-16

;; BEGIN ex-2-17
(define vector-lc-api
  (lc-api (lambda (v) (vector 'var v)) (lambda (v b) (vector 'lam v b))
          (lambda (f x) (vector 'app f x))
          (lambda (e) (eqv? (vector-ref e 0) 'var))
          (lambda (e) (eqv? (vector-ref e 0) 'lam))
          (lambda (e) (eqv? (vector-ref e 0) 'app))
          (lambda (e) (vector-ref e 1)) (lambda (e) (vector-ref e 1))
          (lambda (e) (vector-ref e 2)) (lambda (e) (vector-ref e 1))
          (lambda (e) (vector-ref e 2))))
(define (dispatch-node tag first [second #f])
  (lambda (msg) (case msg [(tag) tag] [(first) first] [(second) second]
                 [else (error 'node "unknown observer")])) )
(define procedure-lc-api
  (lc-api (lambda (v) (dispatch-node 'var v))
          (lambda (v b) (dispatch-node 'lam v b)) (lambda (f x) (dispatch-node 'app f x))
          (lambda (e) (eqv? (e 'tag) 'var)) (lambda (e) (eqv? (e 'tag) 'lam))
          (lambda (e) (eqv? (e 'tag) 'app))
          (lambda (e) (e 'first)) (lambda (e) (e 'first)) (lambda (e) (e 'second))
          (lambda (e) (e 'first)) (lambda (e) (e 'second))))
;; END ex-2-17

;; BEGIN ex-2-18
;; Nonempty sequence zipper: (current reversed-left right).
(define (number->sequence n) (list n '() '()))
(define (seq-current s) (car s))
(define (at-left-end? s) (null? (cadr s)))
(define (at-right-end? s) (null? (caddr s)))
(define (seq-left s)
  (if (at-left-end? s) (error 'move-to-left "left end")
      (list (caadr s) (cdadr s) (cons (car s) (caddr s)))))
(define (seq-right s)
  (if (at-right-end? s) (error 'move-to-right "right end")
      (list (caaddr s) (cons (car s) (cadr s)) (cdaddr s))))
(define (seq-insert-left n s) (list (car s) (cons n (cadr s)) (caddr s)))
(define (seq-insert-right n s) (list (car s) (cadr s) (cons n (caddr s))))
;; END ex-2-18

;; BEGIN ex-2-19
;; Unlike chapter 1: integer interior nodes and empty leaves.
(define (number->bintree n) (list n '() '()))
(define at-leaf? null?)
(define (require-node t who) (when (at-leaf? t) (error who "empty leaf")))
(define (current-element t) (require-node t 'current-element) (car t))
(define (move-to-left-son t) (require-node t 'move-to-left-son) (cadr t))
(define (move-to-right-son t) (require-node t 'move-to-right-son) (caddr t))
(define move-to-left move-to-left-son) ; names used in the book's examples
(define move-to-right move-to-right-son)
(define (insert-to-left n t)
  (require-node t 'insert-to-left)
  (list (car t) (list n (cadr t) '()) (caddr t)))
(define (insert-to-right n t)
  (require-node t 'insert-to-right)
  (list (car t) (cadr t) (list n '() (caddr t))))
;; END ex-2-19

;; BEGIN ex-2-20
;; Tree zipper: (focus breadcrumbs). Each breadcrumb retains parent and sibling.
(define (zip-number n) (list (number->bintree n) '()))
(define (zip-leaf? z) (null? (car z)))
(define (at-root? z) (null? (cadr z)))
(define (zip-current z) (current-element (car z)))
(define (zip-left z)
  (define t (car z)) (require-node t 'zip-left)
  (list (cadr t) (cons (list 'L (car t) (caddr t)) (cadr z))))
(define (zip-right z)
  (define t (car z)) (require-node t 'zip-right)
  (list (caddr t) (cons (list 'R (car t) (cadr t)) (cadr z))))
(define (move-up z)
  (when (at-root? z) (error 'move-up "already at root"))
  (define crumb (caadr z))
  (list (if (eqv? (car crumb) 'L) (list (cadr crumb) (car z) (caddr crumb))
            (list (cadr crumb) (caddr crumb) (car z))) (cdadr z)))
(define (zip-insert-left n z) (list (insert-to-left n (car z)) (cadr z)))
(define (zip-insert-right n z) (list (insert-to-right n (car z)) (cadr z)))
;; END ex-2-20

;; BEGIN ex-2-21
(define (any-value? v) #t)
(define-datatype environment environment?
  (empty-env)
  (extend-env (var symbol?) (val any-value?) (saved environment?)))
(define (apply-env env v)
  (cases environment env
    (empty-env () (missing 'apply-env v))
    (extend-env (w x old) (if (eqv? v w) x (apply-env old v)))))
(define (has-binding? env v)
  (cases environment env
    (empty-env () #f)
    (extend-env (w x old) (or (eqv? v w) (has-binding? old v)))))
(define (empty-env? env) (cases environment env (empty-env () #t) (else #f)))
(define datatype-env-api
  (env-api empty-env extend-env apply-env empty-env? has-binding?
           (lambda (vs xs e) (extend-many extend-env vs xs e))))
;; END ex-2-21

;; BEGIN ex-2-22
(define-datatype stack stack?
  (dt-empty-stack)
  (dt-push (value any-value?) (saved stack?)))
(define (dt-empty-stack? s) (cases stack s (dt-empty-stack () #t) (else #f)))
(define (dt-top s)
  (cases stack s (dt-empty-stack () (error 'top "empty stack")) (dt-push (v old) v)))
(define (dt-pop s)
  (cases stack s (dt-empty-stack () (error 'pop "empty stack")) (dt-push (v old) old)))
;; END ex-2-22

;; BEGIN ex-2-23
(define (identifier? x) (and (symbol? x) (not (eqv? x 'lambda))))
(define-datatype lc-exp lc-exp?
  (var-exp (var identifier?))
  (lambda-exp (bound-var identifier?) (body lc-exp?))
  (app-exp (rator lc-exp?) (rand lc-exp?)))
;; END ex-2-23

;; BEGIN ex-2-24
(define-datatype bintree bintree?
  (leaf-node (num integer?))
  (interior-node (key symbol?) (left bintree?) (right bintree?)))
(define (bintree-to-list t)
  (cases bintree t
    (leaf-node (n) (list 'leaf-node n))
    (interior-node (k l r) (list 'interior-node k (bintree-to-list l) (bintree-to-list r)))))
;; END ex-2-24

;; BEGIN ex-2-25
;; walk returns subtree leaf sum and either #f or (key . best interior sum).
;; Ties choose current, then left, then right. Negative maxima are valid.
(define (max-interior t)
  (define (better a b) (if (and b (> (cdr b) (cdr a))) b a))
  (define (walk t)
    (cases bintree t
      (leaf-node (n) (values n #f))
      (interior-node (k l r)
        (let-values ([(ls lb) (walk l)] [(rs rb) (walk r)])
          (define sum (+ ls rs))
          (values sum (better (better (cons k sum) lb) rb))))))
  (let-values ([(sum best) (walk t)])
    (if best (car best) (error 'max-interior "requires an interior node"))))
;; END ex-2-25

;; BEGIN ex-2-26
(define (list-of pred)
  (lambda (xs) (and (list? xs) (andmap pred xs))))
(define-datatype red-blue-tree red-blue-tree?
  (a-red-blue-tree (root red-blue-subtree?)))
(define-datatype red-blue-subtree red-blue-subtree?
  (red-node (left red-blue-subtree?) (right red-blue-subtree?))
  (blue-node (children (list-of red-blue-subtree?)))
  (rb-leaf (value integer?)))
(define (mark-red-depth tree)
  (define (walk t d)
    (cases red-blue-subtree t
      (rb-leaf (n) (rb-leaf d))
      (red-node (l r) (red-node (walk l (+ d 1)) (walk r (+ d 1))))
      (blue-node (children) (blue-node (map (lambda (c) (walk c d)) children)))))
  (cases red-blue-tree tree (a-red-blue-tree (root) (a-red-blue-tree (walk root 0)))))
(define (rb->list tree)
  (define (walk t)
    (cases red-blue-subtree t (rb-leaf (n) n)
      (red-node (l r) (list 'red (walk l) (walk r)))
      (blue-node (cs) (cons 'blue (map walk cs)))))
  (cases red-blue-tree tree (a-red-blue-tree (root) (walk root))))
;; END ex-2-26

;; BEGIN ex-2-30
;; Any Scheme value -> LcExp or a syntax error with the offending datum.
(define (parse-expression datum)
  (define (bad) (error 'parse-expression "invalid lambda-calculus syntax: ~s" datum))
  (cond [(identifier? datum) (var-exp datum)]
        [(not (and (list? datum) (pair? datum))) (bad)]
        [(eqv? (car datum) 'lambda)
         (if (and (= (length datum) 3) (list? (cadr datum))
                  (= (length (cadr datum)) 1) (identifier? (caadr datum)))
             (lambda-exp (caadr datum) (parse-expression (caddr datum))) (bad))]
        [(= (length datum) 2)
         (app-exp (parse-expression (car datum)) (parse-expression (cadr datum)))]
        [else (bad)]))
(define (unparse-expression exp)
  (cases lc-exp exp
    (var-exp (v) v)
    (lambda-exp (v b) (list 'lambda (list v) (unparse-expression b)))
    (app-exp (f x) (list (unparse-expression f) (unparse-expression x)))))
;; END ex-2-30

;; BEGIN ex-2-27
(define ast-example-1 (parse-expression '((lambda (a) (a b)) c)))
(define ast-example-2 (parse-expression '(lambda (x) (lambda (y) ((lambda (x) (x y)) x)))))
;; END ex-2-27

;; BEGIN ex-2-28
;; Exactly the alternate grammar's strings; grammar is ambiguous for lambda
;; operators, so this is not claimed to have a unique parse inverse.
(define (unparse/string exp)
  (cases lc-exp exp
    (var-exp (v) (symbol->string v))
    (lambda-exp (v b) (string-append "proc " (symbol->string v) " => " (unparse/string b)))
    (app-exp (f x) (string-append (unparse/string f) "(" (unparse/string x) ")"))))
;; END ex-2-28

;; BEGIN ex-2-29
(define-datatype multi-exp multi-exp?
  (m-var (v identifier?))
  (m-lambda (vars (list-of identifier?)) (body multi-exp?))
  (m-app (rator multi-exp?) (rands (list-of multi-exp?))))
(define (parse-multi d)
  (define (bad) (error 'parse-multi "invalid syntax: ~s" d))
  (cond [(identifier? d) (m-var d)]
        [(not (and (list? d) (pair? d))) (bad)]
        [(eqv? (car d) 'lambda)
         (if (and (= (length d) 3) ((list-of identifier?) (cadr d)))
             (m-lambda (cadr d) (parse-multi (caddr d))) (bad))]
        [else (m-app (parse-multi (car d)) (map parse-multi (cdr d)))]))
(define (unparse-multi exp)
  (cases multi-exp exp
    (m-var (v) v)
    (m-lambda (vs b) (list 'lambda vs (unparse-multi b)))
    (m-app (f xs) (cons (unparse-multi f) (map unparse-multi xs)))))
;; END ex-2-29

;; BEGIN ex-2-31
(define-datatype prefix-exp prefix-exp?
  (const-exp (num integer?))
  (diff-exp (operand1 prefix-exp?) (operand2 prefix-exp?)))
;; Returns the parsed tree AND tokens not consumed by that tree.
(define (parse-prefix-part tokens)
  (cond [(null? tokens) (error 'parse-prefix "unexpected end")]
        [(integer? (car tokens)) (values (const-exp (car tokens)) (cdr tokens))]
        [(eqv? (car tokens) '-)
         (let*-values ([(left rest1) (parse-prefix-part (cdr tokens))]
                       [(right rest2) (parse-prefix-part rest1)])
           (values (diff-exp left right) rest2))]
        [else (error 'parse-prefix "invalid token: ~s" (car tokens))]))
(define (parse-prefix tokens)
  (unless (list? tokens) (error 'parse-prefix "proper token list required"))
  (let-values ([(exp rest) (parse-prefix-part tokens)])
    (unless (null? rest) (error 'parse-prefix "unused tokens: ~s" rest)) exp))
(define (prefix-value exp)
  (cases prefix-exp exp
    (const-exp (n) n)
    (diff-exp (l r) (- (prefix-value l) (prefix-value r)))))
(define (prefix->tokens exp)
  (define (walk e tail)
    (cases prefix-exp e
      (const-exp (n) (cons n tail))
      (diff-exp (l r) (cons '- (walk l (walk r tail))))))
  (walk exp '()))
;; END ex-2-31

(module+ main
  (define a (make-bigits 16))
  (write ((number-api-encode a) 258)) (newline)
  (write (unparse-expression ast-example-1)) (newline)
  (write (prefix-value (parse-prefix '(- - 3 2 - 4 - 12 7)))) (newline)
  (write (car (move-up (zip-insert-right 99 (zip-left (zip-insert-left 12 (zip-number 13)))))))
  (newline))
