import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';
const dist=process.argv.includes('--dist');
const partial=process.argv.includes('--partial');
assert(!(partial && dist),'Partial evidence is limited to the candidate');
let file='dist/sicp/notes/chapter03_modularity.html';
if(!dist){
  const source=fs.readFileSync(fs.existsSync('src/content/books/sicp/chapter03_modularity.html')?'src/content/books/sicp/chapter03_modularity.html':'src/content/books/sicp/candidates/chapter03_modularity.html','utf8').replace(/^---\n[\s\S]*?\n---\n/,'');
  file='tmp/i087/browser/chapter03_modularity.html';
  fs.mkdirSync(path.dirname(file),{recursive:true});
  fs.writeFileSync(file,source.replace(/<!-- RN:include ([\w/.-]+) -->/g,(_,asset)=>fs.readFileSync('src/'+asset,'utf8')));
}
assert(fs.existsSync(file));
const url=pathToFileURL(path.resolve(file)).href;
const expected=partial?JSON.parse(fs.readFileSync('books/sicp/review/chapter03.json')).candidate_exercises.length:82;
const browser=await chromium.launch({channel:'chrome'});
try{
  for(const [width,js] of [[1800,true],[1440,true],[1024,true],[390,true],[1440,false],[390,false]]){
    const page=await browser.newPage({viewport:{width,height:900},javaScriptEnabled:js,offline:true});
    const errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    page.on('request',r=>{if(/^https?:/.test(r.url()))errors.push(r.url())});
    await page.goto(url+'#s3-2-3');
    const toc=page.locator('#toc-panel');
    if(!await toc.evaluate(el=>el.open))await toc.locator('summary').first().click();
    if(js)assert.equal(await toc.locator('[aria-controls="toc-group-s3-2"]').getAttribute('aria-expanded'),'true');
    else assert.equal(await toc.locator('a:visible').count(),await toc.locator('a').count());
    assert.equal(await page.locator('.exercise-index a').count(),expected);
    assert.equal(await page.locator('details.exercise:not([open])').count(),expected);
    for(const n of [1,expected]){
      const ex=page.locator('#ex-3-'+n);
      await ex.locator('summary').first().click();
      assert(await ex.locator('.answer').isVisible());
    }
    const diagrams=page.locator('figure svg');
    assert.equal(await diagrams.count(),38);
    assert(await diagrams.evaluateAll(ns=>ns.every(n=>n.getBoundingClientRect().width>0 && n.getBBox().width>0)));
    await page.goto(url+'#fig-3-37');
    assert(await page.locator('#fig-3-37').isVisible());
    await page.goto(url+'#ex-3-80');
    const exercise=page.locator('#ex-3-80');
    if(!await exercise.evaluate(el=>el.open)) await exercise.locator('summary').first().click();
    assert(await exercise.locator('.exercise-question math').first().isVisible());
    const fold=exercise.locator('details.code-details').first();
    await fold.locator('summary').click();
    assert(await fold.locator('pre').isVisible());
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    assert.deepEqual(errors,[]);
    await page.close();
    console.log(width,js?'JS':'no JS',expected,'exercises');
  }
}finally{await browser.close()}
