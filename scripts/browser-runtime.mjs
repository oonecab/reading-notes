import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export function atomicJson(filename,value){
  fs.mkdirSync(path.dirname(filename),{recursive:true});
  const temporary=filename+'.'+randomUUID()+'.tmp';
  try{
    const fd=fs.openSync(temporary,'wx',0o600);
    try{fs.writeFileSync(fd,JSON.stringify(value,null,2)+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
    fs.renameSync(temporary,filename);
    // Windows cannot fsync a directory through Node. Local evidence keeps atomic
    // replacement and file flush, without claiming power-loss durability there.
    // The Linux production installer uses its separate mandatory POSIX barriers.
    if (process.platform !== 'win32') {
      const directory=fs.openSync(path.dirname(filename),'r');
      try{fs.fsyncSync(directory);}finally{fs.closeSync(directory);}
    }
  }finally{fs.rmSync(temporary,{force:true});}
}

export function createRun(base){
  const started_at=new Date().toISOString(),run_id=started_at.replaceAll(/[:.]/g,'-')+'-'+randomUUID().slice(0,8);
  const run={base,run_id,started_at,output:path.join(base,'runs',run_id)};
  fs.mkdirSync(run.output,{recursive:true});
  atomicJson(path.join(run.output,'report.json'),{status:'running',run_id,started_at});
  atomicJson(path.join(base,'latest-attempt.json'),{status:'running',run_id,report:path.relative(base,path.join(run.output,'report.json'))});
  return run;
}

export function finishRun(run,report){
  const final={...report,run_id:run.run_id,started_at:run.started_at,finished_at:new Date().toISOString()};
  atomicJson(path.join(run.output,'report.json'),final);
  atomicJson(path.join(run.base,'latest-attempt.json'),{status:final.status,run_id:run.run_id,report:path.relative(run.base,path.join(run.output,'report.json'))});
  // The successful report points to screenshots in its immutable run directory.
  if(final.status==='passed')atomicJson(path.join(run.base,'report.json'),final);
  return final;
}

export function selectSpace(value,session={}){
  if(value!==undefined){
    if(!/^[1-9][0-9]*$/.test(value)||!Number.isSafeInteger(Number(value)))throw new Error('READING_NOTES_CSP_SPACE must be a positive integer');
    return {spaceId:Number(value),explicit:true};
  }
  return {spaceId:session?.spaceId,explicit:false};
}

export async function openSpace(taskSpace,selection){
  const name='Reading Notes 浏览器验收';
  if(selection.spaceId===undefined)return taskSpace(name);
  try{return await taskSpace(selection.spaceId);}
  catch(error){
    // Do not turn control, permission, timeout or unknown errors into a new space.
    if(selection.explicit||error.message!==`task space not found: ${selection.spaceId}`)throw error;
    console.log(JSON.stringify({stale_space:selection.spaceId,recovery:'create named task space'}));
    return taskSpace(name);
  }
}

export function acquireSession(sessionFile){
  const lock=sessionFile+'.lock',token=randomUUID();
  fs.mkdirSync(path.dirname(lock),{recursive:true});
  let fd;
  try{fd=fs.openSync(lock,'wx',0o600);}
  catch(error){
    if(error.code!=='EEXIST')throw error;
    // Never infer that a terminated CLI means the browser has stopped executing.
    throw new Error(`Browser acceptance already running or interrupted; inspect ${lock} and its driver before removing the lock`);
  }
  fs.writeFileSync(fd,JSON.stringify({pid:process.pid,token,started_at:new Date().toISOString()}));fs.closeSync(fd);
  return ()=>{if(JSON.parse(fs.readFileSync(lock,'utf8')).token===token)fs.unlinkSync(lock);};
}

export async function runDriver(script,run){
  const log=fs.openSync(path.join(run.output,'driver.log'),'wx',0o600);
  try{
    await new Promise((resolve,reject)=>{
      const driver=process.env.READING_NOTES_BROWSER_DRIVER ?? 'playwright';
      if(!['playwright','ego'].includes(driver))throw new Error('Unknown browser driver: '+driver);
      const command=driver==='ego'?'ego-browser':process.execPath;
      const args=driver==='ego'?['nodejs']:[fileURLToPath(new URL('./playwright-driver.mjs',import.meta.url))];
      const child=spawn(command,args,{stdio:['pipe',log,log]});
      child.once('error',reject);
      child.once('close',(code,signal)=>code===0?resolve():reject(new Error(`Browser driver failed (${signal??code}); see ${path.join(run.output,'driver.log')}`)));
      child.stdin.on('error',error=>{if(error.code!=='EPIPE')reject(error);});
      child.stdin.end(script);
    });
    const report=JSON.parse(fs.readFileSync(path.join(run.output,'report.json'),'utf8'));
    if(report.status!=='passed')throw new Error('Browser report did not pass');
    return report;
  }finally{fs.closeSync(log);}
}

export function failedRun(run,error){
  const report=JSON.parse(fs.readFileSync(path.join(run.output,'report.json'),'utf8'));
  return finishRun(run,{...report,status:'failed',errors:[...(report.errors??[]),String(error)]});
}

export async function waitDocument(page,url){
  await page.waitForFunction(url=>location.href.split('#')[0]===url&&document.readyState==='complete'&&!!document.querySelector('main'),url,{timeout:10000});
}

export async function waitTarget(page,target){
  await page.waitForFunction(({id,url})=>{
    if(location.href.split('#')[0]!==url)throw new Error('Unexpected document while waiting for '+id+': '+location.href);
    return !!document.getElementById(id);
  },target,{timeout:10000});
}

export async function readTarget(page,target,reader){
  for(let attempt=0;attempt<3;attempt++){
    await waitTarget(page,target);
    // One evaluate checks identity, resolves the node and reads it synchronously.
    // Serializing a repository-owned callback avoids a second racing DOM lookup.
    const value=await page.evaluate(`(() => {
      const {id,url}=${JSON.stringify(target)};
      if(location.href.split('#')[0]!==url)throw new Error('Unexpected document while reading '+id+': '+location.href);
      const element=document.getElementById(id);
      return element?(${reader.toString()})(element):null;
    })()`);
    if(value!==null)return value;
  }
  throw new Error('Target unavailable after bounded readback: '+target.id);
}

export function exerciseTargets(item,exercises){
  return item.redirect_file||!exercises.length?[]:[...new Set([exercises[0],exercises.at(-1)])];
}
