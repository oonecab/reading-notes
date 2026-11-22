#lang racket
(require rackunit rackunit/text-ui racket/stream "chapter04.rkt")
(define (run e [m 'strict]) (actual e (fresh-environment) m))
(define (answers goal var db)
  (for/list ([f (query goal db)]) (instantiate var f)))
(define db '((edge a b) (edge b c) (edge a d)
             (rule (path ?s ?t) (edge ?s ?t))
             (rule (path ?s ?t) (and (edge ?s ?m) (path ?m ?t)))))
(define tests
  (test-suite "SICP chapter 4"
    (test-case "separate syntax and lexical application"
      (check-equal? (run '(let ((x 7)) (let ((f (lambda (n) (+ n x)))) (let ((x 100)) (f 3))))) 10))
    (test-case "hygienic expansion and short circuit"
      (check-equal? (run '(let ((n 0)) (or (begin (set! n (+ n 1)) n) (/ 1 0)))) 1)
      (check-equal? (run '(cond ((quote (b 2)) => cadr))) 2)
      (check-equal? (run '(let* ((x 3) (y (+ x 2))) (* x y))) 15)
      (check-equal? (run '(let loop ((n 4) (a 1)) (if (= n 0) a (loop (- n 1) (* n a))))) 24))
    (test-case "mixed parameter strategies"
      (for ([strategy '(lazy lazy-memo)] [want '(2 1)])
        (check-equal? (run `(begin (define n 0) (define (id x) (set! n (+ 1 n)) x)
                                  (define (twice (x ,strategy)) (+ x x))
                                  (twice (id 10)) n) 'mixed) want)))
    (test-case "scoped rules and resumable proof search"
      (check-equal? (sort (scoped-answers '(path a ?to) '?to db) symbol<?) '(b c d))
      (check-equal? (scoped-answers '(and (edge a ?x) (not (edge ?x c))) '?x db) '(d)))
    (test-case "primitive boundary, arity, lookup"
      (check-exn exn:fail? (lambda () (run '(eval (quote (+ 1 2))))))
      (check-exn exn:fail? (lambda () (run '((lambda (x) x) 1 2))))
      (check-exn exn:fail? (lambda () (run '(1 2)))))
    (test-case "operand order retains argument positions"
      (for ([traverse (list operands-left operands-right)] [seen '((c b a) (a b c))])
        (define visits '())
        (check-equal? (traverse '(a b c) (lambda (x) (set! visits (cons x visits)) x)) '(a b c))
        (check-equal? visits seen)))
    (test-case "mutual recursion in shared cells"
      (check-true (run '(letrec ((ev (lambda (n) (if (= n 0) #t (od (- n 1)))))
                                 (od (lambda (n) (if (= n 0) #f (ev (- n 1)))))) (od 7))))
      (check-exn #rx"unassigned" (lambda () (run '(letrec ((u v) (v 3)) u)))))
    (test-case "scan definitions before first use"
      (check-exn #rx"unassigned" (lambda () (run `(begin ,@(scan-out-defines '((define b a) (define a 5) b)))))))
    (test-case "compiled and direct agreement"
      (define e '(begin (define (fact n) (if (= n 0) 1 (* n (fact (- n 1))))) (fact 8)))
      (check-equal? (run e) 40320)
      (check-equal? ((analyze-expression e) (fresh-environment)) 40320)
      (check-equal? ((analyze-expression '(let ((a 3)) (set! a (+ a a)) a)) (fresh-environment)) 6))
    (test-case "lazy unused argument"
      (check-equal? (run '((lambda (x y) x) 7 (/ 1 0)) 'lazy) 7)
      (check-exn exn:fail? (lambda () (run '((lambda (x y) x) 7 (/ 1 0))))))
    (test-case "memoized forcing once"
      (check-equal? (run '(begin (define n 0) (define (id x) (set! n (+ 1 n)) x)
                                 (define (square x) (* x x)) (square (id 10)) n) 'lazy) 1))
    (test-case "operator forcing and finite demand on infinite data"
      (check-equal? (run '(((lambda (f) f) (lambda (x) (+ x 1))) 5) 'lazy) 6)
      (check-equal? (run '(begin (define (pair x y) (lambda (s) (s x y)))
                                 (define (ones) (pair 1 (ones)))
                                 (((ones) (lambda (a b) b)) (lambda (a b) a))) 'lazy) 1))
    (test-case "amb alternatives, failure and ordering"
      (check-equal? (amb-values '(let ((a (amb 1 2)) (b (amb 3 4))) (list a b))) '((1 3) (1 4) (2 3) (2 4)))
      (check-equal? (amb-values '(amb)) '())
      (check-equal? (amb-values '(if-fail (amb) 8)) '(8)))
    (test-case "backtracking restores or retains writes"
      (for ([op '(set! permanent-set!)] [want '((1 1) (1 2))])
        (check-equal? (amb-values `(begin (define n 0) (let ((x (amb 1 2))) (,op n (+ n 1)) n))) want)))
    (test-case "apartment constraints and order"
      (define-values (all candidates checks) (floors))
      (define-values (other _ more) (floors #:cheap-first #f))
      (define-values (relaxed _c _k) (floors #:neighbor #f))
      (check-equal? all '((3 2 4 5 1))) (check-equal? candidates 3125)
      (check-equal? all other) (check-not-equal? checks more) (check-equal? (length relaxed) 5))
    (test-case "bounded triples and stateful grammar"
      (check-equal? (bounded-triples 1 5) '((3 4 5)))
      (check-equal? (length (parse-words '(the professor lectures to the student in the class with the cat))) 5)
      (check-equal? (length (parse-words '(the small cat sleeps))) 1)
      (check-equal? (length (generate-words 3 3)) 3))
    (test-case "liars, yachts and queens"
      (check-equal? (rank-puzzle) '((3 5 2 1 4)))
      (check-equal? (length (yachts #f)) 2) (check-equal? (cadar (yachts #t)) 1)
      (check-equal? (length (queen-boards 4)) 2) (check-equal? (length (queen-boards 8)) 92))
    (test-case "guard failure resumes next finite alternative"
      (check-equal? (amb-values '(let ((n (amb 2 3 4))) (require (> n 2)) n) #:limit 1) '(3)))
    (test-case "recursive query freshens variables"
      (check-equal? (sort (answers '(path a ?to) '?to db) symbol<?) '(b c d)))
    (test-case "unification occurs check and dotted patterns"
      (check-false (unify '?x '(a . ?x) (hash)))
      (check-equal? (instantiate '(?x ?tail) (unify '(?x . ?tail) '(a b c) (hash))) '(a (b c))))
    (test-case "negative filter tests existence in current frame"
      (check-equal? (answers '(and (edge a ?to) (not (edge ?to c))) '?to db) '(d))
      (check-equal? (answers '(edge nowhere ?x) '?x db) '()))
    (test-case "safe host predicates and unbound guard"
      (check-equal? (answers '(and (cost ?n) (lisp-value > ?n 4)) '?n '((cost 3) (cost 7))) '(7))
      (check-exn #rx"unbound" (lambda () (stream->list (query '(lisp-value > ?x 0) db)))))
    (test-case "join and deferred filters"
      (check-equal? (join-frames (hash '?x 3) (hash '?y '?x)) (hash '?x 3 '?y 3))
      (check-false (join-frames (hash '?x 3) (hash '?x 4)))
      (check-equal? (for/list ([f (scheduled-query '((lisp-value > ?n 4) (cost ?n)) '((cost 3) (cost 7)))])
                      (instantiate '?n f)) '(7))
      (check-equal? (for/list ([f (scheduled-query '((not (edge ?x c)) (edge a ?x)) db)]) (instantiate '?x f)) '(d))
      (check-exn #rx"suspended" (lambda () (stream->list (scheduled-query '((lisp-value < ?x 3)) db)))))
    (test-case "reified quotation and bounded display"
      (define e (fresh-environment))
      (actual '(define (lazy-cons a b) (cons 'guest-pair (lambda (m) (m a b)))) e 'lazy)
      (check-equal? (lazy-preview (reify-quoted-pairs '(a b)) e 3) '(a b))
      (check-equal? (lazy-preview '(lazy-cons 1 (/ 1 0)) e 1) '(1 . …)))
    (test-case "unique counts solutions, not projected values"
      (check-equal? (answers '(unique (edge b ?x)) '?x db) '(c))
      (check-equal? (answers '(unique (edge a ?x)) '?x db) '()))))
(exit (if (zero? (run-tests tests)) 0 1))
