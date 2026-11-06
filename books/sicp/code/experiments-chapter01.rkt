#lang racket
(require json "chapter01.rkt")
(define f (lambda (x) (/ (log 1000) (log x))))
(define-values (plain plain-trace) (fixed-point/trace f 2.0))
(define-values (damped damped-trace) (fixed-point/trace (average-damp f) 2.0))
(write-json
 (hash 'runtime (version)
       'plain plain-trace 'damped damped-trace
       'wallis (for/list ([n '(100 1000 10000)])
                 (hash 'n n 'value (wallis n) 'error (abs (- (wallis n) pi))))
       'roots (for*/list ([n '(2 3 4 5 8 9 16)] [r (in-range 0 5)])
                (with-handlers ([exn:fail? (lambda (e) (hash 'degree n 'damps r 'converged #f))])
                  (define result (bounded-improve ((repeated average-damp r)
                                                  (lambda (y) (/ 2.0 (expt y (sub1 n))))) 1.0 relative-close? 2000))
                  (hash 'degree n 'damps r 'converged (< (abs (- (expt result n) 2)) 1e-8))))))
(newline)
