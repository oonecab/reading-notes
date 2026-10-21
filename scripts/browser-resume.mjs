import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

// Only completed views of byte-identical HTML are reusable. Failed and partial
// attempts remain immutable, and every reused image retains its original path.
export function resumeViews(report, pages, root, reportFile) {
  assert(!(report.external_requests??[]).length,'Cannot reuse an attempt with external requests');
  const oldPages=new Map((report.pages??[]).map(p=>[p.route,p]));
  const current=new Map(pages.map(p=>[p.route,p]));
  const result={views:[],no_js:[],screenshots:[],origins:[]};
  const images=new Map((report.screenshots??[]).map(i=>[i.file,i]));
  for(const kind of ['views','no_js'])for(const row of report[kind]??[]){
    const page=current.get(row.page),previous=oldPages.get(row.page);
    if(!page||page.redirect_file||page.sha256!==previous?.sha256||!Object.hasOwn(row,'code_fold'))continue;
    if(page.reader_policy&&row.width===390&&!row.expanded_layout)continue;
    if(kind==='views'&&[1800,390].includes(row.width)&&row.state?.exercises?.length&&!row.solution_view)continue;
    const stem=row.page.replaceAll('/','_').replace('.html','');
    const prefix=kind==='views'?stem+'-'+row.width+'-':stem+'-no-js-'+row.width;
    const shots=[...images.values()].filter(i=>path.basename(i.file).startsWith(prefix));
    if(!shots.length)continue;
    for(const shot of shots){
      const absolute=path.resolve(root,shot.file);
      assert(absolute.startsWith(path.resolve(root)+path.sep),'Screenshot outside workspace');
      assert.equal(createHash('sha256').update(fs.readFileSync(absolute)).digest('hex'),shot.sha256,'Reused screenshot changed');
    }
    result[kind].push(row);result.screenshots.push(...shots);
    result.origins.push({kind,page:row.page,width:row.width,html_sha256:page.sha256,report:reportFile});
  }
  result.screenshots=[...new Map(result.screenshots.map(s=>[s.file,s])).values()];
  return result;
}
