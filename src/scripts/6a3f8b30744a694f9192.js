
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
      if (entry.section.getBoundingClientRect().top <= Math.max(110, wide.matches ? 100 : 110, wide.matches ? 0 : panel.querySelector('summary').getBoundingClientRect().bottom + 12) + 1) next = entry;
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
