import test from 'node:test';
import assert from 'node:assert/strict';
import {requireInlinePrograms, checkNodePadding, requirePositionedSvgMath} from '../tools/reading-presentation/check.mjs';

test('complete program syntax is distinct from a code block and fragmented mathematical arguments', () => {
  const expression = 'waitpid(-1,&s,WNOHANG)';
  assert.throws(() => requireInlinePrograms('<p>waitpid(-1,&amp;s,WNOHANG)</p>', [expression]));
  assert.throws(() => requireInlinePrograms('<pre><code>waitpid(-1,&amp;s,WNOHANG)</code></pre>', [expression]));
  assert.throws(() => requireInlinePrograms('<p><code>waitpid</code>(-1,&amp;<math><mi>s</mi></math>,WNOHANG)</p>', [expression]));
  assert.doesNotThrow(() => requireInlinePrograms('<p><code>waitpid(-1,&amp;s,WNOHANG)</code></p>', [expression]));
});

test('node bounds detect overflowing labels and insufficient padding on every side', () => {
  const shape = {x: 100, y: 50, w: 160, h: 64};
  assert.doesNotThrow(() => checkNodePadding(shape, [{x: 120, y: 63, w: 120, h: 34}]));
  for (const label of [{x: 98,y: 63,w: 120,h: 34}, {x: 120,y: 63,w: 150,h: 34},
    {x: 120,y: 51,w: 120,h: 34}, {x: 120,y: 90,w: 120,h: 24}]) {
    assert.throws(() => checkNodePadding(shape, [label]), /boundary/);
  }
});

test('mathematical SVG indices preserve the complete value and script position', () => {
  for (const label of ['N_G(H)', 'G_(N−2)', 'p^(N−1)']) {
    assert.throws(() => requirePositionedSvgMath(`<svg><text>${label}</text></svg>`), /Unpositioned/);
  }
  const correct = '<svg><text>N<tspan baseline-shift="sub" data-notation="_G">G</tspan>(H)</text><text>p<tspan baseline-shift="super" data-notation="^(N−1)">N−1</tspan></text></svg>';
  assert.doesNotThrow(() => requirePositionedSvgMath(correct));
  assert.throws(() => requirePositionedSvgMath(correct.replace('>N−1<', '>N−2<')), /source value/);
  assert.throws(() => requirePositionedSvgMath(correct.replace('baseline-shift="super"', 'baseline-shift="sub"')));
});
