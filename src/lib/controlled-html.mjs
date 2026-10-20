import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'parse5';

export const root = process.cwd();
export const stage = path.join(root, 'tmp/reading-notes-migration');
export function walk(node) {
  return [node, ...(node.content?.childNodes ?? node.childNodes ?? []).flatMap(walk)];
}
export function attr(node, name) { return node.attrs?.find(a => a.name === name)?.value; }
export function sharedAsset(name, base=root, stack=[]) {
  if (!/^(styles\/[a-z0-9-]+\.css|scripts\/[a-z0-9-]+\.js)$/.test(name)) {
    throw new Error('Invalid shared asset');
  }
  if (stack.includes(name)) throw new Error('Circular shared stylesheet: ' + name);
  const content = fs.readFileSync(path.join(base, 'src', name), 'utf8');
  if (!name.startsWith('styles/')) return content;
  const expanded = content.replace(/\/\* RN:include ([^*]+) \*\//g, (_, child) => {
    if (!/^styles\/[a-z0-9-]+\.css$/.test(child)) throw new Error('Stylesheet may only include styles');
    return sharedAsset(child, base, [...stack, name]);
  });
  if (expanded.includes('RN:include')) throw new Error('Unexpanded stylesheet include');
  return expanded;
}
export function readSource(filename, base=root) {
  const source = fs.readFileSync(filename, 'utf8');
  const match = source.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) throw new Error(`Missing controlled JSON frontmatter: ${filename}`);
  const metadata = JSON.parse(match[1]);
  for (const key of ['book', 'chapter', 'title', 'printed_start', 'printed_end', 'pdf_start', 'pdf_end', 'exercise_range', 'statement_count', 'source_manifest']) {
    if (!(key in metadata)) throw new Error(`Missing ${key}: ${filename}`);
  }
  const html = source.slice(match[0].length).replace(/<!-- RN:include ([\w/.-]+) -->/g, (_, name) => {
    return sharedAsset(name, base);
  });
  return { metadata, html, filename };
}
export function entries(base=root) {
  const state = JSON.parse(fs.readFileSync(path.join(base, 'scripts/migration-state.json'), 'utf8'));
  const modeFile=path.join(base,'tmp/reading-notes-migration/build-state.json');
  const mode = fs.existsSync(modeFile)?JSON.parse(fs.readFileSync(modeFile, 'utf8')):{shell:false};
  if (mode.shell) return [];
  const catalog=JSON.parse(fs.readFileSync(path.join(base,'books/catalog.json'),'utf8')).books;
  return state.migrated_books.flatMap(book => {
    const directory = path.join(base, 'src/content/books', book);
    const registered=catalog.find(b=>b.id===book);
    if(!registered)throw new Error('Unregistered book: '+book);
    const filenames=fs.readdirSync(directory).filter(f=>f.endsWith('.html')).sort();
    if(filenames.length!==registered.expected_pages)throw new Error('Controlled source inventory differs: '+book);
    return filenames.map(file=>{
      const entry=readSource(path.join(directory,file),base);
      if(entry.metadata.book!==book||entry.metadata.route!==registered.publish_prefix+'/notes/'+file||entry.metadata.legacy_path!==registered.directory+'/notes/'+file)throw new Error('Controlled route differs: '+file);
      return entry;
    });
  });
}

export function syncMirrors(pages, {write=false,base=root}={}) {
  for(const {metadata,html} of pages){
    const file=path.join(base,metadata.legacy_path);
    const current=fs.existsSync(file)?fs.readFileSync(file,'utf8'):null;
    if(current!==html){
      if(!write)throw new Error('Compatibility mirror differs: '+metadata.legacy_path);
      fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,html);
    }
  }
}

// Locations preserve the reviewed bytes, including MathML and SVG namespaces.
// Components own semantic boundaries; the HTML parser is never used to rewrite them.
export function segments(html) {
  const tree = parse(html, { sourceCodeLocationInfo: true });
  const result = [];
  function inspect(node) {
    const classes = (attr(node, 'class') ?? '').split(/\s+/);
    const type = node.tagName === 'header' ? 'Header'
      : classes.includes('chapter-sidebar') ? 'Toc'
      : classes.includes('annotation-sidebar') ? 'AnnotationRail'
      : classes.includes('chapter-nav') ? 'ChapterNav'
      : classes.includes('exercise') ? 'Exercise'
      : classes.includes('code-pair') ? 'CodePair'
      : node.tagName === 'figure' ? 'Figure'
      : node.tagName === 'math' ? 'MathBlock' : null;
    const loc = node.sourceCodeLocation;
    if (type && loc && loc.endOffset > loc.startOffset) result.push({ type, start: loc.startOffset, end: loc.endOffset });
    else for (const child of node.childNodes ?? []) inspect(child);
  }
  inspect(tree);
  const parts = []; let offset = 0;
  for (const item of result.sort((a,b) => a.start-b.start)) {
    if (item.start < offset) throw new Error('Overlapping controlled fragments');
    if (item.start > offset) parts.push({type: 'Raw', html: html.slice(offset, item.start)});
    parts.push({type: item.type, html: html.slice(item.start, item.end)}); offset = item.end;
  }
  if (offset < html.length) parts.push({type: 'Raw', html: html.slice(offset)});
  return parts;
}
