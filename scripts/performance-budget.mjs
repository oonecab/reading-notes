import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {gzipSync} from 'node:zlib';
import {parse} from 'parse5';
import {htmlFiles} from './inline-assets.mjs';

export function measure(html){
  let elements=0,js_bytes=0;
  function visit(n){
    if(n.tagName)elements++;
    if(n.tagName==='script')js_bytes+=Buffer.byteLength((n.childNodes??[]).map(x=>x.value??'').join(''));
    for(const c of n.childNodes??[])visit(c);
    for(const c of n.content?.childNodes??[])visit(c);
  }
  visit(parse(html));
  return {html_bytes:Buffer.byteLength(html),gzip_bytes:gzipSync(html,{level:6}).length,elements,js_bytes};
}
export function checkBudgets(directory,policy=JSON.parse(fs.readFileSync('scripts/performance-budgets.json'))){
  const records=htmlFiles(directory).map(file=>{
    const route=path.relative(directory,file),metrics=measure(fs.readFileSync(file,'utf8'));
    const budget={...policy.default,...policy.pages[route]};
    for(const [metric,limit] of Object.entries(budget))if(metrics[metric]>limit)throw new Error(`Performance budget exceeded: ${route} ${metric}=${metrics[metric]} > ${limit}`);
    return {route,...metrics};
  });
  return {status:'passed',scope:'deterministic size/DOM budgets; browser timings are measured separately',records};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const report=checkBudgets(path.resolve(process.argv[2]??'dist'));
 fs.mkdirSync('tmp/i035',{recursive:true});fs.writeFileSync('tmp/i035/performance-budget.json',JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,pages:report.records.length}));
}
