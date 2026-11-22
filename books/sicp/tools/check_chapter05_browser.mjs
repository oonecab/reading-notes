import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';
import {sharedAsset} from '../../../src/lib/controlled-html.mjs';
const dist=process.argv.includes('--dist'),name='chapter05_register_machines.html';
let file=path.resolve('dist/sicp/notes',name);
if(!dist){
  const src='src/content/books/sicp/',formal=src+name;
  const html=fs.readFileSync(fs.existsSync(formal)?formal:src+'candidates/'+name,'utf8').replace(/^---\n[\s\S]*?\n---\n/,'');
  file=path.resolve('tmp/i089/browser',name);
  fs.mkdirSync(path.dirname(file),{recursive:true});
  fs.writeFileSync(file,html.replace(/<!-- RN:include ([\w/.-]+) -->/g,(_,a)=>sharedAsset(a)));
}
const url=pathToFileURL(file).href,browser=await chromium.launch({channel:'chrome'});
try{
  for(const [width,js] of [[1800,true],[1440,true],[1024,true],[390,true],[1440,false],[390,false]]){
    const page=await browser.newPage({viewport:{width,height:900},javaScriptEnabled:js,offline:true});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()))errors.push(r.url())});
    await page.goto(url+'#s5-2-2');
    const panel=page.locator('#toc-panel');
    if(!await panel.evaluate(n=>n.open))await panel.locator(':scope > summary').click();
    if(js)assert.equal(await panel.locator('button[aria-controls="toc-group-s5-2"]').getAttribute('aria-expanded'),'true');
    else assert.equal(await panel.locator('a:visible').count(),await panel.locator('a').count());
    if(width<1100)await panel.locator(':scope > summary').click();
    assert.equal(await page.locator('details.exercise:not([open])').count(),52);
    const index=page.locator('.exercise-index-panel');await index.locator('summary').click();
    assert.deepEqual(await index.locator('.exercise-index a').evaluateAll(as=>as.map(a=>a.hash)),Array.from({length:52},(_,i)=>'#ex-5-'+(i+1)));
    for(const n of [1,52]){
      const ex=page.locator('#ex-5-'+n);await ex.locator(':scope > summary').click();
      assert(await ex.locator('.answer').isVisible());
    }
    await page.goto(url+'#fig-5-5');
    assert(await page.locator('#fig-5-5').isVisible());
    assert(await page.locator('figure svg').evaluateAll(ns=>ns.length===9&&ns.every(n=>n.getBBox().width>0&&n.getBoundingClientRect().width>0)));
    await page.goto(url+'#ex-5-14');
    const ex=page.locator('#ex-5-14');
    if(!await ex.evaluate(e=>e.open))await ex.locator(':scope > summary').click();
    assert(await ex.locator('math').first().isVisible());
    const codeExercise=page.locator('#ex-5-4');
    if(!await codeExercise.evaluate(e=>e.open))await codeExercise.locator(':scope > summary').click();
    const fold=codeExercise.locator('details.code-details').first();
    if(!await fold.evaluate(e=>e.open))await fold.locator('summary').click();
    assert(await fold.locator('pre').isVisible());
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    assert.deepEqual(errors,[]);await page.close();console.log(width,js?'JS':'no JS','52 exercises passed');
  }
  if(dist || fs.existsSync('books/sicp/notes/'+name)){
    const mapUrl=dist ? new URL('book_overview.html',url).href : pathToFileURL(path.resolve('books/sicp/notes/book_overview.html')).href;
    const pages=JSON.parse(fs.readFileSync('docs/reader-presentation.json')).books.sicp.pages.filter(p=>p.kind==='chapter');
    assert.equal(pages.length,5);
    for(const width of [1440,390]){
      const page=await browser.newPage({viewport:{width,height:900},javaScriptEnabled:width===1440,offline:true});
      const external=[];page.on('request',r=>{if(/^https?:/.test(r.url()))external.push(r.url())});
      for(const chapter of pages){
        await page.goto(mapUrl);
        const link=page.locator('figure svg a').filter({has:page.locator('text')});
        const chapterLink=link.and(page.locator('[href="'+chapter.file+'"]'));
        assert.equal(await chapterLink.count(),1);
        await chapterLink.locator('text').first().click();
        assert.equal(new URL(page.url()).pathname.split('/').at(-1),chapter.file);
        assert.equal((await page.locator('h1').textContent()).trim(),chapter.label);
      }
      assert.deepEqual(external,[]);await page.close();
      console.log(width,'five map nodes opened their formal chapters');
    }
  }
}finally{await browser.close()}
