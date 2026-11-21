import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { parse } from 'parse5';
import { walk, attr } from '../src/lib/controlled-html.mjs';

// Use the minifier already shipped with the pinned Astro/Vite toolchain.
const require = createRequire(import.meta.url);
const astro = createRequire(require.resolve('astro/package.json'));
const vite = createRequire(astro.resolve('vite/package.json'));
const {minifySync} = vite('rolldown/utils');
const {transform:transformCss} = vite('lightningcss');
const compactNavigationStyles = new Map();
const compactControllers = new Map();

export function htmlFiles(directory) {
  return fs.readdirSync(directory,{withFileTypes:true}).flatMap(e => e.isDirectory() ? htmlFiles(path.join(directory,e.name)) : e.name.endsWith('.html') ? [path.join(directory,e.name)] : []);
}
export function inlineAssets(directory, files = htmlFiles(directory)) {
  for (const file of files) {
    fs.writeFileSync(file, inlineHtmlAssets(directory, file, fs.readFileSync(file, 'utf8')));
  }
}
export function inlineHtmlAssets(directory, file, html) {
  const edits = [];
  for (const node of walk(parse(html,{sourceCodeLocationInfo:true}))) {
    const style = node.tagName === 'link' && attr(node,'rel') === 'stylesheet';
    const script = node.tagName === 'script' && attr(node,'src');
    const icon = node.tagName === 'link' && attr(node,'rel') === 'icon';
    if (node.tagName === 'style' && html.includes('window.TocTree =') && node.childNodes[0]) {
      const css = node.childNodes[0].value;
      if (!compactNavigationStyles.has(css)) {
        const output = transformCss({filename:'reading.css',code:Buffer.from(css),minify:true});
        compactNavigationStyles.set(css,output.code.toString());
      }
      edits.push({start:node.sourceCodeLocation.startTag.endOffset,end:node.sourceCodeLocation.endTag.startOffset,
        value:compactNavigationStyles.get(css)});
    }
    if (node.tagName === 'script' && !script) {
      const body = node.childNodes[0];
      const readingController = body && [
        'window.TocTree =',
        "getElementById('annotation-rail')",
        "querySelectorAll('main details')",
        "document.addEventListener('copy', event",
      ].some(marker => body.value.includes(marker));
      if (readingController) {
        if (!compactControllers.has(body.value)) {
          compactControllers.set(body.value, minifySync('reading-controller.js', body.value).code);
        }
        edits.push({start:node.sourceCodeLocation.startTag.endOffset, end:node.sourceCodeLocation.endTag.startOffset,
          value:compactControllers.get(body.value)});
      }
    }
    if (!style && !script && !icon) continue;
    const url = attr(node, style || icon ? 'href':'src');
    if (url.startsWith('data:')) continue;
    if (/^(?:[a-z]+:|\/\/)/i.test(url) || /[?#]/.test(url)) throw new Error(`Uncontrolled asset: ${url}`);
    const source = path.resolve(url.startsWith('/') ? directory : path.dirname(file), url.replace(/^\//,''));
    if (!source.startsWith(path.resolve(directory)+path.sep) || fs.lstatSync(source).isSymbolicLink()) throw new Error(`Asset outside output: ${url}`);
    const data = fs.readFileSync(source,'utf8');
    if (script && /\bimport\s*(?:\(|[{'"*])|\bexport\s/.test(data)) throw new Error('Script must be bundled before inlining');
    const loc = node.sourceCodeLocation;
    if(icon && !source.endsWith('.svg'))throw new Error('Only explicitly registered SVG icons are supported');
    const value=icon ? html.slice(loc.startOffset,loc.endOffset).replace(/href="[^"]*"/,()=>`href="data:image/svg+xml;base64,${Buffer.from(data).toString('base64')}"`)
      : style ? `<style>${data}</style>` : `<script${attr(node,'type')==='module'?' type="module"':''}>${data}</script>`;
    edits.push({start:loc.startOffset,end:loc.endOffset,value});
  }
  for (const edit of edits.sort((a,b)=>b.start-a.start)) html=html.slice(0,edit.start)+edit.value+html.slice(edit.end);
  return html;
}

export function validateSiteIcon(html, svg) {
  const tree = parse(html);
  const nodes = walk(tree);
  const icons = nodes.filter(node => node.tagName === 'link' && (attr(node, 'rel') ?? '').toLowerCase().split(/\s+/).includes('icon'));
  const head = nodes.find(node => node.tagName === 'head');
  const expected = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
  if (icons.length !== 1 || !walk(head).includes(icons[0]) || attr(icons[0], 'type') !== 'image/svg+xml' || attr(icons[0], 'href') !== expected) {
    throw new Error('Expected one inline site favicon in document head');
  }
}
