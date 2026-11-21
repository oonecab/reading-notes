import assert from 'node:assert/strict';
import {verifyTocState,verifyPrintState} from './toc-tree-contract.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';
import {parse} from 'parse5';
import {walk,attr} from '../src/lib/controlled-html.mjs';

const filename = process.argv.includes('--dist') ? 'dist/sicp/notes/chapter02_data_abstraction.html' :
  process.argv[2] || 'books/sicp/notes/chapter02_data_abstraction.html';
const url = pathToFileURL(path.resolve(filename)).href;
const nav = walk(parse(fs.readFileSync(filename,'utf8'))).find(n => attr(n,'id')==='chapter-toc');
const expected = walk(nav).filter(n=>n.tagName==='a').map(n=>attr(n,'href'));
const browser = await chromium.launch({channel:'chrome'});
try {
  for (const [width,js] of [[1800,true],[1440,true],[1024,true],[390,true],[1440,false],[390,false]]) {
    const page = await browser.newPage({viewport:{width,height:900},javaScriptEnabled:js,offline:true});
    const external = [];
    page.on('request',r=>{if(/^https?:/.test(r.url()))external.push(r.url())});
    await page.goto(url+'#s2-4-3');
    if (js) await page.waitForFunction(() => {
      const top=document.getElementById('s2-4-3').getBoundingClientRect().top;
      return top >= 0 && top < innerHeight / 2;
    });
    const panel=page.locator('#toc-panel'), links=page.locator('#chapter-toc a');
    assert.deepEqual(await links.evaluateAll(a=>a.map(n=>n.getAttribute('href'))),expected);
    assert.equal(await panel.locator('summary a').count(),0);
    if (!await panel.evaluate(n=>n.open)) await panel.locator('summary').click();
    const state=await panel.evaluate(panel=>({
      links:[...panel.querySelectorAll('a')].map(a=>a.getAttribute('href')),
      visible:[...panel.querySelectorAll('a')].filter(a=>a.getClientRects().length).length,
      summaryLinks:panel.querySelectorAll('summary a').length,
      groups:[...panel.querySelectorAll('button')].map(button=>{
        const controls=button.getAttribute('aria-controls');
        const targets=document.querySelectorAll('#'+CSS.escape(controls));
        return {controls,matches:targets.length,expanded:button.getAttribute('aria-expanded'),visible:!!targets[0]?.getClientRects().length};
      }),
    }));
    verifyTocState(state,expected,js,js && 'toc-group-s2-4');
    if(js){
      const button=panel.locator('[aria-controls="toc-group-s2-4"]');
      const children=panel.locator('#toc-group-s2-4');
      assert.equal(await button.getAttribute('aria-expanded'),'true');
      assert(await children.isVisible());
      assert.equal(await panel.locator('button[aria-expanded="false"]').count(),width>=1100?0:4);
      assert.equal(await panel.locator('a[aria-current="location"]').getAttribute('href'),'#s2-4-3');
      await button.click();
      assert.equal(await button.getAttribute('aria-expanded'),'false');
      assert(!await children.isVisible());assert(await panel.evaluate(n=>n.open));assert(page.url().endsWith('#s2-4-3'));
      await page.evaluate(()=>window.dispatchEvent(new Event('scroll')));
      await page.evaluate(()=>new Promise(requestAnimationFrame));
      assert(!await children.isVisible());
      const states=()=>panel.locator('button').evaluateAll(bs=>bs.map(b=>b.getAttribute('aria-expanded')));
      const beforePrint=await states();
      await page.emulateMedia({media:'print'});
      await page.evaluate(()=>window.dispatchEvent(new Event('beforeprint')));
      assert(await children.isVisible());
      assert.equal(await panel.locator('button[aria-expanded="false"]').count(),0);
      const printing=await states();
      await page.evaluate(()=>window.dispatchEvent(new Event('afterprint')));
      verifyPrintState(beforePrint,printing,await states());
      await page.emulateMedia({media:'screen'});
      assert(!await children.isVisible());
      for(const key of ['Enter','Space','Enter']) await button.press(key);
      assert(await children.isVisible());
      await children.locator('a').first().click();
      assert(page.url().endsWith('#s2-4-1'));assert.equal(await panel.evaluate(n=>n.open),width>=1100);
      await page.evaluate(()=>{location.hash='s2-5-1'});
      await panel.locator('[aria-controls="toc-group-s2-5"][aria-expanded="true"]').waitFor({state:'attached'});
    }else{
      assert.equal(await panel.locator('button').count(),0);
      assert.equal(await panel.locator('a:visible').count(),expected.length);
      await panel.locator('a[href="#s2-4-1"]').click();assert(page.url().endsWith('#s2-4-1'));
    }
    const summary = panel.locator(':scope > summary');
    await summary.click({clickCount:3});
    assert.equal(await page.evaluate(()=>getSelection().toString()), '', 'Repeated TOC clicks selected text');
    await page.locator('main h1').dblclick({position:{x:12,y:12}});
    assert(await page.evaluate(()=>getSelection().toString().trim().length > 0), 'Body text should remain selectable');
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    assert.deepEqual(external,[]);await page.close();console.log(width,js?'JS':'no JS','passed');
  }
  await checkStandaloneApi(browser);

}finally{await browser.close()}


async function checkStandaloneApi(browser) {
  const page=await browser.newPage({viewport:{width:700,height:900},offline:true});
  try {
    await page.setContent('<details id="panel" open><summary>目录</summary><nav><ul></ul></nav></details><main></main>');
    await page.addScriptTag({path:path.resolve('src/scripts/toc-tree.js')});
    const result=await page.evaluate(()=>{
      const nav=document.querySelector('nav'),panel=document.querySelector('#panel');
      const options={nav,panel,breakpoint:650,groupHeading:'h3',childHeading:'h4'};
      window.TocTree.init();window.TocTree.init({nav});window.TocTree.init({panel});
      window.TocTree.init(options);
      const headings=['h3','h4','h4','h5','h4','h3',null,'h4','h3'];
      for(const [i,tag] of headings.entries()){
        if(tag) document.querySelector('main').insertAdjacentHTML('beforeend','<'+tag+' id="t'+i+'">T'+i+'</'+tag+'>');
        nav.firstElementChild.insertAdjacentHTML('beforeend','<li><a href="#t'+i+'">T'+i+'</a></li>');
      }
      document.querySelector('main').insertAdjacentHTML('beforeend','<span id="toc-group-t0"></span>');
      window.TocTree.init(options);
      const first=nav.innerHTML;
      window.TocTree.init(options);
      const buttons=[...nav.querySelectorAll('button')];
      return {stable:first===nav.innerHTML,groups:buttons.map(b=>b.getAttribute('aria-controls')),
        expanded:buttons.map(b=>b.getAttribute('aria-expanded')),
        children:[...nav.querySelectorAll('li ul a')].map(a=>a.hash),links:[...nav.querySelectorAll('a')].map(a=>a.hash)};
    });
    assert.deepEqual(result,{stable:true,groups:['toc-group-t0-sub'],expanded:['true'],
      children:['#t1','#t2'],links:Array.from({length:9},(_,i)=>'#t'+i)});
  } finally {await page.close()}
}
