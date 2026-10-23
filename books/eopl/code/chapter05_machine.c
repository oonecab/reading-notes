/* EOPL 5.21/5.33/5.34: one LETREC transition relation, three C11 drivers.
   Inputs are ASTs built below; no source parser. Compile with -O0 to compare
   ordinary host calls with explicit jumps/trampolining. Arena is per run. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <time.h>
typedef struct Node Node; typedef struct Env Env; typedef struct Frame Frame;
typedef struct { int tag; long n; const char *param; Node *body; Env *env; } Value;
struct Node { int tag; long n; const char *name; Node *a,*b,*c; };
struct Env { const char *name; Value value; Env *rest; };
struct Frame { int tag; Value value; const char *name; Node *a,*b; Env *env; Frame *rest; };
enum { NUM,VAR,DIFF,ZERO,IF,LET,PROC,CALL,LETREC };
enum { EV,AP,INVOKE,HALT };
enum { FDIFF1,FDIFF2,FZERO,FIF,FLET,FRATOR,FRAND };
static Node *exp_reg; static Env *env_reg; static Frame *cont_reg;
static Value val_reg,proc_reg; static int pc; static size_t steps, depth, max_depth;
#define CAP 300000
static Env environments[CAP]; static Frame frames[CAP];
static size_t ne,nf;
static void fail(const char *message) { fprintf(stderr,"%s\n",message); exit(2); }
static Value number(long n) { Value v={0};v.tag=0;v.n=n;return v; }
static Value boolean(bool b) { Value v=number(b);v.tag=1;return v; }
static Value closure(Node *body,const char *p,Env *env) {
 Value v={0};v.tag=2;v.param=p;v.body=body;v.env=env;return v;
}
static long numeric(Value v) { if(v.tag!=0)fail("number required");return v.n; }
static Env *extend(const char *x,Value v,Env *rest) {
 if(ne==CAP)fail("environment arena exhausted");
 Env *e=&environments[ne++];*e=(Env){x,v,rest};return e;
}
static Value lookup(Env *e,const char *x) {
 for(;e;e=e->rest)if(!strcmp(e->name,x))return e->value;
 fail("unbound variable");return number(0);
}
static void push(int tag,Value v,const char *x,Node *a,Node *b,Env *e) {
 if(nf==CAP)fail("continuation arena exhausted");
 Frame *f=&frames[nf++];*f=(Frame){tag,v,x,a,b,e,cont_reg};cont_reg=f;
 if(++depth>max_depth)max_depth=depth;
}
/* Each block reads and writes the five registers; the returned pc is the jump. */
static int eval_block(void) {
 Node *e=exp_reg;
 switch(e->tag) {
 case NUM:val_reg=number(e->n);return AP;
 case VAR:val_reg=lookup(env_reg,e->name);return AP;
 case DIFF:push(FDIFF1,number(0),NULL,e->b,NULL,env_reg);exp_reg=e->a;return EV;
 case ZERO:push(FZERO,number(0),NULL,NULL,NULL,NULL);exp_reg=e->a;return EV;
 case IF:push(FIF,number(0),NULL,e->b,e->c,env_reg);exp_reg=e->a;return EV;
 case LET:push(FLET,number(0),e->name,e->b,NULL,env_reg);exp_reg=e->a;return EV;
 case PROC:val_reg=closure(e->a,e->name,env_reg);return AP;
 case CALL:push(FRATOR,number(0),NULL,e->b,NULL,env_reg);exp_reg=e->a;return EV;
 case LETREC:{
  Env *rho=extend(e->name,number(0),env_reg);
  rho->value=closure(e->a->a,e->a->name,rho);env_reg=rho;exp_reg=e->b;return EV;
 }
 default:fail("unknown expression");return HALT;
 }
}
static int apply_block(void) {
 if(!cont_reg)return HALT;
 Frame f=*cont_reg;cont_reg=f.rest;--depth;
 switch(f.tag) {
 case FDIFF1:push(FDIFF2,val_reg,NULL,NULL,NULL,NULL);exp_reg=f.a;env_reg=f.env;return EV;
 case FDIFF2:val_reg=number(numeric(f.value)-numeric(val_reg));return AP;
 case FZERO:val_reg=boolean(numeric(val_reg)==0);return AP;
 case FIF:if(val_reg.tag!=1)fail("boolean required");exp_reg=val_reg.n?f.a:f.b;env_reg=f.env;return EV;
 case FLET:exp_reg=f.a;env_reg=extend(f.name,val_reg,f.env);return EV;
 case FRATOR:push(FRAND,val_reg,NULL,NULL,NULL,f.env);exp_reg=f.a;env_reg=f.env;return EV;
 case FRAND:proc_reg=f.value;return INVOKE;
 default:fail("unknown continuation");return HALT;
 }
}
static int invoke_block(void) {
 if(proc_reg.tag!=2)fail("procedure required");
 exp_reg=proc_reg.body;env_reg=extend(proc_reg.param,val_reg,proc_reg.env);return EV;
}
static int step(void) { ++steps;return pc==EV?eval_block():pc==AP?apply_block():invoke_block(); }
static void value_of(void);static void apply_cont(void);static void apply_procedure(void);
static void transfer(void) { if(pc==EV)value_of();else if(pc==AP)apply_cont();else if(pc==INVOKE)apply_procedure(); }
static void value_of(void) { pc=step();transfer(); }
static void apply_cont(void) { pc=step();transfer(); }
static void apply_procedure(void) { pc=step();transfer(); }
static Value run(Node *program,int driver) {
 ne=nf=steps=depth=max_depth=0;exp_reg=program;env_reg=NULL;cont_reg=NULL;pc=EV;
 if(driver==0){value_of();return val_reg;}
 if(driver==1){
  /* An actual C goto driver; every transfer jumps instead of calling. */
  eval_label:++steps;pc=eval_block();goto dispatch;
  apply_label:++steps;pc=apply_block();goto dispatch;
  invoke_label:++steps;pc=invoke_block();goto dispatch;
  dispatch:if(pc==EV)goto eval_label;if(pc==AP)goto apply_label;if(pc==INVOKE)goto invoke_label;
  return val_reg;
 }
 while(pc!=HALT)pc=step(); /* Trampoline of explicit data snapshots. */
 return val_reg;
}
int main(int argc,char **argv) {
 long n=argc>2?strtol(argv[2],NULL,10):100;
 int driver=argc>1?atoi(argv[1]):2;
 if(n<0||n>20000||driver<0||driver>2)fail("usage: machine [0|1|2] [0..20000]");
 Node x={VAR,0,"x",NULL,NULL,NULL},one={NUM,1,NULL,NULL,NULL,NULL},zero={NUM,0,NULL,NULL,NULL,NULL};
 Node sub={DIFF,0,NULL,&x,&one,NULL},test={ZERO,0,NULL,&x,NULL,NULL};
 Node f={VAR,0,"f",NULL,NULL,NULL},call={CALL,0,NULL,&f,&sub,NULL};
 Node body={IF,0,NULL,&test,&zero,&call},proc={PROC,0,"x",&body,NULL,NULL};
 Node arg={NUM,n,NULL,NULL,NULL,NULL},start={CALL,0,NULL,&f,&arg,NULL};
 Node program={LETREC,0,"f",&proc,&start,NULL};
 clock_t begin=clock();Value v=run(&program,driver);double seconds=(double)(clock()-begin)/CLOCKS_PER_SEC;
 if(v.tag!=0||v.n!=0)fail("unexpected result");
 printf("driver=%d n=%ld result=%ld steps=%zu max_frames=%zu cpu_seconds=%.6f\n",driver,n,v.n,steps,max_depth,seconds);
 return 0;
}
