import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {parse} from 'parse5';
import {walk,attr} from '../../src/lib/controlled-html.mjs';

const digest = value => createHash('sha256').update(value).digest('hex');
const text = n => n.value ?? (n.childNodes ?? []).map(text).join('');
export const depthBinding = rows => digest(JSON.stringify(rows));

export function checkDepthPage(html, policy, contract, review) {
  const page = contract.pages[policy.page];
  const legacy = contract.legacy.filter(row => row.page === policy.page);
  if (!page) {
    assert(legacy.length === 1 && legacy[0].issue === 'I083' && legacy[0].source_sha256 === digest(html),
      'Missing or stale legacy depth registration: '+policy.page);
    return;
  }
  assert.equal(legacy.length, 0, 'Depth page also listed as legacy');
  const teaching = policy.sections.filter(s => s.role === 'teaching');
  const leaves = teaching.filter(s => !teaching.some(child => child.parent === s.id));
  assert.deepEqual(page.sections.map(s=>s.section),leaves.map(s=>s.id),'Depth section inventory differs');
  const nodes = walk(parse(html));
  const ids = new Map(nodes.filter(n=>attr(n,'id')).map(n=>[attr(n,'id'),n]));
  for(const row of page.sections){
    const children = ids.get(row.section).childNodes.filter(n=>n.tagName);
    const example = children.find(n=>attr(n,'data-worked-example')===row.section);
    assert(example,'Missing worked example: '+row.section);
    const fields = [row.question,row.example,row.boundary,row.invariant,row.representation,row.coherence,row.readback_conclusion,
      ...['input','initial','steps','result','check'].map(k=>row.trace?.[k])];
    assert(fields.every(s=>typeof s==='string' && s.trim().length>0) && new Set(fields).size===fields.length,
      'Incomplete or repetitive depth record: '+row.section);
    for(const field of [row.question,row.example,row.boundary]) assert(text(example).includes(field),'Example differs from review');
    const guides = {...row.figures,...row.textbook_code};
    const targets = children.filter(n=>n.tagName==='figure'||attr(n,'id')?.startsWith('input-'));
    assert.deepEqual(Object.keys(guides).sort(),targets.map(n=>attr(n,'id')).sort(),'Unreviewed teaching material');
    for(const node of targets){
      const id=attr(node,'id'), next=children[children.indexOf(node)+1];
      assert(next?.tagName==='p' && attr(next,'data-explains')===id && text(next)===guides[id] &&
        guides[id].trim().length && !text(node).includes(guides[id]),'Missing independent explanation: '+id);
    }
    assert(!targets.some(n=>text(n).includes(row.example)),'Copied input cannot serve as an example');
    const answer=ids.get(row.exercise);
    assert(answer && row.answer_reason && walk(answer).some(n=>attr(n,'class')==='answer' && text(n).includes(row.answer_reason)),
      'Exercise reasoning differs from review');
    assert(row.evidence?.probe===row.racket_readback && row.evidence?.readback===row.readback_conclusion,'Missing depth evidence');
  }
  assert.equal(digest(html),page.source_sha256,'Depth source binding changed');
  assert.equal(depthBinding(page.sections),review.depth_contract_sha256,'Content requires a new depth review');
}
