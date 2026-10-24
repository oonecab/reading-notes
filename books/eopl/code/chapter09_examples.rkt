#lang racket
(require json "chapter09.rkt")
(provide (all-defined-out))
(define figure9-1 #<<END
class c1 extends object
 field i
 field j
 method initialize (x)
  begin
   set i = x;
   set j = -(0,x)
  end
 method countup (d)
  begin
   set i = +(i,d);
   set j = -(j,d)
  end
 method getstate () list(i,j)
let t1 = 0
    t2 = 0
    o1 = new c1(3)
in begin
    set t1 = send o1 getstate();
    send o1 countup(2);
    set t2 = send o1 getstate();
    list(t1,t2)
   end
END
)
(define figure9-2 #<<END
class interior-node extends object
  field left
  field right
  method initialize (l, r)
   begin
    set left = l;
    set right = r
   end
  method sum () +(send left sum(),send right sum())
 class leaf-node extends object
  field value
  method initialize (v) set value = v
  method sum () value
let o1 = new interior-node(
          new interior-node(
           new leaf-node(3),
           new leaf-node(4)),
          new leaf-node(5))
in send o1 sum()
END
)
(define figure9-3 #<<END
class point extends object
 field x
 field y
 method initialize (initx, inity)
  begin
   set x = initx;
   set y = inity
  end
 method move (dx, dy)
  begin
   set x = +(x,dx);
   set y = +(y,dy)
  end
 method get-location () list(x,y)
class colorpoint extends point
 field color
 method set-color (c) set color = c
 method get-color () color
let p = new point(3,4)
    cp = new colorpoint(10,20)
in begin
    send p move(3,4);
    send cp set-color(87);
    send cp move(10,20);
    list(send p get-location(),     % returns (6 8)
         send cp get-location(),    % returns (20 40)
         send cp get-color())       % returns 87
   end
END
)
(define figure9-4 #<<END
class c1 extends object
 field x
 field y
 method initialize () 1
 method setx1 (v) set x = v
 method sety1 (v) set y = v
 method getx1 () x
 method gety1 () y
class c2 extends c1
 field y
 method sety2 (v) set y = v
 method getx2 () x
 method gety2 () y
let o2 = new c2()
in begin
    send o2 setx1(101);
    send o2 sety1(102);
    send o2 sety2(999);
    list(send o2 getx1(),            % returns 101
         send o2 gety1(),            % returns 102
         send o2 getx2(),            % returns 101
         send o2 gety2())            % returns 999
   end
END
)
(define figure9-5 #<<END
class point extends object
 field x
 field y
 method initialize (initx, inity)
  begin
   set x = initx;
   set y = inity
  end
 method move (dx, dy)
  begin
   set x = +(x,dx);
   set y = +(y,dy)
  end
 method get-location () list(x,y)
class colorpoint extends point
 field color
 method initialize (initx, inity, initcolor)
  begin
   set x = initx;
   set y = inity;
   set color = initcolor
  end
 method set-color (c) set color = c
 method get-color () color
let o1 = new colorpoint(3,4,172)
in send o1 get-color()
END
)
(define figure9-6 #<<END
class c1 extends object
 method initialize () 1
 method m1 () send self m2()
 method m2 () 13
class c2 extends c1
 method m1 () 22
 method m2 () 23
 method m3 () super m1()
class c3 extends c2
 method m1 () 32
 method m2 () 33
let o3 = new c3()
in send o3 m3()
END
)
(define figure9-12 #<<END
interface tree
 method int sum ()
 method bool equal (t : tree)

class interior-node extends object implements tree
 field tree left
 field tree right
 method void initialize(l : tree, r : tree)
  begin
   set left = l; set right = r
  end
 method tree getleft () left
 method tree getright () right
 method int sum () +(send left sum(), send right sum())
 method bool equal (t : tree)
  if instanceof t interior-node
  then if send left equal(send
                           cast t interior-node
                           getleft())
       then send right equal(send
                              cast t interior-node
                              getright())
       else zero?(1)
  else zero?(1)

class leaf-node extends object implements tree
 field int value
 method void initialize (v : int) set value = v
 method int sum () value
 method int getvalue () value
 method bool equal (t : tree)
  if instanceof t leaf-node
  then zero?(-(value, send cast t leaf-node getvalue()))
  else zero?(1)

let o1 = new interior-node (
          new interior-node (
           new leaf-node(3),
           new leaf-node(4)),
         new leaf-node(5))
in list(send o1 sum(),
        if send o1 equal(o1) then 100 else 200)
END
)
(define oddeven #<<END
class oddeven extends object
 method initialize()1
 method even(n) if zero?(n) then 1 else send self odd(-(n,1))
 method odd(n) if zero?(n) then 0 else send self even(-(n,1))
END
)
(define override-self #<<END
class c1 extends object
 method initialize()1
 method m1()11
 method m2()send self m1()
class c2 extends c1
 method m1()22
let o1=new c1() o2=new c2()
in list(send o1 m1(),send o2 m1(),send o2 m2())
END
)
(define figure9-8-complete #<<END
class c1 extends object
 field x field y
 method initialize()begin set x=11;set y=12 end
 method m1()list(x,y)
 method m2()send self m3()
class c2 extends c1
 field y
 method initialize()begin super initialize();set y=22 end
 method m1(u,v)list(x,y,u,v)
 method m3()23
class c3 extends c2
 field x field z
 method initialize()begin super initialize();set x=31;set z=32 end
 method m3()list(x,y,z)
let o3=new c3() in send o3 m1(7,8)
END
)
(define queue-definitions #<<END
class counter extends object
 field n
 method initialize()set n=0
 method inc()begin set n=+(n,1);n end
 method get()n
class queue extends object
 field front field rear
 method initialize()begin set front=emptylist;set rear=emptylist end
 method empty?()if null?(front) then null?(rear) else zero?(1)
 method enqueue(x)set rear=cons(x,rear)
 method dequeue()
  begin
   if null?(front)
   then begin
    set front=letrec rev(xs,acc)=if null?(xs) then acc else (rev cdr(xs) cons(car(xs),acc))
              in (rev rear emptylist);
    set rear=emptylist
   end
   else 1;
   let answer=car(front) in begin set front=cdr(front);answer end
  end
class counted-queue extends queue
 field count field total
 method initialize(shared)
  begin super initialize();set count=0;set total=shared end
 method tick()begin set count=+(count,1);send total inc() end
 method enqueue(x)begin send self tick();super enqueue(x) end
 method dequeue()begin send self tick();super dequeue() end
 method empty?()begin send self tick();super empty?() end
 method own-count()count
 method total-count()send total get()
END
)
(define exercise9-1 #<<END
class counter extends object
 field n
 method initialize()set n=0
 method inc()begin set n=+(n,1);n end
 method get()n
class queue extends object
 field front field rear
 method initialize()begin set front=emptylist;set rear=emptylist end
 method empty?()if null?(front) then null?(rear) else zero?(1)
 method enqueue(x)set rear=cons(x,rear)
 method dequeue()
  begin
   if null?(front)
   then begin
    set front=letrec rev(xs,acc)=if null?(xs) then acc else (rev cdr(xs) cons(car(xs),acc))
              in (rev rear emptylist);
    set rear=emptylist
   end
   else 1;
   let answer=car(front) in begin set front=cdr(front);answer end
  end
class counted-queue extends queue
 field count field total
 method initialize(shared)
  begin super initialize();set count=0;set total=shared end
 method tick()begin set count=+(count,1);send total inc() end
 method enqueue(x)begin send self tick();super enqueue(x) end
 method dequeue()begin send self tick();super dequeue() end
 method empty?()begin send self tick();super empty?() end
 method own-count()count
 method total-count()send total get()
let total=new counter()
in let a=new counted-queue(total) b=new counted-queue(total)
in begin
 send a enqueue(10);send b enqueue(20);send a dequeue();send b empty?();
 list(send a own-count(),send b own-count(),send a total-count())
end
END
)
(define exercise9-2 #<<END
class oddeven extends object
 method initialize()1
 method even(n) if zero?(n) then 1 else send self odd(-(n,1))
 method odd(n) if zero?(n) then 0 else send self even(-(n,1))
class bogus-oddeven extends oddeven method even(n)0
let o1=new bogus-oddeven() in send o1 odd(13)
END
)
(define exercise9-9 #<<END
class A extends object
 field x
 method initialize()set x=1
 method parent-x()x
class B extends A
 field x
 method initialize()begin super initialize();set x=2 end
 method test()begin superfieldset x=7;list(superfieldref x,x) end
let b=new B() in send b test()
END
)
(define exercise9-10 #<<END
class A extends object
 field x
 method initialize()set x=1
 method m()11
class B extends A
 field x
 method initialize()begin super initialize();set x=2 end
 method m()22
let b=new B()
in begin named-fieldset A b x=7;
 list(send b m(),named-send A b m(),fieldref b x,named-fieldref A b x) end
END
)
(define exercise9-11 #<<END
class A extends object
 private method secret()17
 protected method middle()23
 method initialize()1
 method reveal()send self secret()
class B extends A
 method inherited-access()send self middle()
let b=new B() in list(send b reveal(),send b inherited-access())
END
)
(define exercise9-12 #<<END
class A extends object
 private field secret protected field shared
 method initialize()begin set secret=17;set shared=23 end
 method reveal()secret
class B extends A
 method inherited-access()shared
let b=new B() in list(send b reveal(),send b inherited-access())
END
)
(define exercise9-13 #<<END
class oddeven extends object
 method initialize () 1
 final method even (n)
  if zero?(n) then 1 else send self odd(-(n,1))
 final method odd (n)
  if zero?(n) then 0 else send self even(-(n,1))
let o=new oddeven() in send o odd(13)
END
)
(define exercise9-15 #<<END
class c1 extends object
 static next-serial-number = 1
 field my-serial-number
 method get-serial-number () my-serial-number
 method initialize ()
  begin
   set my-serial-number = next-serial-number;
   set next-serial-number = +(next-serial-number,1)
  end
let o1 = new c1()
    o2 = new c1()
in list(send o1 get-serial-number(),
        send o2 get-serial-number())
END
)
(define exercise9-16 #<<END
class A extends object
 field x
 method initialize()set x=0
 method initialize(v)set x=v
 method get()x
let a=new A() b=new A(7) in list(send a get(),send b get())
END
)
(define exercise9-17 #<<END
class C extends object method initialize()1 method get()11
let a=new C()
in let b=letclass C=extends object method initialize()1 method get()22 in new C()
in list(send a get(),send b get(),send new C() get())
END
)
(define point-definitions #<<END
class point extends object
 field x field y
 method initialize(a,b)begin set x=a;set y=b end
 method getx()x method gety()y
 method similarpoints(pt)
  if equal?(send pt getx(),x) then equal?(send pt gety(),y) else zero?(1)
class colorpoint extends point
 field color
 method initialize(a,b,c)begin super initialize(a,b);set color=c end
 method getcolor()color
 method similarpoints(pt)
  if super similarpoints(pt)
  then if instanceof pt colorpoint then equal?(send pt getcolor(),color) else zero?(0)
  else zero?(1)
END
)
(define exercise9-25 #<<END
class point extends object
 field x field y
 method initialize(a,b)begin set x=a;set y=b end
 method getx()x method gety()y
 method similarpoints(pt)
  if equal?(send pt getx(),x) then equal?(send pt gety(),y) else zero?(1)
class colorpoint extends point
 field color
 method initialize(a,b,c)begin super initialize(a,b);set color=c end
 method getcolor()color
 method similarpoints(pt)
  if super similarpoints(pt)
  then if instanceof pt colorpoint then equal?(send pt getcolor(),color) else zero?(0)
  else zero?(1)
let p=new point(3,4) c=new colorpoint(3,4,7) d=new colorpoint(3,4,8)
in list(send p similarpoints(p),send p similarpoints(c),send c similarpoints(p),send c similarpoints(c),send c similarpoints(d))
END
)
(define exercise9-26 #<<END
class A extends object
 field x method initialize()set x=0 method get()x
class B extends A method left(v)set x=v
class C extends A method right(v)set x=v
class D extends B,C
let d=new D() in begin send d left(7);send d right(9);send d get() end
END
)
(define exercise9-27 #<<END
let make-oddeven
 = proc ()
    newobject
     even = proc (n) if zero?(n) then 1
                     else (getmethod(self,odd) -(n,1))
     odd = proc (n) if zero?(n) then 0
                    else (getmethod(self,even) -(n,1))
    endnewobject
in let o1 = (make-oddeven) in (getmethod(o1,odd) 13)
END
)
(define exercise9-28 #<<END
let make=proc()
 let x=0 in newobject
  get=proc()x
  inc=proc()set x=+(x,1)
  m=proc()(getmethod(self,n))
  n=proc()1
 endnewobject
in let parent=(make)
in let child=newobject extends parent n=proc()2 endnewobject
in begin (getmethod(child,inc));
 list((getmethod(parent,get)),(getmethod(child,get)),(getmethod(parent,m)),(getmethod(child,m))) end
END
)
(define exercise9-29 #<<END
let object=emptyobject x=100 z=7
in let parent=extend object field x=3 method get()+(x,z) method inc()set x=+(x,1) endextend
in let a=clone parent b=clone parent
in begin send a inc();list(send parent get(),send a get(),send b get()) end
END
)
(define summable-definitions #<<END
interface summable method int sum()
interface stringable method string to-string()
interface item method int sum() method string to-string()
class nil extends object implements summable implements stringable implements item
 method void initialize()unit
 method int sum()0
 method string to-string()"[]"
class link extends object implements summable implements stringable implements item
 field item head field item tail
 method void initialize(h:item,t:item)begin set head=h;set tail=t end
 method int sum()+(send head sum(),send tail sum())
 method string to-string()concat("(",concat(send head to-string(),concat(",",concat(send tail to-string(),")"))))
class leaf extends object implements summable implements stringable implements item
 field int value
 method void initialize(v:int)set value=v
 method int sum()value
 method string to-string()number-to-string(value)
class branch extends object implements summable implements stringable implements item
 field item left field item right
 method void initialize(l:item,r:item)begin set left=l;set right=r end
 method int sum()+(send left sum(),send right sum())
 method string to-string()concat("(",concat(send left to-string(),concat(",",concat(send right to-string(),")"))))
class general extends object implements summable implements stringable implements item
 field int value field item children
 method void initialize(v:int,c:item)begin set value=v;set children=c end
 method int sum()+(value,send children sum())
 method string to-string()concat(number-to-string(value),concat(":",send children to-string()))
END
)
(define summable-client #<<END
let xs=new link(new leaf(3),new link(new leaf(4),new link(new leaf(5),new nil())))
    bt=new branch(new branch(new leaf(3),new leaf(4)),new leaf(5))
    gt=new general(5,new link(new leaf(3),new link(new leaf(4),new nil())))
in
END
)
(define exercise9-30 #<<END
interface summable method int sum()
interface stringable method string to-string()
interface item method int sum() method string to-string()
class nil extends object implements summable implements stringable implements item
 method void initialize()unit
 method int sum()0
 method string to-string()"[]"
class link extends object implements summable implements stringable implements item
 field item head field item tail
 method void initialize(h:item,t:item)begin set head=h;set tail=t end
 method int sum()+(send head sum(),send tail sum())
 method string to-string()concat("(",concat(send head to-string(),concat(",",concat(send tail to-string(),")"))))
class leaf extends object implements summable implements stringable implements item
 field int value
 method void initialize(v:int)set value=v
 method int sum()value
 method string to-string()number-to-string(value)
class branch extends object implements summable implements stringable implements item
 field item left field item right
 method void initialize(l:item,r:item)begin set left=l;set right=r end
 method int sum()+(send left sum(),send right sum())
 method string to-string()concat("(",concat(send left to-string(),concat(",",concat(send right to-string(),")"))))
class general extends object implements summable implements stringable implements item
 field int value field item children
 method void initialize(v:int,c:item)begin set value=v;set children=c end
 method int sum()+(value,send children sum())
 method string to-string()concat(number-to-string(value),concat(":",send children to-string()))
let xs=new link(new leaf(3),new link(new leaf(4),new link(new leaf(5),new nil())))
    bt=new branch(new branch(new leaf(3),new leaf(4)),new leaf(5))
    gt=new general(5,new link(new leaf(3),new link(new leaf(4),new nil())))
in list(send xs sum(),send bt sum(),send gt sum())
END
)
(define exercise9-30-stringable #<<END
interface summable method int sum()
interface stringable method string to-string()
interface item method int sum() method string to-string()
class nil extends object implements summable implements stringable implements item
 method void initialize()unit
 method int sum()0
 method string to-string()"[]"
class link extends object implements summable implements stringable implements item
 field item head field item tail
 method void initialize(h:item,t:item)begin set head=h;set tail=t end
 method int sum()+(send head sum(),send tail sum())
 method string to-string()concat("(",concat(send head to-string(),concat(",",concat(send tail to-string(),")"))))
class leaf extends object implements summable implements stringable implements item
 field int value
 method void initialize(v:int)set value=v
 method int sum()value
 method string to-string()number-to-string(value)
class branch extends object implements summable implements stringable implements item
 field item left field item right
 method void initialize(l:item,r:item)begin set left=l;set right=r end
 method int sum()+(send left sum(),send right sum())
 method string to-string()concat("(",concat(send left to-string(),concat(",",concat(send right to-string(),")"))))
class general extends object implements summable implements stringable implements item
 field int value field item children
 method void initialize(v:int,c:item)begin set value=v;set children=c end
 method int sum()+(value,send children sum())
 method string to-string()concat(number-to-string(value),concat(":",send children to-string()))
let xs=new link(new leaf(3),new link(new leaf(4),new link(new leaf(5),new nil())))
    bt=new branch(new branch(new leaf(3),new leaf(4)),new leaf(5))
    gt=new general(5,new link(new leaf(3),new link(new leaf(4),new nil())))
in list(send xs to-string(),send bt to-string(),send gt to-string())
END
)
(define double-dispatch-definitions #<<END
interface tree
 method bool equal(t:tree)
 method bool same-leaf(v:int)
 method bool same-node(l:tree,r:tree)
class leaf extends object implements tree
 field int value
 method void initialize(v:int)set value=v
 method bool equal(t:tree)send t same-leaf(value)
 method bool same-leaf(v:int)zero?(-(value,v))
 method bool same-node(l:tree,r:tree)zero?(1)
class node extends object implements tree
 field tree left field tree right
 method void initialize(l:tree,r:tree)begin set left=l;set right=r end
 method bool equal(t:tree)send t same-node(left,right)
 method bool same-leaf(v:int)zero?(1)
 method bool same-node(l:tree,r:tree)
  if send left equal(l) then send right equal(r) else zero?(1)
END
)
(define exercise9-32 #<<END
interface tree
 method bool equal(t:tree)
 method bool same-leaf(v:int)
 method bool same-node(l:tree,r:tree)
class leaf extends object implements tree
 field int value
 method void initialize(v:int)set value=v
 method bool equal(t:tree)send t same-leaf(value)
 method bool same-leaf(v:int)zero?(-(value,v))
 method bool same-node(l:tree,r:tree)zero?(1)
class node extends object implements tree
 field tree left field tree right
 method void initialize(l:tree,r:tree)begin set left=l;set right=r end
 method bool equal(t:tree)send t same-node(left,right)
 method bool same-leaf(v:int)zero?(1)
 method bool same-node(l:tree,r:tree)
  if send left equal(l) then send right equal(r) else zero?(1)
let a=new node(new leaf(3),new leaf(4)) b=new node(new leaf(3),new leaf(4)) c=new leaf(7)
in list(send a equal(b),send a equal(c),send c equal(a))
END
)
(define exercise9-36 #<<END
interface I method int a()
interface J extends I method int b()
interface K extends I method int c()
interface L extends J,K
class D extends object implements L
 method int initialize()1
 method int a()11 method int b()22 method int c()33
let f=proc(x:I)send x a() in (f new D())
END
)
(define exercise9-37-original #<<END
class c1 extends object
 method int initialize () 1
 method int m1 () 11
 staticmethod int m2 () 21
class c2 extends c1
 method void m1 () 12
 staticmethod int m2 () 22
let f = proc (x : c1) send x m1()
    g = proc (x : c1) send x m2()
    o = new c2()
in list((f o), (g o))
END
)
(define exercise9-37 #<<END
class c1 extends object
 method int initialize () 1
 method int m1 () 11
 staticmethod int m2 () 21
class c2 extends c1
 method int m1 () 12
 staticmethod int m2 () 22
let f = proc (x : c1) send x m1()
    g = proc (x : c1) send x m2()
    o = new c2()
in list((f o), (g o))
END
)
(define exercise9-40 #<<END
class A extends object
 field int x=3
 field int y=+(x,4)
 method int initialize()1
 method int get()+(x,y)
let a=new A() in send a get()
END
)
(define exercise9-41 #<<END
class A extends object
 field int x=3 method int initialize()1
class B extends A
 field bool x=zero?(0)
 method int initialize()1
let f=proc(a:A)begin fieldset a x=7;fieldref a x end
in let b=new B() in list((f b),named-fieldref A b x)
END
)
(define (lookup-workload n [calls 128])
  (string-append "class A extends object method initialize()1 "
    (apply string-append (for/list ([i (in-range n)]) (format "method m~a()~a " i i)))
    "let a=new A() in letrec loop(n)=if zero?(n) then 0 else begin send a m"
    (number->string (sub1 n)) "();(loop -(n,1)) end in (loop " (number->string calls) ")"))
(define (example-results)
  (hash 'state (run figure9-1) 'tree_sum (run figure9-2) 'field_shadow (run figure9-4)
        'super_self (run figure9-6) 'typed_tree (run figure9-12 #:typed? #t)
        'queue_counts (run exercise9-1) 'serials (run exercise9-15)
        'overloads (run exercise9-16 #:options (hash 'overload? #t))
        'prototype (run exercise9-29) 'summable (run exercise9-30 #:typed? #t)
        'stringable (run exercise9-30-stringable #:typed? #t)
        'static_dispatch (run exercise9-37 #:typed? #t)))
(module+ main (write-json (example-results)) (newline))
