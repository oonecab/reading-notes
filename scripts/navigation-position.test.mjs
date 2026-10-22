import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('../src/scripts/6a3f8b30744a694f9192.js',import.meta.url),'utf8');
function navigation({wide=false,hash='#statement-index'}={}){
  const tasks=[],frames=[],events={};let top=584,scrolled=false;
  const section={getBoundingClientRect:()=>({top:0})};
  const index={tagName:'DETAILS',parentElement:null,open:false,
    getBoundingClientRect:()=>({top}),scrollIntoView(){top=wide?96:128;scrolled=true;}};
  const link=id=>({hash:'#'+id,current:false,setAttribute(){this.current=true;},removeAttribute(){this.current=false;}});
  const first=link('first'),last=link('statement-index');
  const panel={open:false,querySelector:()=>({getBoundingClientRect:()=>({bottom:109.625})})};
  const nav={querySelectorAll:()=>[first,last],addEventListener(){}};
  const nodes={'toc-panel':panel,'chapter-toc':nav,first:section,'statement-index':index};
  const context={document:{documentElement:{classList:{add(){}},scrollHeight:56495},getElementById:id=>nodes[id],addEventListener(){}},
    location:{hash},matchMedia:()=>({matches:wide,addEventListener(){}}),innerHeight:950,
    requestAnimationFrame:f=>frames.push(f),setTimeout:f=>tasks.push(f),
    scrollBy(x,y){top-=y;events.scroll?.();},addEventListener:(name,f)=>{events[name]=f;},window:{scrollY:0}};
  vm.runInNewContext(source,context);
  for(let i=0;i<10&&(tasks.length||frames.length);i++){
    while(tasks.length)tasks.shift()();
    const current=frames.splice(0);for(const f of current)f();
  }
  return {index,last,top,scrolled};
}
for(const wide of [false,true])test(`an expanded end index settles before the current TOC entry is chosen (${wide?'desktop':'mobile'})`,()=>{
  const state=navigation({wide});
  assert(state.index.open,'the original disclosure must open');
  assert(state.scrolled,'native positioning before disclosure expansion must be repeated');
  assert(state.last.current,'the index must become the current TOC entry');
  assert(state.top+12>=(wide?57:109.625),'the visible summary must clear the sticky controls');
});
test('empty or missing fragment targets do not schedule a scroll',()=>{
  for(const hash of ['', '#missing'])assert.equal(navigation({hash}).scrolled,false);
});
