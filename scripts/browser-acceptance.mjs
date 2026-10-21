// Executed by ego-browser nodejs; config is injected by check-offline.mjs.
const fs = await import('node:fs/promises');
const path = await import('node:path');
const crypto = await import('node:crypto');
const { pathToFileURL } = await import('node:url');
const {atomicJson,openSpace,waitDocument,waitTarget,readTarget,exerciseTargets}=await import(config.runtime);
const {checkCodeFold}=await import(new URL('./browser-code-folding.mjs',config.runtime));
const {checkAnnotations,positionReadingSection}=await import(new URL('./browser-reader-contract.mjs',config.runtime));
const {checkReaderFonts}=await import(new URL('./browser-fonts.mjs',config.runtime));
const {inspectReviewedDiagram,restoreDiagramDisclosures}=await import(new URL('./browser-diagrams.mjs',config.runtime));
const task=await openSpace(taskSpace,config.selection);
atomicJson(config.sessionFile,{spaceId:task.spaceId,page:config.page});
const page=task.page(config.page);
const report={status:'running',tool:'ego-browser',space:task.spaceId,pages:config.pages,views:config.resumed?.views??[],no_js:config.resumed?.no_js??[],external_requests:[],screenshots:config.resumed?.screenshots??[],reused_views:config.resumed?.origins??[],previous_attempt:config.previous_attempt??null,errors:[]};
const save=()=>atomicJson(path.join(config.output,'report.json'),report);
const requireTrue=(condition,message)=>{if(!condition)throw new Error(message);};
async function screenshot(name) {
  const filename=path.join(config.output,name+'.png');
  await page.screenshot({path:filename});
  report.screenshots.push({file:path.relative(config.root,filename),sha256:crypto.createHash('sha256').update(await fs.readFile(filename)).digest('hex')});
}
async function expandedLayout() {
  const result=await page.evaluate(()=>{
    const disclosures=[...document.querySelectorAll('main details')],states=disclosures.map(e=>e.open),position={x:scrollX,y:scrollY};
    try {
      disclosures.forEach(e=>{e.open=true;});
      // Geometry reads flush layout synchronously, including with page scripts
      // disabled. Animation-frame callbacks cannot be awaited in that mode.
      return {disclosures:disclosures.length,exercises:document.querySelectorAll('main details.exercise').length,
        viewport:innerWidth,width:document.documentElement.scrollWidth,all_open:disclosures.every(e=>e.open)};
    } finally {
      disclosures.forEach((e,i)=>{e.open=states[i];});
      scrollTo({left:position.x,top:position.y,behavior:'instant'});
    }
  });
  requireTrue(result.all_open&&result.width<=result.viewport+1,'Expanded reading content overflows: '+JSON.stringify(result));
  return result;
}
async function navigate(item) {
  await page.events();
  const url=pathToFileURL(item.file).href;
  // A zero-delay refresh can replace its entry document before that document's
  // load event is delivered. Commit the entry, then require the final URL and
  // a complete destination document below; inspect both network records.
  await page.goto(url,{timeout:30000,waitUntil:'commit'});
  const destination=item.redirect_file?pathToFileURL(item.redirect_file).href:url;
  if(item.redirect_file)await page.waitForURL(destination);
  await waitDocument(page,destination);
  if(!report.user_agent)report.user_agent=await page.evaluate(()=>navigator.userAgent);
  const events=await page.events();
  const requests=events.filter(e=>e.method==='Network.requestWillBeSent').map(e=>({url:e.params.request.url,type:e.params.type}));
  const external=requests.filter(r=>!([url,destination].includes(r.url.split('#')[0])&&r.type==='Document')&&!r.url.startsWith('data:'));
  report.external_requests.push(...external.map(r=>({page:item.route,...r})));
  requireTrue(requests.some(r=>r.type==='Document'&&r.url.split('#')[0]===url),'Network observer did not record the document');
  requireTrue(external.length===0,'Subresource request: '+JSON.stringify(external));
  return {requests,url:destination};
}
try {
  await page.cdp('Network.enable');
  await page.cdp('Network.emulateNetworkConditions',{offline:true,latency:0,downloadThroughput:0,uploadThroughput:0});
  await page.cdp('Emulation.setScriptExecutionDisabled',{value:false});
  for(const item of config.pages)for(const width of config.widths) {
    if(report.views.some(v=>v.page===item.route&&v.width===width))continue;
    await page.cdp('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:false});
    const {requests,url}=await navigate(item);
    const state=await page.evaluate(()=>({title:document.querySelector('h1')?.textContent,
      viewport:innerWidth,document_width:document.documentElement.scrollWidth,main:document.querySelector('main')?.innerText.length,
      maths:[...document.querySelectorAll('math')].filter(n=>!n.closest('#annotation-content')).length,
      svgs:[...document.querySelectorAll('svg')].filter(n=>!n.closest('#annotation-content')).length,merrors:document.querySelectorAll('merror').length,
      mirror_math:document.querySelectorAll('#annotation-content math').length,
      mirrors_match_source:[...document.querySelectorAll('#annotation-content math,#annotation-content svg')].every(n=>[...document.querySelectorAll('main .reading-notes '+n.tagName)].some(m=>m.outerHTML===n.outerHTML)),
      exercises:[...document.querySelectorAll('details.exercise[id]')].map(e=>e.id),toc:[...document.querySelectorAll('#chapter-toc a[href^="#"]')].map(e=>e.getAttribute('href')),
      annotations:document.querySelectorAll('details.reading-notes').length}));
    requireTrue(state.title&&state.main>100,'Missing readable content');
    requireTrue(state.document_width<=state.viewport+1,`Page overflow: ${item.route} @ ${width}`);
    requireTrue(state.maths===item.counts.mathml&&state.svgs===item.counts.svg&&state.merrors===0&&state.mirrors_match_source,'Math/SVG rendering inventory or annotation mirror differs');
    const view={page:item.route,width,state,requests,deep_links:[]};report.views.push(view);
    if(width===1800&&item.reader_policy)view.fonts=await checkReaderFonts(page);
    await page.evaluate(()=>window.scrollTo({top:0,behavior:'instant'}));
    const stem=item.route.replaceAll('/','_').replace('.html','')+'-'+width;
    await screenshot(stem+'-top');
    const targets=exerciseTargets(item,state.exercises);
    view.deep_link_scope=targets.length?'first and last exercises':item.redirect_file?'redirect destination verified; no duplicate exercise deep links':'no exercises';
    for(const id of targets) {
      const target={id,url};
      await readTarget(page,target,e=>{location.hash=e.id;window.__rnMotion=null;return true;});
      await page.waitForFunction(id=>{
        const e=document.getElementById(id);if(!e)return false;
        for(let n=e;n;n=n.parentElement)if(n.tagName==='DETAILS'&&!n.open)return false;
        const blockers=[document.querySelector('.reader-bar'),
          ...(innerWidth<1100?[document.querySelector('#toc-panel > summary')]:[])].filter(Boolean);
        const visibleTop=Math.max(0,...blockers.map(n=>n.getBoundingClientRect()).filter(r=>r.top<150&&r.bottom>0).map(r=>r.bottom));
        const r=(e.tagName==='DETAILS'?e.querySelector(':scope > summary'):e).getBoundingClientRect();
        return r.top>=visibleTop-1&&r.top<innerHeight&&r.bottom>visibleTop;
      },id,{timeout:10000});
      // A revealed details changes the document height. Wait for native anchor
      // scrolling and layout to settle before evaluating the next interaction.
      await page.waitForFunction(()=>{
        const key=scrollY+':'+document.documentElement.scrollHeight,previous=window.__rnMotion;
        window.__rnMotion={key,count:previous?.key===key?previous.count+1:0};
        return window.__rnMotion.count>=5;
      },undefined,{timeout:10000});
      await page.waitForFunction(id=>{
        const links=[...document.querySelectorAll('#chapter-toc a[href^="#"]')];
        let e=document.getElementById(id),expected;if(!e)return false;
        for(;e&&!expected;e=e.parentElement)expected=links.find(a=>a.getAttribute('href')==='#'+e.id);
        return !expected||expected.getAttribute('aria-current')==='location';
      },id,{timeout:10000});
      view.deep_links.push(await readTarget(page,target,e=>{const r=(e.tagName==='DETAILS'?e.querySelector(':scope > summary'):e).getBoundingClientRect();return {id:e.id,hash:location.hash,open:e.open??null,top:r.top,active:document.querySelector('#chapter-toc [aria-current="location"]')?.getAttribute('href'),answer:e.querySelector('.answer')?.textContent.length??null};}));
    }
    if((width===1800||width===390)&&state.exercises.length){
      await screenshot(stem+'-answer');
      // A long original question can fill the anchor viewport. Capture the
      // solution itself as a separate reading surface rather than naming a
      // question-only image an inspected solution.
      view.solution_view=await page.evaluate(id=>{
        const answer=document.getElementById(id).querySelector('.answer');
        if(!answer)throw new Error('Exercise solution absent: '+id);
        const blockers=[document.querySelector('.reader-bar'),...(innerWidth<1100?[document.querySelector('#toc-panel > summary')]:[])].filter(Boolean);
        const bottom=Math.max(0,...blockers.map(n=>n.getBoundingClientRect()).filter(r=>r.top<150&&r.bottom>0).map(r=>r.bottom));
        scrollTo({top:scrollY+answer.getBoundingClientRect().top-bottom-20,behavior:'instant'});
        dispatchEvent(new Event('scroll'));
        const paragraphs=[...answer.querySelectorAll('p')].filter(p=>!p.matches('.answer-title,.rn-exercise-label')&&!p.closest('pre'));
        return {exercise:id,paragraphs:paragraphs.length,text_length:answer.textContent.trim().length};
      },targets.at(-1));
      await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      await screenshot(stem+'-solution');
    }
    view.annotations=await checkAnnotations(page,item.reader_policy,width);
    if(item.reader_policy){
      const middle=item.reader_policy.sections.filter(s=>s.annotation==='required');
      const id=middle[Math.floor(middle.length/2)].id;
      view.reading_position=await positionReadingSection(page,id);
      if(width===1800||width===390)await screenshot(stem+'-reading');
    }
    if(width===390){
      if(state.toc.length){
        view.toc_clicks=[];
        for(const hash of [...new Set([state.toc[0],state.toc[Math.floor(state.toc.length/2)],state.toc.at(-1)])]){
          if(!await page.evaluate(()=>document.getElementById('toc-panel').open))await page.click('#toc-panel > summary',{label:'展开手机章节目录'});
          await page.click('#chapter-toc a[href="'+hash+'"]',{label:'检查手机目录跳转'});
          await page.waitForFunction(hash=>{
            const target=document.getElementById(hash.slice(1));
            const blockers=[document.querySelector('.reader-bar'),document.querySelector('#toc-panel > summary')].filter(Boolean);
            const bottom=Math.max(0,...blockers.map(n=>n.getBoundingClientRect()).filter(r=>r.top<150&&r.bottom>0).map(r=>r.bottom));
            const r=(target.tagName==='DETAILS'?target.querySelector(':scope > summary'):target).getBoundingClientRect();
            return location.hash===hash&&!document.getElementById('toc-panel').open&&document.querySelector('#chapter-toc [aria-current="location"]')?.getAttribute('href')===hash&&r.top>=bottom-1&&r.top<innerHeight;
          },hash,{timeout:10000});
          view.toc_clicks.push({target:hash,collapsed_after_click:true,active_after_click:true,title_clear:true});
        }
      }
      const scroll=await page.evaluate(()=>{
        const candidates=[...document.querySelectorAll('main .scroll,main .equation,main pre,main .diagram,main .rn-math-inline')];
        const e=candidates.find(e=>e.clientWidth>0&&e.scrollWidth>e.clientWidth+10&&['auto','scroll'].includes(getComputedStyle(e).overflowX));
        if(!e)return null;e.scrollIntoView({block:'center',behavior:'instant'});const r=e.getBoundingClientRect();e.setAttribute('data-offline-scroll-test','');
        // Tall tables extend beyond the viewport: target the visible intersection,
        // below the persistent navigation, rather than the table's offscreen top.
        return {x:(Math.max(0,r.left)+Math.min(innerWidth,r.right))/2,y:(Math.max(160,r.top)+Math.min(innerHeight-20,r.bottom))/2,before:e.scrollLeft,client:e.clientWidth,scroll:e.scrollWidth};
      });
      if(scroll){await page.mouse.move(scroll.x,scroll.y,{label:'定位局部滚动区域'});await page.mouse.wheel(220,0,{label:'检查公式图表横向滚动'});
        const after=await page.evaluate(()=>document.querySelector('[data-offline-scroll-test]').scrollLeft);
        requireTrue(after>scroll.before,'Local horizontal wheel did not move');view.local_scroll={...scroll,after};
        await page.evaluate(()=>document.querySelector('[data-offline-scroll-test]').removeAttribute('data-offline-scroll-test'));
      }else view.local_scroll={applicable:false};
    }
    if(width===1800||width===390){
      view.diagram_checks=[];
      for(const diagram of (config.reviewedDiagrams??[]).filter(d=>d.page===item.route)){
        view.diagram_checks.push(await inspectReviewedDiagram(page,diagram));
        await screenshot(stem+'-diagram-'+view.diagram_checks.length);
        await restoreDiagramDisclosures(page);
      }
    }
    view.code_fold=await checkCodeFold(page);
    if(width===390&&item.reader_policy)view.expanded_layout=await expandedLayout();
    await save();console.log(JSON.stringify({page:item.route,width,status:'passed'}));
  }
  await page.cdp('Emulation.setScriptExecutionDisabled',{value:true});
  for(const width of [1440,390])for(const item of config.pages){
    if(report.no_js.some(v=>v.page===item.route&&v.width===width))continue;
    await page.cdp('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:false});
    const {requests,url}=await navigate(item);
    const before=await page.evaluate(()=>{
      const state={heading:document.querySelector('h1')?.textContent,
        maths:document.querySelectorAll('math').length,svgs:document.querySelectorAll('svg').length,merrors:document.querySelectorAll('merror').length,
        width:document.documentElement.scrollWidth,viewport:innerWidth};
      const e=document.querySelector('details.exercise')??document.querySelector('details');
      if(!e)return state;
      const s=e.querySelector('summary');s.scrollIntoView({block:'center',behavior:'instant'});const r=s.getBoundingClientRect();
      return {...state,id:e.id,open:e.open,x:r.x+Math.min(50,r.width/2),y:r.y+r.height/2};
    });
    requireTrue(before.heading,'No-JS heading missing');
    requireTrue(before.width<=before.viewport+1,'No-JS page overflow');
    requireTrue(before.maths===item.counts.mathml&&before.svgs===item.counts.svg&&before.merrors===0,'No-JS static math/SVG inventory differs');
    let after=null;
    if(before.id){
      await waitTarget(page,{id:before.id,url});
      await page.cdp('Input.dispatchMouseEvent',{type:'mousePressed',x:before.x,y:before.y,button:'left',clickCount:1});
      await page.cdp('Input.dispatchMouseEvent',{type:'mouseReleased',x:before.x,y:before.y,button:'left',clickCount:1});
      after=await readTarget(page,{id:before.id,url},e=>{const q=e.querySelector('.exercise-question'),a=e.querySelector('.answer');return {open:e.open,question:q?{length:q.textContent.length,height:q.getBoundingClientRect().height}:null,answer:a?{length:a.textContent.length,height:a.getBoundingClientRect().height}:null,width:document.documentElement.scrollWidth,viewport:innerWidth};});
      requireTrue(after.open!==before.open,'No-JS native details did not toggle');
      if(after.question)requireTrue(after.open&&after.question.length>0&&after.question.height>0&&after.answer.length>0&&after.answer.height>0,'No-JS exercise unreadable');
      requireTrue(after.width<=after.viewport+1,'No-JS page overflow');
    }
    const code_fold=await checkCodeFold(page);
    const annotations=await checkAnnotations(page,item.reader_policy,width,{script:false});
    const expanded_layout=width===390&&item.reader_policy?await expandedLayout():null;
    report.no_js.push({page:item.route,width,requests,before,after,code_fold,annotations,expanded_layout});
    await screenshot(item.route.replaceAll('/','_').replace('.html','')+'-no-js-'+width);await save();
  }
  report.status='passed';
}catch(error){report.status='failed';report.errors.push(String(error));throw error;}
finally{
  await save();
  await page.cdp('Emulation.setScriptExecutionDisabled',{value:false});
  await page.cdp('Network.emulateNetworkConditions',{offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1});
}
