#lang racket
(require json "chapter01.rkt")
;; Outputs measured data only. No timing ratio is an acceptance threshold.
(define batch 1000)
(define repeats 5)
(define seed 20261106)
(define (measure f n)
  (f n) ; warm-up, outside timed region
  (define samples
    (for/list ([i (in-range repeats)])
      (collect-garbage)
      (let ([start (current-inexact-monotonic-milliseconds)])
        (for ([j (in-range batch)]) (unless (f n) (error 'benchmark "known prime rejected")))
        (/ (* 1000 (- (current-inexact-monotonic-milliseconds) start)) batch))))
  (list-ref (sort samples <) (quotient repeats 2)))
(parameterize ([current-pseudo-random-generator (make-pseudo-random-generator)])
  (random-seed seed)
  (write-json
   (hash 'runtime (version) 'unit "microseconds per call; median of five 1000-call batches"
         'batch batch 'repeats repeats 'seed seed 'fermat_rounds 20
         'primes (for*/list ([lower '(1000 10000 100000 1000000)] [n (search-for-primes lower)])
                   (hash 'lower lower 'n n 'trial_us (measure prime? n)
                         'odd_us (measure (lambda (x) (prime? x next-odd)) n)
                         'fermat_us (measure fermat-prime? n))))))
(newline)
