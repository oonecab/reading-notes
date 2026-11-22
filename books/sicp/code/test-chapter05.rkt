#lang racket
(require rackunit rackunit/text-ui "chapter05.rkt")
(define suite
  (test-suite "chapter 5"
    (test-case "tree leaves and empty subtrees"
      (for* ([controller (list tree-counter tree-counter-acc)] [input '((1 (2 . 3) ()) ())] [expected (list (if (null? input) 0 3))])
        (check-equal? (answer (execute controller primitives (hash 'tree input))) expected)))
    (test-case "append copies left and shares right"
      (define right (list 4 5))
      (define result (answer (execute append-controller primitives (hash 'x '(1 2) 'y right))))
      (check-equal? result '(1 2 4 5)) (check-eq? (cddr result) right))
    (test-case "destructive append retains head"
      (define head (mcons 1 (mcons 2 '()))) (define tail (mcons 3 '()))
      (check-eq? (answer (execute splice-controller primitives (hash 'x head 'y tail))) head)
      (check-eq? (mcdr (mcdr head)) tail))
    (test-case "Newton datapath"
      (define guess (hash-ref (execution-registers (execute sqrt-controller primitives (hash 'x 4))) 'guess))
      (check-true (< (abs (- (* guess guess) 4)) .001)))
    (test-case "break before instruction, then resume"
      (define debugger (debug-run gcd-controller primitives (hash 'a 206 'b 40) '((loop 4))))
      (define stop (debugger)) (check-equal? (second stop) '(assign a (reg b)))
      (check-equal? (hash-ref (third stop) 'a) 206)
      (check-equal? (hash-ref (third (debugger)) 'a) 40))
    (test-case "both directions across retained code images"
      (check-equal? (session-run '((define (inc n) (+ n 1))
                        (compile-and-run '(define (twice n) (inc (inc n))))
                        (twice 5) (compile-and-run '(+ 8 (twice 2))))) '(ok ok 7 12)))
    (test-case "read-compile-run with persistent environment"
      (check-equal? (session-run '((define (f x) (* x x)) (f 5)) #:compile-all? #t) '(ok 25)))
    (test-case "explicit lazy forcing and memoization"
      (check-equal? (lazy-result '((lambda (x y) x) 7 (/ 1 0))) 7)
      (check-equal? (lazy-result '(begin (define n 0) (define (tick) (begin (set! n (+ n 1)) n))
                                    ((lambda (x) (+ x x)) (tick)) n)) 1))
    (test-case "cond loop and let transformation"
      (check-equal? (extended-ec '(let ((x 2)) (cond ((= x 1) 7) ((+ x 4)) (else missing)))) 6)
      (check-equal? (extended-ec '(cond (#f 0) (else 8 9))) 9))
    (test-case "non-tail sequence grows in both versions"
      (for ([iter? '(#f #t)])
        (check-true (< (execution-depth (non-tail (factorial-expression 3 iter?)))
                       (execution-depth (non-tail (factorial-expression 6 iter?)))))))
    (test-case "stack discipline and last register write"
      (define ctl '((save y) (save x) (restore y)))
      (define initial (hash 'x 2 'y 9))
      (check-equal? (hash-ref (execution-registers (execute ctl primitives initial)) 'y) 2)
      (check-exn #rx"mismatch" (lambda () (execute ctl primitives initial #:stack-mode 'checked)))
      (check-equal? (hash-ref (execution-registers (execute ctl primitives initial #:stack-mode 'separate)) 'y) 9)
      (define writes '())
      (execute '((assign x (const 2))) primitives initial #:on-write (lambda args (set! writes (cons args writes))))
      (check-equal? writes '((x 2 2))))
    (test-case "open coding respects nesting and shadowing"
      (parameterize ([open-code? #t])
        (check-equal? (answer (run-expression '(+ 2 (* 3 4) 5) #:compiled? #t)) 19)
        (check-equal? (answer (run-expression '((lambda (+) (+ 7 2)) -) #:compiled? #t)) 5)))
    (test-case "scanned internal definitions share lexical slots"
      (parameterize ([scan-internals? #t])
        (check-equal? (answer (run-expression '((lambda (x) (define (f) (g)) (define (g) x) (f)) 9) #:compiled? #t)) 9)
        (check-exn #rx"unassigned" (lambda () (run-expression '((lambda () (define a b) (define b 4) a)) #:compiled? #t)))))
    (test-case "operand order changes effects but keeps argument positions"
      (define e '(begin (define n 0) (define (inc) (begin (set! n (+ n 1)) n)) (- (inc) (inc))))
      (for ([left? '(#t #f)] [expected '(-1 1)])
        (parameterize ([left-first? left?]) (check-equal? (answer (run-expression e #:compiled? #t)) expected))))
    (test-case "unconditional preservation emits extra saves"
      (define (code) (statements (compile '(+ 1 2) 'val 'return)))
      (check-true (> (length (parameterize ([always-save? #t]) (code))) (length (code)))))
    (test-case "mark-sweep keeps stable addresses and reuses unreachable slots"
      (define h (make-free-heap 3)) (define dead (alloc-free h 1 2)) (define live (alloc-free h 3 4))
      (define root (alloc-free h live live)) (mark-and-sweep! h (list root))
      (check-equal? (free-heap-unused h) (list (ptr-index dead)))
      (check-equal? (alloc-free h 5 6) dead) (check-equal? (vector-ref (free-heap-cells h) (ptr-index root)) (vector live live)))
    (test-case "surface assignment syntax changes only the front end"
      (define (normalize instruction)
        (match instruction [`(,destination <- ,rhs ...) `(assign ,destination ,@rhs)]
              [_ instruction]))
      (check-equal? (answer (execute (map normalize '((a <- (const 6)) (val <- (op *) (reg a) (const 7))))
                                     primitives (hash))) 42))
    (test-case "instruction tracing counts, reset, and cancellation"
      (define breaks (box '((loop 4))))
      (define events '()) (define count 0) (define tracing? #t)
      (define (read-and-reset!) (begin0 count (set! count 0)))
      (define (log event)
        (when (eq? (car event) 'instruction)
          (set! count (add1 count))
          (when tracing? (set! events (cons event events)))))
      (define next (debug-run gcd-controller primitives (hash 'a 206 'b 40) breaks #:logger log))
      (next) (check-equal? (read-and-reset!) 4) (check-equal? (read-and-reset!) 0)
      (check-equal? (second (last events)) '(loop))
      (set-box! breaks '()) (set! tracing? #f)
      (define final (next)) (check-equal? (length events) 4)
      (check-equal? (+ 4 (read-and-reset!)) (execution-steps final)))
    (test-case "driver recovers after an unbound name and primitive errors"
      (define env (initial-env))
      (define (turn expr)
        (with-handlers ([exn:fail? (lambda (_) 'error)]) (answer (run-expression expr #:env env))))
      (check-equal? (map turn '((define x 9) unknown (/ 1 0) (car 1) (+ x 2))) '(ok error error error 11)))
    (test-case "fast simple operator path"
      (define code (insert-before ec-controller '(save continue)
                     '((test (op named-call?) (reg exp)) (branch (label simple-call)))))
      (define shared (gensym 'args))
      (set! code (insert-before code '(assign argl (op empty-arglist)) (list shared)))
      (define ops (hash-set machine-ops 'named-call? (lambda (e) (and (pair? e) (symbol? (car e))))))
      (define result (execute (append '((assign continue (label done))) code
        `(simple-call (save continue) (assign unev (op operands) (reg exp)) (assign val (op operator) (reg exp))
           (assign val (op lookup-variable-value) (reg val) (reg env)) (goto (label ,shared)) done))
        ops (hash 'exp '((lambda (f) (f 6 7)) *) 'env (initial-env))))
      (check-equal? (answer result) 42))
    (test-case "labels and jumps"
      (check-equal? (hash-ref (execution-registers (execute gcd-controller primitives (hash 'a 206 'b 40))) 'a) 2))
    (test-case "assembly errors"
      (check-exn exn:fail? (lambda () (assemble '(a a))))
      (check-exn exn:fail? (lambda () (assemble '((goto (label missing)))))))
    (test-case "bounded loop" (check-exn #rx"step limit" (lambda () (execute '(a (goto (label a))) primitives (hash) #:limit 10))))
    (test-case "stack underflow" (check-exn #rx"empty stack" (lambda () (execute '((restore x)) primitives (hash)))))
    (test-case "operation operands" (check-exn #rx"label operand" (lambda () (execute '((test (op =) (label end) (const 1)) end) primitives (hash)))))
    (test-case "independent power paths" (for* ([r '(#f #t)] [n '(0 1 4)]) (check-equal? (answer (execute (power-controller r) primitives (hash 'n n 'b 3))) (expt 3 n))))
    (test-case "factorial pushes" (for ([n '(1 2 4 6)]) (define m (execute factorial-controller primitives (hash 'n n)))
      (check-equal? (answer m) (for/product ([i (in-range 1 (add1 n))]) i))
      (check-equal? (list (execution-pushes m) (execution-depth m)) (make-list 2 (* 2 (sub1 n))))))
    (test-case "unreachable cycle" (define h (make-heap 3)) (define p (allocate h 1 2)) (vector-set! (fields h p) 1 p)
      (define-values (new roots) (collect h '())) (check-equal? (heap-free new) 0))
    (test-case "sharing and cyclic objects" (define h (make-heap 4)) (allocate h 'garbage 0) (define p (allocate h 9 #f))
      (vector-set! (fields h p) 1 p) (define-values (new roots) (collect h (list p p 17)))
      (check-equal? roots (list (ptr 0) (ptr 0) 17)) (check-equal? (fields new (car roots)) (vector 9 (ptr 0))))
    (test-case "full heap" (check-exn #rx"full" (lambda () (allocate (make-heap 0) 1 2))))
    (test-case "lexical addresses" (check-equal? (find-variable 'b '((x) (a b))) '(1 1))
      (check-false (find-variable 'z '((x)))) (check-exn #rx"unassigned" (lambda () (lex-ref '(0 0) (extend-environment '(x) '(*unassigned*) '())))))
    (test-case "EC and compiler agree"
      (for* ([compiled? '(#f #t)] [expr (list (factorial-expression 6) (fib-expression 7) (factorial-expression 6 #t))]
             #:do [(define value (answer (run-expression expr #:compiled? compiled?)))])
        (check-equal? value (if (equal? expr (fib-expression 7)) 13 720))))
    (test-case "lexical scope survives returning"
      (for ([c '(#t #f)]) (check-equal? (answer (run-expression '(((lambda (x) (lambda (y) (+ x y))) 8) 9) #:compiled? c)) 17)))
    (test-case "lexical mutation" (for ([c '(#t #f)])
      (check-equal? (answer (run-expression '((lambda (x) (begin (set! x 7) x)) 2) #:compiled? c)) 7)))
    (test-case "tail stack independent of n"
      (check-equal? (execution-depth (run-expression (factorial-expression 4 #t))) (execution-depth (run-expression (factorial-expression 8 #t)))))
    (test-case "unbound and bad arity" (for ([c '(#t #f)])
      (check-exn #rx"unbound" (lambda () (run-expression 'missing #:compiled? c)))
      (check-exn #rx"arity" (lambda () (run-expression '((lambda (x) x)) #:compiled? c)))))))
(module+ main (exit (if (zero? (run-tests suite)) 0 1)))

;; Reproduce the stack tables and compiler listings independently of the page.
(module+ experiments
  (require json)
  (define (metrics run)
    (list (answer run) (execution-steps run) (execution-pushes run) (execution-depth run)))
  (define (bench n kind)
    (define iter? (eq? kind 'iter))
    (define fib? (eq? kind 'fib))
    (define exp (if fib? (fib-expression n) (factorial-expression n iter?)))
    (define env (initial-env))
    (run-expression (cadr exp) #:env env)
    (hasheq 'n n 'interpreted (metrics (run-expression exp))
            'isolated_call (metrics (run-expression (caddr exp) #:env env))
            'compiled (metrics (run-expression exp #:compiled? #t))
            'non_tail (metrics (non-tail exp))
            'dedicated (metrics (execute (cond [iter? iterative-factorial] [fib? textbook-fib]
                                               [else factorial-controller]) primitives (hash 'n n)))))
  (define standard (factorial-expression 5))
  (define alternative '(begin (define (f n) (if (= n 1) 1 (* n (f (- n 1))))) (f 5)))
  (define (listing expr)
    (for/list ([item (statements (compile expr 'val 'return))]) (format "~s" item)))
  (write-json
    (hasheq 'columns '("value" "executed_instructions" "pushes" "maximum_depth")
            'measurements (for/hasheq ([kind '(factorial iter fib)])
                            (values kind (for/list ([n (in-range 1 8)]) (bench n kind))))
            'exercise_5_33 (list (metrics (run-expression standard #:compiled? #t))
                                 (metrics (run-expression alternative #:compiled? #t)))
            'listings (hasheq 'recursive (listing standard) 'alternate (listing alternative)
                              'tail_iterative (listing (factorial-expression 5 #t)))))
  (newline))
