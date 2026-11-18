import {checkDepthPage} from '../../../tools/content-depth/check.mjs';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {parse, parseFragment} from 'parse5';
import {attr, readSource, walk} from '../../../src/lib/controlled-html.mjs';
import {checkReaderPage, reviewedQuestions} from '../../../tools/reader-contract/check.mjs';
import {checkExerciseContract} from '../../../tools/reading-components/exercise-contract.mjs';
import {checkVisualPage} from '../../../tools/visual-contract/check.mjs';
import {checkPage as checkPresentation} from '../../../tools/check-presentation-contract.mjs';
import {checkPage as checkComponents} from '../../../tools/reading-components/check.mjs';
import {checkTypography} from '../../../tools/reading-typography/check.mjs';
import {requireCodeFolding} from '../../../tools/reading-presentation/check.mjs';
import {offlineDependencies} from '../../../scripts/parity-lib.mjs';

const book = 'books/sicp';
const json = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const sha = data => createHash('sha256').update(data).digest('hex');
const text = node => node.value ?? (node.childNodes ?? []).map(text).join('');
const normalizeQuotes = value => value.replace(/[‘’]/g,"'").replace(/[“”]/g,'"');
const review = json(book+'/review/chapter02.json');
const policy = review.reader_policy;
const source = json('docs/reader-sources.json').books.sicp;
const visuals = json('docs/visual-contract.json');
const {html, metadata} = readSource(policy.source);
const archive = json(book+'/notes/questions_ch02.json').items;
const program = fs.readFileSync(book+'/code/chapter02.rkt','utf8');
const tree = walk(parse(html));
const element = id => tree.find(node => attr(node,'id') === id);
const sourcePre = node => walk(node).filter(n=>n.tagName==='pre').map(text);
const givenCode = s => normalizeQuotes(s).replace(/\r\n/g,'\n').replace(/\n$/,'');
const mathLabels = new Map([['returns the sum','返回和'],['returns the vector','返回向量'],
  ['returns the matrix','返回矩阵'],['where','其中'],['remainder','余数']]);
const mathText = n => n.tagName === 'mtext' ? (mathLabels.get(text(n).trim()) ?? text(n))
  : n.value ?? (n.childNodes ?? []).map(mathText).join('');
const mathTokens = node => walk(node).filter(n=>n.tagName==='math').map(n=>mathText(n).replace(/\s+/g,''));
const pageFile = path.basename(policy.page);

assert.equal(sha(html),review.source_sha256[policy.page],'Reviewed chapter identity changed');
assert.equal(metadata.original_sha256,review.candidate_source_sha256,'Candidate review binding changed');
assert.deepEqual(offlineDependencies(html),[],'Chapter reading requires separate resources');
const depthContract=json('docs/content-depth-contract.json');
checkDepthPage(html,policy,depthContract,review);
const report = checkReaderPage(html,policy,source,null,{strictPages:true});
checkExerciseContract(html,policy.page);
checkVisualPage(html,policy,visuals,source);
checkTypography(html);
requireCodeFolding(html);
checkComponents(html,'sicp');
const page = {file: pageFile, kind: 'chapter', number: 2, label: '第 2 章 · 用数据构造抽象', html, metadata, exceptions: []};
const published = json('docs/reader-presentation.json').books.sicp.pages;
const pages = published.some(p=>p.file===pageFile) ? published : [...published,page];
assert.deepEqual(checkPresentation(page,pages,pages.findIndex(p=>p.file===pageFile)),[]);
assert.deepEqual(reviewedQuestions(html),review.question_bindings,'Question or referenced input changed');
const inv=json(book+'/notes/source_inventory.json');
const expected=inv.exercises.filter(q=>q.number.startsWith('2.'));
assert.equal(expected.length,97);
assert.deepEqual(archive.map(q=>[q.number,q.pdf_page]),expected.map(q=>[q.number,q.pdf_page]));
assert.deepEqual([1,2,3,4,5].map(i=>archive.filter(q=>q.section==='2.'+i).length),[16,36,20,4,21]);
assert.equal(policy.sections.filter(s=>s.parent).length,18);
const majorSections = inv.sections.filter(s=>s.number.startsWith('2.'));
const subSections = inv.toc.filter(s=>s.level===3 && s.pdf_page>=135 && s.pdf_page<=321);
function checkSectionSource(section, number) {
  const sourceLine = element(section.id).childNodes.find(n=>attr(n,'class')==='source');
  const pdfLink = walk(sourceLine).find(n=>n.tagName==='a');
  assert.equal(attr(pdfLink,'href'),'../sicp.pdf#page='+number,section.id+' source page');
}
const majorPolicy = policy.sections.filter(s=>s.role==='teaching'&&!s.parent);
assert.equal(majorPolicy.length,majorSections.length);
majorPolicy.forEach((section,i)=>{
  assert.equal(section.id,'s'+majorSections[i].number.replace('.','-'));
  checkSectionSource(section,majorSections[i].pdf_page);
});
const subPolicy = policy.sections.filter(s=>s.parent);
assert.deepEqual(review.content_depth.sections.map(row=>row.section),subPolicy.map(row=>row.id));
for(const row of review.content_depth.sections) {
  const section=element(row.section);
  const children=section.childNodes.filter(n=>n.tagName);
  const example=children.find(n=>attr(n,'data-worked-example')===row.section);
  assert(example && [row.question,row.example,row.boundary].every(s=>s && text(example).includes(s)),row.section+' worked example');
  for(const node of children.filter(n=>n.tagName==='figure'||attr(n,'id')?.startsWith('input-'))) {
    const id=attr(node,'id');
    const next=children[children.indexOf(node)+1];
    assert(next && attr(next,'data-explains')===id,id+' lacks adjacent explanation');
    assert.equal(text(next),row.figures[id]??row.textbook_code[id],id+' explanation differs from review');
  }
}
assert.equal(subPolicy.length,subSections.length);
subPolicy.forEach((section,i)=>checkSectionSource(section,subSections[i].pdf_page));
for(const pre of tree.filter(n=>n.tagName==='pre')){
  const code=pre.childNodes.find(n=>n.tagName==='code');
  assert(code && ['language-scheme','language-text'].includes(attr(code,'class')),'Code language missing');
  assert(!/[‘’“”]/u.test(text(code)),'Curly quotes in program or output');
}
for(const formula of tree.filter(n=>n.tagName==='math' && attr(n,'display')==='block'))
  assert(attr(formula,'aria-label')?.trim(),'Display formula lacks an accessible name');
for (const q of archive) {
  const id='ex-'+q.number.replace('.','-'), exercise=element(id);
  const body=walk(exercise).find(n=>attr(n,'class')==='exercise-question');
  const original=parseFragment(q.original_html);
  assert.deepEqual(sourcePre(body).map(givenCode),[...sourcePre(original), ...(q.source_footnotes ?? []).flatMap(note=>sourcePre(parseFragment(note.original_html)))].map(givenCode),q.number+' provided program');
  const originalNotes=(q.source_footnotes ?? []).map(note=>parseFragment(note.original_html));
  assert.deepEqual(mathTokens(body),[...mathTokens(original),...originalNotes.flatMap(mathTokens)],q.number+' supplied mathematics');
  assert.equal(attr(body,'data-source-pdf-pages').split(',')[0],String(q.pdf_page));
  assert(walk(exercise).find(n=>attr(n,'class')==='answer')?.childNodes.some(n=>n.tagName==='p'&&text(n).length>14),q.number+' answer');
}
const inputs = json(book+'/notes/chapter02-inputs.json');
const bindings = reviewedQuestions(html);
assert.deepEqual(bindings,json('docs/reader-question-review.json').pages[policy.page]);
function checkDependencies(manifest) {
  const declared = Object.fromEntries(bindings.map(({id,dependencies})=>[
    id, dependencies.map(d=>d.anchor).filter(h=>h.startsWith('#input-')).map(h=>h.slice(1))
  ]).filter(([,refs])=>refs.length));
  assert.deepEqual(manifest.question_dependencies,declared);
  for (const [id,refs] of Object.entries(declared)) for(const ref of refs)
    assert(manifest.records.some(record=>record.id===ref && record.exercises.includes(Number(id.split('-').at(-1)))));
  const other = bindings.filter(q=>!declared[q.id] && q.dependencies.some(d=>
    !walk(element(q.id)).includes(element(d.anchor.slice(1)))
  )).map(q=>q.id);
  assert.deepEqual(manifest.other_references_only,other);
  assert.deepEqual(manifest.inline_only,bindings.map(q=>q.id).filter(id=>!declared[id] && !other.includes(id)));
}
checkDependencies(inputs);
function checkExcerptDecisions(sections) {
  for(const section of majorPolicy) {
    const excerpts=sections[section.id]?.filter(i=>i.kind==='excerpt');
    assert.equal(excerpts?.length,1,'Missing excerpt decision for '+section.id);
    if(excerpts[0].status!=='omitted') assert.equal(attr(element(excerpts[0].target.slice(1)),'lang'),'en');
  }
}
const sections=visuals.books.sicp.pages[policy.page].sections;
checkExcerptDecisions(sections);
const inventory=Object.values(sections).flat();
assert.equal(inventory.filter(i=>i.kind==='table').length,18);
assert.equal(inventory.filter(i=>i.kind==='excerpt' && i.status==='reproduced').length,3);
assert.equal(inventory.filter(i=>i.kind==='excerpt' && i.status==='omitted').length,2);
for (const item of inputs.records) {
  assert.deepEqual(sourcePre(element(item.id)),[item.code]);
  for(const n of item.exercises) assert(walk(element('ex-2-'+n)).some(a=>attr(a,'href')==='#'+item.id));
}
for (const [_,name,block] of program.matchAll(/^;; BEGIN ([\w-]+)\n([\s\S]*?)^;; END \1$/gm)) {
  assert.deepEqual(sourcePre(element('code-'+name)),[block.replace(/\n$/,'')],name+' source mirror');
}
const full=html.match(/<!-- SICP:full-source -->([\s\S]*?)<!-- \/SICP:full-source -->/);
assert(full);assert.deepEqual(sourcePre(parseFragment(full[1])),[program]);
for (const item of review.source.numbered_figure_inventory) {
  const number=item.figure.split('.')[1], node=element('fig-2-'+number);
  assert.equal(attr(node,'data-source-pdf-page'),String(item.pdf_page));
  const filename='figure-2-'+number+'.webp';
  assert(walk(node).some(n=>n.tagName==='svg'||n.tagName==='img'),'Missing figure content');
  assert.equal(sha(fs.readFileSync(book+'/assets/chapter02/'+filename)),review.source.figure_assets[filename].image_sha256);
}

const mutations=[
  ['external image',html.replace(/src="data:image\/webp;base64,[^"]+"/,'src="../assets/chapter02/figure-2-9.webp"'),s=>checkVisualPage(s,policy,visuals,source)],
  ['missing caption',html.replace(/<figcaption\b[^>]*>[\s\S]*?<\/figcaption>/,''),s=>checkVisualPage(s,policy,visuals,source)],
  ['missing source page',html.replace(/(<figure\b[^>]*?) data-source-pdf-page="\d+"/,'$1'),s=>checkVisualPage(s,policy,visuals,source)],
  ['wrong source page',html.replace(/(<figure\b[^>]*?) data-source-pdf-page="\d+"/,'$1 data-source-pdf-page="1"'),s=>checkVisualPage(s,policy,visuals,source)],
  ['missing excerpt',html.replace('id="excerpt-s2-1"','id="missing-excerpt"'),s=>checkVisualPage(s,policy,visuals,source)],
  ['missing omission decision',sections,s=>checkExcerptDecisions({...s,'s2-3':s['s2-3'].filter(i=>i.kind!=='excerpt')} )],
  ['image alt',html.replace(/(src="data:image\/webp;base64,[^"]+" alt=")[^"]+/, '$1'),s=>checkVisualPage(s,policy,visuals,source)],
  ['unregistered image',html,s=>{
    const changed=structuredClone(visuals);
    Object.values(changed.books.sicp.pages[policy.page].sections).flat().find(i=>i.representation==='source-image').representation='figure';
    checkVisualPage(s,policy,changed,source);
  }],
  ['missing image asset',html,s=>{
    const changed=structuredClone(visuals);
    Object.values(changed.books.sicp.pages[policy.page].sections).flat().find(i=>i.representation==='source-image').asset='sicp/assets/missing.webp';
    checkVisualPage(s,policy,changed,source);
  }],
  ['wrong shared input',inputs,m=>checkDependencies({...m,question_dependencies:{}})],
  ['question',html.replace('data-original-exercise="2.97"','data-original-exercise="2.96"'),s=>checkExerciseContract(s,policy.page)],
  ['given input',html.replace('(define (print-point p)','(define (changed-point p)'),s=>assert.deepEqual(reviewedQuestions(s),review.question_bindings)],
  ['code mirror',program.replace('(define (make-rat n d)','(define (unexpected n d)'),s=>assert.deepEqual(sourcePre(parseFragment(full[1])),[s])],
  ['figure',html.replace('id="fig-2-18"','id="removed-figure"'),s=>checkVisualPage(s,policy,visuals,source)],
];
for (const [name,changed,test] of mutations) assert.throws(()=>test(changed),undefined,'Mutation survived: '+name);

if(process.argv.includes('--preview')){
  const base='tmp/i077/preview/sicp', notes=base+'/notes';
  fs.mkdirSync(notes,{recursive:true});
  fs.writeFileSync(notes+'/'+pageFile,html);
  fs.cpSync(book+'/code',base+'/code',{recursive:true});
  fs.copyFileSync(book+'/sicp.pdf',base+'/sicp.pdf');
  const bundle='tmp/i077/chapter02-inline-package';
  const copies=[policy.page,...['chapter02.rkt','test-chapter02.rkt','chapter02-results.json'].map(f=>'sicp/code/'+f)];
  for(const name of copies){
    const dest=path.join(bundle,'site',name);
    fs.mkdirSync(path.dirname(dest),{recursive:true});
    fs.copyFileSync(path.join('tmp/i077/preview',name),dest);
  }
  const packagePolicy={authorized_pdfs:{},files:copies.map(name=>({path:name,mode:'copy'}))};
  fs.writeFileSync(bundle+'/allowlist.json',JSON.stringify(packagePolicy,null,2)+'\n');
  execFileSync('python',['-c',"import sys; sys.path.insert(0, 'deploy'); from public_policy import inspect; inspect(sys.argv[1], policy_path=sys.argv[2])",bundle+'/site',bundle+'/allowlist.json']);
  for(const f of ['preface.html','chapter01_procedures.html','book_overview.html']){
    let body=fs.readFileSync(book+'/notes/'+f,'utf8');
    if(f==='book_overview.html' && !published.some(p=>p.file===pageFile)){
      const start='href="#chapter-2" aria-label="第 2 章章意：用数据构造抽象"';
      assert(body.includes(start),'Candidate map node changed');
      body=body.replace(start,'href="'+pageFile+'" aria-label="第 2 章候选页：用数据构造抽象"');
      body=body.replace(/(aria-label="第 2 章候选页：[\s\S]*?<text class="hint"[^>]*>)[^<]+/, '$1候选正文与 97 题');
      body=body.replace('<h2>第 2 章章意 · 用数据构造抽象</h2>','<h2>第 2 章章意 · 用数据构造抽象</h2><p><a href="'+pageFile+'">阅读第 2 章候选页</a></p>');
    }
    fs.writeFileSync(notes+'/'+f,body);
  }
}
const figures=tree.filter(n=>n.tagName==='figure');
const figureContents=figures.flatMap(walk);
const index=tree.find(n=>attr(n,'class')?.split(/\s+/).includes('exercise-index'));
console.log(JSON.stringify({
  status:'passed',scope:review.status,...report,figures:figures.length,
  svg_figures:figureContents.filter(n=>n.tagName==='svg').length,
  embedded_webp:figureContents.filter(n=>n.tagName==='img' && attr(n,'src')?.startsWith('data:image/webp;base64,')).length,
  index_links:walk(index).filter(n=>n.tagName==='a').length,
  depth_sections:subPolicy.length,
  given_code_blocks:archive.reduce((count,q)=>count+sourcePre(parseFragment(q.original_html)).length,0),
  rejected_mutations:mutations.map(m=>m[0])
}));
