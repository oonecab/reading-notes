import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {parse} from 'parse5';
import {entries, walk, attr} from '../../src/lib/controlled-html.mjs';

const text = n => n.nodeName === '#text' ? n.value : (n.childNodes ?? []).map(text).join('');
const parents = n => n.parentNode ? [n.parentNode, ...parents(n.parentNode)] : [];

export function requireInlinePrograms(html, expected) {
  const codes = walk(parse(html)).filter(n => n.tagName === 'code' && !parents(n).some(p => p.tagName === 'pre'));
  for (const expression of expected) {
    assert(codes.some(n => text(n) === expression && !walk(n).some(p => p.tagName === 'math')),
      `Program expression must be one inline code element: ${expression}`);
  }
}

export function checkNodePadding(shape, labels, minimum = 3) {
  assert(labels.length, 'Node requires an associated label');
  for (const label of labels) {
    const inset = Math.min(label.x - shape.x, label.y - shape.y,
      shape.x + shape.w - label.x - label.w, shape.y + shape.h - label.y - label.h);
    assert(inset >= minimum, `Label touches or exceeds node boundary: ${inset}`);
  }
}

export function requirePositionedSvgMath(html) {
  for (const n of walk(parse(html))) {
    if (n.nodeName === '#text' && parents(n).some(p => p.tagName === 'text')) {
      assert(!/[_^](?:\(|[A-Za-z])/.test(n.value), `Unpositioned SVG mathematical index: ${n.value}`);
    }
    if (n.tagName === 'tspan' && attr(n, 'data-notation')) {
      const match = attr(n, 'data-notation').match(/^([_^])(?:\(([^()]+)\)|([A-Za-z]))$/);
      assert(match, 'SVG mathematical index needs an unambiguous source notation');
      assert.equal(text(n), match[2] ?? match[3], 'SVG index must preserve its source value');
      assert.equal(attr(n, 'baseline-shift'), match[1] === '^' ? 'super' : 'sub');
    }
  }
}

export function checkAll() {
  const pages = entries();
  const examples = {
    'eopl/notes/preface.html': ['proc (y) body', 'let x = 20', 'Env(procedure.param, argument, parent)'],
    'csapp/notes/chapter02_information.html': ['replace_byte(0x12345678,2,0xAB)', 'rotate_left(unsigned x,int n)'],
    'csapp/notes/chapter03_machine_level.html': ['movq (%rdi),%rax', 'movl (%rdx,%rcx,4),%eax'],
    'csapp/notes/chapter04_architecture.html': ['pipe-lf.hcl'],
    'csapp/notes/chapter05_optimization.html': ['while(i1<n && i2<n)', 'memset(void *s,int c,size_t n)'],
    'csapp/notes/chapter08_exceptional.html': ['waitpid(-1,&s,WNOHANG)', 'waitpid(p,&s,0)'],
    'csapp/notes/chapter12_concurrency.html': ['if(!initialized){init(); initialized=1;}'],
  };
  let codes = 0, fittedNodes = 0;
  for (const page of pages) {
    const nodes = walk(parse(page.html));
    const styles = nodes.filter(n => n.tagName === 'style').map(text).join('\n');
    assert(styles.includes('code:not(pre code)'), `${page.metadata.route}: missing inline program style`);
    assert(styles.includes('max-width:100%;vertical-align:baseline'), 'Long code must fit its text column');
    for (const n of nodes.filter(n => n.tagName === 'code')) {
      assert(!parents(n).some(p => p.tagName === 'code'), 'Nested code element');
      if (!parents(n).some(p => p.tagName === 'pre')) codes++;
    }
    fittedNodes += nodes.filter(n => n.attrs?.some(a => a.name === 'data-rn-fit')).length;
    if (examples[page.metadata.route]) requireInlinePrograms(page.html, examples[page.metadata.route]);
    if (['stochastic', 'measure-probability', 'visual-group-theory'].includes(page.metadata.book)) {
      requirePositionedSvgMath(page.html);
    }
  }
  return {status: 'passed', pages: pages.length, inline_code: codes, fitted_nodes: fittedNodes};
}

if (process.argv[1] && path.resolve(process.argv[1]) === new URL(import.meta.url).pathname) {
  console.log(JSON.stringify(checkAll()));
}
