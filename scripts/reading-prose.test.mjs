import assert from 'node:assert/strict';
import test from 'node:test';
import {scanProse} from '../tools/reading-prose/check.mjs';

const examples = {
  scheme: ['(define (id x) x)', '(lambda (x) x)', ...'let cond if map cons car cdr list append reverse null? pair? set! begin'.split(' ').map(op=>'('+op+' x)')],
  c: ['#include &lt;stdio.h&gt;', 'printf("x")', 'malloc(8)', 'sizeof(x)', 'struct point', 'int main(void)'],
  assembly: 'movq movl pushq popq leaq cmpq jne je jmp ret callq'.split(' '),
  python: ['def f(x):', 'class X:', 'import math', 'print(e)'],
  shell: ['clang -O2', 'gcc -Wall', 'make -j2', 'racket example.rkt', 'python "my notes.py"', 'node index.mjs', 'pnpm install', 'git status'],
};
for (const [language, snippets] of Object.entries(examples)) {
  test(language+' syntax must be marked as code', () => {
    for (const code of snippets) {
      const hits = scanProse('<section id="sample"><p>运行 '+code+'</p></section>');
      assert.ok(hits.length,code);
      assert.equal(hits[0].anchor,'sample');
      assert.deepEqual(scanProse('<p><code>'+code+'</code></p>'),[],code);
    }
  });
}
test('ordinary phrases, tuples and literal data', () => {
  assert.deepEqual(scanProse("<p>make sure, gcc compiler, clang 17.0.0, node of a tree, (1 2), '(map red)</p>"),[]);
  assert.equal(scanProse('<p>make sure (1 2) jne</p>')[0].token,'jne');
});
test('protected subtrees and attributes do not count as prose', () => {
  for (const tag of ['pre','code','math','svg','script','style','textarea']) {
    assert.deepEqual(scanProse('<'+tag+'>jne</'+tag+'>'),[]);
  }
  assert.deepEqual(scanProse('<p title="jne">return</p>'),[]);
});


test('extended Scheme forms in prose need code markup', () => {
  const operators = 'quote and or not display newline apply eval force delay call/cc letcc error assert stream-car cons-stream filter accumulate fold-right fold-left for-each';
  for (const expr of ['(quote (quote a))', '(quote a)', ...operators.split(' ').map(op=>'('+op+' x)')]) {
    assert.ok(scanProse('<p>'+expr+'</p>').length, expr);
    assert.deepEqual(scanProse('<p><code>'+expr+'</code></p>'), []);
  }
});

test('English parentheticals only exempt the matched phrase', () => {
  for (const phrase of ['(or equivalently)', '(or equivalently, 1)', '(and instructors)', '(and vice versa)', '(or nonoccurrence)']) {
    assert.deepEqual(scanProse('<p>'+phrase+'</p>'), []);
    assert.equal(scanProse('<p>'+phrase+' (or a b)</p>').length, 1);
  }
});

test('quoted expressions, abbreviations and bare names in program table cells', () => {
  const table = cell => '<table><caption>引用的两层</caption><tr><td>'+cell+'</td></tr></table>';
  for (const value of ["''a", '(quote (quote a))', '(quote a)', 'car', 'quote', 'my-procedure', '(1 2)']) {
    assert.ok(scanProse(table(value)).length, value);
    assert.deepEqual(scanProse(table('<code>'+value+'</code>')), []);
  }
  assert.ok(scanProse(table('取 <em>car</em>')).length);
  assert.ok(scanProse(table('符号 quote')).length);
  assert.deepEqual(scanProse(table('The result is an integer.')), []);
  assert.deepEqual(scanProse('<table><caption>词义</caption><tr><td>car</td></tr></table>'), []);
});

test('a table description can identify code cells without a caption', () => {
  assert.ok(scanProse('<p id="what">本表给出表达式的求值结果</p><table aria-describedby="what"><tr><td>car</td></tr></table>').length);
  assert.ok(scanProse('<figure><table><tr><td>quote</td></tr></table><figcaption>程序输出</figcaption></figure>').length);
});
