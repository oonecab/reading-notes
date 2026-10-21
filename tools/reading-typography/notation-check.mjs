import assert from 'node:assert/strict';
import {parse} from 'parse5';
import {walk,attr} from '../../src/lib/controlled-html.mjs';
import {rawScript} from './math.mjs';
import {notationAliases,uprightMathNames} from './notation-policy.mjs';
const text=n=>n.nodeName==='#text'?n.value:(n.childNodes??[]).filter(c=>c.tagName!=='annotation').map(text).join('');
const ancestors=n=>n.parentNode?[n.parentNode,...ancestors(n.parentNode)]:[];
const mathUnit=n=>{
 if(n.tagName==='math'&&attr(n,'display')!=='block')return n;
 const children=(n.childNodes??[]).filter(c=>c.tagName);
 return n.tagName==='span'&&children.length===1?mathUnit(children[0]):null;
};

export function checkMathUnits(html){
 const nodes=walk(parse(html));let complete=0;
 for(const parent of nodes){
  if(['math','semantics'].includes(parent.tagName)||[parent,...ancestors(parent)].some(p=>['math','pre','code','svg','script','style','blockquote'].includes(p.tagName)||attr(p,'lang')==='en'))continue;
  let previous=false;
  for(const child of parent.childNodes??[]){
   if(child.nodeName==='#text'&&!child.value.trim())continue;
   const current=mathUnit(child);
   assert(!(previous&&current),'Adjacent mathematical fragments must form one complete expression');
   previous=Boolean(current);
  }
 }
 for(const n of nodes.filter(n=>n.tagName==='math'&&attr(n,'display')!=='block')){
  if(ancestors(n).some(p=>['pre','code','svg'].includes(p.tagName)))continue;
  complete++;
  if(text(n).length>24)assert(ancestors(n).some(p=>/(?:^|\s)(?:rn-math-inline|math-block|display-math|math-display)(?:\s|$)/.test(attr(p,'class')??'')),
   'Long inline formula needs a locally scrollable container');
 }
 return {complete_inline_math_units:complete};
}

export function checkMathNotation(html,book){
 assert(!/<\/math>\s*mod\s*\d+/.test(html),'Modulo expression split across math and prose');
 const nodes=walk(parse(html));let namedFunctions=0,formulaTokens=0;
 for(const n of nodes){
  const parents=ancestors(n);
  if(n.tagName==='math'&&!parents.some(p=>['svg','pre','code'].includes(p.tagName))){
   const label=text(n);
   // A half-open interval legitimately mixes round and square delimiters.
   // Counting both kinds together rejects split expressions without rejecting
   // [a,b), (a,b] or a parenthesized expression containing such an interval.
   assert.equal([...label].filter(c=>'(['.includes(c)).length,[...label].filter(c=>')]'.includes(c)).length,
    'Mathematical expression split at a delimiter: '+label);
  }
  if(n.tagName==='math'&&/^[A-H]$/.test(text(n))&&parents.some(p=>/^ex-/.test(attr(p,'id')??''))&&!parents.some(p=>attr(p,'lang')==='en')){
   const siblings=n.parentNode.childNodes,next=siblings[siblings.indexOf(n)+1];
   assert(!(next?.nodeName==='#text'&&/^\.\s/.test(next.value)), 'Subquestion label must use prose typography');
  }
  if(['mi','mo','mtext'].includes(n.tagName)&&text(n)==='mod'){
   const siblings=(n.parentNode.childNodes??[]).filter(c=>c.tagName),i=siblings.indexOf(n);
   const texPmod=text(siblings[i-1]??{})==='('&&siblings[i+1]?.tagName==='mspace'&&parseFloat(attr(siblings[i+1],'width'))>0;
   assert(texPmod||(n.tagName==='mo'&&['prefix','infix'].includes(attr(n,'form'))&&parseFloat(attr(n,'rspace'))>0&&(attr(n,'form')==='prefix'||parseFloat(attr(n,'lspace'))>0)),
    'Modulo operator requires explicit spacing and role');
  }
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
   if(n.tagName==='mtext')assert(!/^(?:frf|fr|rf|bta|ya|hk|ij|ii|at|ujk|ap|bp|m3|inf_n|nZ|⋊|⋉)$/.test(text(n)),'Mathematical expression stored as prose: '+text(n));
   if(n.tagName==='mi'&&/^[A-Za-z]{2,}$/.test(text(n)))assert(attr(n,'mathvariant'),'Multi-letter identifier needs an explicit role: '+text(n));
  }
  if(['msub','msup','msubsup'].includes(n.tagName)){
   const children=(n.childNodes??[]).filter(c=>c.tagName),base=children[0];
   assert(children.length===(n.tagName==='msubsup'?3:2)&&children.every(c=>text(c).trim()),'Mathematical script has an empty operand');
   assert(!(base?.tagName==='mo'&&/^[,;=_^]$/.test(text(base))),'Script attached to punctuation or relation');
  }
  if(n.nodeName!=='#text'||parents.some(p=>['math','pre','code','script','style','svg','head','title','desc','button','output'].includes(p.tagName)))continue;
  for(const m of n.value.matchAll(/\b[A-Za-z][A-Za-z0-9]*\b/g))assert(!Object.hasOwn(notationAliases[book]??{},m[0]),'Reviewed math notation left as plain prose: '+m[0]);
 }
 return{named_functions:namedFunctions,formula_tokens:formulaTokens};
}
