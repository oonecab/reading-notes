import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {parse,serializeOuter} from 'parse5';
import {walk,attr,sharedAsset} from '../../../src/lib/controlled-html.mjs';
import {checkReaderPage,reviewedQuestions} from '../../../tools/reader-contract/check.mjs';
import {checkVisualPage} from '../../../tools/visual-contract/check.mjs';
import {checkDepthPage} from '../../../tools/content-depth/check.mjs';
import {checkExerciseContract} from '../../../tools/reading-components/exercise-contract.mjs';
import {checkTypography} from '../../../tools/reading-typography/check.mjs';
import {checkMathNotation,checkMathUnits} from '../../../tools/reading-typography/notation-check.mjs';
import {scanProse} from '../../../tools/reading-prose/check.mjs';
import {requireCodeFolding} from '../../../tools/reading-presentation/check.mjs';
const read=p=>JSON.parse(fs.readFileSync(p));
const book='books/sicp/',review=read(book+'review/chapter05.json'),policy=review.reader_policy;
const ref=read('docs/reader-sources.json').books.sicp;
const formal=fs.existsSync(policy.source);
const src=fs.readFileSync(formal?policy.source:policy.source.replace(/([^/]+)$/,'candidates/$1'),'utf8').replace(/^---\n[\s\S]*?\n---\n/,'');
assert.equal(src.split('<!-- RN:include scripts/toc-tree.js -->').length,2);
const html=src.replace(/<!-- RN:include ([\w/.-]+) -->/g,(_,a)=>sharedAsset(a));
const hash=x=>createHash('sha256').update(x).digest('hex');
const visual=read('docs/visual-contract.json'),depth=read('docs/content-depth-contract.json');
if(!formal){
  visual.books.sicp.pages[policy.page]={sections:review.visual_sections};
  depth.pages[policy.page]={sections:review.content_depth.sections,source_sha256:review.source_sha256[policy.page]};
}
const byId=(nodes,id)=>nodes.find(n=>attr(n,'id')===id);
const text=n=>n.value??(n.childNodes??[]).map(text).join('');
const checkQuestions=s=>assert.deepEqual(reviewedQuestions(s),review.question_bindings);
const checkVisual=s=>checkVisualPage(s,policy,visual,ref);
const checkDepth=s=>checkDepthPage(s,policy,depth,review);
const checkReader=s=>checkReaderPage(s,policy,ref,null,{strictPages:true});
const checkProse=s=>assert.deepEqual(scanProse(s),[]);
const programs=['chapter05.rkt','chapter05-c.rkt'].map(file=>fs.readFileSync(book+'code/'+file,'utf8').replaceAll('\r\n','\n'));
const checkProgram=s=>{
  const copies=walk(byId(walk(parse(s)),'programs')).filter(n=>n.tagName==='code').map(text);
  for(const program of programs)assert.equal(copies.filter(copy=>copy===program).length,1,'Complete program mirror changed');
};
const nodes=walk(parse(html)),inventory=read(book+'notes/source_inventory.json').exercises.filter(q=>q.number.startsWith('5.'));
const archive=read(book+'notes/questions_ch05.json'),inputs=read(book+'notes/chapter05-inputs.json');
assert.equal(hash(fs.readFileSync(archive.pdf.file)),archive.pdf.sha256);
assert.equal(inventory.length,52);
assert.equal(archive.items.length,inventory.length);
const teaching=policy.sections.filter(section=>section.role==='teaching');
for(const [parts,expected] of [[2,5],[3,22]]){
 const sections=teaching.filter(section=>section.id.slice(1).split('-').length===parts);
 assert.equal(sections.length,expected);
 for(const section of sections)assert(byId(nodes,section.id),section.id);
}
const parents=review.content_depth.parent_sections;
assert.deepEqual(parents.map(row=>row.section),teaching.filter(section=>teaching.some(child=>child.parent===section.id)).map(section=>section.id));
if(formal)assert.deepEqual(parents,depth.pages[policy.page].parent_sections);
for(const parent of parents){
 const section=byId(nodes,parent.section);
 for(const field of ['question','example','boundary'])assert(text(section).includes(parent[field]),parent.section+' '+field);
 const examples=review.content_depth.sections.filter(row=>row.section.startsWith(parent.section+'-'));
 assert.deepEqual(parent.execution_evidence,examples.map(row=>row.racket_readback));
 assert.deepEqual(parent.worked_sections,examples.map(row=>row.section));
}
const figures=nodes.filter(node=>node.tagName==='figure');
assert.deepEqual(figures.map(node=>attr(node,'id')).sort(),Array.from({length:18},(_,i)=>'fig-5-'+(i+1)).sort());
for(const [i,q] of inventory.entries()){
 const n=q.number,f=archive.items[i],ex=byId(nodes,'ex-5-'+(i+1));assert.equal(f.number,n);assert.equal(f.pdf_page,q.pdf_page);
 assert.equal(f.pdf_heading_verified,true);
 assert.equal(hash(f.original_texinfo),f.source_block_sha256);
 assert.equal(hash(serializeOuter(walk(ex).find(n=>attr(n,'class')==='answer'))),review.answer_sha256[n]);
 assert.equal(f.published_question_sha256,review.question_bindings[i].sha256);
 assert.equal((f.original_texinfo.match(/@anchor\{Exercise 5\./g)??[]).length,1);
 assert.equal(attr(ex,'data-exercise'),n);assert.equal(attr(ex,'open'),undefined);
 assert.equal(attr(walk(ex).find(n=>attr(n,'class')==='exercise-question'),'data-source-pdf-pages'),String(q.pdf_page));
 assert.deepEqual(review.question_bindings[i].dependencies.map(d=>d.anchor).filter(a=>a.startsWith('#input-')).sort(),
 (inputs.question_dependencies[n]??[]).map(a=>'#'+a).sort());
}
const outline=read(book+'notes/source_inventory.json').toc.filter(node=>node.pdf_page>=694&&node.pdf_page<=861&&node.level>1);
assert.equal(outline.length,teaching.length);
for(const [i,section] of teaching.entries()){
 const element=byId(nodes,section.id);
 assert.equal(element.childNodes.find(n=>/^h[1-6]$/.test(n.tagName??'')).tagName,'h'+outline[i].level);
 assert.equal(attr(walk(element).find(n=>n.tagName==='a'),'href'),'../sicp.pdf#page='+outline[i].pdf_page);
}
for(const input of inputs.records)assert.equal(text(walk(byId(nodes,input.id)).find(n=>n.tagName==='code')),input.code);
const index=nodes.find(n=>attr(n,'class')==='exercise-index');
assert.deepEqual(walk(index).filter(n=>n.tagName==='a').map(n=>attr(n,'href')),policy.questions.map(v=>'#'+v));
checkQuestions(html);checkVisual(html);checkDepth(html);checkProse(html);checkProgram(html);
checkExerciseContract(html,policy.page);checkTypography(html);checkMathNotation(html,'sicp');checkMathUnits(html);requireCodeFolding(html);
const summary=checkReader(html);
const mutations=[
 ['id="ex-5-52"','id="lost"',checkQuestions],
 ['href="#input-gcd-machine"','href="#input-return-register"',checkQuestions],
 ['(provide (all-defined-out)','(provide damaged-environment',checkProgram],
 ['id="fig-5-1"','id="removed"',checkVisual],
 ['id="excerpt-register"','id="lost"',checkVisual],
 ['<h1>','<p>(lambda (x) x)</p><h1>',checkProse],
 ['href="#ex-5-52"','href="#lost-target"',checkReader],
 ['data-worked-example="s5-1-1"','data-absent="s5-1-1"',checkDepth]];
for(const [a,b,fn] of mutations){const altered=html.replace(a,b);assert.notEqual(altered,html);assert.throws(()=>fn(altered),a)}
console.log(JSON.stringify({...summary,original_figures:figures.length,shared_inputs:inputs.records.length,depth_sections:review.content_depth.sections.length,rejected_mutations:mutations.length}));
