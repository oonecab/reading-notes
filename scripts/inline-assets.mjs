import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'parse5';
import { walk, attr } from '../src/lib/controlled-html.mjs';

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
