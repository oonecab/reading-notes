// RN-002 presentation contract: reading order, navigation, chapter opening,
// index placement, exercise language policy and the shared page shell.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { parse } from 'parse5';
import { entries, walk, attr } from '../src/lib/controlled-html.mjs';
import { checkMapNavigation } from '../src/lib/map-navigation.mjs';

const contractPath = 'docs/reader-presentation.json';
const contract = () => JSON.parse(fs.readFileSync(contractPath, 'utf8'));

const classes = n => (attr(n, 'class') ?? '').split(/\s+/).filter(Boolean);
const hasClass = (n, name) => classes(n).includes(name);
const text = n => n.nodeName === '#text' ? n.value : (n.childNodes ?? []).map(text).join('');
const norm = value => (value ?? '').replace(/\s+/g, ' ').trim();
const parents = n => n.parentNode ? [n.parentNode, ...parents(n.parentNode)] : [];
const inHeader = n => parents(n).some(p => p.tagName === 'header');
const inFooter = n => parents(n).some(p => p.tagName === 'footer');
const hasCjk = value => (value.match(/[\u3400-\u9fff]/g) ?? []).length >= 2;

export function expectedNavigation(pages, index) {
  const page = pages[index];
  const overview = { label: '全书地图', href: 'book_overview.html' };
  if (page.kind === 'overview') {
    const first = pages[1];
    return { header: [{ label: `开始阅读：${first.label} →`, href: first.file }], footer: [{ label: `开始阅读：${first.label} →`, href: first.file }, { label: '返回页首 ↑', href: '#top' }] };
  }
  const header = [overview];
  if (index > 0 && pages[index - 1].kind !== 'overview') {
    const prev = pages[index - 1];
    header.push({ label: prev.kind === 'preface' ? '← 序言' : `← ${prev.label}`, href: prev.file });
  }
  if (index < pages.length - 1) {
    const next = pages[index + 1];
    header.push({ label: `${next.label} →`, href: next.file });
  }
  return { header, footer: [...header, { label: '返回页首 ↑', href: '#top' }] };
}

function navLinks(block) {
  return walk(block).filter(n => n.tagName === 'a').map(a => ({ label: norm(text(a)), href: attr(a, 'href') ?? '' }));
}

function locateNav(main) {
  const blocks = [...walk(main).filter(n => n.tagName === 'p' && hasClass(n, 'chapter-nav'))];
  return { header: blocks.filter(inHeader), footer: blocks.filter(inFooter), all: blocks };
}

function checkNavigation(page, pages, index, errors) {
  const html = page.html;
  const main = walk(parse(html)).find(n => n.tagName === 'main');
  if (!main) { errors.push('main missing'); return; }
  const nav = locateNav(main);
  const expected = expectedNavigation(pages, index);
  if (nav.all.length !== 2 || nav.header.length !== 1 || nav.footer.length !== 1) {
    errors.push(`chapter-nav must appear exactly once in header and footer (header ${nav.header.length}, footer ${nav.footer.length}, total ${nav.all.length})`);
    return;
  }
  const actualHeader = navLinks(nav.header[0]);
  const actualFooter = navLinks(nav.footer[0]);
  if (JSON.stringify(actualHeader) !== JSON.stringify(expected.header))
    errors.push(`header navigation differs: expected ${JSON.stringify(expected.header)}, got ${JSON.stringify(actualHeader)}`);
  if (JSON.stringify(actualFooter) !== JSON.stringify(expected.footer))
    errors.push(`footer navigation differs: expected ${JSON.stringify(expected.footer)}, got ${JSON.stringify(actualFooter)}`);
  for (const block of nav.all) {
    for (const link of walk(block).filter(n => n.tagName === 'a')) {
      const href = attr(link, 'href') ?? '';
      const label = norm(text(link));
      if (/^book_overview\.html#chapter-/.test(href)) errors.push(`chapter link points at map section: ${label} -> ${href}`);
      if (/^(?:第\s*\d+\s*章|附录\s*[A-Z])/.test(label) && !/^(?:chapter|appendix)[\w-]*\.html$/.test(href))
        errors.push(`chapter-labelled link must target a chapter file: ${label} -> ${href}`);
    }
  }
}

function checkSidebar(page, bookPages, errors) {
  const nodes = walk(parse(page.html));
  const main = nodes.find(n => n.tagName === 'main');
  const aside = nodes.find(n => n.tagName === 'aside' && hasClass(n, 'chapter-sidebar'));
  if (!aside) { errors.push('chapter-sidebar missing'); return; }
  const summary = walk(aside).find(n => n.tagName === 'summary');
  if (!summary || norm(text(summary)) !== '目录') errors.push(`sidebar title must be 目录, got ${summary ? norm(text(summary)) : 'none'}`);
  const sectionIds = main ? new Set(walk(main).filter(n => n.tagName === 'section').map(n => attr(n, 'id')).filter(Boolean)) : new Set();
  const links = walk(aside).filter(n => n.tagName === 'a').map(a => ({ href: attr(a, 'href') ?? '', label: norm(text(a)) }));
  for (const link of links) if (/^book_overview\.html#chapter-/.test(link.href)) errors.push(`sidebar chapter entry points at map section: ${link.label} -> ${link.href}`);
  const home = links.filter(l => l.href === 'book_overview.html');
  const preface = links.filter(l => l.href === 'preface.html');
  const wantsPreface = bookPages.some(p => p.kind === 'preface');
  if (home.length !== 1 || home[0].label !== '全书地图') errors.push(`sidebar overview link must be exactly 全书地图, got ${JSON.stringify(home)}`);
  if (wantsPreface && (preface.length !== 1 || preface[0].label !== '序言')) errors.push(`sidebar preface link must be exactly 序言, got ${JSON.stringify(preface)}`);
  const firstToc = links.filter(l => l.href === 'book_overview.html' || l.href === 'preface.html');
  if (firstToc.length && firstToc[0].href !== 'book_overview.html') errors.push('sidebar must list 全书地图 before 序言');
  const indexLinks = links.filter(l => ['#statement-index', '#source-index'].includes(l.href));
  if (indexLinks.length) {
    const indexPos = links.findIndex(l => l.href === indexLinks[0].href);
    const sectionPositions = links.map((l, i) => ({ i, id: l.href.slice(1) })).filter(x => sectionIds.has(x.id)).map(x => x.i);
    if (sectionPositions.some(i => i > indexPos)) errors.push('sidebar index link must come after all section links');
  }
}

function checkOpening(page, errors) {
  const nodes = walk(parse(page.html));
  const main = nodes.find(n => n.tagName === 'main');
  if (!main) return;
  const children = (main.childNodes ?? []).filter(n => n.tagName || (n.nodeName === '#text' && n.value.trim()));
  const headerIndex = children.findIndex(n => n.tagName === 'header');
  const firstSection = children.findIndex(n => n.tagName === 'section');
  if (headerIndex < 0) { errors.push('chapter header missing'); return; }
  if (firstSection < 0) return;
  const between = children.slice(headerIndex + 1, firstSection);
  const paragraphs = between.filter(n => n.tagName === 'p');
  if (paragraphs.length > 1) errors.push(`chapter opening allows at most one lead paragraph, got ${paragraphs.length}`);
  for (const node of between) {
    if (node.tagName === 'p') {
      if (walk(node).some(n => ['details', 'ul', 'ol', 'table', 'nav', 'figure', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'aside'].includes(n.tagName)))
        errors.push('chapter lead paragraph contains a list, index or heading');
      continue;
    }
    if (node.tagName) errors.push(`chapter opening has disallowed element: <${node.tagName}>`);
  }
}

function checkIndexPlacement(page, errors) {
  const nodes = walk(parse(page.html, { sourceCodeLocationInfo: true }));
  const main = nodes.find(n => n.tagName === 'main');
  if (!main) return;
  const children = (main.childNodes ?? []).filter(n => n.tagName);
  const lastSection = children.map((n, i) => n.tagName === 'section' ? i : -1).filter(i => i >= 0).at(-1);
  for (const index of nodes.filter(n => ['statement-index', 'source-index'].includes(attr(n, 'id')) || hasClass(n, 'statement-index'))) {
    if (inHeader(index)) { errors.push('statement/source index must not be in the chapter header'); continue; }
    const chain = parents(index);
    const mainIndex = chain.findIndex(n => n.tagName === 'main');
    if (mainIndex < 0) { errors.push('index outside main'); continue; }
    let position = -1;
    for (let i = 0; i < children.length; i++) if (parents(index).includes(children[i]) || children[i] === index) position = i;
    if (lastSection >= 0 && position <= lastSection) errors.push('statement/source index must follow all content sections');
    if (inFooter(index)) errors.push('statement/source index must not be inside the footer navigation');
  }
  // Exercise index stays inside the exercise section, after its heading, before the first exercise.
  for (const index of nodes.filter(n => hasClass(n, 'exercise-index'))) {
    const section = [...parents(index)].find(p => p.tagName === 'section');
    if (!section || !walk(section).some(n => n.tagName === 'details' && hasClass(n, 'exercise'))) errors.push('exercise index must be inside an exercises section');
    if (section) {
      const firstExercise = walk(section).find(n => n.tagName === 'details' && hasClass(n, 'exercise'));
      if (firstExercise && index.sourceCodeLocation && firstExercise.sourceCodeLocation &&
          index.sourceCodeLocation.startOffset > firstExercise.sourceCodeLocation.startOffset)
        errors.push('exercise index must precede the first exercise');
    }
  }
}

function questionText(n) {
  if (n.tagName === 'math' || n.tagName === 'code' || n.tagName === 'pre' || n.tagName === 'svg') return '';
  if (hasClass(n, 'original-question') || hasClass(n, 'original-source') || hasClass(n, 'question-translation')) return n.nodeName === '#text' ? n.value : '';
  return n.nodeName === '#text' ? n.value : (n.childNodes ?? []).map(questionText).join('');
}

function checkExerciseLanguage(page, errors) {
  const nodes = walk(parse(page.html));
  const allowed = new Set((page.exceptions ?? []).filter(e => e.rule === 'exercise-original').map(e => e.exercise));
  for (const exercise of nodes.filter(n => n.tagName === 'details' && hasClass(n, 'exercise'))) {
    const id = attr(exercise, 'id') ?? '?';
    const question = walk(exercise).find(n => hasClass(n, 'exercise-question'));
    if (!question) { errors.push(`${id}: exercise-question missing`); continue; }
    const fullOriginal = walk(question).filter(n =>
      hasClass(n, 'original-question') || hasClass(n, 'original-source') || attr(n, 'data-exercise-original') !== undefined);
    if (fullOriginal.length && !allowed.has(id)) errors.push(`${id}: full English original is prohibited in reader pages`);
    for (const excerpt of walk(question).filter(n => hasClass(n, 'original-excerpt'))) {
      const reason = norm(attr(excerpt, 'data-excerpt-reason'));
      const body = norm(text(excerpt));
      const sentences = (body.match(/[.!?。！？]/g) ?? []).length;
      if (!reason) errors.push(`${id}: original excerpt needs data-excerpt-reason`);
      if (body.length > 400) errors.push(`${id}: original excerpt exceeds 400 characters`);
      if (sentences > 2) errors.push(`${id}: original excerpt exceeds 2 sentences`);
    }
    const chinese = norm(questionText(question));
    if (!hasCjk(chinese)) errors.push(`${id}: Chinese question task missing`);
    if (!/^q\d/.test(id) && !walk(question).some(n => n.tagName === 'a' && /\.pdf#page=\d+/.test(attr(n, 'href') ?? '')))
      errors.push(`${id}: source PDF page link missing`);
  }
}

function checkShell(page, errors) {
  const nodes = walk(parse(page.html));
  const body = nodes.find(n => n.tagName === 'body');
  if (!body || !hasClass(body, 'rn-components')) errors.push('body must carry rn-components');
  const header = nodes.find(n => n.tagName === 'header');
  if (!header) errors.push('page header missing');
  else {
    if (nodes.filter(n => n.tagName === 'h1' && parents(n).includes(header)).length !== 1) errors.push('header must contain exactly one h1');
    if (!walk(header).some(n => hasClass(n, 'overline'))) errors.push('header overline missing');
    if (page.kind !== 'overview') {
      if (!walk(header).some(n => n.tagName === 'p' && hasClass(n, 'intro'))) errors.push('header intro missing');
      if (!walk(header).some(n => n.tagName === 'p' && (hasClass(n, 'source') || hasClass(n, 'small') || hasClass(n, 'meta')))) errors.push('header source/range line missing');
    }
  }
  if (!nodes.some(n => n.tagName === 'main' && attr(n, 'id') === 'top')) errors.push('main#top missing');
  if (!nodes.some(n => n.tagName === 'footer')) errors.push('footer missing');
}

function checkOverviewLinks(page, pages, errors) {
  if (page.kind !== 'overview') return;
  const nodes = walk(parse(page.html));
  const hrefs = new Set(nodes.filter(n => n.tagName === 'a').map(n => attr(n, 'href')));
  for (const item of pages.slice(1)) {
    if (item.kind === 'chapter' && !hrefs.has(item.file)) errors.push(`overview does not link directly to ${item.file}`);
  }
}

export function checkPage(page, pages, index) {
  const errors = [];
  checkNavigation(page, pages, index, errors);
  checkSidebar(page, pages, errors);
  checkOpening(page, errors);
  checkIndexPlacement(page, errors);
  checkExerciseLanguage(page, errors);
  checkShell(page, errors);
  checkOverviewLinks(page, pages, errors);
  errors.push(...checkMapNavigation(page, pages));
  return errors;
}

export function checkAll({ book = null } = {}) {
  const policy = contract();
  const all = entries();
  const books = book ? [book] : Object.keys(policy.books);
  const report = { status: 'passed', standard: 'RN-002', books: [], errors: [] };
  for (const id of books) {
    const registered = policy.books[id];
    assert(registered, `Unregistered book in presentation contract: ${id}`);
    const pages = all.filter(e => e.metadata.book === id).map(e => ({
      file: path.basename(e.metadata.route),
      html: e.html,
      metadata: e.metadata,
      ...registered.pages.find(p => p.file === path.basename(e.metadata.route)),
    }));
    if (pages.length !== registered.pages.length) {
      report.errors.push({ book: id, page: '-', errors: [`registered ${registered.pages.length} pages, found ${pages.length}`] });
    }
    for (const expected of registered.pages) {
      if (!pages.some(p => p.file === expected.file)) report.errors.push({ book: id, page: expected.file, errors: ['registered page missing'] });
    }
    const ordered = registered.pages.map(item => pages.find(p => p.file === item.file) ?? { ...item, html: '', metadata: {} });
    const bookReport = { book: id, pages: ordered.length, errors: [] };
    for (let i = 0; i < ordered.length; i++) {
      const page = ordered[i];
      if (!page.html) continue;
      page.exceptions = (registered.exceptions ?? []).filter(e => e.page === page.file);
      page.map_navigation = registered.overview_maps ?? [];
      const errors = checkPage(page, ordered, i);
      if (errors.length) {
        bookReport.errors.push({ page: page.file, errors });
        report.errors.push({ book: id, page: page.file, errors });
      }
    }
    bookReport.status = bookReport.errors.length ? 'failed' : 'passed';
    report.books.push(bookReport);
  }
  report.status = report.errors.length ? 'failed' : 'passed';
  return report;
}


export function checkDist({ book = null } = {}) {
  const policy = contract();
  const books = book ? [book] : Object.keys(policy.books);
  const report = { status: 'passed', mode: 'dist', standard: 'RN-002', books: [], errors: [] };
  for (const id of books) {
    const registered = policy.books[id];
    const rows = [];
    const builtPages = registered.pages.map(p => ({ ...p, html: fs.existsSync(path.join('dist', id, 'notes', p.file)) ? fs.readFileSync(path.join('dist', id, 'notes', p.file), 'utf8') : '' }));
    for (let i = 0; i < registered.pages.length; i++) {
      const page = registered.pages[i];
      const file = path.join('dist', id, 'notes', page.file);
      if (!fs.existsSync(file)) { rows.push({ page: page.file, errors: ['built page missing: ' + file] }); continue; }
      const nodes = walk(parse(fs.readFileSync(file, 'utf8')));
      const navs = nodes.filter(n => n.tagName === 'p' && hasClass(n, 'chapter-nav'));
      const expected = expectedNavigation(registered.pages, i);
      const errors = checkMapNavigation({ ...page, html: builtPages[i].html, map_navigation: registered.overview_maps ?? [] }, builtPages);
      if (navs.length !== 2) errors.push(`expected two chapter-nav blocks, got ${navs.length}`);
      const header = navs.find(inHeader), footer = navs.find(inFooter);
      // The portal shell prepends one declared global home link to both chapter-nav
      // blocks at publication time. It is part of the built shell, not the page source.
      const builtWant = (side, want) => [
        ...(side === 'footer' ? ['← 笔记首页'] : ['笔记首页']),
        ...want.map(l => l.label),
      ];
      for (const [side, block, want] of [['header', header, expected.header], ['footer', footer, expected.footer]]) {
        if (!block) { errors.push(`${side} chapter-nav missing in built page`); continue; }
        const links = navLinks(block);
        if (!links[0] || attr(walk(block).find(n => n.tagName === 'a'), 'data-notes-home') === undefined)
          errors.push(`${side} built page is missing the declared global home link`);
        const labels = links.map(l => l.label);
        if (JSON.stringify(labels) !== JSON.stringify(builtWant(side, want)))
          errors.push(`${side} built labels differ: expected ${JSON.stringify(builtWant(side, want))}, got ${JSON.stringify(labels)}`);
      }
      const aside = nodes.find(n => n.tagName === 'aside' && hasClass(n, 'chapter-sidebar'));
      const summary = aside && walk(aside).find(n => n.tagName === 'summary');
      if (!aside || !summary || norm(text(summary)) !== '目录') errors.push('built sidebar title must be 目录');
      if (aside) {
        const toc = walk(aside).filter(n => n.tagName === 'a' && hasClass(n, 'toc-home'));
        const labels = toc.map(n => norm(text(n)));
        const wantsPreface = registered.pages.some(p => p.kind === 'preface');
        const want = ['全书地图', ...(wantsPreface ? ['序言'] : [])];
        if (JSON.stringify(labels) !== JSON.stringify(want)) errors.push(`built sidebar home labels differ: expected ${JSON.stringify(want)}, got ${JSON.stringify(labels)}`);
      }
      if (errors.length) rows.push({ page: page.file, errors });
    }
    report.books.push({ book: id, pages: registered.pages.length, errors: rows });
    report.errors.push(...rows.map(r => ({ book: id, ...r })));
  }
  report.status = report.errors.length ? 'failed' : 'passed';
  return report;
}

if (process.argv[1] && path.resolve(process.argv[1]) === new URL(import.meta.url).pathname) {
  const bookIndex = process.argv.indexOf('--book');
  const book = bookIndex >= 0 ? process.argv[bookIndex + 1] : null;
  const report = process.argv.includes('--dist') ? checkDist({ book }) : checkAll({ book });
  console.log(JSON.stringify(report, null, 2));
  if (report.errors.length) process.exitCode = 1;
}
