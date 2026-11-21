(() => {
  const initialized = new WeakSet();
  function target(hash) {
    try { return document.getElementById(decodeURIComponent(hash.slice(1))); } catch { return null; }
  }
  function entriesFor(nav) {
    return Array.from(nav.querySelectorAll('li a[href^="#"]'), link => ({link, section:target(link.hash)}));
  }
  function init({nav, panel, breakpoint = 1100, groupHeading = "h2", childHeading = "h3"} = {}) {
    if (!nav || !panel || initialized.has(nav)) return;
    const entries = entriesFor(nav);
    const groups = [];
    let parent;
    for (const entry of entries) {
      const heading = /^h[1-6]$/.test(entry.section?.localName) ? entry.section :
        entry.section?.querySelector(':scope > :is(h1,h2,h3,h4,h5,h6)');
      if (heading?.localName !== childHeading) {
        parent = heading?.localName === groupHeading ? entry : null;
        continue;
      }
      if (!parent) continue;
      const item = parent.link.closest('li');
      const child = entry.link.closest('li');
      const nested = child.parentElement.parentElement === item ? child.parentElement : null;
      if (!nested && item.nextElementSibling !== child) {
        parent = null;
        continue;
      }
      if (!parent.group) {
        const list = document.createElement('ul');
        list.id = 'toc-group-' + parent.section.id;
        while (document.getElementById(list.id)) list.id += '-sub';
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'toc-toggle';
        button.setAttribute('aria-controls', list.id);
        const title = parent.link.textContent.trim();
        const open = expanded => {
          list.hidden = !expanded;
          button.ariaExpanded = expanded;
          button.ariaLabel = (expanded ? '折叠 ' : '展开 ') + title;
        };
        button.addEventListener('click', () => open(list.hidden));
        item.classList.add('toc-branch');
        if (nested) nested.before(button, list);
        else item.append(button, list);
        parent.group = {list, open};
        groups.push(parent.group);
      }
      parent.group.list.append(child);
      entry.group = parent.group;
    }
    if (!groups.length) return;
    initialized.add(nav);
    const wide = matchMedia('(min-width:' + breakpoint + 'px)');
    function targetGroup() {
      const node = target(location.hash);
      return entries.findLast(entry => entry.section?.contains(node))?.group;
    }
    function defaults() {
      const active = targetGroup() || entries.find(entry => entry.link.hasAttribute('aria-current'))?.group || groups[0];
      groups.forEach(group => group.open(wide.matches || group === active));
    }
    defaults();
    wide.addEventListener('change', defaults);
    addEventListener('hashchange', () => targetGroup()?.open(true));
    let saved, panelWasOpen;
    addEventListener('beforeprint', () => {
      if (saved) return;
      panelWasOpen = panel.open;
      panel.open = true;
      saved = groups.map(group => !group.list.hidden);
      groups.forEach(group => group.open(true));
    });
    addEventListener('afterprint', () => {
      if (!saved) return;
      groups.forEach((group,i) => group.open(saved[i]));
      panel.open = panelWasOpen;
      saved = null;
    });
  }
  window.TocTree = {init, entriesFor};
})();
