#lang racket
;; CPS-IN -> CPS-OUT, with independent target parsing/evaluation.
(require racket/match "chapter05_syntax.rkt" (prefix-in out: "chapter06_target.rkt"))
(provide (all-defined-out))
(define (ast-size x) (if (pair? x) (+ 1 (ast-size (car x)) (ast-size (cdr x))) 1))
(define (simple? e [strict? #t])
 (match e
  [`(num ,_) #t] [`(var ,_) #t]
  [`(prim ,_ . ,es) (andmap (lambda (x) (simple? x strict?)) es)]
  [`(list . ,es) (andmap (lambda (x) (simple? x strict?)) es)]
  [`(proc ,_ ,b) (or (not strict?) (tail-form? b))] [_ #f]))
;; BEGIN tail-form
(define (tail-form? e)
 (match e
  [`(if ,t ,a ,b) (and (simple? t) (tail-form? a) (tail-form? b))]
  [`(let ,_ ,es ,b) (and (andmap simple? es) (tail-form? b))]
  [`(letrec ,_ ,_ ,bs ,b) (and (andmap tail-form? bs) (tail-form? b))]
  [`(call ,f ,es) (and (simple? f) (andmap simple? es))]
  [_ (simple? e)]))
;; END tail-form
(define (all-vars x)
 (if (pair? x) (append (all-vars (car x)) (all-vars (cdr x))) (if (symbol? x) (list x) '())))
(define (alpha e fresh)
 (define (lookup x rho) (cond [(assq x rho) => cdr] [else x]))
 (define (bind xs rho) (unique! xs) (append (map (lambda (x) (cons x (fresh x))) xs) rho))
 (define (go e rho)
  (match e
   [`(num ,_) e] [`(var ,x) `(var ,(lookup x rho))]
   [`(proc ,xs ,b) (define r (bind xs rho)) `(proc ,(map (lambda (x) (lookup x r)) xs) ,(go b r))]
   [`(let ,xs ,es ,b) (define r (bind xs rho))
    `(let ,(map (lambda (x) (lookup x r)) xs) ,(map (lambda (a) (go a rho)) es) ,(go b r))]
   [`(letrec ,ns ,pss ,bs ,b)
    (define r (bind ns rho))
    (define rs (map (lambda (ps) (bind ps r)) pss))
    `(letrec ,(map (lambda (x) (lookup x r)) ns)
      ,(map (lambda (ps rr) (map (lambda (x) (lookup x rr)) ps)) pss rs)
      ,(map go bs rs) ,(go b r))]
   [`(letcc ,x ,b) (define r (bind (list x) rho)) `(letcc ,(lookup x r) ,(go b r))]
   [`(try ,b ,xs ,h) (define r (bind xs rho)) `(try ,(go b rho) ,(map (lambda (x) (lookup x r)) xs) ,(go h r))]
   [`(set ,x ,rhs) `(set ,(lookup x rho) ,(go rhs rho))]
   [`(call ,f ,es) `(call ,(go f rho) ,(map (lambda (a) (go a rho)) es))]
   [`(prim ,op . ,es) `(prim ,op ,@(map (lambda (a) (go a rho)) es))]
   [(list tag es ...) `(,tag ,@(map (lambda (a) (go a rho)) es))]
   [_ (error 'alpha "unknown syntax ~s" e)]))
 (go e '()))
(define (substitute t x s)
 ;; Every binder has a globally fresh identity before CPS; substitution therefore cannot capture.
 (match t
  [`(var ,y) (if (eq? x y) s t)]
  [`(proc ,xs ,b) (if (memq x xs) t `(proc ,xs ,(substitute b x s)))]
  [`(let1 ,y ,a ,b) `(let1 ,y ,(substitute a x s) ,(if (eq? x y) b (substitute b x s)))]
  [`(letrec ,ns ,pss ,bs ,b)
   (if (memq x ns) t
    `(letrec ,ns ,pss ,(map (lambda (ps body) (if (memq x ps) body (substitute body x s))) pss bs)
      ,(substitute b x s)))]
  [(? pair?) (map (lambda (part) (substitute part x s)) t)] [_ t]))
(define (lower-implicit e fresh optimize?)
 (define assigned
  (let collect ([e e])
   (match e [`(set ,x ,rhs) (cons x (collect rhs))]
    [(? pair?) (apply append (map collect e))] [_ '()])))
 (define (promote-recursive-groups e)
  (match e
   [`(letrec ,ns ,_ ,bs ,b)
    (when (ormap (lambda (x) (memq x assigned)) ns) (set! assigned (append ns assigned)))
    (for-each promote-recursive-groups bs) (promote-recursive-groups b)]
   [(? pair?) (for-each promote-recursive-groups e)] [_ (void)]))
 (promote-recursive-groups e)
 (define (mutable? x) (or (not optimize?) (memq x assigned)))
 (define (bind-values xs es body)
  (if (null? xs) body
   `(let (,(car xs)) (,(if (mutable? (car xs)) `(newref ,(car es)) (car es)))
     ,(bind-values (cdr xs) (cdr es) body))))
 (define (go e)
  (match e
   [`(num ,_) e] [`(var ,x) (if (mutable? x) `(deref ,e) e)]
   [`(set ,x ,rhs) `(begin (setref (var ,x) ,(go rhs)) (num 27))]
   [`(proc ,xs ,b)
    (define args (map (lambda (_) (fresh 'arg)) xs))
    `(proc ,args ,(bind-values xs (map (lambda (x) `(var ,x)) args) (go b)))]
   [`(let ,xs ,es ,b)
    (define temps (map (lambda (_) (fresh 'rhs)) xs))
    `(let ,temps ,(map go es) ,(bind-values xs (map (lambda (x) `(var ,x)) temps) (go b)))]
   [`(letcc ,x ,body)
    (define raw (fresh 'escape))
    `(letcc ,raw ,(bind-values (list x) (list `(var ,raw)) (go body)))]
   [`(try ,body ,xs ,handler)
    (define raw (map (lambda (_) (fresh 'raised)) xs))
    `(try ,(go body) ,raw
      ,(bind-values xs (map (lambda (x) `(var ,x)) raw) (go handler)))]
   [`(letrec ,ns ,pss ,bs ,b)
    ;; Allocate the entire recursive group before installing any closure.
    (define init-xs (map (lambda (_) '(num 0)) ns))
    (define closures (map (lambda (ps body) (go `(proc ,ps ,body))) pss bs))
    (if (ormap mutable? ns)
     (bind-values ns init-xs
      `(begin ,@(map (lambda (n c) `(setref (var ,n) ,c)) ns closures) ,(go b)))
     `(letrec ,ns ,(map cadr closures) ,(map caddr closures) ,(go b)))]
   [`(call ,f ,es) `(call ,(go f) ,(map go es))]
   [`(prim ,op . ,es) `(prim ,op ,@(map go es))]
   [(list tag es ...) `(,tag ,@(map go es))] [_ e]))
 (go e))
(define (cps-program source #:order [order 'left] #:share-if? [share-if? #t]
                     #:send [send-mode 'let] #:fuse-let? [fuse-let? #t]
                     #:exceptions? [exceptions? #f] #:implicit? [implicit? #f]
                     #:immutable? [immutable? #f])
 (define counter 0)
 (define (fresh prefix) (set! counter (add1 counter)) (string->symbol (format "~a%~a" prefix counter)))
 (define input0 (if (string? source) (parse source) source))
 (define input (alpha (if implicit? `(let (i v x) ((num 1) (num 5) (num 10)) ,input0) input0) fresh))
 (define e (if implicit? (lower-implicit input fresh immutable?) input))
 (define (V x) `(var ,x))
 (define (send k s)
  (match k
   [`(proc (,x) ,b)
    (case send-mode [(let) `(let1 ,x ,s ,b)] [(substitute) (substitute b x s)]
     [else `(call ,k (,s))])]
   [_ `(call ,k (,s))]))
;; BEGIN cps-exps
 (define (exps es builder h [call? #f])
  (define operands (list->vector es))
  (define indices (range (vector-length operands)))
  (define positions
   (cond [(eq? order 'right) (reverse indices)]
    [(and call? (eq? order 'operands-first) (pair? es)) (append (cdr indices) '(0))]
    [else indices]))
  (define (walk positions converted)
   (if (null? positions) (builder (map (lambda (i) (hash-ref converted i)) indices))
    (let* ([i (car positions)] [arg (vector-ref operands i)])
     (if (simple? arg #f)
      (walk (cdr positions) (hash-set converted i (simp arg h)))
      (let ([v (fresh 'v)])
       (cps arg `(proc (,v) ,(walk (cdr positions) (hash-set converted i (V v)))) h))))))
  (walk positions (hash)))
;; END cps-exps
 (define (simp e h)
  (match e
   [`(num ,_) e] [`(var ,_) e]
   [`(prim ,op . ,es) `(prim ,op ,@(map (lambda (a) (simp a h)) es))]
   [`(list . ,es) `(list ,@(map (lambda (a) (simp a h)) es))]
   [`(proc ,xs ,b)
    ;; Source identifiers cannot contain %, so %% marks compiler control roles.
    (define k (fresh 'k%)) (define err (and exceptions? (fresh 'h%)))
    `(proc ,(append xs (list k) (if err (list err) '())) ,(cps b (V k) (if err (V err) h)))]))
;; BEGIN cps-main
 (define (cps e k h)
  (match e
   [(? (lambda (a) (simple? a #f))) (send k (simp e h))]
   [`(prim ,op . ,es)
    (exps es (lambda (ss) (send k `(prim ,op ,@ss))) h)]
   [`(list . ,es) (exps es (lambda (ss) (send k `(list ,@ss))) h)]
   [`(call ,f ,es)
    (exps (cons f es) (lambda (ss) `(call ,(car ss) ,(append (cdr ss) (list k) (if exceptions? (list h) '())))) h #t)]
   [`(if ,t ,a ,b)
    (exps (list t) (lambda (ss)
     (if (and share-if? (not (eq? (car k) 'var)))
      (let ([name (fresh 'join%)]) `(let1 ,name ,k (if ,(car ss) ,(cps a (V name) h) ,(cps b (V name) h))))
      `(if ,(car ss) ,(cps a k h) ,(cps b k h)))) h)]
   [`(let ,xs ,es ,b)
    (cond [(and fuse-let? (= (length xs) 1) (not (simple? (car es) #f)))
           (cps (car es) `(proc (,(car xs)) ,(cps b k h)) h)]
     [else (exps es (lambda (ss)
      (foldr (lambda (x a rest) `(let1 ,x ,a ,rest)) (cps b k h) xs ss)) h)])]
   [`(letrec ,ns ,pss ,bs ,b)
    (define ps (map (lambda (xs body) (simp `(proc ,xs ,body) h)) pss bs))
    `(letrec ,ns ,(map cadr ps) ,(map caddr ps) ,(cps b k h))]
   [`(begin ,first . ,rest)
    (if (null? rest) (cps first k h)
     (let ([v (fresh 'discard)]) (cps first `(proc (,v) ,(cps `(begin ,@rest) k h)) h)))]
   [`(print ,arg) (exps (list arg) (lambda (ss) `(printk ,(car ss) ,(send k '(num 38)))) h)]
   [`(newref ,arg) (exps (list arg) (lambda (ss) `(newrefk ,(car ss) ,k)) h)]
   [`(deref ,arg) (exps (list arg) (lambda (ss) `(derefk ,(car ss) ,k)) h)]
   [`(setref ,a ,b) (exps (list a b) (lambda (ss) `(setrefk ,(car ss) ,(cadr ss) ,(send k '(num 23)))) h)]
   [`(letcc ,x ,body) `(let1 ,x ,k ,(cps body (V x) h))]
   [`(throw ,v ,dest) (exps (list v dest) (lambda (ss) `(call ,(cadr ss) (,(car ss)))) h)]
   [`(try ,body (,x) ,handler)
    (unless exceptions? (error 'cps "enable dual continuations"))
    (define err (fresh 'handler))
    `(let1 ,err (proc (,x) ,(cps handler k h)) ,(cps body k (V err)))]
   [`(raise ,arg)
    (unless exceptions? (error 'cps "enable dual continuations"))
    (exps (list arg) (lambda (ss) `(call ,h ,ss)) h)]
   [_ (error 'cps "unsupported expression: ~s" e)]))
;; END cps-main
 (define answer (fresh 'answer))
 (define exn (fresh 'exception))
 (cps e `(proc (,answer) (return (var ,answer))) `(proc (,exn) (uncaught (var ,exn)))))
(define (run-converted source #:numeric? [numeric? #f] #:order [order 'left])
 (define target (cps-program source #:order order))
 ;; Serialize and parse with the independent target grammar before evaluation.
 (out:run-target (out:parse-target (out:target-string target)) #:numeric? numeric?))
(module+ main
 (define pgm "letrec double(x) = if zero?(x) then 0 else -((double -(x,1)),-2) in (double 6)")
 (define target (cps-program pgm))
 (define-values (v m) (out:run-target (out:parse-target (out:target-string target))))
 (printf "CPS-OUT: ~s; output=~s\n" v (hash-ref m 'output)))
