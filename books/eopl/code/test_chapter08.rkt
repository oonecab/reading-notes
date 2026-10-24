#lang racket
(require (except-in rackunit check) rackunit/text-ui json "chapter08.rkt" "chapter08_examples.rkt")
(define assertions 0)
(define-syntax-rule (is a b) (begin (set! assertions (add1 assertions)) (check-equal? a b)))
(define (reject thunk [kind #f])
  (set! assertions (add1 assertions))
  (check-exn (lambda (e) (and (exn:fail:typing? e) (or (not kind) (eq? kind (exn:fail:typing-kind e))))) thunk))
(define (accept p t v) (is (check p) t) (is (run p) v))
(define (conversions arithmetic)
  (string-append arithmetic to-int-maker from-int-maker
   "module to-i interface [to-int:(from ints1 take t -> int)] body (to-int-maker ints1)\n"
   "module from-i interface [from-int:(int -> from ints1 take t)] body (from-int-maker ints1)\n"))
(define suite
 (test-suite "chapter8"
  (test-case "source examples and export filtering"
    (accept example8-1 'int 22)
    (for ([p (list example8-2 example8-3 example8-4 example8-5-reversed example8-7-invalid)]) (reject (lambda () (check p))))
    (accept example8-5 'int 11) (accept example8-6 '(int -> bool) '<procedure>)
    (accept example8-7 '((from m1 take t) -> bool) '<procedure>)
    (accept (string-append colors "(from colors take is-red? from colors take green)") 'bool #f)
    (accept (string-append ints1 (two-client 'ints1)) '(from ints1 take t) 10)
    (accept (string-append ints2 (two-client 'ints2)) '(from ints2 take t) -6)
    (accept (string-append ints1 (local-to-int-client 'ints1)) 'int 2)
    (accept (string-append ints2 (local-to-int-client 'ints2)) 'int 2)
    (accept (string-append mybool "((from mybool take and from mybool take true) from mybool take false)") '(from mybool take t) 13)
    (accept example8-15 'int 2) (accept example8-16 'int 0)
    (is (run example8-4 #:unordered? #t) 44)
    (define hidden "module m interface [a:int] body [a=33 secret=44] from m take secret")
    (reject (lambda () (check hidden)) 'hidden)
    (reject (lambda () (run hidden #:check? #f)) 'runtime-hidden)
    (reject (lambda () (check "module m interface [] body [] module m interface [] body [] 0")) 'duplicate)
    (reject (lambda () (check "module m interface [] body [unused=-(zero?(0),1)] 0"))))
  (test-case "grammar, sequential scope and module components"
    (accept "module m interface [a:int b:int] body [a=4 b=-(a,1)] -(m.a,m.b)" 'int 1)
    (accept "let x=7 in let x=1 y=x in -(y,x)" 'int 6)
    (accept "(proc(x:int,y:int) -(x,y) 7 2)" 'int 5)
    (accept exercise8-5 'bool #t) (accept exercise8-6 'int 32) (accept exercise8-7 'int 33)
    (accept "module m interface [p:pairof int * int] body [p=newpair(3,4)] unpair x y=from m take p in -(y,x)" 'int 1)
    (reject (lambda () (check (string-replace exercise8-6 "from m1 take v" "from m2 take v"))) 'module-unbound)
    (reject (lambda () (check (string-replace exercise8-7 "n:[v:int]" "n:[u:int]"))))
    (reject (lambda () (parse-program "module m interface [x:int x:bool] body [] 0")) 'duplicate)
    (reject (lambda () (parse-program "proc(x:int,x:int)x")) 'duplicate)
    (reject (lambda () (parse-program "1 @")) 'parse)
    (reject (lambda () (check "proc(x) x")) 'annotation)
    (reject (lambda () (check "module m interface [x:int] body [x=y y=1] 0")) 'unbound)
    (accept "module m interface [f:(int -> int)] body let n=7 in [f=proc(x:int) -(x,n)] (from m take f 10)" 'int 3))
  (test-case "interface order, opacity, variance and alpha conversion"
    (for ([row (list
      (list "[u:int v:bool z:int]" "[u:int z:int]" #t)
      (list "[u:int z:int]" "[u:int v:bool z:int]" #f)
      (list "[v:int u:int]" "[u:int v:int]" #f)
      (list "[transparent t=int x:bool y:t]" "[y:int]" #t)
      (list "[transparent t=int transparent u=(t -> t) f:(t -> u)]" "[opaque t transparent u=(t -> int) f:(t -> (int -> int))]" #t)
      (list "[transparent t=int z:t]" "[opaque t z:t]" #t)
      (list "[opaque t z:t]" "[transparent t=int z:t]" #f)
      (list "[opaque t z:t]" "[opaque t z:t]" #t)
      (list "[x:int]" "[]" #t) (list "[]" "[x:int]" #f)
      (list "((A:[x:int]) => [y:int z:bool])" "((B:[x:int more:bool]) => [y:int])" #t)
      (list "((A:[x:int more:bool]) => [y:int])" "((B:[x:int]) => [y:int])" #f)
      (list "((A:[opaque t z:t]) => [out:(from A take t -> int)])" "((B:[opaque t z:t]) => [out:(from B take t -> int)])" #t)
      (list "((A:[opaque t z:t]) => [out:from A take t])" "((B:[transparent t=int z:t]) => [out:int])" #t)
      (list "[x:int]" "((A:[]) => [])" #f))])
      (is (compare-interfaces (first row) (second row)) (third row)))
    (is (compare-interfaces "[v:int u:int]" "[u:int v:int]" #:unordered? #t) #t))
  (test-case "expanded type invariant and nominal identity"
    (reject (lambda () (check (string-replace example8-16 "(to-ints2 two2)" "(to-ints2 two1)"))))
    (reject (lambda () (check (string-append ints1 "-(from ints1 take zero,0)"))))
    (accept "module a interface [opaque t z:t] body [type t=int z=0] module b interface [transparent t=from a take t z:t] body [type t=from a take t z=from a take z] proc(x:from b take t)x"
      '((from a take t) -> (from a take t)) '<procedure>)
    (reject (lambda () (check "module a interface [opaque t z:t] body [type t=int z=0] module b interface [opaque t z:t] body [type t=from a take t z=from a take z] (proc(x:from a take t)x from b take z)")))
    (accept "module m interface [transparent t=int transparent u=(t -> t) f:u] body [type t=int type u=(t -> t) f=proc(x:t)x] (from m take f 22)" 'int 22)
    (reject (lambda () (check "module m interface [x:t opaque t] body [type t=int x=1] 0")) 'type-unbound)
    (reject (lambda () (check "module m interface [transparent t=int] body [type t=t] 0")) 'type-unbound)
    (reject (lambda () (check "module m interface [x:u transparent u=int] body [x=1 type u=int] 0" #:unordered? #t)))
    (is (run "module m interface [transparent t=int x:t] body [x=7 type t=int] from m take x" #:unordered? #t) 7)
    (accept "module m interface [opaque t z:t] body [type hidden=int type t=hidden z=0] from m take z" '(from m take t) 0))
  (test-case "module closures, result projection and general application"
    (accept #<<END
module A interface [] body []
module F interface ((X:[]) => [v:int]) body let captured=7 in module-proc(X:[]) [v=captured]
module B interface [v:int] body let captured=100 in (F A)
from B take v
END
 'int 7)
    (accept #<<END
module A interface [z:int] body [z=12]
module G interface ((X:[z:int]) => [x:int]) body module-proc(X:[z:int]) [x=from X take z]
module F interface ((X:[x:int]) => [y:int]) body module-proc(X:[x:int]) [y=-(from X take x,1)]
module R interface [y:int] body (F (G A))
from R take y
END
 'int 11)
    (reject (lambda () (check "module A interface [] body [] module R interface [] body (A A) 0")) 'module-kind)
    (define base #<<END
module A interface [] body []
module make interface ((X:[]) => [opaque t z:t]) body module-proc(X:[]) [type t=int z=0]
module one interface [opaque t z:t] body (make A)
module two interface [opaque t z:t] body (make A)
END
)
    (accept (string-append base "(proc(x:from one take t) zero?(0) from one take z)") 'bool #t)
    (reject (lambda () (check (string-append base "(proc(x:from one take t) zero?(0) from two take z)"))))
    (reject (lambda () (run #<<END
module A interface [] body []
module F interface ((X:[]) => [x:int]) body module-proc(X:[]) [x=1 hidden=99]
module R interface [x:int] body (F A)
from R take hidden
END
 #:check? #f)) 'runtime-hidden))
  (test-case "arithmetic, tables and signed equality"
    (accept (string-append tables table-client) 'int 100)
    (accept (string-append multi-tables multi-table-client) 'int 100)
    (accept exercise8-19 'int 0)
    (accept (string-append shifted-ints (local-to-int-client 'ints3)) 'int 2)
    (is (run (string-append shifted-ints (two-client 'ints3))) 13)
    (for ([factor '(5 -3)] [offset '(3 0)])
      (define base (conversions (arithmetic-module 'ints1 factor offset)))
      (for ([n (in-range -7 9)])
        (is (run (string-append base (format "(from from-i take from-int ~a)" n))) (+ (* factor n) offset)))
      (define eqbase (string-append base equality-maker
        "module eq interface [equal:(from ints1 take t -> (from ints1 take t -> bool))] body (equality-maker ints1)\n"))
      (for* ([x (in-range -3 4)] [y (in-range -3 4)])
        (is (run (string-append eqbase (format "((from eq take equal (from from-i take from-int ~a)) (from from-i take from-int ~a))" x y))) (= x y)))
      (define ops (string-append base sum-prod-maker
        "module ops interface [plus:(from ints1 take t -> (from ints1 take t -> from ints1 take t)) times:(from ints1 take t -> (from ints1 take t -> from ints1 take t))] body (sum-prod-maker ints1)\n"))
      (for* ([x (in-range 5)] [y (in-range 5)] [op '(plus times)])
        (is (run (string-append ops (format "(from to-i take to-int ((from ops take ~a (from from-i take from-int ~a)) (from from-i take from-int ~a)))" op x y)))
            ((if (eq? op 'plus) + *) x y)))
      (for* ([x (in-range -3 4)] [y (in-range -3 4)] [op '(plus times)])
        (is (run (string-append ops (format "((from ops take ~a (from from-i take from-int ~a)) (from from-i take from-int ~a))" op x y)))
            (+ (* factor ((if (eq? op 'plus) + *) x y)) offset))))
    (define doubled (string-append ints1 doubling-maker "module twice interface " arithmetic-interface " body (doubling-maker ints1)\n"))
    (is (run (string-append doubled "(from twice take succ (from twice take succ from twice take zero))")) 20)
    (reject (lambda () (check (string-append doubled "(from ints1 take succ from twice take zero)"))))
    (define bt (string-append mybool table-of mybool-tables))
    (is (run (string-append bt "(from mybool take to-bool ((from mybool-tables take lookup-in-table 3) (((from mybool-tables take add-to-table 3) from mybool take true) from mybool-tables take empty)))")) #t)
    (is (run (string-append bt "(from mybool take to-bool ((from mybool-tables take lookup-in-table 55) from mybool-tables take empty))")) #f)
    (is (run (string-append tables "((from tables take lookup-in-table -2) from tables take empty)")) 0))
  (test-case "abstract booleans and external rewriting"
    (for* ([base (list mybool alternate-mybool)] [x '("true" "false")])
      (is (run (string-append base (format "(from mybool take to-bool from mybool take ~a)" x))) (equal? x "true"))
      (is (run (string-append base (format "(from mybool take to-bool (from mybool take not from mybool take ~a))" x))) (equal? x "false"))
      (for ([y '("true" "false")])
        (is (run (string-append base (format "(from mybool take to-bool ((from mybool take and from mybool take ~a) from mybool take ~a))" x y)))
            (and (equal? x "true") (equal? y "true")))))
    (define client #<<END
let and=proc(x:from mybool take t) proc(y:from mybool take t)
         if (from mybool take to-bool x) then y else from mybool take false
in let not=proc(x:from mybool take t)
         if (from mybool take to-bool x) then from mybool take false else from mybool take true
in if (from mybool take to-bool ((and (not from mybool take false)) from mybool take true)) then 11 else 22
END
)
    (is (run (string-append mybool client)) 11) (is (run (string-append alternate-mybool client)) 11)
    (reject (lambda () (check (string-append mybool "proc(x:from mybool take t) zero?(x)"))))
    (define (tree n)
      (if (zero? n) "from mybool take true"
          (case (modulo n 3)
            [(0) (format "(from mybool take not ~a)" (tree (sub1 n)))]
            [(1) (format "((from mybool take and ~a) from mybool take false)" (tree (sub1 n)))]
            [else (format "((from mybool take and from mybool take true) ~a)" (tree (sub1 n)))])))
    (for ([n (in-range 31)])
      (define c (format "if (from mybool take to-bool ~a) then 17 else 29" (tree n)))
      (is (run (string-append mybool c)) (run (string-append alternate-mybool c)))))
  (test-case "explicit dependencies and lazy memoized imports"
    (define p #<<END
module m1 interface [x:int] body depends-on [x=7]
module m2 interface [y:int] body depends-on m1 [y=from m1 take x]
depends-on m2
from m2 take y
END
)
    (is (run p #:dependencies 'depends-on) 7)
    (reject (lambda () (check (string-replace p "depends-on m1 [y=" "depends-on [y=") #:dependencies 'depends-on)) 'module-unbound)
    (reject (lambda () (check (string-replace p "depends-on m2\nfrom" "depends-on m1\nfrom") #:dependencies 'depends-on)) 'module-unbound)
    (define r (run/trace exercise8-10 #:dependencies 'imports))
    (is (execution-value r) 33) (is (execution-output r) '(2 3 1))
    (is (sort (hash-values (execution-module-evaluations r)) <) '(1 1 1))
    (define r2 (run/trace exercise8-10-explicit #:dependencies 'imports))
    (is (execution-output r2) '(2 3 1))
    (is (hash-ref (execution-module-evaluations r2) 'base) 1)
    (is (hash-has-key? (execution-module-evaluations r2) 'unused) #f)
    (define never "module never interface [] body [x=letrec int loop(x:int)=(loop x) in (loop 0)] 33")
    (is (run never #:dependencies 'imports #:fuel 50) 33)
    (reject (lambda () (run never #:fuel 50)) 'fuel)
    (for ([fuel (list -1 1/2 #f 0 2.0)])
      (reject (lambda () (run "1" #:fuel fuel)) 'fuel))
    (is (run "1" #:fuel 1) 1)
    (reject (lambda () (check "module m interface [] body imports later [] 33" #:dependencies 'imports)) 'dependency))
  (test-case "consistent inference and named interfaces"
    (define id "module m interface [f:(int -> int)] body [f=proc(x:?)x] (from m take f 33)")
    (is (check id #:inferred? #t) 'int) (is (run id #:inferred? #t) 33)
    (reject (lambda () (check id)) 'annotation)
    (reject (lambda () (check (string-replace id "[f:(int -> int)]" "[f:(int -> bool)]") #:inferred? #t)))
    (reject (lambda () (check "module m interface [f:(int -> int) g:(bool -> bool)] body [f=proc(x:?)x g=f] 0" #:inferred? #t)))
    (reject (lambda () (check "module m interface [] body [f=proc(x:?) (x x)] 0" #:inferred? #t)) 'occurs)
    (define inferred-functor #<<END
module F interface ((A:[transparent t=int z:t]) => [f:(int -> int)])
body module-proc(A:[opaque t z:t]) [f=proc(x:?) if zero?(0) then x else from A take z]
module A interface [transparent t=int z:t] body [type t=int z=3]
module R interface [f:(int -> int)] body (F A)
(from R take f 7)
END
)
    (is (check inferred-functor #:inferred? #t) 'int)
    (is (run inferred-functor #:inferred? #t) 7)
    (accept named-interface-example 'int 1)
    (reject (lambda () (check "interface A=B 0")) 'interface-unbound)
    (reject (lambda () (check "interface A=[] interface A=[] 0")) 'duplicate)
    (accept "module old interface [transparent t=int] body [type t=int] interface saved=[x:from old take t] module result interface saved body [x=11] from result take x" 'int 11))
  (test-case "multiple module arguments and dependent parameter interfaces"
    (define p #<<END
module F interface ((A:[x:int],B:[y:int]) => [z:int])
body module-proc(A:[x:int],B:[y:int]) [z=-(from A take x,from B take y)]
module A interface [x:int] body [x=9]
module B interface [y:int] body [y=4]
module R interface [z:int] body (F A B)
from R take z
END
)
    (accept p 'int 5)
    (reject (lambda () (check (string-replace p "(F A B)" "(F A)"))) 'arity)
    (define dependent (string-append ints1 #<<END
module F interface ((A:[opaque t zero:t],B:[x:from A take t]) => [y:from A take t])
body module-proc(A:[opaque t zero:t],B:[x:from A take t]) [y=from B take x]
module B interface [x:from ints1 take t] body [x=from ints1 take zero]
module R interface [y:from ints1 take t] body (F ints1 B)
from R take y
END
))
    (accept dependent '(from ints1 take t) 0)
    (reject (lambda () (check (string-replace dependent "module B interface [x:from ints1 take t] body [x=from ints1 take zero]"
                                                        "module B interface [x:int] body [x=0]")))))))
(module+ main
  (define failures (run-tests suite))
  (write-json (hash 'status (if (zero? failures) "passed" "failed") 'groups 10 'assertions assertions 'failures failures))
  (newline) (unless (zero? failures) (exit 1)))
