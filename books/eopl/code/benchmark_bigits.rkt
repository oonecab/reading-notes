#lang racket/base
(require "chapter02.rkt" racket/list json)
;; Reproducible measurement, not a speed guarantee. Each case warms once,
;; then collects garbage before each of three separately timed executions.
(define results
  (for*/list ([n '(6 8 10)] [base '(2 10 16 256)])
    (define a (make-bigits base))
    (define input ((number-api-encode a) n))
    (define expected (for/product ([k (in-range 1 (add1 n))]) k))
    (define (run)
      (define out (nat-factorial a input))
      (unless (= ((number-api-decode a) out) expected) (error 'benchmark "incorrect factorial"))
      out)
    (run)
    (define times
      (for/list ([i (in-range 3)])
        (collect-garbage)
        (define start (current-inexact-monotonic-milliseconds))
        (run)
        (- (current-inexact-monotonic-milliseconds) start)))
    (hasheq 'n n 'base base 'factorial expected 'digits ((number-api-encode a) expected)
            'samples_ms times 'median_ms (list-ref (sort times <) 1))))
(write-json (hasheq 'racket (version) 'system (symbol->string (system-type))
                    'method "one warmup; three samples; GC before timer; monotonic milliseconds"
                    'results results))
(newline)
