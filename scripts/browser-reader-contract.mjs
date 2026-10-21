// Browser obligations come from the reviewed section registry, not DOM presence.
export async function positionReadingSection(page,id) {
  await page.evaluate(async id=>{
    const section=document.getElementById(id);
    const blockers=[document.querySelector('.reader-bar'),...(innerWidth<1100?[document.querySelector('#toc-panel > summary')]:[])].filter(Boolean);
    const bottom=Math.max(0,...blockers.map(n=>n.getBoundingClientRect()).filter(r=>r.top<150&&r.bottom>0).map(r=>r.bottom));
    const offset=Math.max(parseFloat(getComputedStyle(section).scrollMarginTop)||0,bottom+12);
    scrollTo({top:scrollY+section.getBoundingClientRect().top-offset,behavior:'instant'});
    dispatchEvent(new Event('scroll'));
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
  },id);
  await page.waitForFunction(id=>{
    const section=document.getElementById(id),heading=section.querySelector('h2');
    const blockers=[document.querySelector('.reader-bar'),...(innerWidth<1100?[document.querySelector('#toc-panel > summary')]:[])].filter(Boolean);
    const bottom=Math.max(0,...blockers.map(n=>n.getBoundingClientRect()).filter(r=>r.top<150&&r.bottom>0).map(r=>r.bottom));
    const link=document.querySelector('#chapter-toc a[href="#'+id+'"]');
    return heading.getBoundingClientRect().top>=bottom+8&&(!link||link.getAttribute('aria-current')==='location')&&(innerWidth<1440||document.getElementById('annotation-rail').dataset.activeSection===id);
  },id,{timeout:7000});
  return await page.evaluate(id=>({section:id,heading_top:document.getElementById(id).querySelector('h2').getBoundingClientRect().top,toc:document.querySelector('#chapter-toc [aria-current]')?.getAttribute('href'),annotation:document.getElementById('annotation-rail').dataset.activeSection}),id);
}
export async function checkAnnotations(page, policy, width, {script=true}={}) {
  if (!policy) return {applicable:false,reason:'Auxiliary or redirect page; destination audited separately'};
  const required=policy.sections.filter(s=>s.annotation==='required').map(s=>s.id);
  if(!required.length)throw new Error('Reader annotation policy is empty: '+policy.page);
  const inventory=await page.evaluate(()=>[...document.querySelectorAll('main .reading-notes')].map(n=>n.dataset.notesFor));
  for(const id of required)if(!inventory.includes(id))throw new Error('Required reading note absent: '+policy.page+'#'+id);
  const observations=[];
  for(const id of required){
    if(script&&width>=1440){
      await page.evaluate(id=>{const s=document.getElementById(id);window.scrollTo({top:scrollY+s.getBoundingClientRect().top-100,behavior:'instant'});window.dispatchEvent(new Event('scroll'));},id);
      await page.waitForFunction(id=>{
        const r=document.getElementById('annotation-rail');
        const link=document.querySelector('#chapter-toc [aria-current="location"]');
        const target=link?document.getElementById(link.hash.slice(1)):null;
        const toc=!document.querySelector('#chapter-toc a[href="#'+id+'"]')||target===document.getElementById(id)||target?.closest('main > section')?.id===id;
        // The rail and TOC update in separate animation-frame callbacks. Both
        // must settle before their coordinated reading position is inspected.
        return toc&&r&&!r.hidden&&r.dataset.activeSection===id&&document.getElementById('annotation-content').textContent.trim().length>0;
      },id,{timeout:7000});
      const state=await page.evaluate(id=>{
        const r=document.getElementById('annotation-rail'),c=document.getElementById('annotation-content');
        const original=document.querySelector('main [data-notes-for="'+id+'"] .reading-notes-body');
        const link=document.getElementById('annotation-context-link');
        const heading=document.getElementById(id).querySelector('h2').cloneNode(true);
        heading.querySelectorAll('.english-title,math annotation').forEach(n=>n.remove());
        const normalize=s=>s.replace(/\s+/g,' ').trim();
        const box=r.getBoundingClientRect();
        const children=n=>Array.from(n.children,child=>child.outerHTML).join('');
        const activeLink=document.querySelector('#chapter-toc [aria-current="location"]');
        const activeTarget=activeLink?document.getElementById(activeLink.hash.slice(1)):null;
        const toc=!document.querySelector('#chapter-toc a[href="#'+id+'"]')||activeTarget===document.getElementById(id)||activeTarget?.closest('main > section')?.id===id;
        return {id,active:r.dataset.activeSection,visible:box.width>0&&box.top<innerHeight,identical:children(c)===children(original),overflows:c.scrollWidth>c.clientWidth+1,context:link.getAttribute('href')==='#'+id&&normalize(link.textContent)===normalize(heading.textContent),toc};
      },id);
      if(!state.visible||!state.identical||state.overflows||!state.context||!state.toc)throw new Error('Annotation render differs: '+JSON.stringify(state));
      observations.push(state);
    }else{
      const state=await page.evaluate(id=>{
        const n=document.querySelector('main [data-notes-for="'+id+'"]'),b=n.querySelector('.reading-notes-body');
        return {id,open:n.open,visible:n.checkVisibility()&&b.getBoundingClientRect().height>0,text:b.textContent.trim().length,overflows:b.scrollWidth>b.clientWidth+1};
      },id);
      if(!state.open||!state.visible||!state.text||state.overflows)throw new Error('Inline annotation unreadable: '+JSON.stringify(state));
      observations.push(state);
    }
  }
  const exceptions=[];
  if(script&&width>=1440)for(const s of policy.sections.filter(s=>s.annotation!=='required'&&!inventory.includes(s.id))){
    await page.evaluate(id=>{const section=document.getElementById(id);window.scrollTo({top:scrollY+section.getBoundingClientRect().top-100,behavior:'instant'});window.dispatchEvent(new Event('scroll'));},s.id);
    await page.waitForFunction(()=>{const r=document.getElementById('annotation-rail');return r.hidden&&!r.dataset.activeSection&&!document.getElementById('annotation-content').textContent.trim();},undefined,{timeout:7000});
    exceptions.push({id:s.id,rail_hidden:true,stale_content_cleared:true});
  }
  return {applicable:true,required:required.length,checked:observations.length,mode:script&&width>=1440?'rail':'inline',observations,exceptions};
}
