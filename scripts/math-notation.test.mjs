import test from 'node:test';
import assert from 'node:assert/strict';
import {checkMathNotation} from '../tools/reading-typography/notation-check.mjs';
import {math} from '../tools/reading-typography/math.mjs';

test('Group Explorer regression: bare frf/fr/rf must not mix with MathML variables',()=>{
 for(const word of ['frf','fr','rf'])assert.throws(()=>checkMathNotation('<p>例如 '+word+'。</p>','visual-group-theory'),/plain prose/);
 assert.doesNotThrow(()=>checkMathNotation('<p>例如 '+math('f r f')+'。</p>','visual-group-theory'));
 assert.doesNotThrow(()=>checkMathNotation('<code>frf</code><pre>rf = fr</pre><p>Group Explorer</p>','visual-group-theory'));
});
test('named functions are upright and variable words cannot be hidden as mtext',()=>{
 assert.throws(()=>checkMathNotation('<math><mi>log</mi><mi>N</mi></math>','weiss'),/upright/);
 assert.throws(()=>checkMathNotation('<math><mtext>frf</mtext></math>','visual-group-theory'),/stored as prose/);
 assert.doesNotThrow(()=>checkMathNotation(math('log N'),'weiss'));
});
test('detached scripts and failed TeX conversion cannot pass a font-only review',()=>{
 for(const html of ['<math><mo>²</mo></math>','<math><mi>\\leM</mi></math>','<math><mo>_</mo><mi>n</mi></math>','<math><msup><mo>=</mo><mn>5</mn></msup></math>'])assert.throws(()=>checkMathNotation(html,'stochastic'));
 assert.doesNotThrow(()=>checkMathNotation('<math><mover><mi>p</mi><mo>^</mo></mover></math><code>^</code>','stochastic'));
});
test('filenames use one complete inline code boundary',()=>{
 assert.throws(()=>checkMathNotation('<p><code>finite_spaces</code>.py</p>','measure-probability'),/Filename extension/);
 assert.doesNotThrow(()=>checkMathNotation('<p><code>finite_spaces.py</code></p>','measure-probability'));
});
test('indexed mathematical objects cannot silently become ordinary products',()=>{
 assert.throws(()=>checkMathNotation('<math aria-label="Δn"><mi>Δ</mi><mi>n</mi></math>','stochastic'),/flattened/);
 assert.throws(()=>checkMathNotation('<math aria-label="b=E[X²1A]"><mi>b</mi><mo>=</mo><mi>E</mi><mi>X</mi><mn>1</mn><mi>A</mi></math>','measure-probability'),/Indicator/);
 assert.doesNotThrow(()=>checkMathNotation(math('Δ_n'),'stochastic'));
 assert.match(math('X^s 1_{|X^s|<2ε}'),/<msub><mn>1<\/mn>/);
});
