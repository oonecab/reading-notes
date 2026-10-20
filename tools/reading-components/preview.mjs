// Isolated I039 prototype; never writes controlled sources, mirrors, or dist.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { parse } from 'parse5';
import { entries, walk, attr, root } from '../../src/lib/controlled-html.mjs';

const out = path.join(root, 'tmp/reading-components-preview');
const css = fs.readFileSync(path.join(root, 'tools/reading-components/components.css'), 'utf8');
// Keep I039's reviewed comparison reproducible after the I040 production rollout.
const baseline = '41a77dd3affc726bef81505ca5cde067d6f3944c';
const pages = entries().map(e => ({
  ...e,
  html: execFileSync('git', ['show', `${baseline}:${e.metadata.legacy_path}`], {
    cwd: root, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024,
  }),
}));
const sha = value => createHash('sha256').update(value).digest('hex');
const tree = html => parse(html, { sourceCodeLocationInfo: true });
const classes = n => (attr(n, 'class') ?? '').split(/\s+/);
const has = (n, c) => classes(n).includes(c);
const children = n => (n.childNodes ?? []).filter(n => n.tagName);
const raw = (html, n) => html.slice(n.sourceCodeLocation.startOffset, n.sourceCodeLocation.endOffset);
const esc = value => value.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
const page = (book, file) => {
  const result = pages.find(e => e.metadata.book === book && path.basename(e.filename) === file + '.html');
  assert(result, `Unknown page: ${book}/${file}`);
  return result;
};
const byId = (html, id) => {
  const n = walk(tree(html)).find(n => attr(n, 'id') === id);
  assert(n, `Missing sample anchor: ${id}`);
  return n;
};
const fragment = (e, id) => raw(e.html, byId(e.html, id));
function patch(html, edits) {
  let limit = html.length;
  for (const e of [...edits].sort((a, b) => b.start - a.start || b.end - a.end)) {
    assert(e.end <= limit && e.start <= e.end, 'Overlapping source edits');
    html = html.slice(0, e.start) + e.text + html.slice(e.end);
    limit = e.start;
  }
  return html;
}

function adapt(html) {
  const nodes = walk(tree(html));
  const edits = [];
  const add = (start, end, text) => edits.push({ start, end, text });
  function opening(n, extra, tag = n.tagName, open = false) {
    const l = n.sourceCodeLocation.startTag;
    let value = html.slice(l.startOffset, l.endOffset).replace(/^<[\w-]+/, '<' + tag);
    // Only wrapper attributes change; inline MathML/SVG is never serialized.
    if (attr(n, 'class') !== undefined) {
      value = value.replace(/\bclass=(["'])(.*?)\1/s, (_, q, c) => `class=${q}${c} ${extra}${q}`);
    } else value = value.replace(/>$/, ` class="${extra}">`);
    if (tag !== 'details') value = value.replace(/\sopen(?:=(?:"[^"]*"|'[^']*'|[^\s>]+))?(?=[\s>])/g, '');
    if (open) value = value.replace(/>$/, ' open>');
    add(l.startOffset, l.endOffset, value);
  }
  function closing(n, tag, prefix = '') {
    const l = n.sourceCodeLocation.endTag;
    assert(l, `Missing closing tag for ${attr(n, 'id')}`);
    add(l.startOffset, l.endOffset, prefix + `</${tag}>`);
  }
  const counts = { statement: 0, example: 0, proof: 0, exercise: 0, exerciseLabels: 0 };
  for (const n of nodes) {
    if (!n.tagName || !n.sourceCodeLocation) continue;
    if (has(n, 'source-statement') || has(n, 'statement')) {
      counts.statement++;
      opening(n, 'rn-statement', n.tagName === 'details' ? 'div' : n.tagName);
      if (n.tagName === 'details') {
        closing(n, 'div');
        const title = children(n).find(n => n.tagName === 'summary');
        assert(title, 'Statement must have a title');
        opening(title, 'rn-title', 'h3');
        closing(title, 'h3');
      }
    } else if (has(n, 'example-worked') || attr(n, 'data-preview-kind') === 'example') {
      counts.example++;
      opening(n, 'rn-example');
    } else if (has(n, 'proof-item') || has(n, 'proof')) {
      counts.proof++;
      const title = children(n)[0];
      assert(title && (/^h[1-6]$/.test(title.tagName) || has(title, 'proof-label')), 'Proof label must be explicit');
      opening(n, 'rn-proof', 'details', true);
      closing(n, 'details', '</div>');
      opening(title, 'rn-proof-title', 'summary');
      closing(title, 'summary', '');
      add(title.sourceCodeLocation.endOffset, title.sourceCodeLocation.endOffset, '<div class="rn-proof-body">');
    } else if (has(n, 'exercise')) {
      counts.exercise++;
      for (const block of children(n).filter(n => has(n, 'exercise-question') || has(n, 'answer'))) {
        const label = children(block)[0];
        assert(label && (/^h[1-6]$/.test(label.tagName) || label.tagName === 'p'), 'Unclassified exercise label');
        // Keep semantic wording and original heading level; normalize presentation.
        opening(label, 'rn-section-label');
        counts.exerciseLabels++;
      }
    }
  }
  return { html: patch(html, edits), counts };
}

function integrity(before, after) {
  const a = walk(tree(before)), b = walk(tree(after));
  const content = nodes => nodes.filter(n => n.nodeName === '#text' &&
    !['style', 'script', 'title'].includes(n.parentNode?.tagName)).map(n => n.value).join('').replace(/\s+/g, '');
  assert.equal(content(a), content(b), 'Text changed');
  for (const tag of ['math', 'svg', 'pre', 'code']) {
    assert.deepEqual(a.filter(n => n.tagName === tag).map(n => raw(before, n)),
      b.filter(n => n.tagName === tag).map(n => raw(after, n)), `${tag} bytes changed`);
  }
  for (const attribute of ['id', 'href', 'src']) {
    assert.deepEqual(a.filter(n => attr(n, attribute) !== undefined).map(n => attr(n, attribute)),
      b.filter(n => attr(n, attribute) !== undefined).map(n => attr(n, attribute)), `${attribute} changed`);
  }
  return {
    text: 'identical', anchors: a.filter(n => attr(n, 'id') !== undefined).length,
    protected: Object.fromEntries(['math', 'svg', 'pre', 'code'].map(tag =>
      [tag, { count: a.filter(n => n.tagName === tag).length,
        sha256: sha(a.filter(n => n.tagName === tag).map(n => raw(before, n)).join('')) }])),
    links: a.filter(n => attr(n, 'href') !== undefined).length,
  };
}

function rebase(html, e) {
  const nodes = walk(tree(html));
  const ids = new Set(nodes.map(n => attr(n, 'id')).filter(Boolean));
  const base = pathToFileURL(path.join(root, e.metadata.legacy_path));
  const edits = [];
  for (const n of nodes) for (const key of ['href', 'src']) {
    const value = attr(n, key), loc = n.sourceCodeLocation?.attrs?.[key];
    if (!value || !loc || /^[a-z][a-z\d+.-]*:/i.test(value) ||
        (value.startsWith('#') && ids.has(value.slice(1)))) continue;
    const url = new URL(value, base).href;
    edits.push({ start: loc.startOffset, end: loc.endOffset, text: `${key}="${esc(url)}"` });
  }
  return patch(html, edits);
}
const shellCSS = `
body.sample-fragment{margin:0;display:block;min-height:0}
body.sample-fragment main{max-width:860px;margin:0 auto;padding:24px;box-sizing:border-box}
@media(max-width:640px){body.sample-fragment main{padding:18px}}
`;
function fragmentDocument(e, body, after) {
  const styles = walk(tree(e.html)).filter(n => n.tagName === 'style').map(n => raw(e.html, n)).join('\n');
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(e.metadata.title)} · 组件样例</title>${styles}<style>${shellCSS}</style>${after ? `<style>${css}</style>` : ''}</head><body class="sample-fragment${after ? ' rn-components' : ''}"><main>${rebase(body, e)}</main></body></html>`;
}
const names = {stochastic:'随机过程',weiss:'Weiss 数据结构',csapp:'CS:APP','visual-group-theory':'视觉群论','measure-probability':'测度概率'};
const st = page('stochastic', 'chapter01_markov_chains');
const we = page('weiss', 'chapter07_hashing');
const cs = page('csapp', 'chapter02_information');
const vg = page('visual-group-theory', 'chapter05_five_families');
const me = page('measure-probability', 'chapter01_measurable_spaces');
const cases = [];
const addCase = (id, label, e, original, note = '') => cases.push({id,label,e,original,note});
addCase('stochastic-theorem', '定理与长证明', st, fragment(st,'theorem-1-1') + fragment(st,'theorem-1-1-proof'));
addCase('stochastic-example', '例题与逐步计算', st, fragment(st,'example-1-4'));
addCase('weiss-exercise', '习题与宽表格', we, fragment(we,'ex7-1'));
addCase('csapp-principle', '原理与双语陈述', cs, fragment(cs,'principle-2-unsigned-encoding'));
const theorem = byId(vg.html, 'theorem-5-1');
const siblings = children(theorem.parentNode), index = siblings.indexOf(theorem);
const proofNodes = siblings.slice(index + 1, index + 4);
assert.deepEqual(proofNodes.map(n => n.tagName), ['p','div','p'], 'VGT proof boundary drifted');
const vgOriginal = raw(vg.html, theorem) + proofNodes.map(n => raw(vg.html,n)).join('\n');
addCase('vgt-theorem', '定理与正文中的证明', vg, vgOriginal, '为三段原有论证补上“证明”标题，段落与公式保持原文。');
cases.at(-1).adaptInput = raw(vg.html, theorem) + '<div class="proof"><p class="proof-label" data-preview-added-label>证明</p>' +
  proofNodes.map(n => raw(vg.html,n)).join('\n') + '</div>';
addCase('measure-theorem', '定理与短证明', me, fragment(me,'theorem-1-3-2') + fragment(me,'theorem-1-3-2-proof'));
const example = fragment(me,'example-1-2-1');
addCase('measure-example', '定义性短例题', me, example);
cases.at(-1).adaptInput = example.replace(/^<article/, '<article data-preview-kind="example"');
for (const e of [st,cs,vg,me]) {
  const n = walk(tree(e.html)).find(n => has(n,'exercise'));
  assert(n);
  addCase(e.metadata.book + '-exercise', '习题的题干与解答', e, raw(e.html,n));
}
// Include an actual C/Python pair in the sample corpus.
const we1 = page('weiss', 'chapter01_introduction');
addCase('weiss-code-exercise', '习题中的 C / Python 代码', we1, fragment(we1,'ex1-1'));

fs.mkdirSync(out, { recursive:true });
const report = { status:'running', date:new Date().toISOString(), baseline, sourcePages:pages.length,
  stylesheetSHA256:sha(css), inventory:[], samples:[], fullChapter:null };
for (const e of pages) {
  const ns = walk(tree(e.html));
  report.inventory.push({ book:e.metadata.book, file:path.basename(e.filename),
    sourceSHA256:sha(e.html),
    exercise:ns.filter(n=>has(n,'exercise')).length,
    statement:ns.filter(n=>has(n,'source-statement')||has(n,'statement')).length,
    explicitExample:ns.filter(n=>has(n,'example-worked')).length,
    explicitProof:ns.filter(n=>has(n,'proof-item')||has(n,'proof')).length });
}
const full = adapt(st.html);
report.fullChapter = {source:path.relative(root,st.filename),counts:full.counts,...integrity(st.html,full.html)};
let fullHTML = rebase(full.html, st).replace('</head>', `<style>${css}</style></head>`);
fullHTML = fullHTML.replace(/<body([^>]*)>/, (_,attrs) => {
  if (/\bclass=/.test(attrs)) return '<body' + attrs.replace(/\bclass=(["'])(.*?)\1/,(_,q,c)=>`class=${q}${c} rn-components${q}`) + '>';
  return `<body${attrs} class="rn-components">`;
});
fs.writeFileSync(path.join(out,'chapter01.html'),fullHTML);

const uiCSS = `:root{--paper:#fffefa;--green:#285a4e;--ink:#252b29;--sub:#58615d;--rule:#d9dfda;--tint:#f4f6f2}*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.9 system-ui,-apple-system,sans-serif}main{max-width:1420px;margin:auto;padding:36px 28px 70px}h1{font-size:1.85rem;line-height:1.4;margin:.5rem 0 1rem}h2{font-size:1.2rem;color:var(--green)}p{max-width:76ch}a{color:var(--green);text-underline-offset:4px}nav{display:flex;gap:12px 24px;flex-wrap:wrap}small,.muted{color:var(--sub)}.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px}.card{padding:18px 20px;border:1px solid var(--rule)}.card h2{margin:0 0 8px}.card p{margin:0}iframe{width:100%;height:780px;border:1px solid var(--rule);background:var(--paper)}.frame-label{font-size:1rem;margin:12px 0}.intro{padding-bottom:24px;border-bottom:1px solid var(--rule);margin-bottom:24px}.button{display:inline-block;border:1px solid var(--green);padding:8px 16px;text-decoration:none}.frames{margin-top:20px}.frames section{min-width:0}a:focus-visible{outline:2px solid var(--green);outline-offset:4px}@media(max-width:780px){main{padding:24px 18px 48px}.grid{grid-template-columns:1fr;gap:18px}h1{font-size:1.5rem}iframe{height:650px}}`;
const ui = (title,body) => `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>${uiCSS}</style></head><body><main>${body}</main></body></html>`;
for (const c of cases) {
  const input = c.adaptInput ?? c.original;
  const converted = adapt(input);
  // Prove all original text is retained, allowing only one explicitly recorded label.
  const checkedAfter = c.id === 'vgt-theorem' ? converted.html.replace(/<summary[^>]*data-preview-added-label[^>]*>证明<\/summary>/,'') : converted.html;
  const evidence = integrity(c.original, checkedAfter);
  fs.writeFileSync(path.join(out,c.id+'-before.html'),fragmentDocument(c.e,c.original,false));
  fs.writeFileSync(path.join(out,c.id+'-after.html'),fragmentDocument(c.e,converted.html,true));
  fs.writeFileSync(path.join(out,c.id+'.html'),ui(names[c.e.metadata.book]+' · '+c.label,
    `<nav><a href="index.html">← 全部样例</a><a href="chapter01.html">第一章完整样章</a></nav><h1>${names[c.e.metadata.book]} · ${c.label}</h1><p class="muted">${c.note || '同一段现有内容，比较容器、标题、间距与展开方式。'} 习题默认收起，可直接展开比较。</p><div class="grid frames"><section><h2 class="frame-label">现有样式 · <a href="${c.id}-before.html">单独阅读</a></h2><iframe title="现有样式" src="${c.id}-before.html"></iframe></section><section><h2 class="frame-label">统一样式提案 · <a href="${c.id}-after.html">单独阅读</a></h2><iframe title="统一样式提案" src="${c.id}-after.html"></iframe></section></div>`));
  report.samples.push({id:c.id,book:c.e.metadata.book,label:c.label,counts:converted.counts,
    addedLabel:c.id==='vgt-theorem'?'证明':null,...evidence});
}
fs.writeFileSync(path.join(out,'index.html'),ui('Reading Notes · 内容组件样章',
  `<div class="intro"><p class="muted">Reading Notes · 内容组件样章</p><h1>让定理、例题、证明与习题<br>有稳定的阅读层次</h1><p>保留纸色、绿色与正文排版。定理使用浅色陈述区，例题顺着计算步骤阅读，证明默认展开并可收起，习题按题干与解答分区。</p><nav><a class="button" href="chapter01.html#theorem-1-1">阅读第一章完整样章</a><a href="measure-theorem.html">先看定理与证明对照</a><a href="weiss-exercise.html">先看习题对照</a></nav><p class="muted"><small>本地样章提案 · 12 组五书原文对照 · 正式页面尚未采用</small></p></div><div class="grid">${cases.map(c=>`<article class="card"><h2><a href="${c.id}.html">${names[c.e.metadata.book]} · ${c.label}</a></h2><p><small>${c.note||'保留原编号、陈述、公式、来源与代码，查看原有页面和提案的差别。'}</small></p></article>`).join('')}</div>`));
// A changed mathematical byte must not pass the preservation guard.
let rejected = false;
try { integrity('<math><mn>2</mn></math>', '<math><mn>3</mn></math>'); }
catch { rejected = true; }
assert(rejected, 'Integrity guard accepted a changed formula');
report.negativeCheck = 'changed formula rejected';
report.status = 'passed';
fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,directory:path.relative(root,out),
  fullChapter:report.fullChapter.counts,samples:report.samples.length,sourcePages:pages.length},null,2));
