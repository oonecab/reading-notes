#lang racket
;; Source examples and complete exercise implementations in the object language.
(provide (all-defined-out))
(define arithmetic-interface "[opaque t zero:t succ:(t -> t) pred:(t -> t) is-zero:(t -> bool)]")
(define (arithmetic-module name factor [offset 0])
  (format "module ~a interface ~a body [type t=int zero=~a succ=proc(x:t) -(x,~a) pred=proc(x:t) -(x,~a) is-zero=proc(x:t) zero?(-(x,~a))]\n"
          name arithmetic-interface offset (- factor) factor offset))
(define ints1 (arithmetic-module 'ints1 5))
(define ints2 (arithmetic-module 'ints2 -3))
(define shifted-ints (arithmetic-module 'ints3 5 3))
(define example8-1 #<<END
module m1 interface [a:int b:int c:int]
body [a=33 x=-(a,1) b=-(a,x) c=-(x,b)]
let a=10 in -(-(from m1 take a,from m1 take b),a)
END
)
(define example8-2 "module m1 interface [u:bool] body [u=33] 44")
(define example8-3 "module m1 interface [u:int v:int] body [u=33] 44")
(define example8-4 "module m1 interface [u:int v:int] body [v=33 u=44] from m1 take u")
(define example8-5 #<<END
module m1 interface [u:int] body [u=44]
module m2 interface [v:int] body [v=-(from m1 take u,11)]
-(from m1 take u,from m2 take v)
END
)
(define example8-5-reversed #<<END
module m2 interface [v:int] body [v=-(from m1 take u,11)]
module m1 interface [u:int] body [u=44]
-(from m1 take u,from m2 take v)
END
)
(define (typed-example opacity suffix)
  (string-append "module m1 interface [" opacity " z:t s:(t -> t) is-z?:(t -> bool)]\n"
                 "body [type t=int z=33 s=proc(x:t) -(x,-1) is-z?=proc(x:t) zero?(-(x,z))]\n" suffix))
(define example8-6 (typed-example "transparent t=int" "proc(x:from m1 take t) (from m1 take is-z? -(x,0))"))
(define example8-7-invalid (typed-example "opaque t" "proc(x:from m1 take t) (from m1 take is-z? -(x,0))"))
(define example8-7 (typed-example "opaque t" "proc(x:from m1 take t) (from m1 take is-z? x)"))
(define colors #<<END
module colors interface [opaque color red:color green:color is-red?:(color -> bool)]
body [type color=int red=0 green=1 is-red?=proc(c:color) zero?(c)]
END
)
(define mybool-interface "[opaque t true:t false:t and:(t -> (t -> t)) not:(t -> t) to-bool:(t -> bool)]")
(define mybool
  (string-append "module mybool interface " mybool-interface #<<END
 body [type t=int true=0 false=13
 and=proc(x:t) proc(y:t) if zero?(x) then y else false
 not=proc(x:t) if zero?(x) then false else true
 to-bool=proc(x:t) zero?(x)]
END
))
(define alternate-mybool
  (string-append "module mybool interface " mybool-interface #<<END
 body [type t=int true=1 false=0
 and=proc(x:t) proc(y:t) if zero?(x) then false else y
 not=proc(x:t) if zero?(x) then true else false
 to-bool=proc(x:t) if zero?(x) then zero?(1) else zero?(0)]
END
))
(define (two-client name)
  (format "let z=from ~a take zero in let s=from ~a take succ in (s (s z))" name name))
(define (local-to-int-client name)
  (format #<<END
let z=from ~a take zero in let s=from ~a take succ
in let p=from ~a take pred in let z?=from ~a take is-zero
in letrec int to-int(x:from ~a take t)=if (z? x) then 0 else -((to-int (p x)),-1)
in (to-int (s (s z)))
END
 name name name name name))
(define to-int-maker
  (format #<<END
module to-int-maker
interface ((ints:~a) => [to-int:(from ints take t -> int)])
body module-proc (ints:~a)
 [to-int=let z?=from ints take is-zero in let p=from ints take pred
 in letrec int to-int(x:from ints take t)=if (z? x) then 0 else -((to-int (p x)),-1)
 in to-int]
END
 arithmetic-interface arithmetic-interface))
(define (conversion-instance argument result)
  (format "module ~a interface [to-int:(from ~a take t -> int)] body (to-int-maker ~a)\n" result argument argument))
(define example8-15
  (string-append to-int-maker ints1 (conversion-instance 'ints1 'ints1-to-int)
   "let two1=(from ints1 take succ (from ints1 take succ from ints1 take zero)) in (from ints1-to-int take to-int two1)"))
(define example8-16
  (string-append to-int-maker ints1 ints2 (conversion-instance 'ints1 'ints1-to-int) (conversion-instance 'ints2 'ints2-to-int)
   #<<END
let s1=from ints1 take succ in let z1=from ints1 take zero
in let to-ints1=from ints1-to-int take to-int
in let s2=from ints2 take succ in let z2=from ints2 take zero
in let to-ints2=from ints2-to-int take to-int
in let two1=(s1 (s1 z1)) in let two2=(s2 (s2 z2))
in -((to-ints1 two1),(to-ints2 two2))
END
))
(define table-interface "[opaque table empty:table add-to-table:(int -> (int -> (table -> table))) lookup-in-table:(int -> (table -> int))]")
(define tables
  (string-append "module tables interface " table-interface #<<END
 body [type table=(int -> int)
 empty=proc(key:int) 0
 add-to-table=proc(key:int) proc(value:int) proc(old:table)
               proc(query:int) if zero?(-(query,key)) then value else (old query)
 lookup-in-table=proc(key:int) proc(tab:table) (tab key)]
END
))
(define table-client #<<END
let empty=from tables take empty in let add-binding=from tables take add-to-table
in let lookup=from tables take lookup-in-table
in let table1=(((add-binding 3) 300) (((add-binding 4) 400) (((add-binding 3) 600) empty)))
in -(((lookup 4) table1),((lookup 3) table1))
END
)
(define multi-tables #<<END
module tables
interface [opaque table empty:table add-to-table:(int * int * table -> table) lookup-in-table:(int * table -> int)]
body [type table=(int -> int) empty=proc(key:int) 0
 add-to-table=proc(key:int,value:int,old:table) proc(query:int) if zero?(-(query,key)) then value else (old query)
 lookup-in-table=proc(key:int,tab:table) (tab key)]
END
)
(define multi-table-client #<<END
let empty=from tables take empty in let add=from tables take add-to-table
in let lookup=from tables take lookup-in-table
in let tab=(add 3 300 (add 4 400 (add 3 600 empty)))
in -((lookup 4 tab),(lookup 3 tab))
END
)
(define from-int-maker
  (format #<<END
module from-int-maker
interface ((ints:~a) => [from-int:(int -> from ints take t)])
body module-proc (ints:~a)
 [from-int=proc(n:int)
   let z=from ints take zero in let s=from ints take succ in let p=from ints take pred
   in letrec from ints take t loop(up:int,down:int,a:from ints take t,b:from ints take t)=
      if zero?(up) then a else if zero?(down) then b
      else (loop -(up,1) -(down,-1) (s a) (p b))
   in (loop n n z z)]
END
 arithmetic-interface arithmetic-interface))
(define exercise8-19
  (string-append ints1 ints2 from-int-maker to-int-maker
   (conversion-instance 'ints1 'to1) (conversion-instance 'ints2 'to2)
   "module from1 interface [from-int:(int -> from ints1 take t)] body (from-int-maker ints1)\n"
   "module from2 interface [from-int:(int -> from ints2 take t)] body (from-int-maker ints2)\n"
   "let a=(from from1 take from-int 7) in let b=(from from2 take from-int 7) in -((from to1 take to-int a),(from to2 take to-int b))"))
(define sum-prod-maker
  (format #<<END
module sum-prod-maker
interface ((ints:~a) => [plus:(from ints take t -> (from ints take t -> from ints take t))
                        times:(from ints take t -> (from ints take t -> from ints take t))])
body module-proc (ints:~a)
 let z=from ints take zero in let s=from ints take succ in let p=from ints take pred
 in let z?=from ints take is-zero
 in [negate=proc(x:from ints take t)
      letrec from ints take t loop(up:from ints take t,down:from ints take t,a:from ints take t,b:from ints take t)=
       if (z? up) then a else if (z? down) then b
       else (loop (p up) (s down) (p a) (s b))
      in (loop x x z z)
     plus=proc(x:from ints take t) proc(y:from ints take t)
      letrec from ints take t loop(up:from ints take t,down:from ints take t,a:from ints take t,b:from ints take t)=
       if (z? up) then a else if (z? down) then b
       else (loop (p up) (s down) (s a) (p b))
      in (loop x x y y)
     times=proc(x:from ints take t) proc(y:from ints take t)
      let negative-y=(negate y)
      in letrec from ints take t loop(up:from ints take t,down:from ints take t,a:from ints take t,b:from ints take t)=
       if (z? up) then a else if (z? down) then b
       else (loop (p up) (s down) ((plus y) a) ((plus negative-y) b))
      in (loop x x z z)]
END
 arithmetic-interface arithmetic-interface))
(define doubling-maker
  (format #<<END
module doubling-maker interface ((ints:~a) => ~a)
body module-proc (ints:~a)
 [type t=from ints take t zero=from ints take zero
 succ=proc(x:t) (from ints take succ (from ints take succ x))
 pred=proc(x:t) (from ints take pred (from ints take pred x))
 is-zero=from ints take is-zero]
END
 arithmetic-interface arithmetic-interface arithmetic-interface))
(define equality-maker
  (format #<<END
module equality-maker
interface ((ints:~a) => [equal:(from ints take t -> (from ints take t -> bool))])
body module-proc (ints:~a)
 let z?=from ints take is-zero in let p=from ints take pred in let s=from ints take succ
 in [equal=proc(x:from ints take t) proc(y:from ints take t)
  letrec bool loop(xp:from ints take t,xn:from ints take t,yp:from ints take t,yn:from ints take t)=
   if (z? xp) then (z? yp) else if (z? xn) then (z? yn)
   else (loop (p xp) (s xn) (p yp) (s yn))
  in (loop x x y y)]
END
 arithmetic-interface arithmetic-interface))
(define table-of #<<END
module table-of
interface ((contents:[opaque t false:t]) =>
 [opaque table empty:table
  add-to-table:(int -> (from contents take t -> (table -> table)))
  lookup-in-table:(int -> (table -> from contents take t))])
body module-proc (contents:[opaque t false:t])
 [type table=(int -> from contents take t)
 empty=proc(key:int) from contents take false
 add-to-table=proc(key:int) proc(value:from contents take t) proc(old:table)
  proc(query:int) if zero?(-(query,key)) then value else (old query)
 lookup-in-table=proc(key:int) proc(tab:table) (tab key)]
END
)
(define mybool-tables #<<END
module mybool-tables
interface [opaque table empty:table
 add-to-table:(int -> (from mybool take t -> (table -> table)))
 lookup-in-table:(int -> (table -> from mybool take t))]
body (table-of mybool)
END
)
(define exercise8-5 #<<END
module even-odd interface [even:(int -> bool) odd:(int -> bool)]
body letrec bool local-odd(x:int)=if zero?(x) then zero?(1) else (local-even -(x,1))
            bool local-even(x:int)=if zero?(x) then zero?(0) else (local-odd -(x,1))
in [even=local-even odd=local-odd]
(from even-odd take even 12)
END
)
(define exercise8-6 #<<END
module m1 interface [u:int v:int]
body module m2 interface [v:int] body [v=33]
 [u=44 v=-(from m2 take v,1)]
from m1 take v
END
)
(define exercise8-7 #<<END
module m1 interface [u:int n:[v:int]]
body module m2 interface [v:int] body [v=33]
 [u=44 n=m2]
from m1 take n take v
END
)
(define exercise8-10 #<<END
module m1 interface [] body [x=print(1)]
module m2 interface [] body [x=print(2)]
module m3 interface [] body import m2 [x=print(3)]
import m3,m1
33
END
)
(define exercise8-10-explicit #<<END
module base interface [] body imports []
module unused interface [] body imports base [x=print(99)]
module m1 interface [] body imports base [x=print(1)]
module m2 interface [] body imports base [x=print(2)]
module m3 interface [] body imports m2 [x=print(3)]
imports m3,m1,m2
33
END
)
;; The book's imports example leaves leaf clauses empty. In imports mode,
;; an omitted leaf clause is interpreted as imports[], never as all predecessors.
(define named-interface-example
  (string-append "interface int-interface=" arithmetic-interface "\n"
                 (string-replace to-int-maker arithmetic-interface "int-interface")
                 ints1 (conversion-instance 'ints1 'convert) "(from convert take to-int (from ints1 take succ from ints1 take zero))"))
