export function mapLandingMatches(state, expected) {
  return !!state && !!expected && state.url === expected.url && state.title === expected.target_title &&
    state.ready && state.visible && state.top >= state.blocker_bottom - 1 &&
    state.bottom <= state.viewport && state.width > 0 && state.width <= state.viewport_width + 1;
}

// A changed fragment is only the start of navigation. Read the named destination
// after native navigation and scrolling have settled, including without page JS.
export async function waitLanding(page, expected, { timeout = 10000, interval = 60 } = {}) {
  const deadline = Date.now() + timeout;
  let previous = '', settled = 0, state;
  while (Date.now() < deadline) {
    state = await page.evaluate(expected => {
      const norm = s => (s ?? '').replace(/\s+/g, ' ').trim();
      const target = expected.kind === 'chapter' ? document.querySelector('main h1') : document.getElementById(new URL(expected.url).hash.slice(1));
      const heading = target?.matches('h1,h2,h3,h4,h5,h6') ? target : target?.querySelector('h1,h2,h3,h4,h5,h6,th,td') ?? target;
      const r = heading?.getBoundingClientRect();
      const blockers = ['.reader-bar', '#toc-panel > summary'].map(s => document.querySelector(s)?.getBoundingClientRect())
        .filter(b => b && r && b.top < 150 && b.bottom > 0 && b.right > r.left && b.left < r.right);
      return { url: location.href, title: heading ? norm(heading.textContent) : '', ready: document.readyState === 'complete' && !!document.documentElement,
        visible: !!r && r.width > 0 && r.height > 0 && getComputedStyle(heading).visibility === 'visible',
        top: r?.top ?? -1, bottom: r?.bottom ?? -1, blocker_bottom: Math.max(0, ...blockers.map(b => b.bottom)),
        viewport: innerHeight, viewport_width: innerWidth, width: document.documentElement?.scrollWidth ?? 0 };
    }, expected);
    const key = JSON.stringify(state);
    settled = key === previous ? settled + 1 : 0;
    previous = key;
    if (mapLandingMatches(state, expected) && settled >= 2) return state;
    await new Promise(resolve => setTimeout(resolve, interval));
  }
  throw new Error('Chapter map did not reach its visible target: ' + JSON.stringify({ expected, state }));
}

// Wheel input can return while compositor scrolling is still moving. Sample
// geometry from Node so the same visibility gate also runs with page JS disabled.
export async function waitMapExposure(page, index, { timeout = 10000, interval = 60 } = {}) {
  const deadline = Date.now() + timeout;
  let state, previous = '', settled = 0;
  while (Date.now() < deadline) {
    state = await page.evaluate(index => {
      const a = [...document.querySelectorAll('main svg a')][index], n = a.getBoundingClientRect();
      for (let p = a.parentElement; p; p = p.parentElement) {
        if (p.clientWidth > 0 && p.scrollWidth > p.clientWidth + 1 && ['auto', 'scroll'].includes(getComputedStyle(p).overflowX)) {
          const r = p.getBoundingClientRect();
          return { scrollLeft: p.scrollLeft, node_visible: n.left >= Math.max(0, r.left) - 1 && n.right <= Math.min(innerWidth, r.right) + 1 };
        }
      }
      return { node_visible: false };
    }, index);
    const key = JSON.stringify(state);
    settled = key === previous ? settled + 1 : 0;
    previous = key;
    if (state.node_visible && settled >= 2) return state;
    await new Promise(resolve => setTimeout(resolve, interval));
  }
  throw new Error('Map node did not become fully visible after wheel input: ' + JSON.stringify({ index, state }));
}

async function exposeMapNode(page, index) {
  const scroll = await page.evaluate(index => {
    const a = [...document.querySelectorAll('main svg a')][index];
    for (let p = a.parentElement; p; p = p.parentElement) {
      if (p.clientWidth > 0 && p.scrollWidth > p.clientWidth + 1 && ['auto', 'scroll'].includes(getComputedStyle(p).overflowX)) {
        p.scrollIntoView({ block: 'center', behavior: 'instant' });
        const r = p.getBoundingClientRect(), n = a.getBoundingClientRect();
        return { before: p.scrollLeft, x: (r.left + r.right) / 2, y: (r.top + r.bottom) / 2,
          delta: (n.left + n.right - r.left - r.right) / 2 };
      }
    }
    return null;
  }, index);
  if (!scroll) return { horizontal_scroll: false };
  if (Math.abs(scroll.delta) > 1) {
    await page.mouse.move(scroll.x, scroll.y, { label: '定位 章节图 横滚区域' });
    await page.mouse.wheel(scroll.delta, 0, { label: '横向 展示 章节节点' });
  }
  const after = await waitMapExposure(page, index);
  if (!after.node_visible) throw new Error('Map node remains horizontally clipped: ' + JSON.stringify({index,scroll,after}));
  return { horizontal_scroll: true, before: scroll.before, after: after.scrollLeft, node_visible: true };
}

async function activate(page, index, { noJs, keyboard = false }) {
  const exposure = await exposeMapNode(page, index);
  const selector = 'main svg a >> nth=' + index;
  if (!noJs) {
    if (keyboard) await page.press(selector, 'Enter');
    else await page.click(selector, { label: '检查 章节图 节点落点' });
    return exposure;
  }
  // The ordinary click helper waits for animation frames, which page scripts
  // disabled mode cannot supply. Dispatch native input at the observed node.
  const p = await page.evaluate(index => {
    const a = [...document.querySelectorAll('main svg a')][index];
    a.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' });
    a.focus();
    const r = a.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, index);
  if (keyboard) {
    await page.cdp('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
    await page.cdp('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  } else {
    await page.cdp('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...p });
    await page.cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...p });
  }
  return exposure;
}

export async function checkChapterMapNavigation(page, { url, maps, noJs = false, screenshot = null }) {
  const expected = maps.flatMap((map, m) => map.nodes.map((node, n) => ({ ...node, diagram: m, node: n, url: new URL(node.href, url).href })));
  const result = { status: 'running', contract_signature: JSON.stringify(maps), nodes: [], keyboard: [], same_fragment: [] };
  await page.goto(url);
  const actual = await page.evaluate(() => [...document.querySelectorAll('main svg a')].map(a => ({ href: a.getAttribute('href'), label: (a.getAttribute('aria-label') ?? a.textContent).replace(/\s+/g, ' ').trim() })));
  if (actual.length !== expected.length) throw new Error('Chapter map inventory differs: ' + JSON.stringify({ expected: expected.length, actual }));
  result.inventory_count = actual.length;
  for (let i = 0; i < expected.length; i++) {
    const want = expected[i];
    if (actual[i].href !== want.href || actual[i].label !== want.label) throw new Error('Chapter map node differs: ' + JSON.stringify({ want, actual: actual[i] }));
    await page.goto(url);
    const activation = await activate(page, i, { noJs });
    const landing = await waitLanding(page, want);
    result.nodes.push({ index: i, activation, source: actual[i], expected: want, landing });
    if (screenshot && (i === 0 || i === expected.length - 1 || want.number === 8)) await screenshot('map-node-' + (i + 1));
    if (want.kind !== 'chapter') {
      await page.evaluate(i => [...document.querySelectorAll('main svg a')][i].scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' }), i);
      const activation = await activate(page, i, { noJs });
      result.same_fragment.push({ index: i, activation, landing: await waitLanding(page, want) });
    }
    if (want.node === 0) {
      await page.goto(url);
      const activation = await activate(page, i, { noJs, keyboard: true });
      result.keyboard.push({ index: i, activation, landing: await waitLanding(page, want) });
    }
  }
  await page.goto(url);
  result.status = 'passed';
  return result;
}
