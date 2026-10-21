import assert from 'node:assert/strict';
import {parse} from 'parse5';
import {walk,attr} from '../../src/lib/controlled-html.mjs';
import {rawScript} from './math.mjs';
import {notationAliases,uprightMathNames} from './notation-policy.mjs';
const text=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).filter(c=>c.tagName!=='annotation').map(text).join('');
const ancestors=n=>n.parentNode?[n.parentNode,...ancestors(n.parentNode)]:[];

export function checkMathNotation(html,book){
 const nodes=walk(parse(html));let namedFunctions=0,formulaTokens=0;
 for(const n of nodes){
  const parents=ancestors(n);
  if(n.tagName==='math'&&book==='stochastic'&&['Δn','WN=VN'].includes(attr(n,'aria-label'))){
   assert(walk(n).some(c=>c.tagName==='msub'),'Indexed holdings/payoff flattened into a product');
  }
  if(n.tagName==='math'&&book==='measure-probability'&&attr(n,'aria-label')==='b=E[X²1A]'){
   assert(walk(n).some(c=>c.tagName==='msub'),'Indicator set must be a subscript');
  }
  if(n.tagName==='code'&&!parents.some(p=>p.tagName==='pre')){
   const siblings=n.parentNode.childNodes,next=siblings[siblings.indexOf(n)+1];
   assert(!(next?.nodeName==='#text'&&/^\.(?:py|c|h|html|json|md|sh|mjs|js)\b/.test(next.value)),
    'Filename extension split from inline code');
  }
  if(n.tagName==='mi'&&uprightMathNames.has(text(n))){
   assert.equal(attr(n,'mathvariant'),'normal','Named function must be upright: '+text(n));namedFunctions++;
  }
  if(['mi','mo','mn','mtext'].includes(n.tagName)){
   formulaTokens++;
   assert(!rawScript.test(text(n)),'Detached Unicode script in MathML: '+text(n));
   assert(!/\\[A-Za-z]+/.test(text(n)),'Unconverted TeX in MathML: '+text(n));
   if(['mi','mo'].includes(n.tagName))assert(!/^[_^]$/.test(text(n))||(text(n)==='^'&&n.parentNode.tagName==='mover'),'Detached TeX script marker');
   if(n.tagName==='mtext')assert(!/^(?:frf|fr|rf|bta|ya|hk|ij|ii|at|ujk|ap|bp|m3|inf_n|nZ)$/.test(text(n)),'Mathematical expression stored as prose: '+text(n));
   if(n.tagName==='mi'&&/^[A-Za-z]{2,}$/.test(text(n)))assert(attr(n,'mathvariant'),'Multi-letter identifier needs an explicit role: '+text(n));
  }
  if(['msub','msup','msubsup'].includes(n.tagName)){
   const children=(n.childNodes??[]).filter(c=>c.tagName),base=children[0];
   assert(!(base?.tagName==='mo'&&/^[,;=_^]$/.test(text(base))),'Script attached to punctuation or relation');
  }
  if(n.nodeName!=='#text'||parents.some(p=>['math','pre','code','script','style','svg','head','title','desc','button','output'].includes(p.tagName)))continue;
  for(const m of n.value.matchAll(/\b[A-Za-z][A-Za-z0-9]*\b/g))assert(!Object.hasOwn(notationAliases[book]??{},m[0]),'Reviewed math notation left as plain prose: '+m[0]);
 }
 return{named_functions:namedFunctions,formula_tokens:formulaTokens};
}
