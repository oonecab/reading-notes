#lang racket/base
;; EOPL 3e, chapter 1. Original companion implementations.
;; Proper finite, acyclic inputs are assumed unless an error is specified.
(provide (all-defined-out))

;; BEGIN basics
;; Listof(SchemeVal) -> Nat. Counts top-level elements.
(define (list-length xs)
  (if (null? xs) 0 (+ 1 (list-length (cdr xs)))))
;; Symbol * Listof(Symbol) -> Listof(Symbol)
(define (remove-first s xs)
  (cond [(null? xs) '()]
        [(eqv? s (car xs)) (cdr xs)]
        [else (cons (car xs) (remove-first s (cdr xs)))]))
;; Symbol * LcExp -> Bool; LcExp = symbol | (lambda (symbol) LcExp) | (LcExp LcExp)
(define (occurs-free? v e)
  (cond [(symbol? e) (eqv? v e)]
        [(eqv? (car e) 'lambda)
         (and (not (eqv? v (caadr e))) (occurs-free? v (caddr e)))]
        [else (or (occurs-free? v (car e)) (occurs-free? v (cadr e)))]))
;; Symbol * Symbol * Slist -> Slist
(define (subst new old xs)
  (define (in-sexp x)
    (if (symbol? x) (if (eqv? x old) new x) (subst new old x)))
  (if (null? xs) '() (cons (in-sexp (car xs)) (subst new old (cdr xs)))))
;; Listof(SchemeVal) * Nat -> Listof((Nat SchemeVal))
(define (number-elements-from xs n)
  (if (null? xs) '()
      (cons (list n (car xs)) (number-elements-from (cdr xs) (+ n 1)))))
(define (number-elements xs) (number-elements-from xs 0))
;; Vectorof(Number) -> Number
(define (vector-sum v)
  (define (partial n)
    (if (= n 0) (vector-ref v 0) (+ (partial (- n 1)) (vector-ref v n))))
  (if (= (vector-length v) 0) 0 (partial (- (vector-length v) 1))))
;; END basics

;; BEGIN ex-1-7
;; Listof(SchemeVal) * Nat -> SchemeVal, or an informative bounds error.
(define (nth-element xs n)
  (define (walk rest k)
    (cond [(null? rest)
           (error 'nth-element "~s does not have ~a elements." xs (+ n 1))]
          [(zero? k) (car rest)]
          [else (walk (cdr rest) (- k 1))]))
  (unless (exact-nonnegative-integer? n) (error 'nth-element "index must be a natural"))
  (walk xs n))
;; END ex-1-7

;; BEGIN ex-1-8
;; The deliberately changed procedure: suffix after the first occurrence.
(define (suffix-after-first s xs)
  (cond [(null? xs) '()]
        [(eqv? s (car xs)) (cdr xs)]
        [else (suffix-after-first s (cdr xs))]))
;; END ex-1-8

;; BEGIN ex-1-9
(define (remove-all s xs)
  (cond [(null? xs) '()]
        [(eqv? s (car xs)) (remove-all s (cdr xs))]
        [else (cons (car xs) (remove-all s (cdr xs)))]))
;; END ex-1-9

;; BEGIN ex-1-12
(define (subst-inline new old xs)
  (cond [(null? xs) '()]
        [(symbol? (car xs))
         (cons (if (eqv? (car xs) old) new (car xs))
               (subst-inline new old (cdr xs)))]
        [else (cons (subst-inline new old (car xs))
                    (subst-inline new old (cdr xs)))]))
;; END ex-1-12

;; BEGIN ex-1-13
(define (subst-map new old xs)
  (map (lambda (x) (if (symbol? x) (if (eqv? x old) new x)
                      (subst-map new old x))) xs))
;; END ex-1-13

;; BEGIN ex-1-15
;; Nat * SchemeVal -> Listof(SchemeVal)
(define (duple n x)
  (if (zero? n) '() (cons x (duple (- n 1) x))))
;; END ex-1-15

;; BEGIN ex-1-16
;; Listof((SchemeVal SchemeVal)) -> Listof((SchemeVal SchemeVal))
(define (invert pairs)
  (map (lambda (p) (list (cadr p) (car p))) pairs))
;; END ex-1-16

;; BEGIN ex-1-17
(define (down xs) (map list xs))
;; END ex-1-17

;; BEGIN ex-1-18
;; Symbol * Symbol * Slist -> Slist; simultaneous replacement.
(define (swapper s1 s2 xs)
  (map (lambda (x)
         (cond [(not (symbol? x)) (swapper s1 s2 x)]
               [(eqv? x s1) s2] [(eqv? x s2) s1] [else x])) xs))
;; END ex-1-18

;; BEGIN ex-1-19
;; Valid zero-based index; preserve every other element.
(define (list-set xs n x)
  (cond [(null? xs) (error 'list-set "index out of range")]
        [(zero? n) (cons x (cdr xs))]
        [else (cons (car xs) (list-set (cdr xs) (- n 1) x))]))
;; END ex-1-19

;; BEGIN ex-1-20
(define (count-occurrences s xs)
  (cond [(null? xs) 0]
        [else (+ (if (symbol? (car xs)) (if (eqv? s (car xs)) 1 0)
                     (count-occurrences s (car xs)))
                 (count-occurrences s (cdr xs)))]))
;; END ex-1-20

;; BEGIN ex-1-21
(define (product xs ys)
  (if (null? xs) '()
      (append (map (lambda (y) (list (car xs) y)) ys)
              (product (cdr xs) ys))))
;; END ex-1-21

;; BEGIN ex-1-22
(define (filter-in pred xs)
  (cond [(null? xs) '()]
        [(pred (car xs)) (cons (car xs) (filter-in pred (cdr xs)))]
        [else (filter-in pred (cdr xs))]))
;; END ex-1-22

;; BEGIN ex-1-23
(define (list-index pred xs)
  (define (walk ys n)
    (cond [(null? ys) #f] [(pred (car ys)) n]
          [else (walk (cdr ys) (+ n 1))]))
  (walk xs 0))
;; END ex-1-23

;; BEGIN ex-1-24
(define (every? pred xs)
  (or (null? xs) (and (pred (car xs)) (every? pred (cdr xs)))))
;; END ex-1-24

;; BEGIN ex-1-25
(define (exists? pred xs)
  (and (pair? xs) (or (pred (car xs)) (exists? pred (cdr xs)))))
;; END ex-1-25

;; BEGIN ex-1-26
(define (up xs)
  (if (null? xs) '()
      (append (if (list? (car xs)) (car xs) (list (car xs))) (up (cdr xs)))))
;; END ex-1-26

;; BEGIN ex-1-27
;; walk xs tail = all leaves of xs followed by tail; each pair visited once.
(define (flatten xs)
  (define (walk ys tail)
    (cond [(null? ys) tail]
          [(symbol? (car ys)) (cons (car ys) (walk (cdr ys) tail))]
          [else (walk (car ys) (walk (cdr ys) tail))]))
  (walk xs '()))
;; END ex-1-27

;; BEGIN ex-1-28
;; Inputs ascending; duplicates retained, first input wins ties.
(define (merge xs ys)
  (cond [(null? xs) ys] [(null? ys) xs]
        [(<= (car xs) (car ys)) (cons (car xs) (merge (cdr xs) ys))]
        [else (cons (car ys) (merge xs (cdr ys)))]))
;; END ex-1-28

;; BEGIN ex-1-30
;; A strict total order is required for the usual sortedness guarantee.
;; Insertion sort: insert the earlier element before a later equal element.
(define (sort/predicate pred xs)
  (define (insert x ys)
    (cond [(null? ys) (list x)]
          [(not (pred (car ys) x)) (cons x ys)]
          [else (cons (car ys) (insert x (cdr ys)))]))
  (if (null? xs) '() (insert (car xs) (sort/predicate pred (cdr xs)))))
;; END ex-1-30

;; BEGIN ex-1-29
(define (sort xs) (sort/predicate < xs))
;; END ex-1-29

;; BEGIN ex-1-31
;; Bintree = Int | (Symbol Bintree Bintree), definition 1.1.7.
(define (leaf n) n)
(define (interior-node key left right) (list key left right))
(define (leaf? t) (integer? t))
(define (lson t) (cadr t))
(define (rson t) (caddr t))
(define (contents-of t) (if (leaf? t) t (car t)))
;; END ex-1-31

;; BEGIN ex-1-32
(define (double-tree t)
  (if (leaf? t) (leaf (* 2 (contents-of t)))
      (interior-node (contents-of t) (double-tree (lson t)) (double-tree (rson t)))))
;; END ex-1-32

;; BEGIN ex-1-33
(define (mark-leaves-with-red-depth t)
  ;; depth counts red strict ancestors of the current node.
  (define (walk t depth)
    (if (leaf? t) (leaf depth)
        (let ([next (+ depth (if (eqv? (contents-of t) 'red) 1 0))])
          (interior-node (contents-of t) (walk (lson t) next) (walk (rson t) next)))))
  (walk t 0))
;; END ex-1-33

;; BEGIN ex-1-34
;; BST = () | (Int BST BST); root equality is tested before descending.
(define (path n bst)
  (cond [(null? bst) (error 'path "value absent: ~a" n)]
        [(= n (car bst)) '()]
        [(< n (car bst)) (cons 'left (path n (cadr bst)))]
        [else (cons 'right (path n (caddr bst)))]))
;; END ex-1-34

;; BEGIN ex-1-35
(define (number-leaves t)
  ;; Returns TWO values: rebuilt tree and the next unused index.
  (define (walk t next)
    (if (leaf? t) (values (leaf next) (+ next 1))
        (let*-values ([(left after-left) (walk (lson t) next)]
                      [(right after-right) (walk (rson t) after-left)])
          (values (interior-node (contents-of t) left right) after-right))))
  (let-values ([(result next) (walk t 0)]) result))
;; END ex-1-35

;; BEGIN ex-1-36
(define (g first numbered-tail)
  (cons first (map (lambda (p) (list (+ 1 (car p)) (cadr p))) numbered-tail)))
(define (number-elements/g xs)
  (if (null? xs) '() (g (list 0 (car xs)) (number-elements/g (cdr xs)))))
;; END ex-1-36

(module+ main
  (write (number-elements '(a b c))) (newline)
  (write (subst 'x 'a '((a b) (c (a))))) (newline)
  (write (mark-leaves-with-red-depth '(red (bar 26 12) (red 11 (quux 117 14))))) (newline)
  (write (number-leaves '(foo (bar 26 12) (baz 11 (quux 117 14))))) (newline))
