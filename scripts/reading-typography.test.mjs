import test from 'node:test';
import assert from 'node:assert/strict';
import {parseFragment} from 'parse5';
import {prose,math,svgScripts,presentation} from '../tools/reading-typography/math.mjs';
import {checkTypography} from '../tools/reading-typography/check.mjs';
import fs from 'node:fs';

test('environment subscripts, maps and signed powers have real MathML structure',()=>{
  const html=prose('在 E₃ 中，x ↦ 20；逆元为 r⁻¹。').html;
  assert.match(html,/<msub><mi>E<\/mi><mn>3<\/mn><\/msub>/);
  assert.match(html,/<mi>x<\/mi><mo>↦<\/mo><mn>20<\/mn>/);
  assert.match(html,/<msup><mi>r<\/mi><mrow><mo>−<\/mo><mn>1<\/mn><\/mrow><\/msup>/);
});
test('accessible formula text remains independent of presentation structure',()=>{
  const html=math('Cₙ',{annotation:true});
  assert.match(html,/aria-label="Cₙ"/);
  assert.match(html,/<annotation encoding="text\/plain">Cₙ<\/annotation>/);
  assert.equal(parseFragment(html).childNodes[0].namespaceURI,'http://www.w3.org/1998/Math/MathML');
});
test('program identifiers, ordinary English and page numbers are not parsed as subscripts',()=>{
  const value='check_notes.py source_sha256 PROC Scheme PDF 97–103 Times New Roman';
  assert.equal(prose(value).html,value);
});
test('nested TeX exponent grouping preserves the dihedral multiplication rule',()=>{
  const html=presentation('r^{i+(-1)^j k}');
  assert.match(html,/<msup><mi>r<\/mi><mrow><mi>i<\/mi><mo>\+<\/mo><msup><mrow><mo>\(<\/mo><mo>−<\/mo><mn>1<\/mn><mo>\)<\/mo><\/mrow><mi>j<\/mi><\/msup><mi>k<\/mi><\/mrow><\/msup>/);
});
test('product powers, roots and absolute-value powers retain their bases',()=>{
  assert.match(presentation('rfr⁻¹'),/^<mrow><mi>r<\/mi><mi>f<\/mi><msup><mi>r<\/mi>/);
  assert.match(presentation('(LNR)²'),/^<msup><mrow><mo>\(<\/mo><mi>L<\/mi><mi>N<\/mi><mi>R<\/mi><mo>\)<\/mo><\/mrow><mn>2<\/mn><\/msup>$/);
  assert.match(presentation('|G|²'),/^<msup><mrow><mo>\|<\/mo><mi>G<\/mi><mo>\|<\/mo><\/mrow>/);
  assert.match(presentation('z^(Xᵢ)'),/^<msup><mi>z<\/mi><msub><mi>X<\/mi><mi>i<\/mi><\/msub><\/msup>$/);
  assert.match(presentation('√2'),/^<msqrt><mn>2<\/mn><\/msqrt>$/);
  assert.match(presentation('cᴬ'),/^<msup><mi>c<\/mi><mi>A<\/mi><\/msup>$/);
  assert.match(presentation('r̄'),/^<mover accent="true"><mi>r<\/mi><mo>¯<\/mo><\/mover>$/);
  assert.equal(prose('定理 A.1，印刷 23 / PDF 35').html,'定理 A.1，印刷 23 / PDF 35');
});
test('SVG scripts retain coordinates, content and baseline roles',()=>{
  assert.equal(svgScripts('E₃：x ↦ 20'),'E<tspan baseline-shift="sub" font-size="70%">3</tspan>：x ↦ 20');
  assert.equal(svgScripts('Tₖ₊ₗ⁻¹'),'T<tspan baseline-shift="sub" font-size="70%">k+l</tspan><tspan baseline-shift="super" font-size="70%">−1</tspan>');
});
test('typography guard rejects raw math, malformed scripts and missing font rules',()=>{
  const style='<style>'+fs.readFileSync('src/styles/reading-typography.css','utf8')+'</style>';
  assert.throws(()=>checkTypography('<p>fine</p>'),/Times New Roman/);
  assert.throws(()=>checkTypography(style+'<p>在 E₃ 中</p>'),/Unformatted prose/);
  assert.throws(()=>checkTypography(style+'<p>在 E_3 中</p>'),/Unformatted prose TeX/);
  assert.throws(()=>checkTypography(style+'<svg><text>E₃</text></svg>'),/Unpositioned SVG/);
  assert.throws(()=>checkTypography(style+'<math><msub><mi>E</mi></msub></math>'),/operands/);
  assert.doesNotThrow(()=>checkTypography(style+'<pre><code>x_3 = 1</code></pre>'+math('E₃')));
});

test('reviewed group products use variables while ordinary words stay prose',()=>{
  assert.equal(presentation('frf',{products:['frf']}),'<mrow><mi>f</mi><mi>r</mi><mi>f</mi></mrow>');
  assert.equal(presentation('Group Explorer'),'<mrow><mtext>Group</mtext><mtext>Explorer</mtext></mrow>');
  assert.match(presentation('bta²'),/<mi>b<\/mi><mi>t<\/mi><msup><mi>a<\/mi><mn>2<\/mn>/);
});
test('Greek indices, nested powers and indexed roots keep their real operands',()=>{
  assert.equal(presentation('α_h^2'),'<msubsup><mi>α</mi><mi>h</mi><mn>2</mn></msubsup>');
  assert.match(presentation('r^{u^j k}'),/<msup><mi>r<\/mi><mrow><msup><mi>u<\/mi><mi>j<\/mi><\/msup><mi>k<\/mi>/);
  assert.match(presentation('p^{a_p}'),/<msup><mi>p<\/mi><msub><mi>a<\/mi><mi>p<\/mi>/);
  assert.equal(presentation('r=⁵√2'),'<mrow><mi>r</mi><mo>=</mo><mroot><mn>2</mn><mn>5</mn></mroot></mrow>');
  assert.equal(presentation('inf_n'),'<msub><mi mathvariant="normal">inf</mi><mi>n</mi></msub>');
});
