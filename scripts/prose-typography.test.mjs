import test from 'node:test';import assert from'node:assert/strict';
import{checkProseTerms}from'../tools/reading-typography/prose-check.mjs';
import{checkMathNotation,checkMathUnits}from'../tools/reading-typography/notation-check.mjs';
import{presentation}from'../tools/reading-typography/math.mjs';
test('author names and technical names stay prose',()=>{
 assert(checkProseTerms('<p>Randal E. Bryant; System V; CPS-IN; Hölder</p>').protected_prose_terms===4);
 for(const bad of ['Randal <math><mi>E</mi></math>. Bryant','System <math><mi>V</mi></math>','CPS<math><mo>-</mo><mi>I</mi><mi>N</mi></math>','<math><mi>H</mi></math>ölder'])assert.throws(()=>checkProseTerms('<p>'+bad+'</p>'),/Ordinary prose/);
});
test('a mathematical minus cannot disguise an encoding or algorithm name',()=>{
 for(const bad of ['<math aria-label="UTF-8"><mi>U</mi><mi>T</mi><mi>F</mi><mo>−</mo><mn>8</mn></math>','zig<math><mo>−</mo><mi>zig</mi></math>'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>'),/Ordinary prose/);
 assert.doesNotThrow(()=>checkProseTerms('<p>UTF-8 和 zig-zig；<math aria-label="x−8"><mi>x</mi><mo>−</mo><mn>8</mn></math></p>'));
});
test('pointer types are code while modulo operators have readable spacing',()=>{
 assert.throws(()=>checkProseTerms('<math aria-label="DIR*"><mi>DIR</mi><mo>*</mo></math>'),/Program/);
 assert.throws(()=>checkProseTerms('<code>DIR</code> *'),/Program/);
 assert.doesNotThrow(()=>checkProseTerms('<code>DIR *</code>'));
 assert.throws(()=>checkMathNotation('<math><mi>k</mi><mi mathvariant="normal">mod</mi><mi>n</mi></math>','csapp'),/Modulo/);
 for(const input of ['k mod n','(mod n)','mod n'])assert.doesNotThrow(()=>checkMathNotation('<math>'+presentation(input)+'</math>','csapp'));
 assert.match(presentation('k mod n'),/form="infix" lspace="0.278em"/);
 assert.match(presentation('(mod n)'),/form="prefix" lspace="0em"/);
 assert.throws(()=>checkMathNotation('<math><mi>n</mi><mo>≡</mo><mn>1</mn></math> mod3','visual-group-theory'),/Modulo expression split/);
 assert.doesNotThrow(()=>checkMathNotation('<math>'+presentation('n≡1 (mod 3)')+'</math>','visual-group-theory'));
});
test('genuine variables and program text retain their semantics',()=>{
 assert.doesNotThrow(()=>checkProseTerms('<p><math><mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup></math>; <code>System V</code></p>'));
});
test('member access is code while sequence and heap names are prose',()=>{
 assert.throws(()=>checkProseTerms('<p><math aria-label="p"><mi>p</mi></math>.Next</p>'),/Program member/);
 assert.throws(()=>checkProseTerms('<p><code>Fibonacci</code> 堆</p>'),/data structure/);
 assert.doesNotThrow(()=>checkProseTerms('<p>Fibonacci 数列；Fibonacci 堆；<code>Fibonacci(n)</code>；<code>p.Next</code>；<math><mi>A</mi></math>.<math><mi>k</mi></math></p>'));
});
test('complete mathematical expressions retain delimiters and real script operands',()=>{
 for(const bad of ['<math><mi>O</mi><mo>(</mo><mi>log</mi></math><math><mi>N</mi></math>)','<math><mo>[</mo><mi>G</mi><mo>:</mo></math><math><mi>H</mi><mo>]</mo></math>','<math><msub><mi>g</mi><mrow></mrow></msub></math>'])
  assert.throws(()=>checkMathNotation(bad,'stochastic'),/split at a delimiter|empty operand/);
 for(const good of ['[a,b)','(a,b]','P(X∈[a,b))','O(log N)','[G:H]','g_{N_k}'])
  assert.doesNotThrow(()=>checkMathNotation('<math>'+presentation(good)+'</math>','stochastic'));
});
test('semidirect products use an operator with its action subscript',()=>{
 assert.match(presentation('G⋊_{α}H'),/<msub><mo>⋊<\/mo><mi>α<\/mi><\/msub>/);
 assert.throws(()=>checkMathNotation('<math><mtext>⋊</mtext></math>','visual-group-theory'),/stored as prose/);
});
test('noncongruence is a mathematical relation',()=>{
 assert.match(presentation('2≢0 (mod 4)'),/<mo>≢<\/mo>/);
});
test('probability abbreviations remain whole upright text',()=>{
 for(const bad of ['<math><mi>a</mi></math>.e.','<math><mi>a</mi><mo>.</mo><mi>s</mi></math>.'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>'),/Probability abbreviation/);
 for(const good of ['a.e.','a.s.','a.u.','<math><mover><mo>→</mo><mtext>a.s.</mtext></mover></math>'])
  assert.doesNotThrow(()=>checkProseTerms('<p>'+good+'</p>'));
});
test('natural English and bibliography titles are not highlighted as program tokens',()=>{
 for(const bad of ['Feel <code>free</code> to choose', '<code>Union</code>-Find with Constant Time Deletions'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>'),/Natural-language/);
 assert.doesNotThrow(()=>checkProseTerms('<p>Feel free to choose. Call <code>free(p)</code> after <code>Union</code>.</p>'));
});
test('protocol literals and qualified API names are not parsed as arithmetic',()=>{
 for(const text of ['HTTP/1.<math><mi>x</mi></math>','application<math><mo>/</mo><mi>x</mi><mo>-</mo><mi>www</mi><mo>-</mo></math>form-urlencoded','subprocess.<math><mi>r</mi><mi>u</mi><mi>n</mi></math>'])
  assert.throws(()=>checkProseTerms('<p>'+text+'</p>'),/incorrectly marked as math/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>subprocess.run</code> 接收 <code>input=body</code>；正文为 <code>a=2&amp;b=3</code>。</p>'));
});
test('subquestion labels are prose and object fields retain mathematical semantics',()=>{
 assert.throws(()=>checkMathNotation('<div id="ex-1"><p><math><mi>A</mi></math>. 说明原因。</p></div>','csapp'),/Subquestion label/);
 assert.doesNotThrow(()=>checkMathNotation('<div id="ex-1"><p><math><mi>A</mi></math>.<math><mi>k</mi></math> 表示对象字段。</p></div>','csapp'));
});
test('program operators and pointer declarations remain one code unit',()=>{
 for(const bad of ['<math aria-label="cnt++"><mi>cnt</mi><mo>+</mo><mo>+</mo></math>','<math aria-label="x^=x&gt;&gt;16"><mi>x</mi></math>','<code>int</code> **','<code>struct</code> dirent*','<code>short</code> *','(<code>float</code><math aria-label=")i"><mi>i</mi></math>'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>'),/Program/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>int **p</code>; <code>x ^= x &gt;&gt; 16</code>; <math aria-label="R[rA]←V"><mi>R</mi></math></p>'));
});
test('compiler options, byte units and hexadecimal data retain their distinct meaning',()=>{
 for(const label of ['-S','-Og -g'])assert.throws(()=>checkProseTerms('<math aria-label="'+label+'"><mi>S</mi></math>','csapp'),/Command option/);
 assert.throws(()=>checkProseTerms('<math aria-label="8 B"><mn>8</mn><mi>B</mi></math>','csapp'),/Byte unit/);
 assert.doesNotThrow(()=>checkProseTerms('<p>8\u00a0B；<code>0B 37</code>；<code>gcc -Og -g</code>；<math aria-label="4+1=5 B"><mn>4</mn><mo>+</mo><mn>1</mn><mo>=</mo><mn>5</mn><mtext> B</mtext></math></p>','csapp'));
 assert.doesNotThrow(()=>checkProseTerms('<math aria-label="N+4+L+2B+3R"><mi>B</mi></math><math aria-label="-8+50=42"><mo>−</mo><mn>8</mn></math>','csapp'));
});
test('array access stays together and subtraction remains mathematical',()=>{
 assert.throws(()=>checkProseTerms('<p>clientrio<math aria-label="[i]"><mi>i</mi></math></p>'),/Program token/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>clientrio[i]</code>; <math aria-label="r−x"><mi>r</mi><mo>−</mo><mi>x</mi></math></p>'));
});
test('program output pairs remain a complete literal',()=>{
 assert.throws(()=>checkProseTerms('<p>normal<math aria-label="=yes"><mo>=</mo><mi>yes</mi></math></p>'),/Program output pair/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>normal=yes</code>；<math aria-label="x=no"><mi>x</mi><mo>=</mo><mi>n</mi><mi>o</mi></math></p>'));
});
test('hexadecimal values stay whole in both arithmetic and program state',()=>{
 assert.match(presentation('P+4=0x4004e3'),/<mn>0x4004e3<\/mn>/);
 assert.match(presentation('M₈[0x100]=0x123'),/<msub><mi>M<\/mi><mn>8<\/mn><\/msub>/);
 assert.doesNotMatch(presentation('0xBC×8+2'),/<mi>x<\/mi>/);
 assert.throws(()=>checkProseTerms('<math aria-label="P=0"><mi>P</mi><mo>=</mo><mn>0</mn></math>x1000'),/Hexadecimal literal/);
 assert.doesNotThrow(()=>checkProseTerms('<math aria-label="P=0x1000"><mi>P</mi><mo>=</mo><mn>0x1000</mn></math><code>%rsp=0x108</code>'));
});
test('simulator commands and system paths retain whole program notation',()=>{
 for(const bad of ['交给官方 psim 运行','用 otool 提取指令','执行 <math aria-label="/usr/bin/"><mo>/</mo><mi>usr</mi><mo>/</mo><mi>bin</mi><mo>/</mo></math><code>true</code>'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>','csapp'),/Program (tool|path)/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>psim</code> 输出的 <code>cycles</code> 加 4；<code>otool -L /usr/bin/gcc</code>；<code>/usr/bin/true</code>。</p>','csapp'));
 assert.doesNotThrow(()=>checkProseTerms('<p>SEQ 与 PIPE 是处理器模型；Clang 是编译器名称。</p>','csapp'));
});
test('program comparisons and protocol field values are complete literals',()=>{
 for(const bad of ['<math aria-label="fd"><mi>f</mi><mi>d</mi></math> == 0','<code>fd</code> == 0','<code>fd</code> != 0','Content-Length:20'])
  assert.throws(()=>checkProseTerms('<p>'+bad+'</p>','csapp'),/Program (comparison|protocol)/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>fd == 0</code>；<code>Content-Length:20</code>；HEAD 与 GET 的响应体约定。</p>','csapp'));
 assert.doesNotThrow(()=>checkProseTerms('<p><math><mi>x</mi><mo>≠</mo><mn>0</mn></math>；HTTP 的 Content-Length 字段。</p>','csapp'));
 assert.doesNotThrow(()=>checkProseTerms('<p><math><mn>12</mn><mo>!</mo><mo>=</mo><mn>479001600</mn></math> 是数学阶乘。</p>','csapp'));
});
test('a function and its argument stay in one mathematical reading unit',()=>{
 const f='<math><msub><mi>F</mi><mi>n</mi></msub></math>',x='<math><mo>(</mo><mi>x</mi><mo>)</mo></math>';
 for(const bad of [f+x,'<span class="math-inline">'+f+'</span> '+x])
  assert.throws(()=>checkMathUnits('<p>'+bad+'</p>'),/Adjacent mathematical fragments/);
 assert.doesNotThrow(()=>checkMathUnits('<p><math><msub><mi>F</mi><mi>n</mi></msub><mo>(</mo><mi>x</mi><mo>)</mo></math></p>'));
 assert.doesNotThrow(()=>checkMathUnits('<p>'+f+' 与 '+x+'</p>'));
 assert.doesNotThrow(()=>checkMathUnits('<blockquote lang="en">(diff '+f+' '+x+')</blockquote>'));
});
test('long inline formulas keep their complete semantics inside a local scroll region',()=>{
 const formula='<math><mrow><mi>abcdefghijklm</mi><mo>=</mo><mi>nopqrstuvwxyz</mi></mrow></math>';
 assert.throws(()=>checkMathUnits('<p>'+formula+'</p>'),/locally scrollable/);
 assert.doesNotThrow(()=>checkMathUnits('<p><span class="rn-math-inline">'+formula+'</span></p>'));
 assert.doesNotThrow(()=>checkMathUnits('<div class="equation">'+formula.replace('<math>','<math display="block">')+'</div>'));
});
test('program assignments keep the value and operator with the program identifier',()=>{
 for(const book of ['weiss','csapp']) {
  for(const bad of ['<code>front</code>=(front+1)%<math><mi>C</mi></math>', '<code>p3</code>=−2', '<code>data</code>=[2,3,5]'])
   assert.throws(()=>checkProseTerms('<p>'+bad+'</p>',book),/Program assignment/);
  assert.doesNotThrow(()=>checkProseTerms('<p><code>front = (front + 1) % C</code>; <math><mi>x</mi><mo>=</mo><mn>2</mn></math></p>',book));
 }
 assert.doesNotThrow(()=>checkProseTerms('<p><code>(top (push v s))</code> = <code>v</code></p>','eopl'));
});
test('binary-search statements are code and graph Low functions stay mathematical',()=>{
 for(const label of ['Low=Mid','Low=0','Mid+1','2.22 · Low=Mid'])
  assert.throws(()=>checkProseTerms('<details id="ex2-22"><summary><math aria-label="'+label+'"><mi>Low</mi></math></summary></details>','weiss'),/Binary-search program/);
 assert.doesNotThrow(()=>checkProseTerms('<p><code>Low = Mid</code>；<math aria-label="Low(w)=min(D(w),D(v))"><mi>Low</mi><mo>(</mo><mi>w</mi><mo>)</mo></math></p>','weiss'));
 assert.doesNotThrow(()=>checkProseTerms('<section id="depth-first"><math aria-label="Low=Num"><mi>Low</mi><mo>=</mo><mi>Num</mi></math></section>','weiss'));
});
