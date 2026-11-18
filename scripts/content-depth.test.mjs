import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {readSource} from '../src/lib/controlled-html.mjs';
import {checkDepthPage} from '../tools/content-depth/check.mjs';
const json=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const contract=json('docs/content-depth-contract.json'), page=Object.keys(contract.pages)[0];
const review=json(contract.pages[page].review_record), policy=review.reader_policy, {html}=readSource(policy.source);
test('reviewed SICP chapter passes depth contract',()=>checkDepthPage(html,policy,contract,review));
for(const [name,change] of Object.entries({
  question:r=>delete r.question, example:r=>delete r.example, boundary:r=>delete r.boundary,
  steps:r=>delete r.trace.steps, generic:r=>Object.keys(r.trace).forEach(k=>r.trace[k]='相同的步骤'),
  figure:r=>r.figures={}, code:r=>r.textbook_code={}, copied:r=>r.example=r.question
})){
  test('depth rejects '+name,()=>{
    const changed=structuredClone(contract),rows=changed.pages[page].sections;
    const row=rows.find(r=>Object.keys(r.figures).length && Object.keys(r.textbook_code).length);
    change(row);
    assert.throws(()=>checkDepthPage(html,policy,changed,review));
  });
}
test('unregistered legacy page fails',()=>assert.throws(()=>checkDepthPage(html,{page:'other/notes/new.html'},contract,review)));
test('copied source material cannot substitute for the worked example',()=>{
  const changed=structuredClone(contract), row=changed.pages[page].sections.find(s=>s.section==='s2-1-4');
  const copy='(define (make-center-width c w)';
  row.example=copy;
  const replaced=html.replace(contract.pages[page].sections.find(s=>s.section===row.section).example,copy);
  assert.throws(()=>checkDepthPage(replaced,policy,changed,review),/Copied input/);
});
