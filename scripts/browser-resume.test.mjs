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

test('map views need the current node inventory and completed clicks before reuse',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'map-resume-'));
 try{
  const image='book_notes_book_overview-390-top.png';fs.writeFileSync(path.join(root,image),'map pixels');
  const maps=[{title:'地图',nodes:[{kind:'chapter',number:1,href:'chapter01.html',label:'第1章',target_title:'第1章'}]}];
  const pages=[{route:'book/notes/book_overview.html',sha256:'current',map_navigation:maps}];
  const row={page:pages[0].route,width:390,code_fold:{status:'passed'}};
  const report={pages,views:[row],no_js:[],screenshots:[{file:image,sha256:createHash('sha256').update('map pixels').digest('hex')}]};
  assert.equal(resumeViews(report,pages,root,'old.json').views.length,0,'old geometry-only views must rerun');
  row.map_navigation={status:'passed',contract_signature:JSON.stringify(maps),inventory_count:1,nodes:[],keyboard:[]};
  assert.equal(resumeViews(report,pages,root,'old.json').views.length,0,'zero clicks cannot cover a nonempty map');
  const expected={...maps[0].nodes[0],url:'file:///book/notes/chapter01.html'};
  const landing={url:expected.url,title:'第1章',ready:true,visible:true,top:130,bottom:160,blocker_bottom:110,viewport:950,viewport_width:390,width:375};
  row.map_navigation.nodes=[{activation:{horizontal_scroll:false},source:{href:expected.href,label:expected.label},expected,landing}];
  row.map_navigation.keyboard=[{index:0,landing}];row.map_navigation.same_fragment=[];
  assert.equal(resumeViews(report,pages,root,'old.json').views.length,1);
  row.map_navigation.nodes[0].landing={...landing,top:1200,bottom:1230};
  assert.equal(resumeViews(report,pages,root,'old.json').views.length,0,'URL-only landing cannot be reused');
  row.map_navigation.nodes[0].landing=landing;row.map_navigation.contract_signature='stale policy';
  assert.equal(resumeViews(report,pages,root,'old.json').views.length,0);
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
