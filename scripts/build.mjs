import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inlineAssets, htmlFiles, validateSiteIcon } from './inline-assets.mjs';
import { entries, syncMirrors } from '../src/lib/controlled-html.mjs';
import { verifyParity } from './verify-parity.mjs';
import { sha, offlineDependencies } from './parity-lib.mjs';
import { checkCsp } from './check-csp.mjs';
import { checkBudgets } from './performance-budget.mjs';
import { checkSource } from '../src/lib/source-revisions.mjs';
import { requireReaderCopy, requireCodeFolding } from '../tools/reading-presentation/check.mjs';
import { checkAll as checkReaderContract } from '../tools/reader-contract/check.mjs';
import { checkAll as checkPresentationContract, checkDist as checkPresentationDist } from '../tools/check-presentation-contract.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
process.chdir(root);
if (process.versions.node !== '24.21.0') throw new Error('Build requires pinned Node 24.21.0');
const shell = process.argv.includes('--shell');
const stage = path.join(root, 'tmp/reading-notes-migration');
fs.mkdirSync(stage, { recursive: true });
const lock=path.join(stage,'build.lock');
try { fs.mkdirSync(lock); } catch (error) { throw new Error('Build already running or interrupted; inspect tmp/reading-notes-migration/build.lock before recovery', {cause:error}); }
fs.writeFileSync(path.join(lock,'owner.json'),JSON.stringify({pid:process.pid}));
process.on('exit',()=>fs.rmSync(lock,{recursive:true,force:true}));
process.on('SIGINT',()=>process.exit(130));
process.on('SIGTERM',()=>process.exit(143));
const releaseIndex=process.argv.indexOf('--release-id');
const releaseId=releaseIndex<0?null:process.argv[releaseIndex+1];
if(releaseIndex>=0 && (!/^\d{8}T\d{6}$/.test(releaseId??'') || shell)) throw new Error('Invalid release build');
fs.writeFileSync(path.join(stage, 'build-state.json'), JSON.stringify({ shell }));
const start = performance.now();
function run(command,args) {
  const result=spawnSync(command,args,{stdio:'inherit'});
  if(result.status!==0)throw new Error(`${command} failed: ${result.status}`);
}
let pages=[];
if(!shell) {
  pages=entries();if(!pages.length)throw new Error('No migrated content');
  const readerContract=checkReaderContract();
  fs.writeFileSync(path.join(stage,'reader-contract.json'),JSON.stringify(readerContract,null,2)+'\n');
  if(readerContract.errors.length)throw new Error('Reader contract failed: '+JSON.stringify(readerContract.errors));
  const presentationContract=checkPresentationContract();
  fs.writeFileSync(path.join(stage,'presentation-contract.json'),JSON.stringify(presentationContract,null,2)+'\n');
  if(presentationContract.errors.length)throw new Error('Presentation contract failed: '+JSON.stringify(presentationContract.errors));
  for(const entry of pages)checkSource(entry);
  syncMirrors(pages,{write:true});
  for(const folder of ['legacy','prepared','canonical'])fs.rmSync(path.join(stage,folder),{recursive:true,force:true});
  run('python3',['deploy/build_portal.py','--export-directory',path.join(stage,'legacy')]);
  fs.cpSync(path.join(stage,'legacy'),path.join(stage,'prepared'),{recursive:true});
  for(const entry of pages) {
    const destination=path.join(stage,'canonical',entry.metadata.route);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,entry.html);
  }
  fs.writeFileSync(path.join(stage,'source-pages.json'),JSON.stringify(pages.map(e=>e.metadata)));
  run('python3',['scripts/prepare-pages.py']);
}
const astroPackage = JSON.parse(fs.readFileSync(path.join(root, 'node_modules/astro/package.json'), 'utf8'));
const result = spawnSync(process.execPath, [path.join(root, 'node_modules/astro', astroPackage.bin.astro), 'build'], {
  stdio: 'inherit', env: { ...process.env, ASTRO_TELEMETRY_DISABLED: '1' },
});
if (result.status !== 0) process.exit(result.status ?? 1);
const output = path.join(stage, 'astro-output');
const target = path.join(stage,shell?'shell-dist':'candidate-dist');
fs.rmSync(target,{recursive:true,force:true});
if(!shell)fs.cpSync(path.join(stage,'prepared'),target,{recursive:true});
fs.cpSync(output,target,{recursive:true});
const routes=htmlFiles(target).map(file=>path.relative(target,file));
inlineAssets(target,routes.map(r=>path.join(target,r)));
for(const route of routes){const issues=offlineDependencies(fs.readFileSync(path.join(target,route),'utf8'));if(issues.length)throw new Error(`${route}: ${issues.join(', ')}`);}
if(!shell){
  const siteIcon=fs.readFileSync(path.join(root,'portal/favicon.svg'));
  for(const route of routes){
    try { validateSiteIcon(fs.readFileSync(path.join(target,route),'utf8'),siteIcon); }
    catch(error) { throw new Error(`${route}: ${error.message}`, {cause:error}); }
  }
  run('python3',['deploy/public_policy.py',target,'--transform','--sums',path.join(stage,'dist-SHA256SUMS')]);
  for (const route of routes) {
    try { requireReaderCopy(fs.readFileSync(path.join(target, route), 'utf8')); }
    catch (error) { throw new Error(`${route}: ${error.message}`, {cause: error}); }
  }
  for (const {metadata:{route}} of pages) {
    try { requireCodeFolding(fs.readFileSync(path.join(target, route), 'utf8')); }
    catch (error) { throw new Error(`${route}: ${error.message}`, {cause: error}); }
  }
  verifyParity(target);
  fs.writeFileSync(path.join(stage,'performance-budget.json'),JSON.stringify(checkBudgets(target),null,2)+'\n');
  await checkCsp(target);
  const previous=path.join(stage,'previous-dist');fs.rmSync(previous,{recursive:true,force:true});
  if(fs.existsSync(path.join(root,'dist')))fs.renameSync(path.join(root,'dist'),previous);
  fs.renameSync(target,path.join(root,'dist'));
  const presentationDist=checkPresentationDist();
  fs.writeFileSync(path.join(stage,'presentation-dist.json'),JSON.stringify(presentationDist,null,2)+'\n');
  if(presentationDist.errors.length)throw new Error('Built presentation contract failed: '+JSON.stringify(presentationDist.errors));
}
const report = { status: 'passed', mode: shell?'empty_scaffold':'book_migration', books:[...new Set(pages.map(p=>p.metadata.book))],pages:pages.length,public_html:routes.length,seconds: (performance.now()-start)/1000, output: shell?path.relative(root,target):'dist' };
fs.writeFileSync(path.join(stage, shell?'scaffold-build.json':'build.json'), JSON.stringify(report,null,2)+'\n');
if(releaseId)run('python3',['deploy/build_astro.py','--package-dist','--release-id',releaseId]);
console.log(JSON.stringify(report));
