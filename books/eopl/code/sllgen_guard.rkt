#lang racket
;; Validate the complete character stream before the installed SLLGEN scanner.
;; Use the same lexical rules and grammar literals, including token boundaries.
(require racket/match)
(provide guard-sllgen)
(define (guard-sllgen parser lexical grammar)
  (define (literals x)
    (cond [(string? x) (list x)] [(list? x) (append-map literals x)] [else '()]))
  (define rules
    (append (map cadr lexical)
            (map list (remove-duplicates (literals grammar)))))
  (lambda (text)
    (unless (string? text) (raise-argument-error 'scanner "string?" text))
    (define size (string-length text))
    (define (sequence patterns start)
      (for/fold ([positions (list start)]) ([pattern patterns])
        (remove-duplicates (append-map (lambda (at) (ends pattern at)) positions))))
    (define (ends pattern at)
      (define (one? predicate)
        (if (and (< at size) (predicate (string-ref text at))) (list (add1 at)) '()))
      (match pattern
        [(? char? c) (one? (lambda (x) (char=? c x)))]
        [(? string? s)
         (define stop (+ at (string-length s)))
         (if (and (<= stop size) (string=? s (substring text at stop))) (list stop) '())]
        ['letter (one? char-alphabetic?)]
        ['digit (one? char-numeric?)]
        ['whitespace (one? char-whitespace?)]
        ['any (one? (lambda (_) #t))]
        [`(not ,(? char? c)) (one? (lambda (x) (not (char=? c x))))]
        [`(or . ,patterns) (append-map (lambda (p) (ends p at)) patterns)]
        [`(concat . ,patterns) (sequence patterns at)]
        [`(arbno ,p)
         (define seen (make-hasheqv))
         (let visit ([todo (list at)] [answer '()])
           (cond [(null? todo) answer]
                 [(hash-has-key? seen (car todo)) (visit (cdr todo) answer)]
                 [else
                  (define pos (car todo))
                  (hash-set! seen pos #t)
                  (visit (append (ends p pos) (cdr todo)) (cons pos answer))]))]
        [_ (error 'scanner "unsupported lexical rule: ~s" pattern)]))
    (let scan ([at 0])
      (when (< at size)
        (define stops (append-map (lambda (r) (sequence r at)) rules))
        (define stop (apply max at stops))
        (when (= stop at)
          (error 'scanner "unsupported character ~s at offset ~a" (string-ref text at) at))
        (scan stop)))
    (parser text)))
