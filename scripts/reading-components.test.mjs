import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { entries } from '../src/lib/controlled-html.mjs';
import { checkPage, checkAll } from '../tools/reading-components/check.mjs';

test('all registered reading components satisfy the common contract', () => {
  assert.equal(checkAll().status, 'passed');
});

test('collapsed proofs, unmapped statements and reversed exercise sections are rejected', () => {
  const e = entries().find(e => e.metadata.book === 'stochastic' && e.metadata.chapter === 1);
  assert.throws(() => checkPage(e.html.replace(/(<details[^>]*rn-proof[^>]*) open>/, '$1>'), 'stochastic'), /default open/);
  assert.throws(() => checkPage(e.html.replace('source-statement rn-statement', 'source-statement'), 'stochastic'), /Unmapped statement/);
  assert.throws(() => checkPage(e.html.replace('class="exercise-question"', 'class="answer"'), 'stochastic'), /Question must precede/);
});

test('exercise 6.27 retains the original fourth moment separately from the second moment extension', () => {
  const e = entries().find(e => e.metadata.book === 'measure-probability' && e.metadata.chapter === 6);
  const block = e.html.split('id="ex-6-27"')[1].split('</details>')[0];
  const [question, answer] = block.split('<div class="answer">');
  assert.match(question, /<msubsup><mi>X<\/mi><mn>1<\/mn><mn>4<\/mn><\/msubsup>/);
  assert.match(answer, /Cauchy–Schwarz/);
  assert.match(answer, /这是解答得到的推广/);
  assert.match(answer, /有限 n 时分母可能为零/);
});

test('splay local accounting distinguishes the two disjoint-subtree pairs', () => {
  const e = entries().find(e => e.metadata.book === 'weiss' && e.metadata.chapter === 12);
  const answer = e.html.split('id="ex12-1"')[1].split('</details>')[0];
  assert.match(answer, /旧 x 的整棵子树与新 t 的子树互不相交/);
  assert.match(answer, /新 y、t 的子树不相交/);
  assert.match(answer, /简化两种自顶向下算法均满足访问引理/);
  assert.match(answer, /不能直接当作本实现的比较次数或指针写入次数/);
  // Enumerate subtree sizes including empty fringe subtrees. Node weights are one.
  for (let a = 0; a < 6; a++) for (let b = 0; b < 6; b++)
  for (let c = 0; c < 6; c++) for (let d = 0; d < 6; d++) {
    const log = Math.log2;
    // zig-zig: t(y(x(A,B),C),D) -> x(A,y(B,t(C,D))).
    const x = 1 + a + b, y = 1 + x + c, t = 1 + y + d;
    const nt = 1 + c + d, ny = 1 + b + nt;
    const actual = 2 + log(ny) + log(nt) - log(x) - log(y);
    assert(actual <= 3 * (log(t) - log(x)) + 1e-12);
    // zig-zag: t(y(A,x(B,C)),D) -> x(y(A,B),t(C,D)).
    const zx = 1 + b + c, zy = 1 + a + zx, zt = 1 + zy + d;
    const zny = 1 + a + b, znt = 1 + c + d;
    const zigzag = 2 + log(zny) + log(znt) - log(zx) - log(zy);
    assert(zigzag <= 2 * (log(zt) - log(zx)) + 1e-12);
  }
  const issues = JSON.parse(fs.readFileSync('books/measure-probability/notes/source_issues.json'));
  assert(issues.issues.some(i => i.id === 'MP-COMPANION-627' && i.pdf_pages[0] === 228));
});
