import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { parse } from 'parse5';
import { walk, attr } from '../../src/lib/controlled-html.mjs';

const text = node => node?.value ?? (node?.childNodes ?? []).map(text).join('');
const direct = (node, tag) => node.childNodes.find(child => child.tagName === tag);
const anchor = node => '#' + attr(node, 'id');
const hasClass = (node, name) => (attr(node, 'class') ?? '').split(/\s+/).includes(name);

export function checkVisualPage(html, policy, contract, source) {
  const book = policy.page.split('/')[0];
  const page = contract.books[book]?.pages[policy.page];
  if (!page) {
    const entry = contract.legacy.find(row => row.page === policy.page);
    assert(entry?.book === book && entry.issue === 'I081' && entry.reason && entry.review_version, 'Unregistered visual page: ' + policy.page);
    assert.equal(createHash('sha256').update(html).digest('hex'), entry.source_sha256, 'Changed legacy visual page');
    return;
  }
  const nodes = walk(parse(html));
  const ids = new Map(nodes.filter(n => attr(n,'id')).map(n => [anchor(n), n]));
  const seen = new Set();
  const registeredImages = new Set();
  const teachingNodes = new Set();
  const expected = policy.sections.filter(s => s.role === 'teaching' && s.parent);
  for (const {id} of expected) assert(page.sections[id]?.length, 'Missing visual inventory: ' + id);
  for (const [section, items] of Object.entries(page.sections)) {
    const region = ids.get('#' + section);
    assert(region && policy.sections.some(s => s.id === section), 'Unknown visual section: ' + section);
    const local = walk(region);
    local.forEach(n => teachingNodes.add(n));
    for (const item of items) {
      const {kind, status, representation, source_pdf_page: number} = item;
      assert(Number.isInteger(number) && number > 0 && number <= source.pages, 'Invalid visual PDF page');
      assert(item.title && item.reason?.trim() && item.review_version, 'Missing visual review metadata');
      assert(['figure','table','excerpt','trace'].includes(kind), 'Unknown visual kind');
      assert(['required','reproduced','equivalent','omitted','linked'].includes(status), 'Unknown visual status');
      if (status === 'omitted') continue;
      const target = ids.get(item.target);
      assert(target, 'Missing visual target: ' + item.target);
      let parts = [target];
      if (status === 'linked') {
        parts = (item.parts ?? [item.target]).map(ref => {
          assert(local.some(n => n.tagName === 'a' && attr(n,'href') === ref), 'Missing visual entry link: ' + ref);
          const part = ids.get(ref);
          assert(part && walk(target).includes(part), 'Incorrect linked visual destination: ' + ref);
          return part;
        });
      } else assert(local.includes(target), 'Visual outside registered section');
      const forms = representation.split('+');
      assert.equal(forms.length, parts.length, 'Incomplete visual representation');
      for (const [i, node] of parts.entries()) {
        seen.add(node);
        const children = walk(node);
        const form = forms[i];
        assert(['figure','svg','source-image','table','blockquote'].includes(form), 'Unknown representation');
        assert.equal(node.tagName, ['svg','source-image'].includes(form) ? 'figure' : form, 'Incorrect visual element');
        assert.equal(attr(node,'data-source-pdf-page'), String(number), 'Visual source page mismatch');
        assert(children.some(n => {
          if (n.tagName !== 'a') return false;
          const url = new URL(attr(n,'href'), 'https://reader.invalid/'+policy.page);
          return url.href === 'https://reader.invalid/'+source.route+'#page='+number;
        }), 'Missing visual source link');
        if (node.tagName === 'figure') {
          assert(text(direct(node,'figcaption')).trim(), 'Missing figure caption');
          const refs = (attr(node,'aria-labelledby') ?? '').trim().split(/\s+/);
          assert(attr(node,'aria-label')?.trim() || refs.every(ref => text(ids.get('#'+ref)).trim()), 'Unnamed figure');
          if (form === 'svg') assert(children.some(n => n.tagName === 'svg'), 'Missing SVG');
          const images = children.filter(n => n.tagName === 'img');
          if (form === 'source-image') {
            assert.equal(images.length, 1, 'Expected a single registered source image');
            assert(attr(images[0], 'alt')?.trim(), 'Missing image alt');
            const data = /^data:image\/webp;base64,([A-Za-z0-9+/]+={0,2})$/.exec(attr(images[0], 'src'));
            assert(data, 'Source image must be embedded');
            registeredImages.add(images[0]);
            assert(item.asset.startsWith(book+'/assets/') && /^[a-z0-9/_-]+\.webp$/.test(item.asset), 'Invalid source image path');
            const digest = bytes => createHash('sha256').update(bytes).digest('hex');
            assert.equal(digest(fs.readFileSync('books/'+item.asset)), item.asset_sha256, 'Source asset mismatch');
            assert.equal(digest(Buffer.from(data[1],'base64')), item.inline_sha256, 'Embedded image mismatch');
          } else assert.equal(images.length, 0, 'Unregistered source image');
        } else if (node.tagName === 'table') {
          assert(text(direct(node,'caption')).trim() || attr(node,'aria-label')?.trim(), 'Unnamed table');
          const headings = children.filter(n => n.tagName === 'th');
          assert(headings.length && headings.every(n => ['row','col','rowgroup','colgroup'].includes(attr(n,'scope'))), 'Invalid table headers');
        } else {
          assert(hasClass(node,'original-excerpt') && attr(node,'data-excerpt-reason')?.trim(), 'Missing excerpt reason');
          const quote = node.childNodes.filter(n => n.tagName !== 'cite').map(text).join('').trim();
          assert(quote && [...quote].length <= 400 && (quote.match(/[.!?。！？]+(?=\s|$)|[。！？]+/gu) ?? []).length <= 2, 'Excerpt exceeds limit');
        }
      }
    }
  }
  for (const n of nodes.filter(n => attr(n,'data-source-pdf-page') !== undefined || n.tagName === 'figure' || (teachingNodes.has(n) && ['table','blockquote'].includes(n.tagName)) || hasClass(n,'original-excerpt'))) {
    assert(seen.has(n), 'Unregistered visual element: ' + anchor(n));
  }
  for (const img of nodes.filter(n=>n.tagName==='img')) assert(registeredImages.has(img),'Unregistered image');
}
