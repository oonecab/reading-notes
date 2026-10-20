
(() => {
  document.documentElement.classList.add('toc-enhanced');
  const panel = document.getElementById('toc-panel');
  const nav = document.getElementById('chapter-toc');
  const wide = matchMedia('(min-width:1100px)');
  const links = Array.from(nav.querySelectorAll('li a[href^="#"]'));
  const entries = links.map(link => ({link, section: document.getElementById(link.hash.slice(1))})).filter(item => item.section);
  let current = null, scheduled = false;
  const fit = () => { panel.open = wide.matches; };
  fit();
  wide.addEventListener('change', fit);
  const reveal = () => {
    let target;
    try { target = document.getElementById(decodeURIComponent(location.hash.slice(1))); } catch { return; }
    for (let node = target; node; node = node.parentElement) {
      if (node.tagName === 'DETAILS') node.open = true;
    }
  };
  const mark = () => {
    scheduled = false;
    let next = entries[0];
    for (const entry of entries) {
      if (entry.section.getBoundingClientRect().top <= (wide.matches ? 110 : 144)) next = entry;
    }
    if (window.scrollY + innerHeight >= document.documentElement.scrollHeight - 2) next = entries[entries.length - 1];
    if (next && next.link !== current) {
      if (current) current.removeAttribute('aria-current');
      current = next.link; current.setAttribute('aria-current', 'location');
    }
  };
  const schedule = () => { if (!scheduled) { scheduled = true; requestAnimationFrame(mark); } };
  nav.addEventListener('click', event => {
    if (event.target.closest('a[href^="#"]') && !wide.matches) panel.open = false;
  });
  addEventListener('scroll', schedule, {passive:true});
  addEventListener('resize', schedule);
  addEventListener('hashchange', () => { reveal(); schedule(); });
  document.addEventListener('toggle', schedule, true);
  reveal(); mark();
})();


(() => {
  const rail = document.getElementById('annotation-rail');
  const content = document.getElementById('annotation-content');
  const context = document.getElementById('annotation-context-link');
  const groups = Array.from(document.querySelectorAll('main .reading-notes')).map(notes => ({
    notes, section: document.getElementById(notes.dataset.notesFor)
  })).filter(item => item.section);
  if (!rail || !content || !context || !groups.length) return;
  const wide = matchMedia('(min-width:1440px)');
  let current = null, scheduled = false;
  const update = () => {
    scheduled = false;
    if (!wide.matches) return;
    const sections = Array.from(document.querySelectorAll('main > section'));
    let active = sections[0];
    for (const section of sections) if (section.getBoundingClientRect().top <= 110) active = section;
    const relevant = groups.find(item => item.section === active);
    rail.hidden = !relevant;
    if (!relevant) { current = null; return; }
    let next = groups[0];
    for (const item of groups) {
      if (item.section.getBoundingClientRect().top <= 110) next = item;
    }
    if (scrollY + innerHeight >= document.documentElement.scrollHeight - 2) next = groups[groups.length - 1];
    if (current === next) return;
    const body = next.notes.querySelector('.reading-notes-body');
    const heading = next.section.querySelector('h2');
    if (!body || !heading) return;
    content.replaceChildren(...Array.from(body.children, node => node.cloneNode(true)));
    const label = heading.cloneNode(true);
    label.querySelectorAll('.english-title').forEach(node => node.remove());
    context.textContent = label.textContent;
    context.href = '#' + next.section.id;
    rail.dataset.activeSection = next.section.id;
    rail.scrollTop = 0;
    current = next;
  };
  const schedule = () => {
    if (!scheduled) { scheduled = true; requestAnimationFrame(update); }
  };
  const fit = () => {
    rail.hidden = !wide.matches;
    current = null;
    if (wide.matches) {
      document.documentElement.classList.add('notes-enhanced');
      update();
    } else {
      document.documentElement.classList.remove('notes-enhanced');
    }
  };
  wide.addEventListener('change', fit);
  addEventListener('scroll', schedule, {passive:true});
  addEventListener('resize', schedule);
  addEventListener('hashchange', schedule);
  document.addEventListener('toggle', schedule, true);
  fit();
})();


(() => {
  let saved=[];
  addEventListener('beforeprint',()=>{
    if(saved.length)return;
    saved=[...document.querySelectorAll('main details')].map(node=>[node,node.open]);
    saved.forEach(([node])=>{node.open=true;});
  });
  addEventListener('afterprint',()=>{
    saved.forEach(([node,open])=>{node.open=open;});saved=[];
  });
})();

(() => {
  const containers = Array.from(document.querySelectorAll('main .equation, main .math-block, main .scroll'));
  let pending = false;
  const update = () => {
    pending = false;
    // Measure every container before changing attributes that can trigger layout.
    const measured = containers.map(node => {
      const width = node.clientWidth;
      return [node, width > 0 && node.scrollWidth > width + 2];
    });
    for (const [node, overflow] of measured) {
      if (node.dataset.horizontalOverflow !== String(overflow)) node.dataset.horizontalOverflow = String(overflow);
      if (overflow) {
        const label = node.matches('.equation,.math-block') ? '左右滑动查看完整公式 →' : '左右滑动查看完整图表 →';
        if (node.dataset.scrollLabel !== label) node.dataset.scrollLabel = label;
        if (!node.hasAttribute('tabindex')) {
          node.tabIndex = 0;
          node.dataset.scrollFocusable = 'true';
        }
      } else if (node.dataset.scrollFocusable === 'true') {
        node.removeAttribute('tabindex');
        delete node.dataset.scrollFocusable;
      }
    }
  };
  const schedule = () => {
    if (!pending) { pending = true; requestAnimationFrame(update); }
  };
  addEventListener('resize', schedule);
  document.addEventListener('toggle', schedule, true);
  document.fonts.ready.then(schedule);
  update();
})();
