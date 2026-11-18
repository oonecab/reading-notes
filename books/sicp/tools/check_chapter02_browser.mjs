import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';

const formal = process.argv.includes('--dist') || JSON.parse(fs.readFileSync('books/catalog.json','utf8')).books
  .find(book=>book.id==='sicp').expected_pages===4;
const folder = formal ? 'tmp/i077/formal-browser' : 'tmp/i077/preview';
const notes = path.resolve(formal ? 'dist' : folder,'sicp/notes');
const chapter = 'chapter02_data_abstraction.html';
const title = '第 2 章 · 用数据构造抽象';
const rows = [];
assert(fs.existsSync(path.join(notes,chapter)), 'Missing requested chapter output in '+notes);
fs.mkdirSync(folder,{recursive:true});
const browser = await chromium.launch({channel:'chrome'});
try {
  const assets=path.resolve('books/sicp/assets/chapter02');
  const assetContext=await browser.newContext({offline:true,javaScriptEnabled:false});
  const assetPage=await assetContext.newPage();
  for(let number=1; number<=26; number++){
    await assetPage.goto(pathToFileURL(path.join(assets,'figure-2-'+number+'.webp')).href);
    assert(await assetPage.locator('img').evaluate(i=>i.complete && i.naturalWidth>0 && i.naturalHeight>0),
      'Undecodable source figure 2.'+number);
  }
  await assetContext.close();
  for (const [width,js] of [[1800,true],[1440,true],[1024,true],[390,true],[1440,false],[390,false]]) {
    const ctx = await browser.newContext({viewport:{width,height:900},javaScriptEnabled:js});
    await ctx.setOffline(true);
    const page = await ctx.newPage();
    const external = [];
    page.on('request',request=>{
      if (/^https?:/.test(request.url()) || /^file:.*\.webp(?:[?#]|$)/i.test(request.url())) external.push(request.url());
    });
    await page.goto(pathToFileURL(path.join(notes,'book_overview.html')).href);
    await page.locator('svg a[href="'+chapter+'"]').click();
    assert.equal(await page.locator('h1').innerText(),title);
    assert.equal(new URL(page.url()).pathname.split('/').at(-1),chapter);
    assert.equal(await page.locator('details.exercise').count(),97);
    assert.equal(await page.locator('details.exercise[open]').count(),0);
    if(width===1440 && js){
      const depth=await page.locator('[data-worked-example]').evaluateAll(paragraphs=>paragraphs.map(p=>{
        const section=p.closest('section');
        const guides=[...section.querySelectorAll('p[data-explains]')];
        return {section:section.id,example:p.innerText,explanations:guides.map(g=>({
          target:g.dataset.explains,adjacent:g.previousElementSibling?.id===g.dataset.explains,text:g.innerText
        }))};
      }));
      assert.equal(depth.length,18);
      assert.equal(depth.flatMap(s=>s.explanations).length,42);
      assert(depth.every(s=>s.example && s.explanations.every(g=>g.text && g.adjacent)));
      fs.writeFileSync(path.join(folder,'depth-readback.json'),JSON.stringify(depth,null,2)+'\n');
    }
    const images=page.locator('.rn-figure img');
    assert.equal(await images.count(),3);
    assert(await images.evaluateAll(list=>list.every(i=>i.currentSrc.startsWith('data:image/webp;base64,')&&i.complete&&i.naturalWidth>0)));
    const vectors=page.locator('.rn-figure svg[role="img"]');
    assert.equal(await vectors.count(),23);
    assert(await vectors.evaluateAll(list=>list.every(svg=>svg.getBBox().width>0 && svg.getBBox().height>0)));
    const chapterUrl=pathToFileURL(path.join(notes,chapter)).href;
    const formula=page.locator('math[display="block"]').first();
    const formulaAnchor=await formula.evaluate(m=>m.closest('[id]').id);
    await page.goto(chapterUrl+'#'+formulaAnchor);
    const folded=page.locator('details:not([open])').filter({has:formula});
    while(await folded.count()) await folded.first().locator(':scope > summary').click();
    await formula.scrollIntoViewIfNeeded();
    assert(await formula.isVisible());
    await page.goto(chapterUrl);
    await page.reload();
    assert.equal(await page.locator('blockquote.original-excerpt[lang="en"]').count(),3);
    const decision=JSON.parse(fs.readFileSync('docs/visual-contract.json','utf8')).books.sicp.pages['sicp/notes/'+chapter];
    assert.equal(Object.values(decision.sections).flat().filter(i=>i.kind==='excerpt' && i.status==='omitted').length,2);
    const index=page.locator('.exercise-index-panel');
    await index.locator('summary').click();
    assert.equal(await index.locator('a').count(),97);
    for (const n of [1,97]) {
      await index.locator('a').nth(n-1).click();
      const q=page.locator('#ex-2-'+n);
      assert.equal(new URL(page.url()).hash,'#ex-2-'+n);
      if (!await q.evaluate(e=>e.open)) await q.locator(':scope > summary').click();
      assert(await q.locator('.answer').isVisible());
      await q.locator(':scope > summary').click();
    }
    const url=pathToFileURL(path.join(notes,chapter)).href;
    await page.goto(url+'#code-polynomials');
    const code=page.locator('#code-polynomials details');
    const original=await code.evaluate(e=>e.open);
    await code.locator('summary').click();
    assert.equal(await code.evaluate(e=>e.open),!original);
    await page.goto(url+'#fig-2-18');
    const figure=page.locator('#fig-2-18');
    await figure.scrollIntoViewIfNeeded();
    await page.screenshot({path:path.join(folder,'figure-'+width+'-'+js+'.png')});
    const scroll=await figure.locator('.figure-scroll').evaluate(e=>{
      e.scrollLeft=e.scrollWidth;
      return {width:e.clientWidth,content:e.scrollWidth,offset:e.scrollLeft};
    });
    if (width===390) assert(scroll.offset>0,'Figure detail cannot be reached');
    await page.locator('details.exercise').evaluateAll(list=>list.forEach(el=>el.open=true));
    const formulas=await page.locator('math[display="block"]').evaluateAll(list=>list.map(m=>{
      const r=m.getBoundingClientRect();
      return {visible:r.width>0&&r.height>0, name:m.getAttribute('aria-label'),overflow:m.scrollWidth-m.clientWidth};
    }));
    assert(formulas.length>0&&formulas.every(f=>f.visible&&f.name));
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Page overflows when exercises expand');
    assert.deepEqual(external,[]);
    rows.push({width,js,map_scope:formal?'dist':'candidate',index_links:97,initially_collapsed:97,first_and_last:true,
      formula_anchor:formulaAnchor,inline_svgs:23,embedded_webps:3,decodable_maintenance_assets:26,
      code_toggle:true,direct_figure_link:true,loaded_figures:26,figure_scroll:scroll,block_formulas:formulas.length,
      max_formula_overflow:Math.max(...formulas.map(f=>f.overflow)),page_overflow:false,external_requests:external});
    await ctx.close();
  }
} finally { await browser.close(); }
fs.writeFileSync(path.join(folder,'browser.json'),JSON.stringify(rows,null,2)+'\n');
console.log(JSON.stringify({status:'passed',views:rows.length,report:path.join(folder,'browser.json')}));
