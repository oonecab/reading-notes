// Inspect the platform glyphs used for existing content, as well as CSS families.
export async function checkReaderFonts(page) {
 await page.cdp('DOM.enable');await page.cdp('CSS.enable');
 const probes=await page.evaluate(()=>{
  const leaves=[...document.querySelectorAll('main *,header *,nav *')].filter(n=>!n.childElementCount&&/[A-Za-z0-9]/.test(n.textContent));
  const candidates={
   prose:leaves.filter(n=>!n.closest('pre,code,kbd,samp,math,svg,script,style')),
   code:[...document.querySelectorAll('main pre')],
   inline:[...document.querySelectorAll('main code:not(pre code)')],
   math:[...document.querySelectorAll('main math mi,main math mn')].filter(n=>/^[A-Za-z0-9]+$/.test(n.textContent)&&!['double-struck','script','fraktur'].includes(n.getAttribute('mathvariant')))
  };
  const opened=new Set();window.__rnFontOpened=opened;
  const selected={};
  for(const [kind,nodes] of Object.entries(candidates))for(const n of nodes){
   const ancestors=[];
   for(let p=n.parentElement;p;p=p.parentElement)if(p.tagName==='DETAILS'&&!p.open){ancestors.push(p);p.open=true;}
   if(n.checkVisibility()&&n.getBoundingClientRect().height>0){ancestors.forEach(p=>opened.add(p));selected[kind]=n;break;}
   ancestors.forEach(p=>p.open=false);
  }
  return Object.entries(selected).filter(([,n])=>n).map(([kind,n])=>{
   for(let p=n.parentElement;p;p=p.parentElement)if(p.tagName==='DETAILS'&&!p.open){opened.add(p);p.open=true;}
   n.setAttribute('data-reader-font-probe',kind);
   return {kind,text:n.textContent.slice(0,90),family:getComputedStyle(n).fontFamily};
  });
 });
 const rows=[];
 try{
  const {root}=await page.cdp('DOM.getDocument');
  for(const probe of probes){
   await page.evaluate(async kind=>{document.querySelector('[data-reader-font-probe="'+kind+'"]').scrollIntoView({block:'center',behavior:'instant'});await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));},probe.kind);
   const {nodeId}=await page.cdp('DOM.querySelector',{nodeId:root.nodeId,selector:'[data-reader-font-probe="'+probe.kind+'"]'});
   const {fonts}=await page.cdp('CSS.getPlatformFontsForNode',{nodeId});
   const expected=['code','inline'].includes(probe.kind)?/Mono|Menlo|Consolas|Courier/i:/Times New Roman/;
   if(!fonts.some(f=>expected.test(f.familyName)&&f.glyphCount>0))throw new Error('Reader glyph family differs: '+JSON.stringify({probe,fonts}));
   rows.push({...probe,fonts});
  }
  if(!rows.some(r=>r.kind==='prose'))throw new Error('No ordinary Latin/digit content was inspected');
  return rows;
 }finally{
  await page.evaluate(()=>{for(const p of window.__rnFontOpened)p.open=false;document.querySelectorAll('[data-reader-font-probe]').forEach(n=>n.removeAttribute('data-reader-font-probe'));delete window.__rnFontOpened;});
 }
}
