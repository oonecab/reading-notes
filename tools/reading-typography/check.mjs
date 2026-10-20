import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {parse} from 'parse5';
import {entries,walk,attr} from '../../src/lib/controlled-html.mjs';
import {rawScript} from './math.mjs';
const text=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).map(text).join('');
const ancestors=n=>n.parentNode?[n.parentNode,...ancestors(n.parentNode)]:[];

export function checkTypography(html){
  const nodes=walk(parse(html)),styles=nodes.filter(n=>n.tagName==='style').map(text).join('\n');
  assert(styles.includes('--rn-text-font:"Times New Roman"'),'Missing Times New Roman contract');
  assert(styles.includes('text-transform:none'),'Math letters must not be remapped to a different font');
  let maths=0,graphs=0,scripts=0;
  for(const n of nodes){
    const parents=ancestors(n);
    if(n.tagName==='math'){
      maths++;
      assert(!parents.some(p=>p.tagName==='math'),'Nested math element');
      for(const s of walk(n).filter(x=>['msub','msup','msubsup','mfrac'].includes(x.tagName))){
        const parts=(s.childNodes??[]).filter(c=>c.tagName);
        assert.equal(parts.length,s.tagName==='msubsup'?3:2,'Invalid script or fraction operands');
        if(s.tagName!=='mfrac')assert(!(parts[0]?.tagName==='mo'&&[')',']','}','⟩'].includes(text(parts[0]))),'Script must apply to the complete fenced base');
      }
    }
    if(n.tagName==='svg')graphs++;
    if(n.tagName==='tspan'&&attr(n,'baseline-shift'))scripts++;
    if(n.nodeName!=='#text'||parents.some(p=>['math','script','style','pre','code','head','title','desc'].includes(p.tagName)))continue;
    if(parents.some(p=>p.tagName==='svg')){
      if(parents.some(p=>['text','tspan'].includes(p.tagName)))assert(!rawScript.test(n.value),'Unpositioned SVG sub/superscript: '+n.value.slice(0,90));
    }else{
      assert(!rawScript.test(n.value),'Unformatted prose sub/superscript: '+n.value.slice(0,90));
      assert(!/\b[A-Za-z](?:_[0-9]+|_\{[^}]+\}|\^[0-9]+|\^\{[^}]+\})/.test(n.value),
        'Unformatted prose TeX script: '+n.value.slice(0,90));
      assert(!/[∈∉⊂⊆⊃⊇∪∩∅∞≤≥≠≈≡↦∘√∣∧∨]/u.test(n.value),'Unformatted prose math: '+n.value.slice(0,90));
    }
  }
  return {maths,graphs,svg_scripts:scripts};
}
export function checkAll(){
  const pages=[];
  for(const entry of entries()){
    const source=fs.readFileSync(entry.filename,'utf8');
    assert.equal(source.split('RN:include styles/reading-typography.css').length,2,'Typography must be included once');
    assert(/RN:include styles\/reading-typography.css -->\s*<\/style>/.test(source),'Typography must close the cascade');
    try{pages.push({page:entry.metadata.route,...checkTypography(entry.html)});}
    catch(error){throw new Error(entry.metadata.route+': '+error.message,{cause:error});}
  }
  const scope=entries().find(e=>e.metadata.route==='eopl/notes/preface.html');
  if(scope){
    const nodes=walk(parse(scope.html)),edges=nodes.map(n=>attr(n,'data-edge')).filter(Boolean);
    assert.deepEqual(edges,['E3-E2','E2-E1','closure-E1','E4-E1'],'Closure environment relationships changed');
  }
  const overview=entries().find(e=>e.metadata.route==='eopl/notes/book_overview.html');
  if(overview){
    const edges=walk(parse(overview.html)).map(n=>attr(n,'data-edge')).filter(Boolean);
    assert.deepEqual(edges,['1-2','2-3','3-4','4-5','5-6','4-7','7-8','7-9'],
      'EOPL chapter dependencies changed');
  }
  return {status:'passed',pages:pages.length,records:pages};
}
if(process.argv[1]&&path.resolve(process.argv[1])===new URL(import.meta.url).pathname){
  const result=checkAll();fs.mkdirSync('tmp/reading-typography',{recursive:true});
  fs.writeFileSync('tmp/reading-typography/static-check.json',JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({status:result.status,pages:result.pages,maths:result.records.reduce((s,p)=>s+p.maths,0),graphs:result.records.reduce((s,p)=>s+p.graphs,0)}));
}
