// Inspect the actual styles of diagrams changed in the current review. The
// caller records a screenshot before restoring native disclosure states.
export async function inspectReviewedDiagram(page, review) {
  return page.evaluate(async review=>{
    const matches=[...document.querySelectorAll('main svg')].filter(s=>s.querySelector('title')?.textContent===review.title);
    if(matches.length!==1)throw new Error('Diagram title is not unique: '+review.title);
    const svg=matches[0],opened=[];
    for(let n=svg.parentElement;n;n=n.parentElement)if(n.tagName==='DETAILS'&&!n.open){n.open=true;opened.push(n);}
    window.__rnDiagramOpened=opened;
    svg.scrollIntoView({block:'start',behavior:'instant'});
    window.scrollBy({top:-(innerWidth<1100?180:130),behavior:'instant'});
    await document.fonts.ready;
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    const nodes=[...svg.querySelectorAll('.rn-node')].map(n=>{
      const style=getComputedStyle(n),accent=n.classList.contains('rn-node-accent'),bbox=n.getBBox();
      if(style.fill!==(accent?'rgb(255, 246, 228)':'rgb(237, 245, 253)'))throw new Error('Node palette differs: '+review.title);
      if(style.stroke!==(accent?'rgb(214, 189, 135)':'rgb(169, 191, 213)'))throw new Error('Node border differs: '+review.title);
      const labels=[...svg.querySelectorAll('text')].map(t=>({text:t.textContent,bbox:t.getBBox()})).filter(t=>{
        const x=t.bbox.x+t.bbox.width/2,y=t.bbox.y+t.bbox.height/2;
        return x>=bbox.x&&x<=bbox.x+bbox.width&&y>=bbox.y&&y<=bbox.y+bbox.height;
      }).map(t=>({text:t.text,inset:Math.min(t.bbox.x-bbox.x,t.bbox.y-bbox.y,bbox.x+bbox.width-t.bbox.x-t.bbox.width,bbox.y+bbox.height-t.bbox.y-t.bbox.height)}));
      return {width:bbox.width,height:bbox.height,fill:style.fill,stroke:style.stroke,labels};
    });
    if(nodes.length!==review.nodes)throw new Error('Diagram node inventory differs: '+review.title);
    if(svg.querySelectorAll('.rn-edge').length!==review.edges)throw new Error('Diagram edge inventory differs: '+review.title);
    if(document.documentElement.scrollWidth>innerWidth+1)throw new Error('Diagram causes page overflow');
    const compact=review.fit==='compact';
    if(compact){
      const bounds=svg.getBoundingClientRect();
      if(bounds.left<0||bounds.right>innerWidth+1)throw new Error('Compact diagram must fit the initial viewport: '+review.title);
      for(const node of svg.querySelectorAll('.rn-node,text')){
        const r=node.getBoundingClientRect();
        if(r.left<bounds.left||r.right>bounds.right)throw new Error('Compact diagram label or node is clipped: '+review.title);
      }
    }
    return {title:review.title,nodes,edges:svg.querySelectorAll('.rn-edge').length,compact_fit_checked:compact};
  },review);
}

export async function restoreDiagramDisclosures(page) {
  await page.evaluate(()=>{for(const n of window.__rnDiagramOpened??[])n.open=false;delete window.__rnDiagramOpened;});
}
