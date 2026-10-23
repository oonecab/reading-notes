import { parse } from 'parse5';
import { walk, attr } from './controlled-html.mjs';

const text = n => n.nodeName === '#text' ? n.value : (n.childNodes ?? []).map(text).join('');
const norm = s => (s ?? '').replace(/\s+/g, ' ').trim();
export const targetTitle = node => {
  const nodes = walk(node);
  return norm(text(nodes.find(n => /^h[1-6]$/.test(n.tagName)) ?? nodes.find(n => ['th', 'td'].includes(n.tagName)) ?? node));
};

export function mapLinks(html) {
  const nodes = walk(parse(html));
  const main = nodes.find(n => n.tagName === 'main');
  let index = 0;
  return (main ? walk(main) : []).filter(n => n.tagName === 'svg').map(svg => ({
    title: norm(text(walk(svg).find(n => n.tagName === 'title') ?? { childNodes: [] })),
    nodes: walk(svg).filter(n => n.tagName === 'a').map(a => ({
      index: index++, href: attr(a, 'href') ?? '',
      label: norm(attr(a, 'aria-label') ?? text(a)), visible_text: norm(text(a)),
    })),
  })).filter(svg => svg.nodes.length);
}

// Expectations come from RN-002's reviewed registry, never from the href under test.
export function checkMapNavigation(page, pages) {
  if (page.kind !== 'overview') return [];
  const actual = mapLinks(page.html), expected = page.map_navigation ?? [], errors = [];
  if (actual.length !== expected.length) errors.push(`unregistered or missing chapter map: expected ${expected.length}, got ${actual.length}`);
  for (let m = 0; m < Math.max(actual.length, expected.length); m++) {
    const map = actual[m], registered = expected[m];
    if (!map || !registered) continue;
    if (map.title !== registered.title) errors.push(`chapter map title differs: ${map.title} -> ${registered.title}`);
    if (map.nodes.length !== registered.nodes.length) errors.push(`map node count differs: ${map.title}: expected ${registered.nodes.length}, got ${map.nodes.length}`);
    for (let i = 0; i < registered.nodes.length; i++) {
      const want = registered.nodes[i], node = map.nodes[i], prefix = `map node ${map.title} [${i + 1}]`;
      if (!node) continue;
      if (node.href !== want.href || node.label !== want.label) errors.push(`${prefix}: expected ${want.label} -> ${want.href}, got ${node.label} -> ${node.href}`);
      const chapter = pages.find(p => p.kind === 'chapter' && p.number === want.number);
      let destination;
      if (want.kind === 'chapter') {
        if (!chapter || want.href !== chapter.file || node.href !== chapter.file) errors.push(`${prefix}: chapter ${want.number} must target its registered formal chapter file`);
        destination = chapter?.html && walk(parse(chapter.html)).find(n => n.tagName === 'h1');
      } else if (['chapter-summary', 'chapter-group-summary'].includes(want.kind)) {
        if (want.kind === 'chapter-summary') {
          if (chapter) errors.push(`${prefix}: chapter ${want.number} has a formal chapter page; a map summary cannot replace it`);
          if (!/(章意|摘要)/.test(node.visible_text)) errors.push(`${prefix}: visible chapter summary purpose is missing`);
        } else if (!Array.isArray(want.numbers) || !want.numbers.length) {
          errors.push(`${prefix}: chapter group needs explicit chapter numbers`);
        }
        if (!/^#[\w-]+$/.test(want.href)) errors.push(`${prefix}: summary target must be an explicit map anchor`);
        const targets = walk(parse(page.html)).filter(n => attr(n, 'id') === want.href.slice(1));
        if (targets.length !== 1) errors.push(`${prefix}: target must resolve exactly once`);
        destination = targets[0];
      } else errors.push(`${prefix}: unknown target kind ${want.kind}`);
      if (!destination) errors.push(`${prefix}: target title is missing`);
      else if (!want.target_title || targetTitle(destination) !== want.target_title) errors.push(`${prefix}: target title differs from ${want.target_title}`);
    }
  }
  return errors;
}
