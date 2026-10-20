// Run with ego-browser nodejs; the CLI injects config and keeps the shared session.
const {atomicJson,openSpace,waitDocument}=await import(config.runtime);
const task=await openSpace(taskSpace,config.selection), page=task.page(config.page);
atomicJson(config.sessionFile,{spaceId:task.spaceId,page:config.page});
const report={status:'running',scope:'desktop Chromium lab; CPU throttling is not a real handset or field percentile',network:'unthrottled',samples:[],errors:[]};
const save=()=>atomicJson(config.output+'/report.json',report);
try {
 await page.cdp('Network.enable');
 await page.cdp('Performance.enable');
 await page.cdp('Page.addScriptToEvaluateOnNewDocument',{source:`window.__rnPerf={longTasks:[],lcp:[]};for(const [type,key] of [['longtask','longTasks'],['largest-contentful-paint','lcp']])new PerformanceObserver(list=>window.__rnPerf[key].push(...list.getEntries().map(e=>e.toJSON()))).observe({type,buffered:true});`});
 for(const profile of [{width:1440,cpu:1},{width:390,cpu:4}]){
  await page.cdp('Emulation.setDeviceMetricsOverride',{width:profile.width,height:profile.width===390?844:900,deviceScaleFactor:1,mobile:false});
  await page.cdp('Emulation.setCPUThrottlingRate',{rate:profile.cpu});
  for(const route of config.routes)for(let round=0;round<config.rounds;round++){
   const url=config.origin+'/'+route+'?rn-perf='+encodeURIComponent(config.runId+'-'+profile.width+'-'+round);
   for(const visit of ['first','repeat']){
    if(visit==='first')await page.goto(url);else await page.reload();
    await waitDocument(page,url);
    const metrics=await page.evaluate(async()=>{
     if(!window.__rnPerf)throw new Error('Performance observer missing');
     await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>requestAnimationFrame(()=>setTimeout(resolve,0)))));
     const n=performance.getEntriesByType('navigation')[0];
     return {navigation:n.toJSON(),elements:document.getElementsByTagName('*').length,
      longTasks:window.__rnPerf.longTasks,lcp:window.__rnPerf.lcp.at(-1)??null,
      width:innerWidth,documentWidth:document.documentElement.scrollWidth,
      resources:performance.getEntriesByType('resource').map(r=>({name:r.name,transferSize:r.transferSize})),userAgent:navigator.userAgent};
    });
    if(metrics.documentWidth>metrics.width+1)throw new Error('Horizontal document overflow: '+route);
    const cdp=Object.fromEntries((await page.cdp('Performance.getMetrics')).metrics.filter(x=>['LayoutDuration','RecalcStyleDuration','ScriptDuration','LayoutCount','RecalcStyleCount'].includes(x.name)).map(x=>[x.name,x.value]));
    report.samples.push({route,profile,round,visit,...metrics,cdp});save();
    console.log(JSON.stringify({route,profile,round,visit,load:metrics.navigation.loadEventEnd}));
   }
  }
 }
 report.status='passed';save();
} catch(error){report.status='failed';report.errors.push(String(error));save();throw error;}
finally {await page.cdp('Emulation.setCPUThrottlingRate',{rate:1});await page.cdp('Emulation.clearDeviceMetricsOverride');}
