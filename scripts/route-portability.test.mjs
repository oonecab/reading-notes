import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {cspManifest} from './csp-lib.mjs';
import {checkBudgets} from './performance-budget.mjs';
import {validateInternalAnchors} from './parity-lib.mjs';

test('CSP routes use URL separators and feed the anchor checker', () => {
  fs.mkdirSync('tmp/route-tests',{recursive:true});
  const root=fs.mkdtempSync(path.resolve('tmp/route-tests/nested-'));
  try {
    fs.mkdirSync(path.join(root,'book','notes'),{recursive:true});
    fs.writeFileSync(path.join(root,'book','notes','index.html'),'<h1 id="top">Title</h1><a href="#top">Top</a>');
    const manifest=cspManifest(root);
    assert.deepEqual(Object.keys(manifest.files),['book/notes/index.html']);
    const pages=new Map(Object.keys(manifest.files).map(route=>[route,fs.readFileSync(path.join(root,route),'utf8')]));
    assert.doesNotThrow(()=>validateInternalAnchors(pages));
    assert.throws(()=>validateInternalAnchors(new Map([['book/notes/index.html','<a href="#missing">Bad</a>']])),/Missing internal anchor/);
  } finally { fs.rmSync(root,{recursive:true,force:true}); }
});
test('nested page-specific budgets are applied on the host platform', () => {
  fs.mkdirSync('tmp/route-tests',{recursive:true});
  const root=fs.mkdtempSync(path.resolve('tmp/route-tests/budget-'));
  try {
    fs.mkdirSync(path.join(root,'book'));fs.writeFileSync(path.join(root,'book','index.html'),'<p>Too large</p>');
    assert.throws(()=>checkBudgets(root,{default:{html_bytes:10000},pages:{'book/index.html':{html_bytes:1}}}),/Performance budget exceeded/);
  } finally { fs.rmSync(root,{recursive:true,force:true}); }
});
