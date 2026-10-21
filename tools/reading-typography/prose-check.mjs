import assert from 'node:assert/strict';
import {parse} from 'parse5';
import {walk,attr} from '../../src/lib/controlled-html.mjs';

// These are prose names, titles and technical terms, not products or differences.
// A math parser must never infer their meaning from isolated Latin letters.
export const proseTerms = [
  'Randal E. Bryant', 'David R. O’Hallaron', "David R. O'Hallaron", 'Daniel P. Friedman',
  'John D. Ramsdell', 'A Programmer’s Perspective', "A Programmer's Perspective",
  'Bit-Level', 'Two’s-Complement', "Two's-Complement", 'System V', 'Mach-O',
  'guarded-do', 'do-while', 'TCP/IP', 'v-node', 'first-fit', 'next-fit',
  'Ctrl+C', 'Ctrl+D', 'Ctrl+Z', 'ELF/Linux', 'SEQ+', 'ORG+', 'ICS+', 'GOT/PLT',
  'CPS-IN', 'CPS-OUT', 'TYPED-OO', 'CALL-BY-NEED', 'i.i.d.',
  'Cramér', 'Hölder', 'Lévy', 'zig-zig', 'zig-zag', 'k-d 树', 'k-d tree',
  'UTF-8', 'SHA-256', 'FNV-64', 'TI-83', 'NAS-00-003', 'IA-32e', 'HTTP/1.x', 'application/x-www-form-urlencoded', 'subprocess.run',
  'Sec-Fetch-Site', 'Sec-Fetch-Mode', 'Sec-Fetch-Dest', 'Sec-Fetch-User',
  'Sec-CH-UA', 'Sec-CH-UA-Mobile', 'Sec-CH-UA-Platform',
  'SIGCHLD', 'SIGINT', 'SIGTSTP', 'no-write-allocate', 'R5RS',
  'word-RAM', 'top-down', 'bottom-up', 'SIAM J.', 'A famous toy', 'Rules of a group',
];
const blocks=new Set(['p','li','h1','h2','h3','h4','h5','h6','td','th','figcaption','summary']);
export function checkProseTerms(html,book) {
  let checked=0;
  assert(!/Feel\s+<code(?:\s[^>]*)?>free<\/code>\s+to|<code(?:\s[^>]*)?>Union<\/code>-Find with Constant Time Deletions/.test(html),'Natural-language phrase incorrectly marked as code');
  const nodes=walk(parse(html));
  assert(!/<\/math>x[0-9a-f]/i.test(html),'Hexadecimal literal split across math and prose');
  assert(!/<\/math>\.(?:Next|Prev)\b/.test(html),'Program member access split across math and prose');
  assert(!/<code>Fibonacci<\/code>\s*(?:堆|数|序列|队列)/.test(html),'Sequence or data structure name incorrectly marked as code');
  for(const n of nodes.filter(n=>n.tagName==='math'))
    assert(!proseTerms.some(term=>(attr(n,'aria-label')??'').replaceAll('−','-').includes(term)),'Ordinary prose incorrectly marked as math: '+attr(n,'aria-label'));
  for(const n of nodes.filter(n=>n.tagName==='math'))
    assert(!/\+\+|\^=|<<=|>>=|&&|[A-Za-z_]\w*->|^[A-Za-z_]\w*--$|^--[A-Za-z_]\w*$|\b(?:DIR|FILE|void|char|int|double|float)\s*\*/.test(attr(n,'aria-label')??''),'Program syntax incorrectly marked as math: '+attr(n,'aria-label'));
  if(book==='csapp')for(const n of nodes.filter(n=>n.tagName==='math')) {
    const label=attr(n,'aria-label')??'';
    assert(!/^-(?:S|c|Og|ll|t|v 2|pg|g|l|L|Ws|dr|r|d|Og -g)$/.test(label),'Command option incorrectly marked as math: '+label);
    if(/^\/?\s*[0-9,.+ =/]+\s+(?:[KMGTPE]i?)?B(?:\/(?:s|day))?\s*\/?$/.test(label))
      assert(!walk(n).some(x=>x.tagName==='mi'&&(x.childNodes??[]).some(c=>c.value==='B')),'Byte unit incorrectly marked as a variable: '+label);
  }
  assert(!/(?:clientrio|argv|environ|readelf|objdump)\s*<math\b/.test(html),'Program token split across prose and math');
  assert(!/[A-Za-z_]\w*<math\b[^>]*aria-label="=(?:yes|no|true|false)"/.test(html),'Program output pair split across prose and math');
  assert(!/<code>\s*(?:int(?:\d+_t)?|struct|char|void|short|long|float|double|FILE|DIR|socklen_t)\s*<\/code>\s*(?:\*|<math|[A-Za-z_]\w*\s*(?:\*|<math))/.test(html),'Program declaration split across code and prose');
  if(['weiss','csapp'].includes(book))
    assert(!/<\/code>\s*=(?!=)/.test(html),'Program assignment split across code and prose');
  if(book==='weiss')for(const n of nodes.filter(n=>n.tagName==='math')) {
    // The same name Low is also a mathematical DFS low-link value. Only
    // the sourced binary-search exercise establishes program semantics.
    let inBinarySearch=false;
    for(let p=n;p;p=p.parentNode)if(attr(p,'id')==='ex2-22')inBinarySearch=true;
    if(inBinarySearch)assert(!/\b(?:Low|Mid|High)\s*[=+]/.test(attr(n,'aria-label')??attr(n,'data-tex')??''),
      'Binary-search program statement incorrectly marked as math');
  }
  for(const block of walk(parse(html)).filter(n=>blocks.has(n.tagName))) {
    let text='',mathPositions=[];
    function visit(n,math=false){
      if(['annotation','annotation-xml','script','style','pre','code','svg'].includes(n.tagName))return;
      if(n.nodeName==='#text'){text+=n.value.replaceAll('−','-');mathPositions.push(...Array(n.value.length).fill(math));return;}
      const uprightAbbreviation=n.tagName==='mtext'&&/^(?:a\.[esu]\.)$/.test((n.childNodes??[]).map(c=>c.value??'').join(''));
      for(const child of n.childNodes??[])visit(child,uprightAbbreviation?false:math||n.tagName==='math');
    }
    visit(block);
    if(book==='csapp') {
      assert(!/\b(?:yas|yis|ssim|psim|otool)\b/.test(text),'Program tool must use code notation');
      assert(!/\/(?:usr|bin|etc|tmp|proc|var|dev|home)\//.test(text),'Program path must remain one code unit');
      assert(!/==/.test(text),'Program comparison must remain one code unit');
      for(const match of text.matchAll(/!=/g))
        assert(mathPositions[match.index]&&mathPositions[match.index+1],
          'Program comparison must remain one code unit');
      assert(!/Content-Length\s*:\s*\d+/i.test(text),'Program protocol field value must remain one code unit');
    }
    for(const match of text.matchAll(/a\.[esu]\./g))
      assert(!mathPositions.slice(match.index,match.index+match[0].length).some(Boolean),'Probability abbreviation must be whole upright text: '+match[0]);
    for(const term of proseTerms) {
      for(let start=text.indexOf(term);start!==-1;start=text.indexOf(term,start+term.length)) {
        assert(!mathPositions.slice(start,start+term.length).some(Boolean),'Ordinary prose incorrectly marked as math: '+term);
        checked++;
      }
    }
  }
  return {protected_prose_terms:checked};
}
