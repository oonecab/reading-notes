import {parse} from 'parse5';
import {walk} from '../src/lib/controlled-html.mjs';

// Only syntax is shortened. Source text and protected byte-sensitive islands
// remain unchanged; verifyParity compares against the unmodified legacy HTML.
export function compactHtml(html) {
  const edits=[];
  for (const node of walk(parse(html,{sourceCodeLocationInfo:true}))) {
    const location=node.sourceCodeLocation;
    if (!location?.attrs || node.namespaceURI!=='http://www.w3.org/1999/xhtml') continue;
    let protectedNode=false;
    for(let p=node;p;p=p.parentNode)
      if(['pre','code','math','svg','script','style','textarea'].includes(p.tagName)) protectedNode=true;
    if(protectedNode) continue;
    for(const attr of Object.values(location.attrs)) {
      const raw=html.slice(attr.startOffset,attr.endOffset);
      const match=/^([^\s=]+)=(['"])([^]*?)\2$/.exec(raw);
      if(match && /^(?:id|class|data-[a-z0-9-]+)$/.test(match[1]) && match[3] && !/[\s"'`=<>]/u.test(match[3]))
        edits.push({start:attr.startOffset,end:attr.endOffset,value:match[1]+'='+match[3]+(html.slice(attr.endOffset,attr.endOffset+2)==='/>'?' ':'')});
    }
  }
  for(const edit of edits.sort((a,b)=>b.start-a.start))html=html.slice(0,edit.start)+edit.value+html.slice(edit.end);
  return html;
}
