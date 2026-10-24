#lang racket
(require rackunit rackunit/text-ui json "appendix_b.rkt")
(define assertions 0)
(define (same actual expected) (set! assertions (add1 assertions)) (check-equal? actual expected))
(define (reject thunk) (set! assertions (add1 assertions)) (check-exn exn:fail? thunk))
(define suite
 (test-suite "appendix B"
  (test-case "original lexical specification and keyword boundaries"
   ;; SLLGEN appends a generated number to its literal-token class name.
   (same (map (lambda (t) (cons (if (regexp-match? #rx"^literal-string[0-9]+$" (symbol->string (car t)))
                                  'literal-string (car t)) (cdr t)))
              (scan-statement "while whilex := 3 % ignored\nfoo"))
         '((literal-string "while" 1) (identifier whilex 1) (literal-string ":=" 1) (number 3 1) (identifier foo 2)))
   (same (map cadr (scan-arithmetic "3-2 3*-2")) '(3 "-" 2 3 "*" "-" 2))
   (same (map cadr (scan-statement "xyz x2 %nothing at EOF")) '(xyz x2)))
  (test-case "original syntax tree and independent precedence shape"
   (same (statement-datum (parse-statement "{x := foo; while x do x := (x - bar)}"))
         '(block (assign x (var foo)) (while (var x) (assign x (- (var x) (var bar))))))
   (same (arithmetic-datum (parse-base "3+2*66-5"))
         '(expr (term 3 () ()) (+ -) ((term 2 (*) (66)) (term 5 () ()))))
   (same (arithmetic-datum (parse-unary "3*-2"))
         '(expr (term 3 (*) ((neg 2))) () ()))
   (same (parameterize ([current-input-port (open-input-string "5;\n2+3;\n")])
           (with-output-to-string (lambda () (arithmetic-repl)))) "--> 5\n--> 5\n--> ")
   (reject (lambda () (parameterize ([current-input-port (open-input-string "5+")]
                                   [current-output-port (open-output-string)]) (arithmetic-repl)))))
  (test-case "stream errors are distinct from clean end of input"
   (for ([source '("5;@2;" "@" "5;@" "5;2+" "5;;")])
     (reject (lambda () (parameterize ([current-input-port (open-input-string source)]
                                     [current-output-port (open-output-string)]) (arithmetic-repl)))))
   (same (parameterize ([current-input-port (open-input-string "5;% arbitrary @ _\n2+3;\n")])
           (with-output-to-string (lambda () (arithmetic-repl)))) "--> 5\n--> 5\n--> ")
   (same (parameterize ([current-input-port (open-input-string "")])
           (with-output-to-string (lambda () (arithmetic-repl)))) "--> "))
  (test-case "B.1 and B.3 precedence, parentheses, left associativity"
   (for ([source '("3+2*66-5" "20-5-3" "48/4/3" "1/2+1/3" "2*(3+4)" "8/(2*2)" "0004+2" "7" "2+3*4/2-1")]
         [expected '(130 12 4 5/6 14 2 6 7 7)])
     (same (calculate source #:mode 'base) expected))
   (for* ([a (in-range 0 4)] [b (in-range 1 4)] [c (in-range 1 4)])
     (same (calculate (format "~a-~a-~a" a b c) #:mode 'base) (- a b c))
     (same (calculate (format "~a/~a/~a" a b c) #:mode 'base) (/ a b c))))
  (test-case "B.4 environments, shadowing, feature boundaries"
   (same (calculate "x-y*3" '((x . 7) (y . 2)) #:mode 'variables) 1)
   (same (calculate "x+x" '((x . 3) (x . 100)) #:mode 'variables) 6)
   (same (calculate "x/2" '((x . 3)) #:mode 'variables) 3/2)
   (reject (lambda () (calculate "x+1" #:mode 'variables)))
   (reject (lambda () (parse-base "x+1")))
   (reject (lambda () (parse-variables "-2")))
   (reject (lambda () (calculate "x" '((x . "3")))))
   (reject (lambda () (parse-arithmetic "1" #:mode 'unknown))))
  (test-case "B.5 syntactic unary minus and arithmetic failures"
   (for ([source '("3*-2" "--2" "-(3+2)*4" "3--2" "-x*-y" "-8/2/2")]
         [expected '(-6 2 -20 5 14 -2)])
     (same (calculate source '((x . 7) (y . 2))) expected))
   (same (calculate "1 % comment may contain @ and _\n+2") 3)
   (for ([source '("" "1+" "(1+2" "1 2" "3**2" "1@2" "1/0" "1/(2-2)" "2)" "+2")])
     (reject (lambda () (calculate source)))))
  (test-case "arbno versus separated-list and nested output lists"
   (same (block-datum (parse-terminated "{}")) '())
   (same (block-datum (parse-terminated "{x:=y;z:=t;}")) '((x y) (z t)))
   (same (block-datum (parse-separated "{}")) '())
   (same (block-datum (parse-separated "{x:=y;z:=t}")) '((x y) (z t)))
   (reject (lambda () (parse-separated "{x:=y;z:=t;}")))
   (reject (lambda () (parse-terminated "{x:=y}")))
   (same (bindings-datum (parse-bindings "let x = y u = v in z"))
         '(let (x u) ((var y) (var v)) (var z)))
   (same (parallel-datum (parse-parallel "{x,y := u,v ; z := 4; t1,t2 := 5,6}"))
         '(((x y) (z) (t1 t2)) ((u v) (4) (5 6))))
   ;; The original grammar permits mismatched list lengths; parsing is not checking.
   (same (parallel-datum (parse-parallel "{x,y := 1}")) '(((x y)) ((1))))
   (same (parallel-datum (parse-parallel "{}")) '(() ()))
   (reject (lambda () (parse-parallel "{x:=1;}"))))))
(module+ main
 (define failures (run-tests suite))
 (displayln (jsexpr->string (hash 'status (if (zero? failures) "passed" "failed") 'groups 7 'assertions assertions 'failures failures)))
 (exit (if (zero? failures) 0 1)))
