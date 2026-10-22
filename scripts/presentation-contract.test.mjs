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
