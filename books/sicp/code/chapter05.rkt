#lang racket
;; SICP, second edition, chapter 5. The EC controller and instruction-sequence
;; combinators below are adapted from the textbook. The VM, heap, frame model
;; and bounded driver are local implementations.
(provide (all-defined-out))
(struct image (code labels) #:transparent)
(struct location (program pc) #:transparent)
(struct execution (registers steps pushes depth) #:transparent)

(define (assemble controller)
  (define labels (make-hasheq))
  (define code
    (for/fold ([rev '()]) ([item controller])
      (cond [(symbol? item)
             (when (hash-has-key? labels item) (error 'assemble "duplicate label ~a" item))
             (hash-set! labels item (length rev)) rev]
            [else (cons item rev)])))
  (for* ([instruction code] [arg (cdr instruction)])
    (match arg [(list 'label name) (hash-ref labels name)] [_ (void)]))
  (image (list->vector (reverse code)) labels))

(define (execute controller ops initial #:limit [limit 1000000] #:observe [observe void]
                 #:stack-mode [stack-mode 'shared] #:on-write [on-write void])
  (define program (if (image? controller) controller (assemble controller)))
  (define code (image-code program))
  (define regs (hash-copy initial))
  (define stack '())
  (define per-register (make-hasheq))
  (define (write! r v)
    (on-write r (hash-ref regs r '*unassigned*) v)
    (hash-set! regs r v))
  (define height 0)
  (define peak 0)
  (define pushes 0)
  (define flag #f)
  (define (operand arg)
    (match arg [`(const ,x) x] [`(reg ,r) (hash-ref regs r)]
          [`(label ,name) (location program (hash-ref (image-labels program) name))]))
  (define (value args)
    (match args
      [(list (list 'op name) operands ...)
       (for ([arg operands]) (when (eq? (car arg) 'label) (error 'execute "label operand")))
       (apply (hash-ref ops name) (map operand operands))]
      [(list arg) (operand arg)]))
  (let loop ([pc 0] [steps 0])
    (cond [(= pc (vector-length code)) (execution regs steps pushes peak)]
          [(>= steps limit) (error 'execute "step limit ~a" limit)]
          [else
           (define inst (vector-ref code pc))
           (observe pc inst regs stack)
           (define next (add1 pc))
           (match inst
             [`(assign ,r ,args ...) (write! r (value args))]
             [`(perform ,args ...) (value args)]
             [`(test ,args ...) (set! flag (value args))]
             [`(branch ,addr) (when flag (set! next (operand addr)))]
             [`(goto ,addr) (set! next (operand addr))]
             [`(save ,r) (case stack-mode
                            [(separate) (hash-update! per-register r (lambda (s) (cons (hash-ref regs r) s)) '())]
                            [(checked) (set! stack (cons (cons r (hash-ref regs r)) stack))]
                            [else (set! stack (cons (hash-ref regs r) stack))])
                          (set! height (add1 height)) (set! peak (max peak height))
                          (set! pushes (add1 pushes))]
             [`(restore ,r) (define slots (if (eq? stack-mode 'separate) (hash-ref per-register r '()) stack))
                             (when (null? slots) (error 'restore "empty stack"))
                             (when (and (eq? stack-mode 'checked) (not (eq? r (caar slots))))
                               (error 'restore "register mismatch"))
                             (write! r (if (eq? stack-mode 'checked) (cdar slots) (car slots)))
                             (if (eq? stack-mode 'separate) (hash-set! per-register r (cdr slots))
                                 (set! stack (cdr slots)))
                             (set! height (sub1 height))])
           (when (location? next)
             (set! program (location-program next))
             (set! code (image-code program))
             (set! next (location-pc next)))
           (loop next (add1 steps))])))

;; A pointer is distinct from an immediate integer. Only root-reachable cells
;; enter to-space. Install forwarding addresses before scanning either field.
(struct ptr (index) #:transparent)
(struct heap (cells free) #:mutable #:transparent)
(define (make-heap n) (heap (make-vector n #f) 0))
(define (allocate h a d)
  (define i (heap-free h))
  (when (= i (vector-length (heap-cells h))) (error 'allocate "full heap"))
  (vector-set! (heap-cells h) i (vector a d))
  (set-heap-free! h (add1 i)) (ptr i))
(define (fields h p)
  (unless (< -1 (ptr-index p) (heap-free h)) (error 'fields "invalid pointer"))
  (vector-ref (heap-cells h) (ptr-index p)))
(define (collect old roots)
  (define new (make-heap (vector-length (heap-cells old))))
  (define forwarding (make-hash))
  (define (copy x)
    (if (ptr? x)
        (hash-ref! forwarding x (lambda () (apply allocate new (vector->list (fields old x)))))
        x))
  (define fresh-roots (map copy roots))
  (let scan ([i 0])
    (when (< i (heap-free new))
      (define cell (fields new (ptr i)))
      (for ([j 2]) (vector-set! cell j (copy (vector-ref cell j))))
      (scan (add1 i))))
  (values new fresh-roots))

(struct frame (names slots extra) #:transparent)
(define (extend-environment names vals env)
  (unless (= (length names) (length vals)) (error 'extend "arity mismatch"))
  (cons (frame names (list->vector vals) (make-hasheq)) env))
(define (find-variable name ctx)
  (for/or ([names ctx] [i (in-naturals)])
    (define j (index-of names name))
    (and j (list i j))))
(define (lex-ref addr env)
  (define v (vector-ref (frame-slots (list-ref env (car addr))) (cadr addr)))
  (when (eq? v '*unassigned*) (error 'lookup "unassigned"))
  v)
(define (lex-set! addr v env)
  (vector-set! (frame-slots (list-ref env (car addr))) (cadr addr) v))
(define (binding name env found)
  (cond [(null? env) (error 'lookup "unbound ~a" name)]
        [else (define f (car env)) (define j (index-of (frame-names f) name))
              (cond [j (found f j)] [(hash-has-key? (frame-extra f) name) (found f #f)]
                    [else (binding name (cdr env) found)])]))
(define (lookup-variable-value name env)
  (binding name env (lambda (f j) (if j (lex-ref (list 0 j) (list f)) (hash-ref (frame-extra f) name)))))
(define (set-variable-value! name v env)
  (binding name env (lambda (f j) (if j (vector-set! (frame-slots f) j v) (hash-set! (frame-extra f) name v)))))
(define (define-variable! name v env)
  (define f (car env)) (define j (index-of (frame-names f) name))
  (if j (vector-set! (frame-slots f) j v) (hash-set! (frame-extra f) name v)))
(define (tagged-list? x tag) (and (pair? x) (eq? (car x) tag)))
(define (self-evaluating? x) (or (number? x) (string? x) (boolean? x)))
(define variable? symbol?)
(define (quoted? x) (tagged-list? x 'quote))
(define (definition? x) (tagged-list? x 'define))
(define (assignment? x) (tagged-list? x 'set!))
(define (if? x) (tagged-list? x 'if))
(define (cond? x) (tagged-list? x 'cond))
(define (begin? x) (tagged-list? x 'begin))
(define (lambda? x) (tagged-list? x 'lambda))
(define application? pair?)
(define text-of-quotation cadr)
(define assignment-variable cadr)
(define assignment-value caddr)
(define (definition-variable x) (if (symbol? (cadr x)) (cadr x) (caadr x)))
(define (definition-value x) (if (symbol? (cadr x)) (caddr x) `(lambda ,(cdadr x) ,@(cddr x))))
(define if-predicate cadr)
(define if-consequent caddr)
(define (if-alternative x) (if (= (length x) 4) (cadddr x) #f))
(define lambda-parameters cadr)
(define lambda-body cddr)
(define begin-actions cdr)
(define operator car)
(define operands cdr)
(define first-exp car)
(define rest-exps cdr)
(define (last-exp? x) (null? (cdr x)))
(define (cond->if x)
  (let expand ([clauses (cdr x)])
    (match clauses ['() #f] [(cons (list 'else body ...) '()) `(begin ,@body)]
           [(cons (list test body ...) more) `(if ,test (begin ,@body) ,(expand more))])))
(struct closure (parameters body environment))
(define primitives (hash '+ + '- - '* * '/ / '= = '< < '> > 'cons cons 'car car 'cdr cdr
                         'list list 'pair? pair? 'null? null? 'eq? eq? 'number? number?
                         'symbol? symbol? 'remainder remainder 'not not 'abs abs 'mcdr mcdr 'set-mcdr! set-mcdr!))
(define (initial-env)
  (define env (extend-environment '() '() '()))
  (for ([(name op) (in-hash primitives)]) (define-variable! name op env)) env)

(define open-code? (make-parameter #f))
(define scan-internals? (make-parameter #f))
(define (compile-open exp target linkage)
  (define op (car exp))
  (define operands (cdr exp))
  (define left (if (= (length operands) 2) (car operands) (cons op (drop-right operands 1))))
  (preserving '(env continue)
    (compile left 'arg1 'next)
    (preserving '(arg1 continue)
      (compile (last operands) 'arg2 'next)
      (end-with-linkage linkage
        (make-instruction-sequence '(arg1 arg2) (list target)
          (list `(assign ,target (op ,op) (reg arg1) (reg arg2))))))))
(define (scan-body body)
  (define defs (filter definition? body))
  (if (null? defs) body
      (list `((lambda ,(map definition-variable defs)
                ,@(for/list ([d defs]) `(set! ,(definition-variable d) ,(definition-value d)))
                ,@(filter-not definition? body))
              ,@(map (lambda (_) '(quote *unassigned*)) defs)))))
(define lexical-context (make-parameter (quote ())))

(define (compile exp target linkage)
  (cond ((and (open-code?) (pair? exp) (memq (car exp) '(+ * = -))
               (not (find-variable (car exp) (lexical-context)))
               (or (= (length exp) 3) (and (memq (car exp) '(+ *)) (> (length exp) 3))))
          (compile-open exp target linkage))
         ((self-evaluating? exp)
         (compile-self-evaluating
          exp target linkage))
        ((quoted? exp)
         (compile-quoted exp target linkage))
        ((variable? exp)
         (compile-variable
          exp target linkage))
        ((assignment? exp)
         (compile-assignment
          exp target linkage))
        ((definition? exp)
         (compile-definition
          exp target linkage))
        ((if? exp)
         (compile-if exp target linkage))
        ((lambda? exp)
         (compile-lambda exp target linkage))
        ((begin? exp)
         (compile-sequence
          (begin-actions exp) target linkage))
        ((cond? exp)
         (compile
          (cond->if exp) target linkage))
        ((application? exp)
         (compile-application
          exp target linkage))
        (else
         (error "Unknown expression type:
                 COMPILE"
                exp))))

(define (make-instruction-sequence
         needs modifies statements)
  (list needs modifies statements))

(define (empty-instruction-sequence)
  (make-instruction-sequence '() '() '()))

(define (compile-linkage linkage)
  (cond ((eq? linkage 'return)
         (make-instruction-sequence
          '(continue)
          '()
          '((goto (reg continue)))))
        ((eq? linkage 'next)
         (empty-instruction-sequence))
        (else
         (make-instruction-sequence '() '()
          `((goto (label ,linkage)))))))

(define (end-with-linkage
         linkage instruction-sequence)
  (preserving '(continue)
   instruction-sequence
   (compile-linkage linkage)))

(define (compile-self-evaluating
         exp target linkage)
  (end-with-linkage
   linkage (make-instruction-sequence
            '()
            (list target)
            `((assign ,target (const ,exp))))))

(define (compile-quoted exp target linkage)
  (end-with-linkage
   linkage
   (make-instruction-sequence
    '()
    (list target)
    `((assign
       ,target
       (const ,(text-of-quotation exp)))))))

(define (compile-variable name target linkage)
  (define addr (find-variable name (lexical-context)))
  (end-with-linkage linkage
    (make-instruction-sequence '(env) (list target)
      (list (if addr
        `(assign ,target (op lex-ref) (const ,addr) (reg env))
        `(assign ,target (op lookup-variable-value) (const ,name) (reg env)))))))

(define (compile-assignment exp target linkage)
  (define name (assignment-variable exp))
  (define addr (find-variable name (lexical-context)))
  (end-with-linkage linkage
    (preserving '(env) (compile (assignment-value exp) 'val 'next)
      (make-instruction-sequence '(env val) (list target)
        (list (if addr
                  `(perform (op lex-set!) (const ,addr) (reg val) (reg env))
                  `(perform (op set-variable-value!) (const ,name) (reg val) (reg env)))
              `(assign ,target (const ok)))))))

(define (compile-definition
         exp target linkage)
  (let ((var (definition-variable exp))
        (get-value-code
         (compile (definition-value exp)
                  'val
                  'next)))
    (end-with-linkage
     linkage
     (preserving
      '(env)
      get-value-code
      (make-instruction-sequence
       '(env val)
       (list target)
       `((perform (op define-variable!)
                  (const ,var)
                  (reg val)
                  (reg env))
         (assign ,target (const ok))))))))

(define (compile-if exp target linkage)
  (let ((t-branch (make-label 'true-branch))
        (f-branch (make-label 'false-branch))
        (after-if (make-label 'after-if)))
    (let ((consequent-linkage
           (if (eq? linkage 'next)
               after-if
               linkage)))
      (let ((p-code
             (compile (if-predicate exp)
                      'val
                      'next))
            (c-code
             (compile (if-consequent exp)
                      target
                      consequent-linkage))
            (a-code
             (compile (if-alternative exp)
                      target
                      linkage)))
        (preserving
         '(env continue)
         p-code
         (append-instruction-sequences
          (make-instruction-sequence
           '(val)
           '()
           `((test (op false?) (reg val))
             (branch (label ,f-branch))))
          (parallel-instruction-sequences
           (append-instruction-sequences
            t-branch c-code)
           (append-instruction-sequences
            f-branch a-code))
          after-if))))))

(define (compile-sequence seq target linkage)
  (if (last-exp? seq)
      (compile (first-exp seq) target linkage)
      (preserving '(env continue)
       (compile (first-exp seq) target 'next)
       (compile-sequence (rest-exps seq)
                         target
                         linkage))))

(define (compile-lambda exp target linkage)
  (let ((proc-entry
         (make-label 'entry))
        (after-lambda
         (make-label 'after-lambda)))
    (let ((lambda-linkage
           (if (eq? linkage 'next)
               after-lambda
               linkage)))
      (append-instruction-sequences
       (tack-on-instruction-sequence
        (end-with-linkage
         lambda-linkage
         (make-instruction-sequence
          '(env)
          (list target)
          `((assign ,target (label ,proc-entry))
            (assign
             ,target
             (op make-compiled-procedure)
             (reg ,target)
             (reg env)))))
        (compile-lambda-body exp proc-entry))
       after-lambda))))

(define (compile-lambda-body exp proc-entry)
  (let ((formals (lambda-parameters exp)))
    (append-instruction-sequences
     (make-instruction-sequence
      '(env proc argl)
      '(env)
      `(,proc-entry
        (assign env
                (op compiled-procedure-env)
                (reg proc))
        (assign env
                (op extend-environment)
                (const ,formals)
                (reg argl)
                (reg env))))
     (parameterize ([lexical-context (cons formals (lexical-context))])
       (compile-sequence (if (scan-internals?) (scan-body (lambda-body exp)) (lambda-body exp))
                       'val
                       'return)))))

(define (compile-application
         exp target linkage)
  (let ((proc-code
         (compile (operator exp) 'proc 'next))
        (operand-codes
         (map (lambda (operand)
                (compile operand 'val 'next))
              (operands exp))))
    (preserving
     '(env continue)
     proc-code
     (preserving
      '(proc continue)
      (construct-arglist operand-codes)
      (compile-procedure-call
       target
       linkage)))))

(define left-first? (make-parameter #f))
(define (construct-arglist operand-codes)
  (if (or (not (left-first?)) (null? operand-codes))
      (right-to-left-args operand-codes)
      (preserving '(continue)
        (append-instruction-sequences
          (make-instruction-sequence '() '(argl) '((assign argl (const ()))))
          (let emit ([remaining operand-codes])
            (if (null? remaining) (empty-instruction-sequence)
                (preserving '(env)
                  (preserving '(argl) (car remaining)
                    (make-instruction-sequence '(val argl) '(argl) '((assign argl (op cons) (reg val) (reg argl)))))
                  (emit (cdr remaining))))))
        (make-instruction-sequence '(argl) '(argl) '((assign argl (op reverse) (reg argl)))))))
(define (right-to-left-args operand-codes)
  (let ((operand-codes
         (reverse operand-codes)))
    (if (null? operand-codes)
        (make-instruction-sequence
         '()
         '(argl)
         '((assign argl (const ()))))
        (let ((code-to-get-last-arg
               (append-instruction-sequences
                (car operand-codes)
                (make-instruction-sequence
                 '(val)
                 '(argl)
                 '((assign argl
                           (op list)
                           (reg val)))))))
          (if (null? (cdr operand-codes))
              code-to-get-last-arg
              (preserving
               '(env)
               code-to-get-last-arg
               (code-to-get-rest-args
                (cdr operand-codes))))))))

(define (code-to-get-rest-args operand-codes)
  (let ((code-for-next-arg
         (preserving
          '(argl)
          (car operand-codes)
          (make-instruction-sequence
           '(val argl)
           '(argl)
           '((assign argl
                     (op cons)
                     (reg val)
                     (reg argl)))))))
    (if (null? (cdr operand-codes))
        code-for-next-arg
        (preserving
         '(env)
         code-for-next-arg
         (code-to-get-rest-args
          (cdr operand-codes))))))

(define (compile-procedure-call
         target linkage)
  (let ((primitive-branch
         (make-label 'primitive-branch))
        (compiled-branch
         (make-label 'compiled-branch))
        (after-call
         (make-label 'after-call)))
    (let ((compiled-linkage
           (if (eq? linkage 'next)
               after-call
               linkage)))
      (append-instruction-sequences
       (make-instruction-sequence
        '(proc)
        '()
        `((test
           (op primitive-procedure?)
           (reg proc))
          (branch
           (label ,primitive-branch))))
       (parallel-instruction-sequences
        (append-instruction-sequences
         compiled-branch
         (compile-proc-appl
          target
          compiled-linkage))
        (append-instruction-sequences
         primitive-branch
         (end-with-linkage
          linkage
          (make-instruction-sequence
           '(proc argl)
           (list target)
           `((assign
              ,target
              (op apply-primitive-procedure)
              (reg proc)
              (reg argl)))))))
       after-call))))

(define (compile-proc-appl target linkage)
  (cond ((and (eq? target 'val)
              (not (eq? linkage 'return)))
         (make-instruction-sequence
          '(proc)
          all-regs
          `((assign continue (label ,linkage))
            (assign
             val
             (op compiled-procedure-entry)
             (reg proc))
            (goto (reg val)))))
        ((and (not (eq? target 'val))
              (not (eq? linkage 'return)))
         (let ((proc-return
                (make-label 'proc-return)))
           (make-instruction-sequence
            '(proc)
            all-regs
            `((assign continue
                      (label ,proc-return))
              (assign
               val
               (op compiled-procedure-entry)
               (reg proc))
              (goto (reg val))
              ,proc-return
              (assign ,target (reg val))
              (goto (label ,linkage))))))
        ((and (eq? target 'val)
              (eq? linkage 'return))
         (make-instruction-sequence
          '(proc continue)
          all-regs
          '((assign
             val
             (op compiled-procedure-entry)
             (reg proc))
            (goto (reg val)))))
        ((and (not (eq? target 'val))
              (eq? linkage 'return))
         (error "return linkage,
                 target not val: COMPILE"
                target))))

(define (registers-needed s)
  (if (symbol? s) '() (car s)))
(define (registers-modified s)
  (if (symbol? s) '() (cadr s)))
(define (statements s)
  (if (symbol? s) (list s) (caddr s)))

(define (needs-register? seq reg)
  (memq reg (registers-needed seq)))
(define (modifies-register? seq reg)
  (memq reg (registers-modified seq)))

(define (append-instruction-sequences . seqs)
  (define (append-2-sequences seq1 seq2)
    (make-instruction-sequence
     (list-union
      (registers-needed seq1)
      (list-difference
       (registers-needed seq2)
       (registers-modified seq1)))
     (list-union
      (registers-modified seq1)
      (registers-modified seq2))
     (append (statements seq1)
             (statements seq2))))
  (define (append-seq-list seqs)
    (if (null? seqs)
        (empty-instruction-sequence)
        (append-2-sequences
         (car seqs)
         (append-seq-list (cdr seqs)))))
  (append-seq-list seqs))

(define (list-union s1 s2)
  (cond ((null? s1) s2)
        ((memq (car s1) s2)
         (list-union (cdr s1) s2))
        (else
         (cons (car s1)
               (list-union (cdr s1) s2)))))

(define (list-difference s1 s2)
  (cond ((null? s1) '())
        ((memq (car s1) s2)
         (list-difference (cdr s1) s2))
        (else
         (cons (car s1)
               (list-difference (cdr s1)
                                s2)))))

(define always-save? (make-parameter #f))
(define (preserving regs seq1 seq2)
  (if (null? regs)
      (append-instruction-sequences seq1 seq2)
      (let ((first-reg (car regs)))
        (if (or (always-save?) (and
             (needs-register? seq2 first-reg)
             (modifies-register? seq1
                                 first-reg)))
            (preserving
             (cdr regs)
             (make-instruction-sequence
              (list-union
               (list first-reg)
               (registers-needed seq1))
              (list-difference
               (registers-modified seq1)
               (list first-reg))
              (append `((save ,first-reg))
                      (statements seq1)
                      `((restore ,first-reg))))
             seq2)
            (preserving
             (cdr regs)
             seq1
             seq2)))))

(define (tack-on-instruction-sequence
         seq body-seq)
  (make-instruction-sequence
   (registers-needed seq)
   (registers-modified seq)
   (append (statements seq)
           (statements body-seq))))

(define (parallel-instruction-sequences
         seq1 seq2)
  (make-instruction-sequence
   (list-union (registers-needed seq1)
               (registers-needed seq2))
   (list-union (registers-modified seq1)
               (registers-modified seq2))
   (append (statements seq1)
           (statements seq2))))

(define label-counter 0)

(define (new-label-number)
  (set! label-counter (+ 1 label-counter))
  label-counter)

(define (make-label name)
  (string->symbol
   (string-append
    (symbol->string name)
    (number->string (new-label-number)))))

(define (make-compiled-procedure entry env)
  (list 'compiled-procedure entry env))
(define (compiled-procedure? proc)
  (tagged-list? proc 'compiled-procedure))
(define (compiled-procedure-entry c-proc)
  (cadr c-proc))
(define (compiled-procedure-env c-proc)
  (caddr c-proc))

(define all-regs '(env proc val argl continue arg1 arg2))

(define ec-controller
  '(
eval-dispatch
  (test (op self-evaluating?) (reg exp))
  (branch (label ev-self-eval))
  (test (op variable?) (reg exp))
  (branch (label ev-variable))
  (test (op quoted?) (reg exp))
  (branch (label ev-quoted))
  (test (op assignment?) (reg exp))
  (branch (label ev-assignment))
  (test (op definition?) (reg exp))
  (branch (label ev-definition))
  (test (op if?) (reg exp))
  (branch (label ev-if))
  (test (op lambda?) (reg exp))
  (branch (label ev-lambda))
  (test (op begin?) (reg exp))
  (branch (label ev-begin))
  (test (op application?) (reg exp))
  (branch (label ev-application))
  (goto (label unknown-expression-type))
ev-self-eval
  (assign val (reg exp))
  (goto (reg continue))
ev-variable
  (assign val
          (op lookup-variable-value)
          (reg exp)
          (reg env))
  (goto (reg continue))
ev-quoted
  (assign val
          (op text-of-quotation)
          (reg exp))
  (goto (reg continue))
ev-lambda
  (assign unev
          (op lambda-parameters)
          (reg exp))
  (assign exp
          (op lambda-body)
          (reg exp))
  (assign val
          (op make-procedure)
          (reg unev)
          (reg exp)
          (reg env))
  (goto (reg continue))
ev-application
  (save continue)
  (save env)
  (assign unev (op operands) (reg exp))
  (save unev)
  (assign exp (op operator) (reg exp))
  (assign
   continue (label ev-appl-did-operator))
  (goto (label eval-dispatch))
ev-appl-did-operator
  (restore unev)             ; the operands
  (restore env)
  (assign argl (op empty-arglist))
  (assign proc (reg val))    ; the operator
  (test (op no-operands?) (reg unev))
  (branch (label apply-dispatch))
  (save proc)
ev-appl-operand-loop
  (save argl)
  (assign exp
          (op first-operand)
          (reg unev))
  (test (op last-operand?) (reg unev))
  (branch (label ev-appl-last-arg))
  (save env)
  (save unev)
  (assign continue
          (label ev-appl-accumulate-arg))
  (goto (label eval-dispatch))
ev-appl-accumulate-arg
  (restore unev)
  (restore env)
  (restore argl)
  (assign argl
          (op adjoin-arg)
          (reg val)
          (reg argl))
  (assign unev
          (op rest-operands)
          (reg unev))
  (goto (label ev-appl-operand-loop))
ev-appl-last-arg
  (assign continue
          (label ev-appl-accum-last-arg))
  (goto (label eval-dispatch))
ev-appl-accum-last-arg
  (restore argl)
  (assign argl
          (op adjoin-arg)
          (reg val)
          (reg argl))
  (restore proc)
  (goto (label apply-dispatch))
apply-dispatch
  (test (op primitive-procedure?) (reg proc))
  (branch (label primitive-apply))
  (test (op compound-procedure?) (reg proc))
  (branch (label compound-apply))
  (goto (label unknown-procedure-type))
primitive-apply
  (assign val (op apply-primitive-procedure)
              (reg proc)
              (reg argl))
  (restore continue)
  (goto (reg continue))
compound-apply
  (assign unev
          (op procedure-parameters)
          (reg proc))
  (assign env
          (op procedure-environment)
          (reg proc))
  (assign env
          (op extend-environment)
          (reg unev)
          (reg argl)
          (reg env))
  (assign unev
          (op procedure-body)
          (reg proc))
  (goto (label ev-sequence))
ev-begin
  (assign unev
          (op begin-actions)
          (reg exp))
  (save continue)
  (goto (label ev-sequence))
ev-sequence
  (assign exp (op first-exp) (reg unev))
  (test (op last-exp?) (reg unev))
  (branch (label ev-sequence-last-exp))
  (save unev)
  (save env)
  (assign continue
          (label ev-sequence-continue))
  (goto (label eval-dispatch))
ev-sequence-continue
  (restore env)
  (restore unev)
  (assign unev
          (op rest-exps)
          (reg unev))
  (goto (label ev-sequence))
ev-sequence-last-exp
  (restore continue)
  (goto (label eval-dispatch))
ev-if
  (save exp)   ; save expression for later
  (save env)
  (save continue)
  (assign continue (label ev-if-decide))
  (assign exp (op if-predicate) (reg exp))
  ; evaluate the predicate:
  (goto (label eval-dispatch))
ev-if-decide
  (restore continue)
  (restore env)
  (restore exp)
  (test (op true?) (reg val))
  (branch (label ev-if-consequent))
ev-if-alternative
  (assign exp (op if-alternative) (reg exp))
  (goto (label eval-dispatch))
ev-if-consequent
  (assign exp (op if-consequent) (reg exp))
  (goto (label eval-dispatch))
ev-assignment
  (assign unev
          (op assignment-variable)
          (reg exp))
  (save unev)   ; save variable for later
  (assign exp
          (op assignment-value)
          (reg exp))
  (save env)
  (save continue)
  (assign continue
          (label ev-assignment-1))
  ; evaluate the assignment value:
  (goto (label eval-dispatch))
ev-assignment-1
  (restore continue)
  (restore env)
  (restore unev)
  (perform (op set-variable-value!)
           (reg unev)
           (reg val)
           (reg env))
  (assign val
          (const ok))
  (goto (reg continue))
ev-definition
  (assign unev
          (op definition-variable)
          (reg exp))
  (save unev)   ; save variable for later
  (assign exp
          (op definition-value)
          (reg exp))
  (save env)
  (save continue)
  (assign continue (label ev-definition-1))
  ; evaluate the definition value:
  (goto (label eval-dispatch))
ev-definition-1
  (restore continue)
  (restore env)
  (restore unev)
  (perform (op define-variable!)
           (reg unev)
           (reg val)
           (reg env))
  (assign val (const ok))
  (goto (reg continue))
unknown-expression-type
unknown-procedure-type
  (perform (op report-error) (reg exp))
))

(define textbook-fib
  '(
(assign continue (label fib-done))
 fib-loop
   (test (op <) (reg n) (const 2))
   (branch (label immediate-answer))
   ;; set up to compute Fib(n − 1)
   (save continue)
   (assign continue (label afterfib-n-1))
   (save n)           ; save old value of n
   (assign n
           (op -)
           (reg n)
           (const 1)) ; clobber n to n-1
   (goto
    (label fib-loop)) ; perform recursive call
 afterfib-n-1 ; upon return, val contains Fib(n − 1)
   (restore n)
   (restore continue)
   ;; set up to compute Fib(n − 2)
   (assign n (op -) (reg n) (const 2))
   (save continue)
   (assign continue (label afterfib-n-2))
   (save val)         ; save Fib(n − 1)
   (goto (label fib-loop))
 afterfib-n-2 ; upon return, val contains Fib(n − 2)
   (assign n
           (reg val)) ; n now contains Fib(n − 2)
   (restore val)      ; val now contains Fib(n − 1)
   (restore continue)
   (assign val        ; Fib(n − 1) + Fib(n − 2)
           (op +)
           (reg val)
           (reg n))
   (goto              ; return to caller,
    (reg continue))   ; answer is in val
 immediate-answer
   (assign val
           (reg n))   ; base case: Fib(n) = n
   (goto (reg continue))
 fib-done
))

(define machine-ops
  (hash '* * '= = 'reverse reverse
    '+ +
    '- -
    '< <
    'adjoin-arg (lambda (arg args) (append args (list arg)))
    'application? application?
    'apply-primitive-procedure apply
    'assignment-value assignment-value
    'assignment-variable assignment-variable
    'assignment? assignment?
    'begin-actions begin-actions
    'begin? begin?
    'compiled-procedure-entry compiled-procedure-entry
    'compiled-procedure-env compiled-procedure-env
    'compound-procedure? closure?
    'cons cons
    'define-variable! define-variable!
    'definition-value definition-value
    'definition-variable definition-variable
    'definition? definition?
    'empty-arglist (lambda () (quote ()))
    'extend-environment extend-environment
    'false? not
    'first-exp first-exp
    'first-operand car
    'if-alternative if-alternative
    'if-consequent if-consequent
    'if-predicate if-predicate
    'if? if?
    'lambda-body lambda-body
    'lambda-parameters lambda-parameters
    'lambda? lambda?
    'last-exp? last-exp?
    'last-operand? last-exp?
    'lex-set! lex-set!
    'lex-ref lex-ref
    'list list
    'lookup-variable-value lookup-variable-value
    'make-compiled-procedure make-compiled-procedure
    'make-procedure closure
    'no-operands? null?
    'operands operands
    'operator operator
    'primitive-procedure? procedure?
    'procedure-body closure-body
    'procedure-environment closure-environment
    'procedure-parameters closure-parameters
    'quoted? quoted?
    'report-error (lambda (exp) (error 'ec "invalid expression or procedure ~s" exp))
    'rest-exps rest-exps
    'rest-operands cdr
    'self-evaluating? self-evaluating?
    'set-variable-value! set-variable-value!
    'text-of-quotation text-of-quotation
    'true? (lambda (x) (not (eq? x #f)))
    'variable? variable?
))

(define (expression-controller expr compiled?)
  (define prefix '((assign continue (label done))))
  (define body
    (if compiled?
        (statements (compile expr 'val 'return))
        (cons '(goto (label eval-dispatch)) ec-controller)))
  (append prefix body '(done)))
(define (run-expression expr #:compiled? [compiled? #f] #:limit [limit 1000000] #:env [env (initial-env)])
  (execute (expression-controller expr compiled?) machine-ops (hash 'env env 'exp expr) #:limit limit))
(define (answer result) (hash-ref (execution-registers result) 'val))
(define factorial-controller
  '((assign continue (label done))
    loop (test (op =) (reg n) (const 1)) (branch (label base))
    (save continue) (save n) (assign n (op -) (reg n) (const 1))
    (assign continue (label unwind)) (goto (label loop))
    unwind (restore n) (restore continue)
    (assign val (op *) (reg n) (reg val)) (goto (reg continue))
    base (assign val (const 1)) (goto (reg continue)) done))
(define iterative-factorial
  '((assign val (const 1)) (assign i (const 1))
    loop (test (op >) (reg i) (reg n)) (branch (label done))
    (assign val (op *) (reg val) (reg i)) (assign i (op +) (reg i) (const 1))
    (goto (label loop)) done))
(define gcd-controller
  '(loop (test (op =) (reg b) (const 0)) (branch (label done))
    (assign t (op remainder) (reg a) (reg b)) (assign a (reg b)) (assign b (reg t))
    (goto (label loop)) done))
(define (power-controller recursive?)
  (if recursive?
      '((assign continue (label done)) loop (test (op =) (reg n) (const 0))
        (branch (label base)) (save continue) (assign continue (label multiply))
        (assign n (op -) (reg n) (const 1)) (goto (label loop))
        multiply (restore continue) (assign val (op *) (reg b) (reg val))
        (goto (reg continue)) base (assign val (const 1)) (goto (reg continue)) done)
      '((assign val (const 1)) loop (test (op =) (reg n) (const 0))
        (branch (label done)) (assign val (op *) (reg b) (reg val))
        (assign n (op -) (reg n) (const 1)) (goto (label loop)) done)))
(define (factorial-expression n [iter? #f])
  `(begin (define (f n)
            ,(if iter? '(begin (define (iter product counter)
                                 (if (> counter n) product (iter (* counter product) (+ counter 1))))
                                (iter 1 1))
                 '(if (= n 1) 1 (* (f (- n 1)) n)))) (f ,n)))
(define (fib-expression n)
  `(begin (define (fib n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))) (fib ,n)))

;; SICP 4.1.1 guest evaluator. Syntax and environment operations are supplied
;; as elementary procedures to the outer implementation (not host eval).
(define (meta-expression guest)
  `(begin
(define (eval exp env)
  (cond ((self-evaluating? exp)
         exp)
        ((variable? exp)
         (lookup-variable-value exp env))
        ((quoted? exp)
         (text-of-quotation exp))
        ((assignment? exp)
         (eval-assignment exp env))
        ((definition? exp)
         (eval-definition exp env))
        ((if? exp)
         (eval-if exp env))
        ((lambda? exp)
         (make-procedure
          (lambda-parameters exp)
          (lambda-body exp)
          env))
        ((begin? exp)
         (eval-sequence
          (begin-actions exp)
          env))
        ((cond? exp)
         (eval (cond->if exp) env))
        ((application? exp)
         (apply (eval (operator exp) env)
                (list-of-values
                 (operands exp)
                 env)))
        (else
         (error "Unknown expression
                 type: EVAL" exp))))
(define (apply procedure arguments)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure
          procedure
          arguments))
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters
              procedure)
             arguments
             (procedure-environment
              procedure))))
        (else
         (error "Unknown procedure
                 type: APPLY"
                procedure))))
(define (list-of-values exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
            (list-of-values
             (rest-operands exps)
             env))))
(define (eval-if exp env)
  (if (true? (eval (if-predicate exp) env))
      (eval (if-consequent exp) env)
      (eval (if-alternative exp) env)))
(define (eval-sequence exps env)
  (cond ((last-exp? exps)
         (eval (first-exp exps) env))
        (else
         (eval (first-exp exps) env)
         (eval-sequence (rest-exps exps)
                        env))))
(define (eval-assignment exp env)
  (set-variable-value!
   (assignment-variable exp)
   (eval (assignment-value exp) env)
   env)
  'ok)
(define (eval-definition exp env)
  (define-variable!
    (definition-variable exp)
    (eval (definition-value exp) env)
    env)
  'ok)
(eval (quote ,guest) guest-environment)))
(define (meta-env)
  (define env (initial-env))
  (for ([(name f) (in-hash machine-ops)]) (define-variable! name f env))
  (define-variable! 'cond? cond? env) (define-variable! 'cond->if cond->if env)
  (define-variable! 'guest-environment (initial-env) env) env)
;; Execution hooks for exercises 5.12 and 5.15-19. A generator suspension
;; preserves the complete machine, including its instruction and stack.
(require racket/generator)
(define (inspect-controller code)
  (define instructions (filter list? code))
  (define (uniq xs) (remove-duplicates xs equal?))
  (hash 'instructions (sort (uniq instructions) symbol<? #:key car)
        'entries (uniq (for/list ([x instructions] #:when (match x [`(goto (reg ,_)) #t] [_ #f])) (cadadr x)))
        'saved (uniq (for/list ([x instructions] #:when (memq (car x) '(save restore))) (cadr x)))
        'sources (for/fold ([h (hash)]) ([x instructions] #:when (eq? (car x) 'assign))
                   (hash-update h (cadr x) (lambda (old) (uniq (cons (cddr x) old))) '()))))
(define (debug-run controller ops regs breaks #:watch [watch '()] #:logger [logger void])
  (define img (assemble controller))
  (define (stopped? pc)
    (for/or ([b (if (box? breaks) (unbox breaks) breaks)])
      (match-define (list label (? exact-positive-integer? offset)) b)
      (= pc (+ (hash-ref (image-labels img) label) (sub1 offset)))))
    (generator ()
    (execute img ops regs #:on-write (lambda (name old new) (when (member name watch) (logger (list 'write name old new)))) #:observe
      (lambda (pc instruction regs stack)
        (logger (list 'instruction (hash-keys (for/hash ([(k v) (in-hash (image-labels img))] #:when (= v pc)) (values k v))) instruction))
        (when (stopped? pc) (yield (list pc instruction (hash-copy regs) stack)))))))
(define tree-counter
  '((assign continue (label done))
    visit (test (op null?) (reg tree)) (branch (label empty))
    (test (op pair?) (reg tree)) (branch (label fork))
    (assign val (const 1)) (goto (reg continue))
    empty (assign val (const 0)) (goto (reg continue))
    fork (save continue) (assign right (op cdr) (reg tree)) (save right)
    (assign tree (op car) (reg tree)) (assign continue (label after-left)) (goto (label visit))
    after-left (restore tree) (save val) (assign continue (label after-right)) (goto (label visit))
    after-right (restore left) (restore continue) (assign val (op +) (reg left) (reg val))
    (goto (reg continue)) done))
(define tree-counter-acc
  '((assign val (const 0)) (assign work (op list) (reg tree))
    loop (test (op null?) (reg work)) (branch (label done))
    (assign tree (op car) (reg work)) (assign work (op cdr) (reg work))
    (test (op null?) (reg tree)) (branch (label loop))
    (test (op pair?) (reg tree)) (branch (label fork))
    (assign val (op +) (reg val) (const 1)) (goto (label loop))
    fork (assign right (op cdr) (reg tree)) (assign work (op cons) (reg right) (reg work))
    (assign left (op car) (reg tree)) (assign work (op cons) (reg left) (reg work))
    (goto (label loop)) done))
(define append-controller
  '((assign pending (const ()))
    descend (test (op null?) (reg x)) (branch (label build))
    (assign item (op car) (reg x)) (assign pending (op cons) (reg item) (reg pending))
    (assign x (op cdr) (reg x)) (goto (label descend))
    build (assign val (reg y))
    unwind (test (op null?) (reg pending)) (branch (label done))
    (assign item (op car) (reg pending)) (assign val (op cons) (reg item) (reg val))
    (assign pending (op cdr) (reg pending)) (goto (label unwind)) done))
(define splice-controller
  '((assign val (reg x))
    walk (assign tail (op mcdr) (reg x)) (test (op null?) (reg tail)) (branch (label link))
    (assign x (reg tail)) (goto (label walk))
    link (perform (op set-mcdr!) (reg x) (reg y))))
(define sqrt-controller
  '((assign guess (const 1.0))
    test (assign t (op *) (reg guess) (reg guess)) (assign t (op -) (reg t) (reg x))
    (assign t (op abs) (reg t)) (test (op <) (reg t) (const 0.001)) (branch (label done))
    (assign t (op /) (reg x) (reg guess)) (assign t (op +) (reg t) (reg guess))
    (assign guess (op /) (reg t) (const 2)) (goto (label test)) done))
;; A session shares the top-level frame and retains the instruction image in
;; every return address. Code compiled on the second turn may call closures
;; installed by either execution mode on the first turn.
(define (insert-before code wanted extra)
  (define rest (member wanted code))
  (unless rest (error 'controller "missing instruction ~s" wanted))
  (append (take code (- (length code) (length rest))) extra rest))
(define session-image
  (assemble
   (append
    (insert-before
     (insert-before ec-controller '(test (op self-evaluating?) (reg exp))
       '((test (op compile-request?) (reg exp)) (branch (label enter-compiler))))
     '(goto (label unknown-procedure-type))
     '((test (op compiled-procedure?) (reg proc)) (branch (label apply-compiled))))
    '(enter-compiler (assign val (op install-code) (reg exp)) (goto (reg val))
      apply-compiled (restore continue) (assign val (op compiled-procedure-entry) (reg proc))
      (goto (reg val)) from-compiled (save continue) (goto (label compound-apply))))))
(define (session-run expressions #:compile-all? [compile-all? #f])
  (define env (initial-env))
  (define (install req)
    (match req [`(compile-and-run (quote ,exp))
                (location (assemble (statements (compile exp 'val 'return))) 0)]))
  (define ops
    (hash-set* machine-ops 'compile-request? (lambda (e) (tagged-list? e 'compile-and-run))
               'install-code install 'compiled-procedure? compiled-procedure?
               'compiled-procedure-entry (lambda (proc)
                   (if (closure? proc) (location session-image (hash-ref (image-labels session-image) 'from-compiled))
                       (compiled-procedure-entry proc)))))
  (define stop (location (assemble '()) 0))
  (for/list ([expr expressions])
    (answer (execute session-image ops
                     (hash 'env env 'continue stop 'exp (if compile-all? `(compile-and-run (quote ,expr)) expr))))))
(struct delayed (expression environment ready? value) #:mutable)
(define (between code start end)
  (takef (member start code) (lambda (x) (not (eq? x end)))))
(define (replace-block code start end new)
  (append (take code (- (length code) (length (member start code)))) new (member end code)))
(define (lazy-result expr)
  (define code ec-controller)
  (for ([interval '((ev-application ev-appl-did-operator) (ev-appl-operand-loop ev-appl-accumulate-arg)
                    (ev-appl-last-arg ev-appl-accum-last-arg) (ev-if ev-if-decide))])
    (define block (apply between code interval))
    (set! code (replace-block code (car interval) (cadr interval)
                 (for/list ([item block]) (if (equal? item '(goto (label eval-dispatch)))
                                              '(goto (label actual-entry)) item)))))
  (set! code (insert-before code '(test (op no-operands?) (reg unev))
               '((test (op compound-procedure?) (reg proc)) (branch (label delay-arguments)))))
  (define ops (hash-set* machine-ops 'delay-all (lambda (xs env) (map (lambda (e) (delayed e env #f #f)) xs))
              'delayed? delayed? 'ready? delayed-ready? 'payload delayed-expression 'context delayed-environment
              'cached delayed-value 'remember! (lambda (p v) (set-delayed-value! p v) (set-delayed-ready?! p #t)
                                                  (set-delayed-expression! p #f) (set-delayed-environment! p #f))))
  (answer (execute (append '((assign continue (label done)) (goto (label actual-entry))) code
     '(delay-arguments (assign argl (op delay-all) (reg unev) (reg env)) (goto (label compound-apply))
       actual-entry (save continue) (assign continue (label demand)) (goto (label eval-dispatch))
       demand (test (op delayed?) (reg val)) (branch (label inspect-thunk))
       return-value (restore continue) (goto (reg continue))
       inspect-thunk (test (op ready?) (reg val)) (branch (label use-cache))
       (save val) (assign exp (op payload) (reg val)) (assign env (op context) (reg val))
       (assign continue (label memoize)) (goto (label actual-entry))
       memoize (restore thunk) (perform (op remember!) (reg thunk) (reg val)) (goto (label return-value))
       use-cache (assign val (op cached) (reg val)) (goto (label return-value)) done))
    ops (hash 'env (initial-env) 'exp expr))))
(define (extended-ec expr)
  (define ops
    (hash-set* machine-ops 'cond? cond? 'let? (lambda (e) (tagged-list? e 'let))
      'let->application (lambda (e) `((lambda ,(map car (cadr e)) ,@(cddr e)) ,@(map cadr (cadr e))))
      'else? (lambda (e) (eq? e 'else)) 'car car 'cdr cdr 'null? null?))
  (define extended (insert-before ec-controller '(test (op self-evaluating?) (reg exp))
              '((test (op let?) (reg exp)) (branch (label rewrite-let))
                (test (op cond?) (reg exp)) (branch (label ec-cond)))))
  (answer (execute (append '((assign continue (label done))) extended
    '(rewrite-let (assign exp (op let->application) (reg exp)) (goto (label eval-dispatch))
      ec-cond (assign clauses (op cdr) (reg exp))
      next-clause (test (op null?) (reg clauses)) (branch (label no-clause))
      (assign clause (op car) (reg clauses)) (assign exp (op car) (reg clause))
      (assign unev (op cdr) (reg clause)) (assign clauses (op cdr) (reg clauses))
      (test (op else?) (reg exp)) (branch (label else-clause))
      (save continue) (save env) (save clauses) (save unev)
      (assign continue (label cond-decide)) (goto (label eval-dispatch))
      cond-decide (restore unev) (restore clauses) (restore env) (restore continue)
      (test (op false?) (reg val)) (branch (label next-clause))
      (test (op null?) (reg unev)) (branch (label cond-return))
      actions (save continue) (goto (label ev-sequence))
      else-clause (test (op null?) (reg clauses)) (branch (label actions))
      (goto (label unknown-expression-type))
      no-clause (assign val (const #f)) cond-return (goto (reg continue)) done))
    ops (hash 'env (initial-env) 'exp expr))))

(define (non-tail expr)
  (define code (replace-block ec-controller 'ev-sequence 'ev-if
  '(
ev-sequence
  (test (op no-more-exps?) (reg unev))
  (branch (label ev-sequence-end))
  (assign exp (op first-exp) (reg unev))
  (save unev)
  (save env)
  (assign continue
          (label ev-sequence-continue))
  (goto (label eval-dispatch))
ev-sequence-continue
  (restore env)
  (restore unev)
  (assign unev (op rest-exps) (reg unev))
  (goto (label ev-sequence))
ev-sequence-end
  (restore continue)
  (goto (reg continue))
)))
  (execute (append '((assign continue (label done))) code '(done))
           (hash-set machine-ops 'no-more-exps? null?) (hash 'env (initial-env) 'exp expr)))
;; The nonmoving alternative keeps a list of reusable indices. A separate
;; mark vector prevents cycles from pushing children a second time.
(struct free-heap (cells unused) #:mutable #:transparent)
(define (make-free-heap size) (free-heap (make-vector size #f) (range size)))
(define (alloc-free h a d)
  (match (free-heap-unused h)
    ['() (error 'alloc-free "out of cells")]
    [(cons i rest) (set-free-heap-unused! h rest)
                   (vector-set! (free-heap-cells h) i (vector a d)) (ptr i)]))
(define (mark-and-sweep! h roots)
  (define cells (free-heap-cells h))
  (define marks (make-vector (vector-length cells) #f))
  (let mark ([todo roots])
    (unless (null? todo)
      (match (car todo)
        [(ptr i) #:when (not (vector-ref marks i))
         (define cell (vector-ref cells i))
         (unless cell (error 'mark "pointer to free cell"))
         (vector-set! marks i #t)
         (mark (cons (vector-ref cell 0) (cons (vector-ref cell 1) (cdr todo))))]
        [_ (mark (cdr todo))])))
  (set-free-heap-unused! h
    (for/list ([i (in-range (vector-length cells))] #:unless (vector-ref marks i))
      (vector-set! cells i #f) i)))
