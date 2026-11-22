import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';
import {sharedAsset} from '../../../src/lib/controlled-html.mjs';
const dist=process.argv.includes('--dist'),name='chapter04_metalinguistic.html';
let file=path.resolve('dist/sicp/notes',name);
if(!dist){
  const src='src/content/books/sicp/',formal=src+name;
  const html=fs.readFileSync(fs.existsSync(formal)?formal:src+'candidates/'+name,'utf8').replace(/^---\n[\s\S]*?\n---\n/,'');
  file=path.resolve('tmp/i088/browser',name);
  fs.mkdirSync(path.dirname(file),{recursive:true});
  fs.writeFileSync(file,html.replace(/<!-- RN:include ([\w/.-]+) -->/g,(_,a)=>sharedAsset(a)));
}
const url=pathToFileURL(file).href,browser=await chromium.launch({channel:'chrome'});
try{
  for(const [width,js] of [[1800,true],[1440,true],[1024,true],[390,true],[1440,false],[390,false]]){
    const page=await browser.newPage({viewport:{width,height:900},javaScriptEnabled:js,offline:true});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()))errors.push(r.url())});
    await page.goto(url+'#s4-2-2');
    const panel=page.locator('#toc-panel');
    if(!await panel.evaluate(n=>n.open))await panel.locator(':scope > summary').click();
    if(js)assert.equal(await panel.locator('button[aria-controls="toc-group-s4-2"]').getAttribute('aria-expanded'),'true');
    else assert.equal(await panel.locator('a:visible').count(),await panel.locator('a').count());
    if(width<1100)await panel.locator(':scope > summary').click();
    assert.equal(await page.locator('details.exercise:not([open])').count(),79);
    const index=page.locator('.exercise-index-panel');await index.locator('summary').click();
    assert.deepEqual(await index.locator('.exercise-index a').evaluateAll(as=>as.map(a=>a.hash)),Array.from({length:79},(_,i)=>'#ex-4-'+(i+1)));
    for(const n of [1,79]){
      const ex=page.locator('#ex-4-'+n);await ex.locator(':scope > summary').click();
      assert(await ex.locator('.answer').isVisible());
    }
    await page.goto(url+'#fig-4-5');
    assert(await page.locator('#fig-4-5').isVisible());
    assert(await page.locator('figure svg').evaluateAll(ns=>ns.length===6&&ns.every(n=>n.getBBox().width>0&&n.getBoundingClientRect().width>0)));
    await page.goto(url+'#ex-4-20');
    const ex=page.locator('#ex-4-20');
    if(!await ex.evaluate(e=>e.open))await ex.locator(':scope > summary').click();
    assert(await ex.locator('math').first().isVisible());
    const fold=ex.locator('details.code-details').first();
    if(!await fold.evaluate(e=>e.open))await fold.locator('summary').click();
    assert(await fold.locator('pre').isVisible());
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    assert.deepEqual(errors,[]);await page.close();console.log(width,js?'JS':'no JS','79 exercises passed');
  }
}finally{await browser.close()}
