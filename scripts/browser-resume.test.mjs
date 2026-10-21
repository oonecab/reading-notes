import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {resumeViews} from './browser-resume.mjs';

test('resume rejects stale HTML, partial views and modified evidence',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'reader-resume-'));
 try{
  const image='book_notes_ch-390-top.png';fs.writeFileSync(path.join(root,image),'pixels');
  const pages=[{route:'book/notes/ch.html',sha256:'current'}];
  const report={pages,views:[{page:pages[0].route,width:390,code_fold:{status:'passed'}},{page:pages[0].route,width:1440}],screenshots:[{file:image,sha256:createHash('sha256').update('pixels').digest('hex')}],no_js:[]};
  const reused=resumeViews(report,pages,root,'old/report.json');assert.equal(reused.views.length,1);assert.equal(reused.origins[0].report,'old/report.json');
  const solution={...report,views:[{...report.views[0],state:{exercises:['ex-1']}}]};
  assert.equal(resumeViews(solution,pages,root,'old/report.json').views.length,0);
  solution.views[0].solution_view={exercise:'ex-1',text_length:100};
  assert.equal(resumeViews(solution,pages,root,'old/report.json').views.length,1);
  const readingPages=[{...pages[0],reader_policy:{sections:[]}}];
  assert.equal(resumeViews(solution,readingPages,root,'old/report.json').views.length,0);
  solution.views[0].expanded_layout={all_open:true,width:390,viewport:390};
  assert.equal(resumeViews(solution,readingPages,root,'old/report.json').views.length,1);
  assert.equal(resumeViews(report,[{...pages[0],sha256:'changed'}],root,'old/report.json').views.length,0);
  fs.writeFileSync(path.join(root,image),'changed');assert.throws(()=>resumeViews(report,pages,root,'old/report.json'),/screenshot changed/);
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
