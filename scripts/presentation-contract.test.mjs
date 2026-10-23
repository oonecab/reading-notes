import test from 'node:test';
import assert from 'node:assert/strict';
import { checkPage } from '../tools/check-presentation-contract.mjs';

const pages = [
  { file: 'book_overview.html', kind: 'overview', label: '全书地图' },
  { file: 'preface.html', kind: 'preface', label: '序言' },
  { file: 'chapter01_test.html', kind: 'chapter', number: 1, label: '第 1 章 · 测试' },
  { file: 'chapter02_test.html', kind: 'chapter', number: 2, label: '第 2 章 · 继续' },
];

const nav = links => `<p class="chapter-nav">${links.map(([label, href]) => `<a href="${href}">${label}</a>`).join('')}</p>`;
const headerNav = nav([['全书地图', 'book_overview.html'], ['← 序言', 'preface.html'], ['第 2 章 · 继续 →', 'chapter02_test.html']]);
const footerNav = nav([['全书地图', 'book_overview.html'], ['← 序言', 'preface.html'], ['第 2 章 · 继续 →', 'chapter02_test.html'], ['返回页首 ↑', '#top']]);

function page(body, extra = '') {
  return `<html lang="zh-CN"><body class="rn-components"><div class="reading-layout"><aside class="chapter-sidebar"><details class="toc-panel" open><summary>目录</summary><nav class="chapter-toc"><a class="toc-home" href="book_overview.html">全书地图</a><a class="toc-home" href="preface.html">序言</a><a href="#s1">1.1</a></nav></details></aside><main id="top"><header><p class="overline">测试书</p><h1>第 1 章 · 测试</h1><p class="intro">副题</p><p class="source">来源</p>${headerNav}</header>${body}<footer><p>页脚</p>${footerNav}</footer></main></div></body></html>`;
}

const section = `<section id="s1"><h2>1.1 正文</h2><p>正文内容。</p></section>`;

test('canonical page passes', () => {
  assert.deepEqual(checkPage({ html: page(section), kind: 'chapter' }, pages, 2), []);
});

test('chapter navigation must not point at the map section', () => {
  const html = page(section).replace('href="chapter02_test.html">第 2 章', 'href="book_overview.html#chapter-2">第 2 章');
  assert.match(checkPage({ html, kind: 'chapter' }, pages, 2).join('\n'), /points at map section|chapter-labelled link/);
});

test('preface must link directly to the first chapter', () => {
  const preface = page(section)
    .replace(headerNav, nav([['全书地图', 'book_overview.html'], ['第 2 章 · 继续 →', 'chapter02_test.html']]))
    .replace(footerNav, nav([['全书地图', 'book_overview.html'], ['第 2 章 · 继续 →', 'chapter02_test.html'], ['返回页首 ↑', '#top']]));
  assert.match(checkPage({ html: preface, kind: 'preface' }, pages, 1).join('\n'), /navigation differs/);
});

test('chapter opening rejects indexes and lists', () => {
  const html = page(`<details class="statement-index" id="statement-index"><summary>定义与定理</summary><ul><li><a href="#t1">定理 1</a></li></ul></details>${section}`);
  const errors = checkPage({ html, kind: 'chapter' }, pages, 2).join('\n');
  assert.match(errors, /opening has disallowed element/);
  assert.match(errors, /index must follow all content sections/);
});

test('full English original is prohibited', () => {
  const exercise = `<section id="s1"><h2>1.1 习题</h2><details class="exercise" id="ex-1-1"><summary>习题 1.1</summary><div class="exercise-question"><p>请证明命题。</p><details class="original-question"><summary>英文原题</summary><p lang="en">Prove the claim.</p></details><a href="../assets/source.pdf#page=4">PDF 4</a></div><div class="answer"><p>证明如下。</p></div></details></section>`;
  assert.match(checkPage({ html: page(exercise), kind: 'chapter' }, pages, 2).join('\n'), /full English original is prohibited/);
});

test('short original excerpt needs a bounded reason', () => {
  const exercise = `<section id="s1"><h2>1.1 习题</h2><details class="exercise" id="ex-1-1"><summary>习题 1.1</summary><div class="exercise-question"><p>请证明命题。</p><blockquote class="original-excerpt" lang="en">Prove the claim.</blockquote><a href="../assets/source.pdf#page=4">PDF 4</a></div><div class="answer"><p>证明如下。</p></div></details></section>`;
  assert.match(checkPage({ html: page(exercise), kind: 'chapter' }, pages, 2).join('\n'), /needs data-excerpt-reason/);
});

test('sidebar title and last-page navigation are enforced', () => {
  const html = page(section).replace('<summary>目录</summary>', '<summary>本章目录</summary>');
  assert.match(checkPage({ html, kind: 'chapter' }, pages, 2).join('\n'), /sidebar title must be 目录/);
  const last = `<html lang="zh-CN"><body class="rn-components"><aside class="chapter-sidebar"><details class="toc-panel" open><summary>目录</summary><nav class="chapter-toc"><a class="toc-home" href="book_overview.html">全书地图</a><a class="toc-home" href="preface.html">序言</a></nav></details></aside><main id="top"><header><p class="overline">书</p><h1>第 2 章 · 继续</h1><p class="intro">副题</p><p class="source">来源</p>${nav([['全书地图', 'book_overview.html'], ['← 第 1 章 · 测试', 'chapter01_test.html'], ['第 3 章 · 不存在 →', 'chapter03_test.html']])}</header>${section}<footer>${nav([['全书地图', 'book_overview.html'], ['← 第 1 章 · 测试', 'chapter01_test.html'], ['第 3 章 · 不存在 →', 'chapter03_test.html'], ['返回页首 ↑', '#top']])}</footer></main></body></html>`;
  assert.match(checkPage({ html: last, kind: 'chapter' }, pages, 3).join('\n'), /navigation differs/);
});

const mapNodes = [
  { kind: 'chapter', number: 1, href: 'chapter01_test.html', label: '第 1 章 · 测试', target_title: '第 1 章 · 测试' },
  { kind: 'chapter', number: 2, href: 'chapter02_test.html', label: '第 2 章 · 继续', target_title: '第 2 章 · 继续' },
  { kind: 'chapter-summary', number: 3, href: '#chapter-3', label: '第 3 章 · 章意', target_title: '3 · 后续章意' },
];
const mapHtml = `<svg><title>章节关系图</title>${mapNodes.map(n => `<a href="${n.href}" aria-label="${n.label}"><rect/><text>${n.label}</text></a>`).join('')}</svg>`;
function overviewMap(html = mapHtml, expected = mapNodes) {
  const htmlBody = page(`<section id="s1"><h2>地图</h2>${html}<p><a href="chapter01_test.html">第一章文字入口</a><a href="chapter02_test.html">第二章文字入口</a></p><div id="chapter-3"><h3>3 · 后续章意</h3><p>内容摘要。</p></div></section>`)
    .replace(headerNav, nav([['开始阅读：序言 →', 'preface.html']]))
    .replace(footerNav, nav([['开始阅读：序言 →', 'preface.html'], ['返回页首 ↑', '#top']]));
  const all = pages.map(p => ({ ...p, html: `<main><header><h1>${p.label}</h1></header></main>` }));
  const current = { ...all[0], html: htmlBody, map_navigation: [{ title: '章节关系图', nodes: expected }] };
  return checkPage(current, [current, ...all.slice(1)], 0);
}

test('every chapter map node is checked separately from correct text entrances', () => {
  assert.deepEqual(overviewMap(), []);
  for (const [from, to] of [
    ['href="chapter01_test.html"', 'href="#chapter-1"'],
    ['href="chapter02_test.html"', 'href="chapter01_test.html"'],
    ['href="#chapter-3"', 'href="chapter03_missing.html"'],
    ['<text>第 3 章 · 章意</text>', '<text>第 3 章</text>'],
  ]) {
    assert.match(overviewMap(mapHtml.replace(from, to)).join('\n'), /map node/);
  }
});

test('chapter map inventory cannot silently omit, duplicate or add a node', () => {
  for (const html of [mapHtml.replace(/<a[^>]*>[\s\S]*?<\/a>/, ''), mapHtml.replace('</svg>', '<a href="chapter01_test.html">额外节点</a></svg>')]) {
    assert.match(overviewMap(html).join('\n'), /map.*node count/);
  }
  assert.match(overviewMap(mapHtml, [mapNodes[0], mapNodes[0], mapNodes[2]]).join('\n'), /map node/);
  assert.match(overviewMap(mapHtml, []).join('\n'), /map.*node count/);
});

test('map targets must exist, identify the expected chapter and have a readable title', () => {
  assert.match(overviewMap(mapHtml, [{...mapNodes[0],number:2},...mapNodes.slice(1)]).join('\n'), /map node.*chapter/);
  assert.match(overviewMap(mapHtml.replace('#chapter-3','#missing'), [...mapNodes.slice(0,2),{...mapNodes[2],href:'#missing'}]).join('\n'), /map node.*target/);
  assert.match(overviewMap(mapHtml,[{...mapNodes[0],target_title:'别的章节'},...mapNodes.slice(1)]).join('\n'), /map node.*title/);
  assert.match(overviewMap(mapHtml,[{...mapNodes[0],kind:'chapter-summary',href:'#chapter-1'},...mapNodes.slice(1)]).join('\n'), /map node.*chapter/);
});

test('new clickable diagrams require registration rather than zero coverage', () => {
  const all=pages.map(p=>({...p,html:`<main><h1>${p.label}</h1></main>`}));
  const html=page(section+mapHtml).replace(headerNav,nav([['开始阅读：序言 →','preface.html']])).replace(footerNav,nav([['开始阅读：序言 →','preface.html'],['返回页首 ↑','#top']]));
  assert.match(checkPage({...all[0],html,map_navigation:[]},all,0).join('\n'),/unregistered.*map/);
});
