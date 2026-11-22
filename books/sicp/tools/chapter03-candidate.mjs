import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {parse} from 'parse5';
import {walk,attr,sharedAsset} from '../../../src/lib/controlled-html.mjs';
const json=file=>JSON.parse(fs.readFileSync('books/sicp/'+file,'utf8'));
const inventory=json('notes/source_inventory.json').exercises.filter(q=>q.number.startsWith('3.'));
const archive=json('notes/questions_ch03.json');
const hash=data=>createHash('sha256').update(data).digest('hex');
assert.equal(hash(fs.readFileSync(archive.pdf.file)),archive.pdf.sha256);
assert.equal(inventory.length,82);
assert.deepEqual(archive.items.map(q=>q.number),inventory.map(q=>q.number));
for(const [i,q] of archive.items.entries()){
  assert.equal(q.pdf_page,inventory[i].pdf_page);
  assert.equal(q.source_block_sha256,hash(q.original_texinfo));
  assert(q.original_texinfo.startsWith('@quotation\n@strong{@anchor{Exercise '+q.number+'}'));
  assert(q.original_texinfo.endsWith('@end quotation'));
}
const review=json('review/chapter03.json');
assert.deepEqual(archive.items.map(q=>q.published_question_sha256),
                 review.question_bindings.map(q=>q.sha256),'Archive and reviewed translations differ');
const formal=review.reader_policy.source;
const filename=fs.existsSync(formal)?formal:'src/content/books/sicp/candidates/chapter03_modularity.html';
const source=fs.readFileSync(filename,'utf8').replace(/^---\n[\s\S]*?\n---\n/,'');
assert.equal(source.split('<!-- RN:include scripts/toc-tree.js -->').length,2);
const nodes=walk(parse(source));
const exercises=nodes.filter(n=>attr(n,'data-exercise'));
const numbers=exercises.map(n=>attr(n,'data-exercise'));
const partial=process.argv.includes('--partial');
const expected=partial?json('review/chapter03.json').candidate_exercises:inventory.map(q=>q.number);
assert.deepEqual(numbers,expected,'Candidate exercise coverage');
const index=nodes.find(n=>attr(n,'class')==='exercise-index');
assert.deepEqual(walk(index).filter(n=>n.tagName==='a').map(n=>attr(n,'href')),exercises.map(n=>'#'+attr(n,'id')));
for(const [i,ex] of exercises.entries()){
  assert.equal(ex.tagName,'details');assert(!ex.attrs.some(a=>a.name==='open'));
  const question=walk(ex).find(n=>attr(n,'data-original-exercise')===numbers[i]);
  assert.equal(attr(question,'data-source-pdf-pages'),String(inventory[i].pdf_page));
  for(const [name,label] of [['exercise-question','原题（中文翻译）'],['answer','解答']]){
    const div=walk(ex).find(n=>attr(n,'class')===name);
    assert.equal(div.childNodes.find(n=>n.tagName).childNodes[0].value,label);
  }
}

import {checkExerciseContract} from '../../../tools/reading-components/exercise-contract.mjs';
import {checkReaderPage,reviewedQuestions} from '../../../tools/reader-contract/check.mjs';
import {checkVisualPage} from '../../../tools/visual-contract/check.mjs';
import {checkDepthPage} from '../../../tools/content-depth/check.mjs';
import {checkTypography} from '../../../tools/reading-typography/check.mjs';
import {checkMathNotation,checkMathUnits} from '../../../tools/reading-typography/notation-check.mjs';
import {scanProse} from '../../../tools/reading-prose/check.mjs';
import {requireCodeFolding} from '../../../tools/reading-presentation/check.mjs';
const html=source.replace(/<!-- RN:include ([\w/.-]+) -->/g,(_,name)=>sharedAsset(name));
const registry=file=>JSON.parse(fs.readFileSync('docs/'+file+'.json'));
const policy=review.reader_policy, reference=registry('reader-sources').books.sicp;
const depth=registry('content-depth-contract'),visual=registry('visual-contract');
const verifyQuestions=body=>assert.deepEqual(reviewedQuestions(body),review.question_bindings);
const verifyVisual=body=>checkVisualPage(body,policy,visual,reference);
const verifyDepth=body=>checkDepthPage(body,policy,depth,review);
const verifyProse=body=>assert.deepEqual(scanProse(body),[]);
const checks=checkReaderPage(html,policy,reference,null,{strictPages:true});
checkExerciseContract(html,policy.page);
verifyQuestions(html);verifyVisual(html);verifyDepth(html);verifyProse(html);
checkTypography(html);checkMathNotation(html,'sicp');checkMathUnits(html);requireCodeFolding(html);
assert.equal(nodes.filter(n=>n.tagName==='figure').length,38);
assert.equal(policy.sections.filter(s=>s.parent).length,19);
const text=n=>n.value??(n.childNodes??[]).map(text).join('');
const programs=fs.readFileSync('books/sicp/code/chapter03.rkt','utf8').replaceAll('\r\n','\n');
function verifyProgram(body){
 const region=walk(parse(body)).find(n=>attr(n,'id')==='programs');
 assert(walk(region).some(n=>n.tagName==='code'&&text(n)===programs),'Executable program and reading copy must match');
}
verifyProgram(html);
const inputs=json('notes/chapter03-inputs.json');
for(const input of inputs.records){
 const region=nodes.find(n=>attr(n,'id')===input.id);
 assert.equal(text(walk(region).find(n=>n.tagName==='code')),input.code);
}
for(const q of inventory){
 const binding=review.question_bindings.find(b=>b.id==='ex-'+q.number.replace('.','-'));
 assert.deepEqual(binding.dependencies.map(d=>d.anchor).filter(h=>h.startsWith('#input-')).sort(),
                  (inputs.question_dependencies[q.number]??[]).map(h=>'#'+h).sort());
}
assert.equal(hash(archive.items[79].continuation_texinfo),archive.items[79].continuation_sha256);
const negatives=[
 ['(provide make-accumulator','(provide changed-accumulator',verifyProgram],
 ['data-source-pdf-pages="331"','data-source-pdf-pages="332"',body=>checkReaderPage(body,policy,reference,null,{strictPages:true})],
 ['href="#input-make-account"','href="#input-monte-carlo"',verifyQuestions],
 ['id="fig-3-37"','id="removed-37"',verifyVisual],
 ['id="excerpt-s3-2"','id="removed-excerpt"',verifyVisual],
 ['data-worked-example="s3-3-1"','data-removed="s3-3-1"',verifyDepth],
 ['<h1>','<p>(lambda (x) x)</p><h1>',verifyProse],
 ['id="ex-3-82"','id="lost-exercise"',body=>checkReaderPage(body,policy,reference,null)],
];
for(const [before,after,check] of negatives){
 const broken=html.replace(before,after);
 assert.notEqual(broken,html);
 assert.throws(()=>check(broken),before);
}
console.log(JSON.stringify({...checks,figures:38,depth:19,sharedInputs:inputs.records.length,mutations:negatives.length}));
