import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync('src/scripts/65baddecd4cd62c3e734.js','utf8');
const overflow=source.slice(source.lastIndexOf('(() => {'));
test('overflow measurement reads the whole batch before writing and is stable on repeated events',()=>{
  let writes=0, dirty=false, frame;
  const widths=[{width:100,scroll:150},{width:0,scroll:300},{width:100,scroll:101},{width:100,scroll:140}];
  const containers=widths.map((size,i)=>{
    const attrs=i===3?{tabindex:'7'}:{};
    const changed=()=>{dirty=true;writes++;};
    return {
      dataset:new Proxy({}, {set(obj,key,value){changed();obj[key]=value;return true;},deleteProperty(obj,key){changed();delete obj[key];return true;}}),
      get clientWidth(){assert.equal(dirty,false,'layout read after a DOM write');return size.width;},
      get scrollWidth(){assert.equal(dirty,false,'layout read after a DOM write');return size.scroll;},
      matches(){return i===0;},hasAttribute(name){return name in attrs;},
      set tabIndex(value){changed();attrs.tabindex=String(value);},
      removeAttribute(name){changed();delete attrs[name];},attrs,
    };
  });
  const events={};
  vm.runInNewContext(overflow, {document:{querySelectorAll:()=>containers,addEventListener(){},fonts:{ready:{then(){}}}},
    addEventListener:(name,fn)=>events[name]=fn,requestAnimationFrame:fn=>frame=fn});
  assert.deepEqual(containers.map(n=>n.dataset.horizontalOverflow),['true','false','false','true']);
  assert.equal(containers[0].attrs.tabindex,'0');assert.equal(containers[3].attrs.tabindex,'7');
  assert.match(containers[0].dataset.scrollLabel,/公式/);
  writes=0;dirty=false;events.resize();frame();assert.equal(writes,0);
  widths[0].width=200;dirty=false;events.resize();frame();
  assert.equal(containers[0].dataset.horizontalOverflow,'false');assert.equal(containers[0].attrs.tabindex,undefined);
  assert.equal(containers[3].attrs.tabindex,'7');
});

import os from 'node:os';
import path from 'node:path';
import {checkBudgets,measure} from './performance-budget.mjs';
test('size and DOM budget catches growth independently of browser timings',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'rn-budget-'));
 try {
  const html='<html><head></head><body><main>reading</main></body></html>';
  const metrics=measure(html),policy={default:metrics,pages:{}};
  fs.writeFileSync(path.join(folder,'index.html'),html);checkBudgets(folder,policy);
  fs.writeFileSync(path.join(folder,'index.html'),html.replace('</main>','<span>extra</span></main>'));
  assert.throws(()=>checkBudgets(folder,policy),/budget exceeded/);
 } finally {fs.rmSync(folder,{recursive:true,force:true});}
});
