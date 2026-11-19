import { parse } from 'parse5';
import { pathToFileURL } from 'node:url';
import { attr, entries, walk } from '../../src/lib/controlled-html.mjs';

const excluded = new Set('code pre math svg script style textarea'.split(' '));

// Lexical exceptions cover a single span. A later call or instruction in the
// same sentence is still checked. Program input with an operator is code.
const allowedSpans = [
  {pattern: /\(or equivalently(?=,|\))/gi, reason: 'English restatement introducing an alternative definition'},
  {pattern: /\((?:or nonoccurrence|and vice versa|and instructors)\)/gi, reason: 'Parenthetical English prose, not Scheme applications'},
  {pattern: /\bclang \d+(?:\.\d+)+\b/g, reason: 'Compiler version in experiment metadata'},
  {pattern: /\b(?:make sure|gcc compiler|node of)\b/gi, reason: 'Ordinary English phrases'},
  {proseOnly: true, pattern: /\(\d+(?: +\d+)+\)/g, reason: 'A numeric tuple or a literal list is not a procedure call'},
  {proseOnly: true, pattern: /'\([a-z]+(?: [a-z]+)*\)/g, reason: 'Quoted flat symbol data has no evaluated operator'},
];
const scheme = /\(\s*(?:define|lambda|let\*?|letrec|cond|if|map|cons|c[ad]{1,4}r|list|append|reverse|null\?|pair\?|set!|begin|quote|and|or|not|display|newline|apply|eval|force|delay|call\/cc|letcc|error|assert|stream-car|cons-stream|filter|accumulate|fold-right|fold-left|for-each)(?=[\s()])/g;
const c = /#\s*include\b|\b(?:printf|malloc|sizeof)\s*\(|\bstruct\s+[A-Za-z_]\w*|\bint\s+main\b/g;
const assembly = /\b(?:movq|movl|pushq|popq|leaq|cmpq|jne|je|jmp|ret|callq)\b|\bpush(?=\/ret\b)/g;
const python = /\bdef\s+[A-Za-z_]\w*\s*\(|\bclass\s+[A-Za-z_]\w*\s*[:(]|\bimport\s+[A-Za-z_]\w*|\bprint\s*\(/g;
const command = /\b(?:clang|gcc|make|racket|python|node|pnpm|git)[ \t]+(?:"[^"\n]+"|'[^'\n]+'|[\w./\\:@-]+)/g;
const subcommands = {
  git: /^(?:add|branch|checkout|clone|commit|diff|fetch|init|log|merge|pull|push|rebase|remote|restore|show|status|switch|tag)$/,
  pnpm: /^(?:add|build|dev|dlx|exec|install|lint|remove|run|start|test|update)$/,
  make: /^(?:all|build|check|clean|install|test)$/,
};

function commandHasArgument(invocation) {
  const [, name, raw] = invocation.match(/^(\w+)\s+(.+)$/);
  const argument = raw.replace(/^['"]/, '');
  return /^[-./\\]|[/\\]|\.\w+/.test(argument) || subcommands[name]?.test(argument);
}

const labelText = node => node?.value ?? (node?.childNodes ?? []).map(labelText).join('');
const codeTableLabel = /表达式|引用(?:的两层|形式|简写)|(?:求值|返回|运行|输出)结果|参数与结果|程序(?:片段|输入|输出|代码)|^(?:程序|结果)(?:表|示例)?$|\b(?:expressions?|quotations?|evaluation results?|program (?:output|fragments?))\b|^(?:programs?|results?)(?: table)?$/i;
const tableToken = /'+[A-Za-z][\w?!-]*|\([^()]*\)|(?<![\w-])[A-Za-z][\w-]*(?:[?!])?(?![\w-])/g;

export function scanProse(html) {
  const document = parse(html, {sourceCodeLocationInfo:true});
  const ids = new Map(walk(document).filter(n => attr(n,'id')).map(n => [attr(n,'id'),n]));
  function isCodeTable(table) {
    const refs = ['aria-labelledby','aria-describedby'].flatMap(k => (attr(table,k) ?? '').split(/\s+/));
    const labels = [
      attr(table, 'aria-label'), attr(table, 'summary'),
      labelText(table.childNodes.find(n => n.tagName === 'caption')),
      ...refs.map(id => labelText(ids.get(id))),
    ];
    if (table.parentNode?.tagName === 'figure') {
      labels.push(labelText(table.parentNode.childNodes.find(n => n.tagName === 'figcaption')));
    }
    return labels.some(label => label && codeTableLabel.test(label));
  }
  const hits = [];
  function visit(node, anchor, codeTable = false, cell = false) {
    if (excluded.has(node.tagName)) return;
    anchor = attr(node, 'id') ?? anchor;
    if (node.tagName === 'table') {
      codeTable = isCodeTable(node);
      cell = false;
    }
    if (node.tagName === 'td' || node.tagName === 'th') cell = codeTable;
    if (node.nodeName === '#text') {
      const value = node.value;
      const exceptions = allowedSpans.filter(entry => !cell || !entry.proseOnly).flatMap(({pattern}) =>
        Array.from(value.matchAll(pattern), m => [m.index, m.index + m[0].length]));
      const rules = cell ? [tableToken, c, assembly, python, command] : [scheme, c, assembly, python, command];
      for (const rule of rules) {
        for (const match of value.matchAll(rule)) {
          const start = match.index, end = start + match[0].length;
          if (exceptions.some(([a,b]) => a <= start && end <= b)) continue;
          // In a sentence of English prose, spaces alone do not identify variable names.
          if (rule === tableToken && node.parentNode.tagName === 'th' && /^(?:expression|result|program|step|input|output)s?$/i.test(value.trim())) continue;
          if (rule === tableToken && /^[A-Za-z]/.test(match[0]) && value.trim() !== match[0] &&
              !/[\p{Script=Han}'()]/u.test(value)) continue;
          if (rule === command && !commandHasArgument(match[0])) continue;
          const location = node.sourceCodeLocation;
          hits.push({anchor, line: location.startLine + value.slice(0,start).split('\n').length - 1, token: match[0]});
        }
      }
    }
    for (const child of node.childNodes ?? []) visit(child, anchor, codeTable, cell);
  }
  visit(document, '');
  return hits;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const pages = entries();
  if (!pages.length) throw new Error('Empty reading page inventory');
  let count = 0;
  for (const {html, metadata} of pages) {
    for (const hit of scanProse(html)) {
      console.error(metadata.route+'#'+hit.anchor+' line '+hit.line+' '+hit.token);
      count++;
    }
  }
  console.log(pages.length+' pages, '+count+' bare code tokens');
  if (count) process.exitCode = 1;
}
