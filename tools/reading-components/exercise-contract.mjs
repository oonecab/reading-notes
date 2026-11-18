import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {parse} from 'parse5';
import {walk, attr} from '../../src/lib/controlled-html.mjs';

const rules = JSON.parse(fs.readFileSync(new URL('../../docs/exercise-contract.json', import.meta.url)));
export const digest = html => createHash('sha256').update(html).digest('hex');
const has = (n, c) => (n && attr(n, 'class') || '').split(/\s+/).includes(c);
const children = n => (n?.childNodes ?? []).filter(c => c.tagName);
const visible = n => n?.tagName === 'annotation' ? '' : n?.value ?? (n?.childNodes ?? []).map(visible).join('');
export function pdfPagesValid(q) {
  const pages = (q && attr(q, 'data-source-pdf-pages') || '').split(',');
  const links = q ? walk(q).filter(n => n.tagName === 'a').map(n => attr(n,'href') ?? '').filter(h => /\.pdf#/i.test(h)) : [];
  return pages.every(p => /^[1-9]\d*$/.test(p)) && new Set(pages).size === pages.length &&
    links.length > 0 && links.every(h => pages.includes(h.match(/#page=(\d+)$/)?.[1]));
}
export function exerciseAudit(html) {
  const nodes = walk(parse(html)), issues = {};
  const exercises = nodes.filter(n => has(n,'exercise'));
  const add = (rule,id) => (issues[rule] ??= []).push(id);
  const nums = new Set();
  const idCounts = new Map();
  for (const n of nodes) {
    const id = attr(n, 'id');
    if (id) idCounts.set(id, (idCounts.get(id) ?? 0) + 1);
  }
  for (const e of exercises) {
    const id = attr(e,'id'), number = attr(e,'data-exercise'), self = attr(e,'data-self-check') === 'true';
    const blocks = children(e), [s,q,a] = blocks, [ql] = children(q), [al] = children(a);
    const check = (ok, rule) => { if (!ok) add(rule,id ?? '(missing)'); };
    check(e.tagName === 'details' && attr(e,'open') === undefined,'collapsed');
    check(id && idCounts.get(id) === 1,'stable-id');
    check(number && !nums.has(number) && (self || /^\d+\.\d+$/.test(number)), 'data-exercise');
    nums.add(number);
    check(blocks.length === 3 && s?.tagName === 'summary' && q?.tagName === 'div' && has(q,'exercise-question') && a?.tagName === 'div' && has(a,'answer'),'structure');
    const title = visible(s).trim();
    check(self ? /^自测\s+\S/.test(title) : title.startsWith('习题 '+number+' · ') && title.slice(('习题 '+number+' · ').length).trim(), 'summary');
    check(self || attr(e,'data-self-check') === undefined,'self-check');
    check(ql?.tagName === 'p' && has(ql,'question-title') && has(ql,'rn-exercise-label'),'question-title');
    check(al?.tagName === 'p' && has(al,'answer-title') && has(al,'rn-exercise-label'),'answer-title');
    check(visible(ql).trim() === rules.question_label,'question-label');
    check(visible(al).trim() === rules.answer_label,'answer-label');
    check(q && number && attr(q,'data-original-exercise') === number,'data-original-exercise');
    check(pdfPagesValid(q),'data-source-pdf-pages');
  }
  const originals = exercises.filter(e => attr(e,'data-self-check') !== 'true');
  if (originals.length >= rules.index_threshold) {
    const index = nodes.find(n => has(n,'exercise-index'));
    const links = index ? walk(index).filter(n => n.tagName === 'a') : [];
    if (!index || nodes.indexOf(index) >= nodes.indexOf(originals[0]) ||
        !originals.every(e => links.some(a => attr(a,'href') === '#'+attr(e,'id') && attr(a,'aria-label') === '习题 '+attr(e,'data-exercise')))) add('exercise-index','page');
  }
  return {count:exercises.length,issues};
}
export function registeredLegacy(page,html) {
  const row = rules.legacy.find(r => r.page === page);
  if (row) assert(row.book === page.split('/')[0] && row.reason && row.issue === 'I079' && row.review_version && row.source_sha256 === digest(html),'Legacy page changed; migrate to RN-001: '+page);
  return Boolean(row);
}
export function checkExerciseContract(html,page) {
  if (registeredLegacy(page, html)) return;
  const {issues} = exerciseAudit(html);
  assert.deepEqual(issues, {}, 'Exercise contract deviation: '+page+' '+JSON.stringify(issues));
}
