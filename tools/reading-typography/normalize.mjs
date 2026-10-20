import fs from 'node:fs';
import path from 'node:path';
import {parse} from 'parse5';
import {escape,prose,math,presentation,svgScripts,rawScript} from './math.mjs';
const write=process.argv.includes('--write');
const out=process.argv.find(a=>a.startsWith('--report='))?.slice(9)??'tmp/reading-typography/normalization.json';
const report={version:1,mode:write?'write':'check',pages:[],changes:[]};
const text=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).map(text).join('');
const attrs=n=>Object.fromEntries((n.attrs??[]).map(a=>[a.name,a.value]));
const all=n=>[n,...(n.childNodes??[]).flatMap(all)];
for(const book of fs.readdirSync('src/content/books')){
  for(const name of fs.readdirSync(`src/content/books/${book}`).filter(n=>n.endsWith('.html'))){
    const file=`src/content/books/${book}/${name}`,original=fs.readFileSync(file,'utf8');
    const front=original.match(/^---\n[\s\S]*?\n---\n/)[0],html=original.slice(front.length),edits=[];
    const tree=parse(html,{sourceCodeLocationInfo:true});
    function edit(n,value,kind,before=text(n)){
      const loc=n.sourceCodeLocation;if(!loc||html.slice(loc.startOffset,loc.endOffset)===value)return;
      edits.push({start:loc.startOffset,end:loc.endOffset,value});
      report.changes.push({file,line:loc.startLine,kind,before,after:value});
    }
    function inspect(n,anc=[]){
      const inTag=tag=>anc.some(a=>a.tagName===tag);
      // Interactive tile labels are replaced through textContent by the
      // existing permutation demo; they are UI state, not static formula nodes.
      if((attrs(n).class??'').split(/\s+/).includes('picture'))return;
      if(n.tagName==='style'){
        return;
      }
      if(['script','pre','head','title','desc','noscript','textarea'].includes(n.tagName)){
        // Styles inside head are handled without interpreting the document title.
        if(n.tagName==='head')for(const c of n.childNodes??[])if(c.tagName==='style')inspect(c,[...anc,n]);
        return;
      }
      if(n.tagName==='math'){
        for(const child of all(n).filter(c=>c.tagName==='mtext')){
          const value=text(child);
          if(rawScript.test(value)||/[=+−∈∋≡⊂≤≥↦→⇔]/u.test(value)){
            let formula=value;
            // The superscript j is nested inside the exponent, not multiplied by j.
            formula=formula.replace('rⁱ⁺⁽⁻¹⁾ʲᵏ','r^{i+(-1)^j k}');
            let markup=presentation(formula);
            if(value.startsWith('G ──φ──→ H；'))markup=markup.replace(
              '<mi>G</mi><mtext>─</mtext><mtext>─</mtext><mi>φ</mi><mtext>─</mtext><mtext>─</mtext><mo>→</mo><mi>H</mi>',
              '<mi>G</mi><mover><mo>→</mo><mi>φ</mi></mover><mi>H</mi>');
            edit(child,markup,'structured-formula',value);
          }
        }
        return;
      }
      if(n.tagName==='code'){
        const value=text(n);
        // These are mathematical notations in code tags, not runnable syntax.
        if(/[↦∈∉⊂⊆⊃⊇∪∩∅ℝℤℕℚℂ]/u.test(value)&&!/[;{}\n]/.test(value)){
          edit(n,math(value,{annotation:book==='visual-group-theory'}),'mathematical-code-tag',value);
        }else if(rawScript.test(value)&&!/[_;{}\n]/.test(value)&&!/\b(?:printf|return|let|proc|for|if)\b/.test(value)){
          edit(n,math(value,{annotation:book==='visual-group-theory'}),'mathematical-code-tag',value);
        }
        return;
      }
      if(n.nodeName==='#text'&&!inTag('math')){
        if(inTag('svg')){
          if(inTag('text')||inTag('tspan')){
            if(rawScript.test(n.value))edit(n,svgScripts(n.value),'svg-script',n.value);
          }
        }else{
          // In the Bernoulli/iid derivations these denote indexed random variables.
          const value=book==='stochastic'?n.value.replace(/\bXi\b/g,'Xᵢ').replace(/\bBi\b/g,'Bᵢ').replace(/\bEBi\b/g,'EBᵢ'):n.value;
          const sourceLabel=anc.some(a=>(attrs(a).class??'').split(/\s+/).some(c=>['source','code-label','code-title','english'].includes(c)));
          const englishSentence=!/[\u3400-\u9fff]/u.test(value)&&/[A-Za-z]{3,}\s+[A-Za-z]{2,}/.test(value);
          const result=prose(value,{annotation:book==='visual-group-theory',singles:!sourceLabel&&!englishSentence});
          if(result.changes.length)edit(n,result.html,'prose-math',n.value);
        }
        return;
      }
      for(const child of n.childNodes??[])inspect(child,[...anc,n]);
    }
    inspect(tree);
    if(!html.includes('RN:include styles/reading-typography.css')){
      const loc=html.lastIndexOf('</style>',html.indexOf('</head>'));
      if(loc<0)throw new Error('Missing stylesheet: '+file);
      edits.push({start:loc,end:loc,value:'\n<!-- RN:include styles/reading-typography.css -->\n'});
    }
    // A node class identifies diagram shapes; chart series and cell grids do not
    // acquire a node role merely because they are rectangular.
    let diagrams=0;
    for(const svg of all(tree).filter(n=>n.tagName==='svg')){
      const nodes=all(svg),a=attrs(svg);
      if(/benchmark|chart/.test(a.class??''))continue;
      const hasNodes=nodes.some(n=>['node','n'].some(c=>(attrs(n).class??'').split(/\s+/).includes(c)));
      if(!hasNodes)continue;
      const loc=svg.sourceCodeLocation.startTag,tag=html.slice(loc.startOffset,loc.endOffset);
      if(!(a.class??'').split(/\s+/).includes('rn-diagram')){
        const replacement=a.class?tag.replace(/\bclass=(["'])(.*?)\1/,(_,q,c)=>`class=${q}${c} rn-diagram${q}`):tag.replace('<svg','<svg class="rn-diagram"');
        edits.push({start:loc.startOffset,end:loc.endOffset,value:replacement});diagrams++;
      }
    }
    const sorted=edits.sort((a,b)=>b.start-a.start);let value=html,previous=html.length;
    for(const e of sorted){
      if(e.end>previous)throw new Error('Overlapping authoring edits: '+file);
      value=value.slice(0,e.start)+e.value+value.slice(e.end);previous=e.start;
    }
    if(write&&edits.length)fs.writeFileSync(file,front+value);
    report.pages.push({file,edits:edits.length,diagrams});
  }
}
fs.mkdirSync(path.dirname(out),{recursive:true});
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({mode:report.mode,pages:report.pages.length,changedPages:report.pages.filter(p=>p.edits).length,changes:report.changes.length,diagrams:report.pages.reduce((s,p)=>s+p.diagrams,0),report:out}));
