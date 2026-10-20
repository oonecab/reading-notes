// Repair legacy converter output that attaches a script to a closing fence.
// Edits only wrap/reparent existing bytes; tokens and their order are invariant.
import fs from 'node:fs';import path from 'node:path';import {parse} from 'parse5';import {walk,attr} from '../../src/lib/controlled-html.mjs';
const write=process.argv.includes('--write');
const out=process.argv.find(a=>a.startsWith('--report='))?.slice(9)??'tmp/reading-typography/fence-repairs.json';
const match={')':'(',']':'[','}':'{','⟩':'⟨','|':'|','∣':'∣','‖':'‖'};
const text=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).map(text).join('');
const report={changes:[],unresolved:[]};
for(const book of fs.readdirSync('src/content/books'))for(const name of fs.readdirSync('src/content/books/'+book).filter(n=>n.endsWith('.html'))){
 const file='src/content/books/'+book+'/'+name;let s=fs.readFileSync(file,'utf8');const front=s.match(/^---\n[\s\S]*?\n---\n/)[0];let body=s.slice(front.length);
 for(let pass=0;pass<12;pass++){
  const nodes=walk(parse(body,{sourceCodeLocationInfo:true})),proposed=[],unresolved=[];
  for(const n of nodes){
   if(!['msub','msup','msubsup'].includes(n.tagName))continue;
   const cs=n.childNodes.filter(c=>c.tagName),loc=n.sourceCodeLocation;
   if(n.tagName==='msup'&&cs.length===4&&text(cs[0])==='('&&cs[1].tagName==='mfrac'&&text(cs[2])===')'){
    const a=cs[0].sourceCodeLocation.startOffset,b=cs[2].sourceCodeLocation.endOffset;
    proposed.push({start:loc.startOffset,end:loc.endOffset,value:body.slice(loc.startOffset,a)+'<mrow>'+body.slice(a,b)+'</mrow>'+body.slice(b,loc.endOffset),kind:'binomial-base'});continue;
   }
   if(cs[0]?.tagName!=='mo'||!match[text(cs[0])])continue;
   const close=text(cs[0]),open=match[close],siblings=n.parentNode.childNodes.filter(c=>c.tagName),index=siblings.indexOf(n);let depth=1,found=null;
   for(let i=index-1;i>=0;i--){
    const sib=siblings[i];if(sib.tagName!=='mo')continue;const value=text(sib);
    if(value===open){depth--;if(depth===0){found=sib;break;}}
    else if(value===close)depth++;
   }
   // Half-open intervals have intentionally different left and right fences.
   if(!found&&[')',']'].includes(close)){
    for(let i=index-1;i>=0;i--){
     const sib=siblings[i];
     if(sib.tagName==='mo'&&['(','['].includes(text(sib))){
      if(siblings.slice(i+1,index).some(x=>x.tagName==='mo'&&text(x)===','))found=sib;
      break;
     }
    }
   }
   if(!found){let m=n;while(m&&m.tagName!=='math')m=m.parentNode;unresolved.push({file,label:attr(m,'aria-label')??attr(m,'data-tex'),fence:close,line:loc?.startLine});continue;}
   const begin=found.sourceCodeLocation.startOffset,c=cs[0].sourceCodeLocation;
   const value=body.slice(loc.startOffset,loc.startTag.endOffset)+'<mrow>'+body.slice(begin,loc.startOffset)+body.slice(c.startOffset,c.endOffset)+'</mrow>'+body.slice(c.endOffset,loc.endOffset);
   proposed.push({start:begin,end:loc.endOffset,value,kind:'fenced-base'});
  }
  if(!proposed.length){report.unresolved.push(...unresolved);break;}
  const selected=[];for(const e of proposed.sort((a,b)=>(a.end-a.start)-(b.end-b.start)))if(!selected.some(x=>e.start<x.end&&e.end>x.start))selected.push(e);
  for(const e of selected.sort((a,b)=>b.start-a.start)){
   report.changes.push({file,pass,kind:e.kind,before:body.slice(e.start,e.end),after:e.value});body=body.slice(0,e.start)+e.value+body.slice(e.end);
  }
  if(pass===11)throw Error('Fence repair did not converge: '+file);
 }
 if(write)fs.writeFileSync(file,front+body);
}
fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({mode:write?'write':'check',repairs:report.changes.length,unresolved:report.unresolved}));
