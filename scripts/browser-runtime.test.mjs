import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {atomicJson, createRun, finishRun, selectSpace, openSpace, acquireSession, readTarget, exerciseTargets} from './browser-runtime.mjs';

function fixture(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rn-browser-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return dir;}

test('failed and incomplete attempts preserve the previous success and its screenshot',t=>{
  const output=fixture(t), first=createRun(output);
  fs.writeFileSync(path.join(first.output,'screen.png'),'first screenshot');
  finishRun(first,{status:'passed',screenshots:['screen.png']});
  const previous=fs.readFileSync(path.join(output,'report.json'));
  const second=createRun(output);
  atomicJson(path.join(second.output,'report.json'),{status:'running'});
  assert.deepEqual(fs.readFileSync(path.join(output,'report.json')),previous);
  finishRun(second,{status:'failed',errors:['injected failure']});
  assert.deepEqual(fs.readFileSync(path.join(output,'report.json')),previous);
  assert.equal(fs.readFileSync(path.join(first.output,'screen.png'),'utf8'),'first screenshot');
  assert.equal(JSON.parse(fs.readFileSync(path.join(output,'latest-attempt.json'))).status,'failed');
  assert.notEqual(first.output,second.output);
  assert.equal(fs.readdirSync(second.output).some(p=>p.endsWith('.tmp')),false);
});

test('an interrupted atomic replacement leaves valid previous JSON and removes its temporary',t=>{
  const filename=path.join(fixture(t),'report.json');atomicJson(filename,{status:'passed'});
  t.mock.method(fs,'renameSync',()=>{throw new Error('injected rename failure');});
  assert.throws(()=>atomicJson(filename,{status:'failed'}),/injected/);
  assert.deepEqual(JSON.parse(fs.readFileSync(filename)),{status:'passed'});
  assert.deepEqual(fs.readdirSync(path.dirname(filename)),['report.json']);
});

test('failure writing the attempt index cannot replace the successful report',t=>{
  const base=fixture(t),first=createRun(base);finishRun(first,{status:'passed'});
  const before=fs.readFileSync(path.join(base,'report.json')),second=createRun(base),rename=fs.renameSync;
  t.mock.method(fs,'renameSync',(from,to)=>{
    if(to===path.join(base,'latest-attempt.json'))throw new Error('injected index failure');
    return rename(from,to);
  });
  assert.throws(()=>finishRun(second,{status:'passed'}),/injected index failure/);
  assert.deepEqual(fs.readFileSync(path.join(base,'report.json')),before);
});

test('only an exact missing cached space can create a replacement',async()=>{
  const calls=[], taskSpace=async id=>{calls.push(id);if(typeof id==='number')throw new Error('task space not found: 25');return {spaceId:26};};
  assert.equal((await openSpace(taskSpace,selectSpace(undefined,{spaceId:25}))).spaceId,26);
  assert.deepEqual(calls,[25,'Reading Notes 浏览器验收']);
  await assert.rejects(openSpace(taskSpace,selectSpace('25',{})),/task space not found/);
  for(const message of ['space inactive','user has control','permission denied','timeout','task space not found: 99']){
    let count=0;
    await assert.rejects(openSpace(async()=>{count++;throw new Error(message);},selectSpace(undefined,{spaceId:25})));
    assert.equal(count,1);
  }
  for(const value of ['','name','-1','1.2','1e2',' 26','9007199254740992'])assert.throws(()=>selectSpace(value,{}),/positive integer/);
  assert.deepEqual(selectSpace('26',{spaceId:25}),{spaceId:26,explicit:true});
});

test('session lease refuses concurrent drivers and releases on completion',t=>{
  const file=path.join(fixture(t),'session.json'),release=acquireSession(file);
  assert.throws(()=>acquireSession(file),/already running/);
  release();const again=acquireSession(file);again();
});

test('target disappearing after wait is retried, missing target or changed document fails',async()=>{
  let reads=0,waits=0;
  const page={waitForFunction:async()=>{waits++;},evaluate:async()=>++reads===1?null:{id:'exercise-1',top:42}};
  assert.deepEqual(await readTarget(page,{id:'exercise-1',url:'file:///chapter.html'},()=>({})),{id:'exercise-1',top:42});
  assert.equal(waits,2);
  await assert.rejects(readTarget({...page,evaluate:async()=>null},{id:'missing',url:'file:///chapter.html'},()=>({})),/Target unavailable.*missing/);
  await assert.rejects(readTarget({...page,waitForFunction:async()=>{throw new Error('Unexpected document');}},{id:'exercise-1',url:'file:///chapter.html'},()=>({})),/Unexpected document/);
});

test('deep links apply to actual exercises, not redirect or auxiliary TOC fallback',()=>{
  assert.deepEqual(exerciseTargets({redirect_file:'/other'},['ex-1','ex-2']),[]);
  assert.deepEqual(exerciseTargets({},[]),[]);
  assert.deepEqual(exerciseTargets({},['ex-1','ex-2','ex-3']),['ex-1','ex-3']);
  assert.deepEqual(exerciseTargets({},['ex-1']),['ex-1']);
});

test('browser readback executes the real callback with disappearance and wrong-page mutations',async()=>{
  const context=vm.createContext({location:{href:'file:///chapter.html#exercise'},document:{getElementById:()=>({id:'exercise',tagName:'DETAILS'})}});
  let reads=0;
  const page={
    waitForFunction:async(fn,arg)=>assert.equal(vm.runInContext(`(${fn.toString()})(${JSON.stringify(arg)})`,context),true),
    evaluate:async code=>{
      context.document.getElementById=()=>++reads===1?null:{id:'exercise',tagName:'DETAILS'};
      return vm.runInContext(code,context);
    }
  };
  assert.equal(await readTarget(page,{id:'exercise',url:'file:///chapter.html'},e=>e.tagName),'DETAILS');
  context.location.href='file:///other.html';
  await assert.rejects(readTarget(page,{id:'exercise',url:'file:///chapter.html'},e=>e.tagName),/Unexpected document/);
});

test('a failed file flush preserves old evidence and cleans the temporary file', t => {
  const directory=fixture(t), filename=path.join(directory,'evidence.json');
  atomicJson(filename,{value:'old'});
  t.mock.method(fs,'fsyncSync',()=>{throw new Error('injected file flush failure');});
  assert.throws(()=>atomicJson(filename,{value:'new'}),/injected file flush failure/);
  assert.deepEqual(JSON.parse(fs.readFileSync(filename)),{value:'old'});
  assert.deepEqual(fs.readdirSync(directory),['evidence.json']);
});
test('local evidence flushes files on every platform and directories on POSIX', t => {
  const directory=fixture(t), kinds=[], original=fs.fsyncSync;
  t.mock.method(fs,'fsyncSync',fd=>{kinds.push(fs.fstatSync(fd).isDirectory()?'directory':'file');return original(fd);});
  atomicJson(path.join(directory,'report.json'),{status:'passed'});
  assert.deepEqual(kinds,process.platform==='win32'?['file']:['file','directory']);
});
