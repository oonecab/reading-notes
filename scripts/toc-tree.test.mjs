import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyTocState,expectedTocGroups,verifyGroupLayout,verifyPrintState} from './toc-tree-contract.mjs';
const links=['#parent','#child'];
const group={controls:'toc-group-parent',expanded:'true',visible:true,matches:1};
const state={links,summaryLinks:0,groups:[group],visible:2};
for (const [name,change,js,required] of [
  ['reordered links',{links:links.toReversed()},true],
  ['missing expansion',{groups:[{...group,expanded:null}]},true],
  ['missing control',{groups:[{...group,controls:null}]},true],
  ['link nested in summary',{summaryLinks:1},true],
  ['hidden without script',{groups:[],visible:1},false],
  ['deep link in collapsed group',{groups:[{...group,expanded:'false',visible:false}]},true,group.controls],
  ['current group not opened initially',{groups:[]},true,group.controls],
]) test(name,()=>assert.throws(()=>verifyTocState({...state,...change},links,js,required)));


test('only contiguous children belong to a parent', () => {
  const headings=['h2','h3','h3','h4','h3','h2',null,'h3','h2'];
  const rows=headings.map((heading,i)=>({href:'#s'+i,heading}));
  assert.deepEqual(expectedTocGroups(rows),[{href:'#s0',children:['#s1','#s2']}]);
});
test('buttons without scripting are invalid even if links remain visible', () => {
  assert.throws(()=>verifyTocState(state,links,false));
});
test('printing must expand and restore', () => {
  assert.throws(()=>verifyPrintState(['false'],['false'],['false']));
  assert.throws(()=>verifyPrintState(['false'],['true'],['true']));
});

test('duplicate initialization and spurious children are rejected', () => {
  const rows=[{href:'#p',heading:'h2'},{href:'#c',heading:'h3'},{href:'#x',heading:'h4'}];
  const groups=expectedTocGroups(rows);
  assert.throws(()=>verifyGroupLayout({stable:false,groups},rows,true));
  assert.throws(()=>verifyGroupLayout({stable:true,groups:[...groups,...groups]},rows,true));
  assert.throws(()=>verifyGroupLayout({stable:true,groups:[{href:'#p',children:['#c','#x']}]},rows,true));
});

test('smoke rejects missing expected buttons and hidden expanded lists', () => {
  const rows=[{href:'#parent',heading:'h2'},{href:'#child',heading:'h3'}];
  assert.throws(()=>verifyGroupLayout({stable:true,groups:[]},rows,true), /grouping/);
  assert.throws(()=>verifyTocState({...state,groups:[{...group,visible:false}]},links,true), /visibility/);
});

test('a duplicated controlled id makes the group ambiguous', () => {
  const duplicate={...group,matches:2};
  assert.throws(()=>verifyTocState({...state,groups:[duplicate]},links,true), /ambiguous/);
});
