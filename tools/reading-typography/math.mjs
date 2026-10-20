// Authoring-time helpers. Published pages contain native MathML / SVG only.
// They do not load a TeX engine, a font service, or this module.
export const escape = value => value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const subFrom = '₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₒₓₕₖₗₘₙₚₛₜᵢⱼᵣᵤᵥ';
const subTo =   '0123456789+−=()aeoxhklmnpstijruv';
const superFrom = '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱᵃᵇᶜᵈᵉᶠᵍʰʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣʸᶻ';
const superTo =   '0123456789+−=()niabcdefghjklmoprstuvwxyz';
const scripts = new Map([...subFrom].map((c,i)=>[c,{kind:'sub',text:subTo[i]}]).concat([...superFrom].map((c,i)=>[c,{kind:'sup',text:superTo[i]}])));
for(const c of 'ᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿᵀᵁⱽᵂ')scripts.set(c,{kind:'sup',text:c.normalize('NFKC')});
export const rawScript = new RegExp(`[${[...scripts.keys()].join('')}]`, 'u');
const functions = new Set('log ln exp sin cos tan cot sec csc sinh cosh tanh lim sup inf max min mod gcd lcm det dim rank ker Ker im Im sgn Sym Gal Aut Hom End GL SL SO SU O Pr Var Cov E P Re Im diag trace tr span CF ZF SF OF'.split(' '));
const ordinary = new Set('the and for not in of to is as or if at on an by be so int let def all new get set end sub add mul xor pop mov cmp ret out bit map was has can any one two ten die its are may but you our via use per sum CPU PDF EOF TCP UDP GET PUT URL URI API AST SSA CPS LET'.split(' '));
const operator = /^[+\-−=<>≤≥≠≈≡≅≃∼∝±∓×÷·⋅*/\\∕∈∉∋⊂⊆⊃⊇⊊⊋∪∩∅∞↦→←↔⇒⇐⇔∘√∣|∧∨¬∀∃∑Σ∏∫∮∂∇!%:;,′″‴⋯…⊕⊗⊙◁▷⊲⊳⊥∥∤∴∵≔≜≪≫⌊⌋⌈⌉()[\]{}⟨⟩〈〉]$/u;
const atom = (tag,value,attrs='')=>`<${tag}${attrs}>${escape(value)}</${tag}>`;
const row = parts=>parts.length===1?parts[0]:`<mrow>${parts.join('')}</mrow>`;

// Keep words, filenames, paths and program identifiers out of mathematical runs.
// ASCII ^ / _ are interpreted only by this authoring function, never inside code.
function lex(text) {
  const result=[];
  for(let i=0;i<text.length;){
    const rest=text.slice(i);let m;
    if((m=rest.match(/^\s+/))){result.push({kind:'space',raw:m[0]});i+=m[0].length;continue;}
    if((m=rest.match(/^(?:pp?\.\s*(?:\d+(?:[–−-]\d+)?|[ivxlcdm]+)|[A-Z]\.\d+(?:\.\d+)*|C\/Python|I\/O)\b/i))||
       (!text.slice(0,i).trim()&&(m=rest.match(/^(?:\([a-z]\)|[a-z]\.)\s+/)))){
      result.push({kind:'word',raw:m[0]});i+=m[0].length;continue;
    }
    if((m=rest.match(/^(?:https?:\/\/[^\s\u3000-\u9fff]+|[\w./-]+\.(?:py|c|h|html|json|md|pdf|svg|png|css|js|mjs|zip|csv|tsv)\b)/))){
      result.push({kind:'word',raw:m[0]});i+=m[0].length;continue;
    }
    if(scripts.has(text[i])){
      const kind=scripts.get(text[i]).kind;let raw='',value='';
      while(i<text.length&&scripts.get(text[i])?.kind===kind){raw+=text[i];value+=scripts.get(text[i++]).text;}
      result.push({kind,raw,value});continue;
    }
    if(['\u0304','\u0305','\u0302','\u0303'].includes(text[i])){
      result.push({kind:'accent',raw:text[i],value:{'\u0304':'¯','\u0305':'¯','\u0302':'ˆ','\u0303':'~'}[text[i++]]});continue;
    }
    if((m=rest.match(/^(?:\d+(?:\.\d+)?(?:[eE][+−-]?\d+)?)/))){
      result.push({kind:'number',raw:m[0]});i+=m[0].length;continue;
    }
    if((m=rest.match(/^[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)*/))){
      const value=m[0];
      const singleSub=value.match(/^([A-Za-z])_([A-Za-z0-9]+)$/);
      if(singleSub){
        result.push({kind:'identifier',raw:singleSub[1]},{kind:'sub',raw:'_'+singleSub[2],value:singleSub[2]});
      }else {
        const adjacent=/^[()[\]{}+\-−=<>≤≥≠≈≡∈×*/^⁰-ⁿ₀-ₜ]/u.test(rest.slice(value.length))||/[()[\]{}+\-−=<>≤≥≠≈≡∈×*/^]$/.test(text.slice(0,i));
        const kind=value.length===1?'identifier':functions.has(value)?'function':/^[A-Za-z]{2,3}$/.test(value)&&!ordinary.has(value)&&adjacent?'product':'word';
        if(kind==='product')result.push(...[...value].map(c=>({kind:'identifier',raw:c})));
        else result.push({kind,raw:value});
      }
      i+=value.length;continue;
    }
    if(/[Α-ωϑϕϖϵϱℓℝℤℕℚℂℙ𝔼ℱℋ]/u.test(text[i])){
      result.push({kind:'identifier',raw:text[i]});i++;continue;
    }
    if((text[i]==='_'&&(['{','('].includes(text[i+1])||
       (result.at(-1)?.kind==='identifier'&&/^_[A-Za-z0-9](?![A-Za-z0-9_])/.test(rest))))||text[i]==='^'){
      result.push({kind:text[i]==='_'?'submark':'supmark',raw:text[i++]});continue;
    }
    if(operator.test(text[i])){
      result.push({kind:'operator',raw:text[i++]});continue;
    }
    result.push({kind:'word',raw:text[i++]});
  }
  return result;
}

export function presentation(text) {
  // Presentation-only parser: parentheses remain visible; it never reorders terms.
  const tokens=lex(text).filter(t=>t.kind!=='space');let pos=0;
  function sequence(stop) {
    const out=[];
    while(pos<tokens.length&&tokens[pos].raw!==stop)out.push(unit());
    return out;
  }
  function unit(){
    const t=tokens[pos++];let base;
    const pairedBar=['|','∣'].includes(t.raw)&&tokens.slice(pos).some(n=>n.raw===t.raw);
    if(['(','[','{'].includes(t.raw)||pairedBar){
      const closing=pairedBar?t.raw:{'(':')','[':']','{':'}'}[t.raw],inside=sequence(closing);
      const end=tokens[pos]?.raw===closing?tokens[pos++].raw:'';
      base=row([atom('mo',t.raw),...inside,...(end?[atom('mo',end)]:[])]);
    }else if(t.raw==='√'&&tokens[pos]&&!['=',',',';'].includes(tokens[pos].raw)){
      base='<msqrt>'+unit()+'</msqrt>';
    }else if(t.kind==='number')base=atom('mn',t.raw);
    else if(t.kind==='identifier')base=atom('mi',t.raw);
    else if(t.kind==='function')base=atom('mi',t.raw,' mathvariant="normal"');
    else if(t.kind==='word')base=atom('mtext',t.raw);
    else base=atom('mo',t.raw==='-'?'−':t.raw==='\\'?'∖':t.raw);
    while(tokens[pos]?.kind==='accent')base='<mover accent="true">'+base+atom('mo',tokens[pos++].value)+'</mover>';
    let sub=null,sup=null;
    while(pos<tokens.length&&['sub','sup','submark','supmark'].includes(tokens[pos].kind)){
      const script=tokens[pos++];let markup;
      if(script.value!==undefined)markup=presentation(script.value);
      else if(['{','('].includes(tokens[pos]?.raw)){
        const closing=tokens[pos++].raw==='{'?'}':')';
        markup=row(sequence(closing));if(tokens[pos]?.raw===closing)pos++;
      }else if(tokens[pos])markup=unit();
      else throw new Error('Missing script argument: '+text);
      if(script.kind.startsWith('sub'))sub=markup;else sup=markup;
    }
    if(sub&&sup)return `<msubsup>${base}${sub}${sup}</msubsup>`;
    if(sub)return `<msub>${base}${sub}</msub>`;
    if(sup)return `<msup>${base}${sup}</msup>`;
    return base;
  }
  return row(sequence(null));
}

export function math(text,{annotation=false}={}) {
  const body=presentation(text);
  return `<math xmlns="http://www.w3.org/1998/Math/MathML" aria-label="${escape(text)}" display="inline">${annotation?`<semantics>${body}<annotation encoding="text/plain">${escape(text)}</annotation></semantics>`:body}</math>`;
}

export function prose(text,{annotation=false,singles=true}={}) {
  const tokens=lex(text),changes=[];let html='',run=[];
  function flush(){
    if(!run.length)return;
    const raw=run.map(t=>t.raw).join(''),trimmed=raw.trim();
    const core=run.filter(t=>t.kind!=='space');
    const signal=core.some(t=>['sub','sup','submark','supmark','accent'].includes(t.kind)||/[Α-ωℓℝℤℕℚℂℙ∈∉⊂⊆⊃⊇∪∩∅∞≤≥≠≈≡↦∘√∑∏∫±×∣∧∨¬⊕]/u.test(t.raw));
    const relation=core.some(t=>t.kind==='operator'&&/[=<>+−*/]/.test(t.raw));
    const variable=core.some(t=>t.kind==='identifier'||t.kind==='product');
    const fn=core.some(t=>t.kind==='function')&&core.some(t=>t.raw==='(');
    // Plain numbers, page ranges and punctuation remain ordinary prose.
    const numericEquation=/\d\s*[+*/=]\s*\d/.test(trimmed);
    const qualifies=signal||fn||(variable&&(singles||relation)&&trimmed!=='C')||numericEquation;
    if(qualifies&&trimmed){
      // Keep prose delimiters outside math. A bracket is retained if paired here.
      let start=0,end=raw.length;
      while(start<end&&/[\s,;:]/.test(raw[start]))start++;
      while(end>start&&/[\s,;:]/.test(raw[end-1]))end--;
      let value=raw.slice(start,end);
      if(value&&value!==','&&value!==';'){
        html+=escape(raw.slice(0,start))+math(value,{annotation})+escape(raw.slice(end));
        changes.push(value);
      }else html+=escape(raw);
    }else html+=escape(raw);
    run=[];
  }
  for(const t of tokens){if(t.kind==='word'){flush();html+=escape(t.raw);}else run.push(t);}
  flush();return {html,changes};
}

export function svgScripts(text) {
  let html='',plain='',kind=null,part='';
  const flush=()=>{
    if(plain){html+=escape(plain);plain='';}
    if(part){html+=`<tspan baseline-shift="${kind==='sub'?'sub':'super'}" font-size="70%">${escape(part)}</tspan>`;part='';}
  };
  for(const c of text){
    const s=scripts.get(c);
    if(s){if(kind!==s.kind){flush();kind=s.kind;}else if(plain)flush();part+=s.text;}
    else{flush();kind=null;plain+=c;}
  }
  flush();return html;
}
