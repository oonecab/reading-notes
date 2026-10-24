#lang racket
(require "chapter09_syntax.rkt" "chapter09_runtime.rkt" "chapter09_types.rkt" "chapter09_compile.rkt")
(provide run run/trace check check/compiled class-layout method-slots
         (all-from-out "chapter09_syntax.rkt") (struct-out execution) (struct-out checked)
         mangle-program translate subtype?)
(define (validate-options! options)
  (unless (hash? options) (oo-error 'option options "options must be a hash"))
  (define enumerated (hash 'method-lookup '(linear hash) 'object-class '(name record)
                           'initialization '(textbook new-only) 'casts '(runtime related)))
  (define booleans '(typed? overload? mangle? stable? lexical? direct-super? named-slots?
                            multiple? host-fields-only? static-self? field-initializers?))
  (for ([(k v) (in-hash options)])
    (unless (cond [(eq? k 'fuel) (exact-positive-integer? v)]
                  [(hash-has-key? enumerated k) (member v (hash-ref enumerated k))]
                  [(memq k booleans) (boolean? v)] [else #f])
      (oo-error 'option k "invalid option ~a: ~s" k v))))
(define (has-initializer-extension? tree)
  (cond [(fdecl? tree) (and (fdecl-init tree) #t)]
        [(pair? tree) (or (has-initializer-extension? (car tree)) (has-initializer-extension? (cdr tree)))]
        [(struct? tree) (for/or ([v (in-vector (struct->vector tree))] [i (in-naturals)] #:when (positive? i)) (has-initializer-extension? v))]
        [else #f]))
(define (check/compiled source #:options [options (hash)])
  (validate-options! options)
  (check-program (parse source #:typed? #t) (hash-set options 'typed? #t)))
(define (check source #:options [options (hash)]) (checked-type (check/compiled source #:options options)))
(define (run/trace source #:typed? [typed? #f] #:check? [check? #t] #:options [options (hash)])
  (validate-options! options)
  (define parsed (parse source #:typed? typed?))
  (when (and (hash-ref options 'lexical? #f) (has-initializer-extension? parsed))
    (oo-error 'compile parsed "nameless mode covers CLASSES/TYPED-OO without static/field initializer extensions"))
  (define opts (hash-set options 'typed? (pgm-typed? parsed)))
  (define checked-program (if (and (pgm-typed? parsed) check?) (checked-program* parsed opts) parsed))
  (define prepared (if (hash-ref opts 'mangle? #f) (mangle-program checked-program) checked-program))
  (define runtime-options (if (hash-ref opts 'mangle? #f) (hash-set opts 'overload? #f) opts))
  (execute prepared runtime-options
           #:prepare (lambda (body names classes host)
                       (translate body names classes host #:lexical? (hash-ref opts 'lexical? #f)
                                  #:direct-super? (hash-ref opts 'direct-super? #f) #:named-slots? (hash-ref opts 'named-slots? #f)))))
(define (checked-program* p opts) (checked-program (check-program p opts)))
(define (run source #:typed? [typed? #f] #:check? [check? #t] #:options [options (hash)])
  (execution-value (run/trace source #:typed? typed? #:check? check? #:options options)))
(define (class-layout execution name)
  (define c (lookup-class (execution-classes execution) name))
  (for/list ([f (rclass-fields c)] [index (in-naturals)]) (list index (rclass-name (rfield-owner f)) (rfield-name f))))
(define (method-slots execution name)
  (for/list ([m (in-vector (rclass-slots (lookup-class (execution-classes execution) name)))] [i (in-naturals)])
    (list i (mdecl-name (rmethod-decl m)) (rclass-name (rmethod-host m)))))
(module+ main
  (displayln (run "class counter extends object field n method initialize(x)set n=x method bump(d)begin set n=+(n,d);n end let c=new counter(3) in send c bump(2)")))
