// Validate shared teaching semantics independently of the browser geometry checks.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { parse } from 'parse5';
import { entries, walk, attr } from '../../src/lib/controlled-html.mjs';

const has = (n, c) => (attr(n, 'class') ?? '').split(/\s+/).includes(c);
const children = n => (n.childNodes ?? []).filter(n => n.tagName);
const text = n => n.nodeName === '#text' ? n.value : (n.childNodes ?? []).map(text).join('');

export function checkPage(html, book) {
  const nodes = walk(parse(html));
  assert(nodes.some(n => n.tagName === 'body' && has(n, 'rn-components')), 'Missing shared reading scope');
  const toc = nodes.find(n => has(n, 'chapter-toc'));
  if (toc) {
    const positions = new Map(nodes.map((n, i) => [attr(n, 'id'), i]).filter(([id]) => id));
    let previous = -1;
    for (const a of walk(toc).filter(n => n.tagName === 'a' && (attr(n, 'href') ?? '').startsWith('#'))) {
      const position = positions.get(attr(a, 'href').slice(1));
      assert(position !== undefined && position >= previous, 'TOC order differs from reading order');
      previous = position;
    }
  }
  if (book === 'csapp') {
    let previousLevel = 0;
    for (const n of nodes.filter(n => /^h[1-6]$/.test(n.tagName))) {
      const level = Number(n.tagName.slice(1));
      assert(level <= previousLevel + 1, 'Heading level skipped');
      previousLevel = level;
    }
  }
  const counts = { statement: 0, example: 0, proof: 0, exercise: 0 };
  for (const n of nodes) {
    if (has(n, 'source-statement') || has(n, 'statement')) assert(has(n, 'rn-statement'), 'Unmapped statement');
    if (has(n, 'example-worked') || (attr(n, 'data-source-item') ?? '').startsWith('例 ')) {
      assert(has(n, 'rn-example'), 'Unmapped numbered example');
    }
    if (has(n, 'proof') || has(n, 'proof-item') ||
        (book === 'stochastic' && (attr(n, 'id') ?? '').endsWith('-proof'))) {
      assert(has(n, 'rn-proof'), 'Unmapped proof');
    }
    if (has(n, 'rn-statement')) {
      counts.statement++;
      assert(n.tagName !== 'details', 'Statements must be visible');
      assert(children(n).some(n => /^h[3-4]$/.test(n.tagName)), 'Statement title missing');
      assert(children(n).filter(n => has(n, 'statement-body')).length === 1, 'Statement body missing');
    }
    if (has(n, 'rn-example')) {
      counts.example++;
      if (book === 'measure-probability' && attr(n, 'data-example-kind')) {
        const label = children(n).find(n => has(n, 'example-kind'));
        assert(label && text(label).trim() === '类型：' + attr(n, 'data-example-kind'), 'Example classification missing');
      }
    }
    if (has(n, 'rn-proof')) {
      counts.proof++;
      assert(n.tagName === 'details' && attr(n, 'open') !== undefined, 'Proof must default open');
      const [title, body] = children(n);
      assert(title?.tagName === 'summary' && text(title).trim(), 'Proof title missing');
      assert(has(body, 'rn-proof-body') && text(body).trim().length > 15, 'Proof body missing');
    }
    if (has(n, 'exercise')) {
      counts.exercise++;
      assert(n.tagName === 'details' && attr(n, 'open') === undefined, 'Exercise must default closed');
      const blocks = children(n);
      assert(blocks[0]?.tagName === 'summary', 'Exercise summary missing');
      const q = blocks.findIndex(n => has(n, 'exercise-question'));
      const a = blocks.findIndex(n => has(n, 'answer'));
      assert(q > 0 && a > q, 'Question must precede answer');
      for (const i of [q, a]) {
        const label = children(blocks[i])[0];
        assert(label?.tagName === 'p' && has(label, 'rn-exercise-label') && text(label).trim(), 'Exercise label missing');
        if (book === 'stochastic' && i === a) assert.equal(text(label).trim(), '解答', 'Solution label must be 解答');
      }
    }
    if (n.tagName === 'th') assert(['col', 'row', 'colgroup', 'rowgroup'].includes(attr(n, 'scope')), 'Table header scope missing');
    if (has(n, 'code-details')) {
      assert(n.tagName === 'details' && children(n)[0]?.tagName === 'summary' &&
        walk(n).some(n => n.tagName === 'code'), 'Code disclosure structure missing');
    }
    if (n.tagName === 'table') {
      const labelled = (attr(n, 'aria-labelledby') ?? '').split(/\s+/).filter(Boolean);
      assert(children(n).some(n => n.tagName === 'caption' && text(n).trim()) || attr(n, 'aria-label') ||
        (labelled.length && labelled.every(id => nodes.some(n => attr(n, 'id') === id && text(n).trim()))), 'Table accessible name missing');
    }
  }
  const originalExercises = nodes.filter(n => has(n, 'exercise') && !/^q\d/.test(attr(n, 'id') ?? ''));
  const indexes = nodes.filter(n => has(n, 'exercise-index'));
  if (originalExercises.length >= 20) {
    const links = indexes.flatMap(n => walk(n).filter(n => n.tagName === 'a'));
    assert(originalExercises.every(n => links.some(a => attr(a, 'href') === '#' + attr(n, 'id'))), 'Exercise index incomplete');
  }
  for (const index of indexes) {
    assert(attr(index, 'role') === 'navigation' && attr(index, 'aria-label'), 'Exercise index navigation name missing');
    for (const a of walk(index).filter(n => n.tagName === 'a')) {
      assert(attr(a, 'aria-label')?.startsWith('习题 '), 'Exercise index link name missing');
    }
  }
  return counts;
}

export function checkAll() {
  const inventory = JSON.parse(fs.readFileSync('docs/reading-components-inventory.json'));
  const result = [];
  for (const e of entries()) {
    const source = fs.readFileSync(e.filename, 'utf8');
    assert.equal(source.split('RN:include styles/reading-components.css').length, 2, 'Shared CSS must be included once');
    const counts = checkPage(e.html, e.metadata.book);
    const expected = inventory.pages.find(p => p.page === e.metadata.route);
    assert(expected, 'Missing component inventory');
    assert.deepEqual(counts, expected.counts, 'Component coverage drift: ' + e.metadata.route);
    result.push({ page: e.metadata.route, ...counts });
  }
  assert.equal(result.length, inventory.pages.length);
  return { status: 'passed', pages: result.length, totals: result.reduce((a, r) => {
    for (const k of ['statement', 'example', 'proof', 'exercise']) a[k] += r[k];
    return a;
  }, { statement: 0, example: 0, proof: 0, exercise: 0 }) };
}

if (process.argv[1] && path.resolve(process.argv[1]) === new URL(import.meta.url).pathname) {
  console.log(JSON.stringify(checkAll()));
}
