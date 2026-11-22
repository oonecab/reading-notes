#lang racket
;; Exercises 5.51 and 5.52. The generated C99 translation unit owns its PC,
;; registers, branch dispatch and stack. Its callback ABI supplies only data
;; operations and stable handles to Scheme values; handles live for one run.
(require ffi/unsafe racket/file racket/system "chapter05.rkt")
(provide run-c)
(define (run-c expr compiled? env)
  (define img (assemble (expression-controller expr compiled?)))
  (define regs (make-hasheq))
  (define (reg r) (format "r[~a]" (hash-ref! regs r (lambda () (hash-count regs)))))
  (define pool (make-hasheqv))
  (define (store x)
    (define i (add1 (hash-count pool)))
    (hash-set! pool i x) i)
  (define address (lambda (label) (hash-ref (image-labels img) label)))
  (define (operand x)
    (match x [`(reg ,r) (reg r)] [`(const ,k) (number->string (store k))]
           [`(label ,l) (number->string (store (address l)))]))
  (define (value args)
    (match args
      [(list (list 'op f) xs ...)
       (format "op(~a,~a,(int[]){~a})" (store (hash-ref machine-ops f)) (length xs)
               (if (null? xs) "0" (string-join (map operand xs) ",")))]
      [(list x) (operand x)]))
  (define (ins x)
    (match x
      [`(assign ,r ,args ...) (format "~a=~a;" (reg r) (value args))]
      [`(perform ,args ...) (format "(void)~a;" (value args))]
      [`(test ,args ...) (format "flag=truth(~a);" (value args))]
      [`(branch (label ,l)) (format "if(flag){pc=~a;continue;}" (address l))]
      [`(goto (label ,l)) (format "pc=~a;continue;" (address l))]
      [`(goto (reg ,r)) (format "pc=addr(~a);continue;" (reg r))]
      [`(save ,r) (format "if(sp==4096)return -2;stack[sp++]=~a;" (reg r))]
      [`(restore ,r) (format "if(!sp)return -3;~a=stack[--sp];" (reg r))]))
  (define lines (for/list ([x (image-code img)] [i (in-naturals)]) (format "case ~a: ~a break;" i (ins x))))
  (define init (format "~a=~a; ~a=~a;" (reg 'env) (store env) (reg 'exp) (store expr)))
  (define result (reg 'val))
  (define folder (make-temporary-file "sicp-c~a" 'directory))
  (define src (build-path folder "machine.c"))
  (define lib (build-path folder (if (eq? (system-type) 'windows) "machine.dll" "machine.so")))
  (dynamic-wind void (lambda ()
    (call-with-output-file src (lambda (out)
      (fprintf out "int run(int (*op)(int,int,int*),int (*truth)(int),int (*addr)(int)){\nint r[~a]={0},stack[4096],sp=0,pc=0,flag=0;~a\nfor(int fuel=1000000;fuel>0;--fuel,++pc){switch(pc){\n"
               (hash-count regs) init)
      ;; Continue must skip the normal PC increment on a transfer.
      (for ([line lines]) (displayln (string-replace line "continue;" "goto transfer;") out))
      (fprintf out "case ~a:return ~a;default:return -4;}continue;transfer: --pc;}return -1;}\n" (length lines) result)))
    (define gcc (or (find-executable-path "gcc") (error 'run-c "C99 compiler missing")))
    (unless (system* gcc "-std=c99" "-shared" "-fPIC" "-o" lib src) (error 'run-c "C build failed"))
    (define cust (make-custodian))
    (dynamic-wind void (lambda ()
      (define dll (ffi-lib lib #:custodian cust))
      (define run (get-ffi-obj "run" dll (_fun (_fun _int _int _pointer -> _int)
                                               (_fun _int -> _int) (_fun _int -> _int) -> _int)))
      (define failure #f)
      (define (operation f n argv)
        (with-handlers ([exn:fail? (lambda (e) (set! failure e) 0)])
          (store (apply (hash-ref pool f) (for/list ([j n]) (hash-ref pool (ptr-ref argv _int j)))))))
      (define handle (run operation (lambda (i) (if (hash-ref pool i #f) 1 0))
                          (lambda (i) (hash-ref pool i -4))))
      (when failure (raise failure))
      (unless (positive? handle) (error 'run-c "control/stack limit ~a" handle))
      (hash-ref pool handle))
      (lambda () (custodian-shutdown-all cust))))
    (lambda () (delete-directory/files folder #:must-exist? #f))))
(module+ main
  (define guest (factorial-expression 5))
  (define meta (meta-expression guest))
  (for ([name '(compiled-metacircular explicit-control-C compiled-metacircular-C)]
        [result (list (answer (run-expression meta #:compiled? #t #:env (meta-env)))
                      (run-c guest #f (initial-env)) (run-c meta #t (meta-env)))])
    (unless (equal? result 120) (error name "expected factorial 5"))
    (printf "~a ~a\n" name result)))
