
(() => {
  const rail = document.getElementById('annotation-rail');
  const content = document.getElementById('annotation-content');
  const context = document.getElementById('annotation-context-link');
  const groups = Array.from(document.querySelectorAll('main .reading-notes')).map(notes => ({
    notes, section: document.getElementById(notes.dataset.notesFor)
  })).filter(item => item.section);
  if (!rail || !content || !context || !groups.length) return;
  const wide = matchMedia('(min-width:1440px)');
  const sections = Array.from(document.querySelectorAll('main > section[id]'));
  let current = null, scheduled = false;
  const update = () => {
    scheduled = false;
    if (!wide.matches) return;
    let active = sections[0];
    for (const section of sections) {
      if (section.getBoundingClientRect().top <= 111) active = section;
    }
    // A short final section cannot always reach the usual reading-position line.
    if (scrollY > 0 && scrollY + innerHeight >= document.documentElement.scrollHeight - 1) {
      active = sections.findLast(section => section.getBoundingClientRect().top < innerHeight - 100) ?? active;
    }
    const next = groups.find(item => item.section === active);
    rail.hidden = !next;
    if (!next) {
      content.replaceChildren();
      delete rail.dataset.activeSection;
      current = null;
      return;
    }
    if (current === next) return;
    const body = next.notes.querySelector('.reading-notes-body');
    const heading = next.section.querySelector('h2');
    if (!body || !heading) return;
    content.replaceChildren(...Array.from(body.children, node => node.cloneNode(true)));
    const label = heading.cloneNode(true);
    label.querySelectorAll('.english-title,math annotation').forEach(node => node.remove());
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
