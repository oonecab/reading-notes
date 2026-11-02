import fs from 'node:fs';
import path from 'node:path';
import {parse} from 'parse5';
import {createHash} from 'node:crypto';
import {walk} from '../src/lib/controlled-html.mjs';
import {htmlFiles} from './inline-assets.mjs';
import {sha} from './parity-lib.mjs';

export function scriptSources(html){
  return walk(parse(html)).filter(n=>n.tagName==='script').map(n=>(n.childNodes??[]).map(c=>c.value??'').join(''));
}
export const cspHash=source=>"'sha256-"+createHash('sha256').update(source).digest('base64')+"'";
export function cspManifest(directory){
  const files={},sources=new Set();
  for(const file of htmlFiles(directory)){
    const html=fs.readFileSync(file,'utf8');files[path.relative(directory,file).split(path.sep).join('/')]=sha(html);
    for(const script of scriptSources(html))sources.add(cspHash(script));
  }
  return {files,sources:[...sources].sort()};
}
export function verifyCspManifest(directory,expected){
  if(JSON.stringify(cspManifest(directory))!==JSON.stringify(expected))throw new Error('CSP-validated HTML or inline script hash changed');
}
export function cspHeader(template,sources){
  const match=template.match(/add_header Content-Security-Policy "([^"]+)" always;/);
  if(!match)throw new Error('Missing production CSP template');
  return match[1].replace('@@SCRIPT_SOURCES@@',sources.join(' '));
}
