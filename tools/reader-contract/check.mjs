// Reader-facing obligations are registered independently of rendered content.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {parse,serialize,serializeOuter} from 'parse5';
import {entries,walk,attr} from '../../src/lib/controlled-html.mjs';
const has=(n,c)=>(attr(n,'class')??'').split(/\s+/).includes(c);
const raw=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).map(raw).join('');
const within=(n,c)=>n&&(has(n,c)||within(n.parentNode,c));
const exerciseLabels=new Set(['原题（中文翻译）','解答','问题','题目','自测题','题目（中文）','解答与推导','原题','解答与执行','原书题目','参考解答','原书题意（中文转述）','解答与推演','题目（中文转述）：']);
export function inputSnapshot(target){
 if(/^h[1-6]$/.test(target.tagName)){
  const level=Number(target.tagName[1]),siblings=target.parentNode.childNodes;
  const chunk=[];
  for(let i=siblings.indexOf(target);i<siblings.length;i++){
   const n=siblings[i];
   if(n!==target&&/^h[1-6]$/.test(n.tagName)&&Number(n.tagName[1])<=level)break;
   chunk.push(serializeOuter(n));
  }
  return chunk.join('');
 }
 if(['a','span','strong','em'].includes(target.tagName)){
  while(target.parentNode&&!['p','li','div','section','figure','table'].includes(target.tagName))target=target.parentNode;
 }
 return serializeOuter(target);
}
export function questionText(n){
 if(n.tagName==='math'||n.tagName==='code'||n.tagName==='pre'||n.tagName==='svg'||attr(n,'lang')==='en'||['rn-exercise-label','source','source-ref','original-question','question-context'].some(c=>has(n,c)))return '';
 return n.nodeName==='#text'?n.value:(n.childNodes??[]).map(questionText).join('');
}
export function reviewedQuestions(html){
 const nodes=walk(parse(html));
 return nodes.filter(n=>has(n,'exercise')).map(exercise=>{
  const q=walk(exercise).find(n=>has(n,'exercise-question'));
  assert(q,'Question missing: '+attr(exercise,'id'));
  const dependencies=[...new Set(walk(q).filter(n=>n.tagName==='a').map(n=>attr(n,'href')).filter(h=>h?.startsWith('#')))];
  return {id:attr(exercise,'id'),sha256:createHash('sha256').update(serialize(q)).digest('hex'),
   dependencies:dependencies.map(h=>{
    const target=nodes.find(n=>attr(n,'id')===h.slice(1));assert(target,'Question input missing: '+h);
    return {anchor:h,sha256:createHash('sha256').update(inputSnapshot(target)).digest('hex')};
   })};
 });
}
export function checkReaderPage(html,policy,source,review){
 const nodes=walk(parse(html));const result={page:policy.page,questions:0,annotations:0,pdf_links:0};
 const find=id=>nodes.find(n=>attr(n,'id')===id);
 const main=nodes.find(n=>n.tagName==='main');assert(main,'main missing');
 for(const label of walk(main).filter(n=>has(n,'rn-exercise-label')))
  assert(exerciseLabels.has(raw(label).trim()),'Exercise label contains body text');
 const sections=walk(main).filter(n=>n.tagName==='section'&&n.parentNode===main);
 assert.deepEqual(sections.map(n=>attr(n,'id')),policy.sections.map(s=>s.id),'Unreviewed section inventory');
 const expected=policy.sections.filter(s=>s.annotation==='required').map(s=>s.id);
 assert(expected.length,'Every reading page must register annotation coverage');
 const groups=walk(main).filter(n=>has(n,'reading-notes'));
 assert(groups.length,'Missing reading annotations');
 const targets=groups.map(n=>attr(n,'data-notes-for'));
 assert.equal(targets.length,new Set(targets).size,'Duplicate annotation binding');
 for(const id of expected)assert(targets.includes(id),'Missing required annotation: '+id);
 for(const group of groups){
  const id=attr(group,'data-notes-for');const section=find(id);
  assert(section?.tagName==='section'&&policy.sections.some(s=>s.id===id),'Invalid annotation target: '+id);
  assert(walk(section).includes(group),'Annotation outside its section');
  const body=walk(group).find(n=>has(n,'reading-notes-body'));
  assert(body&&raw(body).replace(/\s/g,'').length>=45,'Annotation content too short: '+id);
  assert(group.tagName==='details'&&attr(group,'open')!==undefined,'Inline annotation must be readable without JS');
 }
 assert(find('annotation-rail')&&find('annotation-content')&&find('annotation-context-link'),'Missing annotation rail');
 assert(nodes.some(n=>n.tagName==='script'&&attr(n,'id')==='reading-notes-controller'),'Annotation controller missing');
 result.annotations=groups.length;
 const questions=walk(main).filter(n=>has(n,'exercise'));
 assert.deepEqual(questions.map(n=>attr(n,'id')),policy.questions,'Unreviewed exercise inventory');
 for(const exercise of questions){
  const id=attr(exercise,'id'),q=walk(exercise).find(n=>has(n,'exercise-question'));
  assert(q,'Question missing: '+id);
  const chinese=(questionText(q).match(/[\u3400-\u9fff]/g)??[]).length;
  // A complete task can be as short as “证明” followed by a displayed formula.
  assert(chinese>=2,'Chinese question task missing: '+id);
  // RN-002 forbids full English originals in reader pages; legacy blocks, if any,
  // must at least stay collapsed and follow the Chinese translation.
  const translation=walk(q).find(n=>has(n,'question-translation'));
  if(translation){
   assert(attr(translation,'lang')==='zh-CN','Chinese translation language missing: '+id);
   assert((questionText(translation).match(/[\u3400-\u9fff]/g)??[]).length>=10,'Empty translation: '+id);
  }
  const original=walk(q).find(n=>has(n,'original-question'));
  if(original){
   assert(original.tagName==='details'&&attr(original,'open')===undefined,'English original disclosure must stay collapsed: '+id);
   if(translation)assert(walk(q).indexOf(translation)<walk(q).indexOf(original),'Chinese translation must precede English original: '+id);
  }
  if(!/^q\d/.test(id))assert(walk(q).some(n=>n.tagName==='a'&&isPdf(attr(n,'href'),policy,source)),'Question PDF link missing: '+id);
  result.questions++;
 }
 for(const a of nodes.filter(n=>n.tagName==='a')){
  const href=attr(a,'href')??'';
  if(/\.pdf(?:#|$)/i.test(href)&&!/^https?:/.test(href)){
   assert(isPdf(href,policy,source),'Wrong PDF identity or page: '+href);result.pdf_links++;
  }
  const label=raw(a).trim();
  if(/^(?:原文|原书原文|查看原文|打开原书|PDF\s*(?:第\s*)?\d)/.test(label))assert(isPdf(href,policy,source),'Source label does not open PDF: '+label);
 }
 assert(result.pdf_links,'Page source PDF entry missing');
 const indexes=nodes.filter(n=>has(n,'exercise-index'));
 for(const index of indexes){
  assert(within(index,'exercise-index-panel'),'Exercise index must use the shared disclosure');
  const links=walk(index).filter(n=>n.tagName==='a');
  assert(links.length&&new Set(links.map(n=>attr(n,'href'))).size===links.length,'Duplicate or empty exercise index');
  for(const a of links)assert(questions.some(q=>'#'+attr(q,'id')===attr(a,'href')),'Exercise index target is not an exercise');
 }
 const text=raw(main);
 assert(!/已完成本地验收|已通过(?:本地)?验收|验收通过|待验收|本地验收完成|占位待补|TODO|TBD/.test(text),'Internal workflow copy in reading page');
 if(review)assert.deepEqual(reviewedQuestions(html),review,'Question or referenced input changed after source review');
 return result;
}
export function isPdf(href,policy,source){
 if(!href)return false;
 const url=new URL(href,'https://reader.invalid/'+policy.page);
 if(url.origin!=='https://reader.invalid'||decodeURI(url.pathname)!=='/'+source.route)return false;
 const match=url.hash.match(/^#page=([1-9]\d*)$/);
 return !!match&&Number(match[1])<=source.pages;
}
export function checkAll({baseline=false}={}){
 const policy=JSON.parse(fs.readFileSync('docs/reader-contract.json'));
 const sources=JSON.parse(fs.readFileSync('docs/reader-sources.json')).books;
 const review=baseline?null:JSON.parse(fs.readFileSync('docs/reader-question-review.json'));
 const pages=entries();assert.equal(pages.length,policy.pages.length,'Unregistered reader page');
 for(const item of Object.values(sources))for(const filename of new Set([item.file,'books/'+item.route]))
  assert.equal(createHash('sha256').update(fs.readFileSync(filename)).digest('hex'),item.sha256,'Source PDF bytes changed: '+filename);
 const results=[],errors=[];
 for(const page of pages){
  const item=policy.pages.find(p=>p.page===page.metadata.route);assert(item,'Reader policy missing');
  let html=page.html;if(baseline)html=fs.readFileSync('tmp/reader-audit-20261021/baseline/'+item.source,'utf8');
  try{
   if(review)assert(review.pages[item.page],'Question source review missing: '+item.page);
   results.push(checkReaderPage(html,item,sources[page.metadata.book],review?.pages[item.page]));
  }catch(e){errors.push({page:item.page,error:e.message});}
 }
 return {status:errors.length?'failed':'passed',pages:pages.length,results,errors};
}
if(process.argv[1]&&path.resolve(process.argv[1])===new URL(import.meta.url).pathname){
 const result=checkAll({baseline:process.argv.includes('--baseline')});console.log(JSON.stringify(result,null,2));if(result.errors.length)process.exitCode=1;
}
