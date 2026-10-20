import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {acquireSession,selectSpace,createRun,runDriver,finishRun,failedRun} from './browser-runtime.mjs';
const root=process.cwd(),origin=process.argv[2];
const url=new URL(origin);
if(!['http:','https:'].includes(url.protocol)||url.pathname!=='/'||url.search||url.hash||url.username)throw new Error('Pass a public or local HTTP(S) origin');
const sessionFile=path.join(root,'tmp/final-assessment/browser-session.json'),release=acquireSession(sessionFile);
let run;
try {
 run=createRun(path.join(root,'tmp/reading-notes-migration/performance'));
 const session=fs.existsSync(sessionFile)?JSON.parse(fs.readFileSync(sessionFile)):{};
 const config={origin:origin.replace(/\/$/,''),rounds:3,runId:run.run_id,output:run.output,
  routes:['index.html','stochastic/notes/chapter01_markov_chains.html','csapp/notes/chapter02_information.html'],
  selection:selectSpace(process.env.READING_NOTES_CSP_SPACE,session),page:session.page??'p1',sessionFile,
  runtime:pathToFileURL(path.join(root,'scripts/browser-runtime.mjs')).href};
 const report=await runDriver('const config='+JSON.stringify(config)+';\n'+fs.readFileSync('scripts/browser-performance.mjs','utf8'),run);
 finishRun(run,report);console.log(JSON.stringify({status:report.status,samples:report.samples.length,report:run.output+'/report.json'}));
} catch(error){if(run)failedRun(run,error);throw error;}finally{release();}
