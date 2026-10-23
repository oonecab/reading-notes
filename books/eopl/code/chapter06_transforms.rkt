#lang racket
;; Defunctionalization, atomic simple operands and ANF. Integer-tag closure lists.
(require racket/match "chapter06.rkt")
(provide (all-defined-out))
(define (minus xs ys) (filter (lambda (x) (not (memq x ys))) xs))
(define (union . xs) (remove-duplicates (apply append xs)))
(define (free t)
 (match t
  [`(var ,x) (list x)] [`(num ,_) '()]
  [`(proc ,xs ,b) (minus (free b) xs)]
  [`(let1 ,x ,s ,b) (union (free s) (minus (free b) (list x)))]
  [`(letrec ,ns ,pss ,bs ,b)
   (minus (apply union (free b) (map (lambda (ps body) (minus (free body) ps)) pss bs)) ns)]
  [`(prim ,_ . ,es) (apply union (map free es))]
  [`(call ,f ,ss) (apply union (map free (cons f ss)))]
  [(list _ es ...) (apply union (map free es))] [_ '()]))
(define (defunctionalize target #:all? [all? #t])
 (define table '()) (define next 0)
 (define dispatcher 'applyData%0) (define clos 'closure%0) (define args 'args%0)
 (define (V x) `(var ,x))
 (define (at list-exp i) `(prim car ,(for/fold ([x list-exp]) ([_ (in-range i)]) `(prim cdr ,x))))
 (define (pack tag fvs) `(list (num ,tag) ,@(map V fvs)))
 (define (cont-proc? ps)
  (not (ormap (lambda (p) (regexp-match? #rx"^[kh]%" (symbol->string p))) ps)))
 (define (cont-name? x) (regexp-match? #rx"^(k|join)%" (symbol->string x)))
 (define (reserve! ps b fvs group)
  (set! next (add1 next))
  (define entry (vector next ps b fvs group #f))
  (set! table (append table (list entry))) entry)
 (define (lift-proc ps body)
  (define fvs (minus (free body) ps))
  (define entry (reserve! ps body fvs #f))
  (vector-set! entry 5 (go body)) (pack (vector-ref entry 0) fvs))
 (define (go t)
  (match t
   [`(proc ,ps ,b)
    (if (or all? (cont-proc? ps)) (lift-proc ps b) `(proc ,ps ,(go b)))]
   [`(letrec ,ns ,pss ,bs ,b)
    (if (not all?) `(letrec ,ns ,pss ,(map go bs) ,(go b))
     (let* ([fvs (minus (apply union (map (lambda (ps body) (minus (free body) ps)) pss bs)) ns)]
            [entries (map (lambda (ps body) (reserve! ps body fvs #t)) pss bs)]
            [tags (map (lambda (entry) (vector-ref entry 0)) entries)]
            [group (map cons ns tags)])
      (for ([entry entries]) (vector-set! entry 4 group) (vector-set! entry 5 (go (vector-ref entry 2))))
      (foldr (lambda (n tag rest) `(let1 ,n ,(pack tag fvs) ,rest)) (go b) ns tags)))]
   [`(call ,f ,ss)
    (define indirect? (or all? (match f [`(var ,x) (cont-name? x)] [`(proc ,ps ,_) (cont-proc? ps)] [_ #f])))
    (if indirect? `(call (var ,dispatcher) (,(go f) (list ,@(map go ss)))) `(call ,(go f) ,(map go ss)))]
   [`(let1 ,x ,s ,b) `(let1 ,x ,(go s) ,(go b))]
   [`(prim ,op . ,ss) `(prim ,op ,@(map go ss))]
   [(? pair?) (map go t)] [_ t]))
 (define body (go target))
;; BEGIN defunction-dispatch
 (define (case-body entry)
  (match-define (vector tag ps original fvs group converted) entry)
  (define restored
   (if group
    (foldr (lambda (p rest) `(let1 ,(car p) ,(pack (cdr p) fvs) ,rest)) converted group)
    converted))
  (define with-params
   (for/fold ([t restored]) ([p (in-list (reverse ps))] [i (in-list (reverse (range (length ps))))])
    `(let1 ,p ,(at (V args) i) ,t)))
  (for/fold ([t with-params]) ([x (in-list (reverse fvs))] [i (in-list (reverse (range 1 (add1 (length fvs)))))])
   `(let1 ,x ,(at (V clos) i) ,t)))
 (define dispatch
  (foldr (lambda (entry rest)
   `(if (prim equal? ,(at (V clos) 0) (num ,(vector-ref entry 0))) ,(case-body entry) ,rest))
   '(uncaught (num 999)) table))
;; END defunction-dispatch
 (values `(letrec (,dispatcher) ((,clos ,args)) (,dispatch) ,body)
  (for/list ([entry table]) (list (vector-ref entry 0) (vector-ref entry 1) (vector-ref entry 3)))))
(define (atomicize target)
 (define count 0)
 (define used (make-hasheq))
 (for ([name (all-vars target)]) (hash-set! used name #t))
 (define (fresh)
  (set! count (add1 count))
  (define name (string->symbol (format "atom%~a" count)))
  (if (hash-has-key? used name) (fresh)
      (begin (hash-set! used name #t) name)))
 (define (atom s context)
  (match s
   [(or `(num ,_) `(var ,_)) (context s)]
   [_ (define x (fresh)) (simple s (lambda (a) `(let1 ,x ,a ,(context `(var ,x)))))]))
 (define (atoms ss context)
  (if (null? ss) (context '())
   (atom (car ss) (lambda (a) (atoms (cdr ss) (lambda (rest) (context (cons a rest))))))))
 (define (simple s context)
  (match s
   [`(prim ,op . ,ss) (atoms ss (lambda (as) (context `(prim ,op ,@as))))]
   [`(list . ,ss) (atoms ss (lambda (as) (context `(list ,@as))))]
   [`(proc ,ps ,b) (context `(proc ,ps ,(go b)))] [_ (context s)]))
 (define (go t)
  (match t
   [`(return ,s) (simple s (lambda (a) `(return ,a)))]
   [`(let1 ,x ,s ,b) (simple s (lambda (a) `(let1 ,x ,a ,(go b))))]
   [`(letrec ,ns ,pss ,bs ,b) `(letrec ,ns ,pss ,(map go bs) ,(go b))]
   [`(if ,s ,a ,b) (simple s (lambda (v) `(if ,v ,(go a) ,(go b))))]
   [`(call ,f ,ss) (simple f (lambda (p) (atoms ss (lambda (as) `(call ,p ,as)))))]
   [`(printk ,s ,b) (simple s (lambda (a) `(printk ,a ,(go b))))]
   [`(newrefk ,s ,k) (simple s (lambda (a) (simple k (lambda (c) `(newrefk ,a ,c)))))]
   [`(derefk ,s ,k) (simple s (lambda (a) (simple k (lambda (c) `(derefk ,a ,c)))))]
   [`(setrefk ,a ,b ,next) (simple a (lambda (x) (simple b (lambda (y) `(setrefk ,x ,y ,(go next))))))]
   [_ t])) (go target))
(define (anf source)
 (define count 0)
 (define (fresh p) (set! count (add1 count)) (string->symbol (format "~a%anf~a" p count)))
 (define e (alpha source fresh))
 (define (atom? e) (match e [`(num ,_) #t] [`(var ,_) #t] [`(proc ,_ ,_) #t]
  [`(prim ,_ . ,es) (andmap atom? es)] [`(list . ,es) (andmap atom? es)] [_ #f]))
 (define (name e ctx)
  (define n (norm e))
  (match n
   [`(let ,xs ,es ,b) `(let ,xs ,es ,(name b ctx))]
   [_ (if (atom? n) (ctx n)
       (let ([x (fresh 'value)]) `(let (,x) (,n) ,(ctx `(var ,x)))))]))
 (define (names es ctx)
  (if (null? es) (ctx '())
   (name (car es) (lambda (a) (names (cdr es) (lambda (as) (ctx (cons a as))))))))
 (define (bind-one x rhs body)
  (match rhs
   [`(let ,xs ,es ,inner)
    (foldr (lambda (y v rest) (bind-one y v rest)) (bind-one x inner body) xs es)]
   [_ `(let (,x) (,rhs) ,body)]))
 (define (norm e)
  (match e
   [`(proc ,xs ,b) `(proc ,xs ,(norm b))]
   [`(prim ,op . ,es) (names es (lambda (as) `(prim ,op ,@as)))]
   [`(list . ,es) (names es (lambda (as) `(list ,@as)))]
   [`(call ,f ,es) (names (cons f es) (lambda (as) `(call ,(car as) ,(cdr as))))]
   [`(if ,t ,a ,b) (name t (lambda (s) `(if ,s ,(norm a) ,(norm b))))]
   [`(let ,xs ,es ,b)
    (foldr (lambda (x rhs rest) (bind-one x (norm rhs) rest)) (norm b) xs es)]
   [`(letrec ,ns ,pss ,bs ,b) `(letrec ,ns ,pss ,(map norm bs) ,(norm b))]
   [_ e])) (norm e))
(define (canonical-target target)
 (define count 0)
 (define (fresh) (set! count (add1 count)) (string->symbol (format "bound~a" count)))
 (define (bind xs rho)
  (define names (map (lambda (_) (fresh)) xs)) (values names (append (map cons xs names) rho)))
 (define (go t rho)
  (match t
   [`(var ,x) `(var ,(cond [(assq x rho) => cdr] [else x]))]
   [`(proc ,xs ,b) (define-values (ns rr) (bind xs rho)) `(proc ,ns ,(go b rr))]
   [`(let1 ,x ,s ,b) (define-values (ns rr) (bind (list x) rho)) `(let1 ,(car ns) ,(go s rho) ,(go b rr))]
   [`(letrec ,xs ,pss ,bs ,b)
    (define-values (ns rr) (bind xs rho))
    (define pairs (map (lambda (ps body) (define-values (new rrr) (bind ps rr)) (list new (go body rrr))) pss bs))
    `(letrec ,ns ,(map car pairs) ,(map cadr pairs) ,(go b rr))]
   [(? pair?) (map (lambda (x) (go x rho)) t)] [_ t]))
 (go target '()))
