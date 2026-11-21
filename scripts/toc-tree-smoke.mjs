import assert from 'node:assert/strict';
import {verifyTocState,verifyGroupLayout,expectedTocGroups} from './toc-tree-contract.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chromium} from 'playwright';
import {parse} from 'parse5';
import {walk,attr} from '../src/lib/controlled-html.mjs';

import {parseArgs} from 'node:util';

const {values} = parseArgs({options:{dist:{type:'boolean'},book:{type:'string'},page:{type:'string'},width:{type:'string'}}});
const widths = values.width === undefined ? [1440,390] : [Number(values.width)];
assert(widths.every(w=>Number.isSafeInteger(w) && w>0),'Invalid viewport width');
const report = {mode:values.dist?'dist':'source',pages:0,groupedPages:0,groups:0,preflightFailures:[],views:[],sample:'scripts/toc-tree-browser.mjs'};
const registry = JSON.parse(fs.readFileSync('docs/reader-presentation.json','utf8')).books;
const pages = [];
for (const [book,registration] of Object.entries(registry)) {
  for (const {file} of registration.pages) {
    if ((values.book && values.book!==book) || (values.page && values.page!==file)) continue;
    const route = [book,'notes',file].join('/');
    report.pages++;
    try {
      const html=fs.readFileSync(path.join('src/content/books',book,file),'utf8');
      assert.equal(html.split('<!-- RN:include scripts/toc-tree.js -->').length-1,1,'Expected one shared script');
      const nodes=walk(parse(html));
      const ids=new Map(nodes.filter(n=>attr(n,'id')).map(n=>[attr(n,'id'),n]));
      const rows=walk(ids.get('chapter-toc')).filter(n=>n.tagName==='a').map(a=>{
        const href=attr(a,'href'), target=ids.get(href.slice(1));
        const heading=target && (/^h[1-6]$/.test(target.tagName)?target:target.childNodes.find(n=>/^h[1-6]$/.test(n.tagName)));
        return {href,heading:heading?.tagName};
      });
      const artifact=fs.readFileSync(path.join(values.dist?'dist':'books',route),'utf8');
      const nav=walk(parse(artifact)).find(n=>attr(n,'id')==='chapter-toc');
      assert(nav,'Missing static directory');
      const hrefs=walk(nav).filter(n=>n.tagName==='a').map(n=>attr(n,'href'));
      assert.deepEqual(hrefs,rows.map(row=>row.href),'Static directory differs from source');
      const groups=expectedTocGroups(rows);
      report.groups+=groups.length;
      if(groups.length) report.groupedPages++;
      pages.push({route,rows,groups});
    } catch(error) {report.preflightFailures.push({route,error:error.message})}
  }
}
assert(report.pages,'No matching registered pages');
async function checkPage(page,{route,rows,groups},js) {
  const file=path.resolve(values.dist?'dist':'books',route);
  const target=groups.at(-1)?.children[0] ?? '';
  await page.goto(pathToFileURL(file).href+target);
  const result=await page.evaluate(js=>{
    const panel=document.querySelector('#toc-panel'), nav=document.querySelector('#chapter-toc');
    panel.open=true;
    const initializations=window.tocInitCalls;
    const before=[...nav.querySelectorAll('a,button,ul')];

    const originalMarkup=nav.innerHTML;
    if(js) window.TocTree.init({nav,panel});
    const after=[...nav.querySelectorAll('a,button,ul')];
    const links=[...nav.querySelectorAll('a')];
    return {
      initializations,stable:originalMarkup===nav.innerHTML && before.length===after.length && before.every((n,i)=>n===after[i]),
      links:links.map(a=>a.getAttribute('href')),visible:links.filter(a=>a.checkVisibility()).length,
      groups:[...nav.querySelectorAll('button')].map(button=>{
        const list=document.getElementById(button.getAttribute('aria-controls'));
        const controls=button.getAttribute('aria-controls');
        const matches=controls ? document.querySelectorAll('#'+CSS.escape(controls)).length : 0;
        return {controls,matches,expanded:button.getAttribute('aria-expanded'),visible:!!list?.checkVisibility(),href:button.parentElement.querySelector('a').getAttribute('href'),children:[...(list?.querySelectorAll('a') ?? [])].map(a=>a.getAttribute('href'))};
      }),
      summaryLinks:panel.querySelectorAll("summary a").length,overflow:document.documentElement.scrollWidth-innerWidth,
    };
  },js);
  if(js) assert.equal(result.initializations,1,'Expected exactly one controller initialization');
  const located=result.groups.find(group=>group.children.includes(target));
  verifyTocState(result,rows.map(row=>row.href),js,js && located?.controls);
  verifyGroupLayout({...result,groups:result.groups.map(({href,children})=>({href,children}))},rows,js);
  assert.equal(new Set(result.groups.map(g=>g.controls)).size,result.groups.length,'Repeated controls');
  assert(result.overflow<=1,'Page overflows horizontally');
  if(js && groups.length) {
    await page.locator('main h1').first().dblclick({position:{x:12,y:12}});
    assert(await page.evaluate(()=>getSelection().toString().trim().length>0),'Body selection failed');
  }
}
if(!report.preflightFailures.length){
  const browser=await chromium.launch({channel:'chrome'});
  try {
    for(const width of widths) for(const js of [true,false]){
      const view={width,js,passed:0,failures:[]};
      report.views.push(view);
      const page=await browser.newPage({viewport:{width,height:900},javaScriptEnabled:js,offline:true});
      if(js) await page.addInitScript(()=>{
        let api;
        window.tocInitCalls=0;
        Object.defineProperty(window,'TocTree',{
          get:()=>api,
          set(value){
            api={...value,init(options){window.tocInitCalls++;return value.init(options)}};
          },
        });
      });
      const errors=[];
      page.on('pageerror',error=>errors.push(error.message));
      page.on('request',request=>{if(/^https?:/.test(request.url()))errors.push(request.url())});
      for(const entry of pages){
        if(!values.width && width===390 && !entry.groups.length) continue;
        errors.length=0;
        try {
          await checkPage(page,entry,js);
          assert.deepEqual(errors,[]);
          view.passed++;
        } catch(error){view.failures.push({route:entry.route,error:error.message})}
      }
      await page.close();
    }
  } finally {await browser.close()}
}
fs.mkdirSync('tmp/toc-tree-smoke',{recursive:true});
const output=JSON.stringify(report,null,2);
fs.writeFileSync('tmp/toc-tree-smoke/report.json',output);
console.log(output);
if(report.preflightFailures.length || report.views.some(view=>view.failures.length)) process.exitCode=1;
