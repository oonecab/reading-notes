import test from 'node:test';
import assert from 'node:assert/strict';
import { supports } from './toolchain.mjs';
test('toolchain boundaries reject old, future-major and prerelease versions', () => {
  for (const [minimum, major, accepted, rejected] of [
    ['24.21.0',24,['24.21.0','24.22.1'],['24.14.0','24.20.9','25.0.0','24.21.0-rc.1']],
    ['11.21.0',11,['11.21.0','11.25.0'],['11.20.9','12.0.0','11.21.0-beta.1']]
  ]) {
    for(const version of accepted) assert.equal(supports(version,minimum,major),true,version);
    for(const version of [...rejected,undefined,'garbage']) assert.equal(supports(version,minimum,major),false,String(version));
  }
});

import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
test('doctor and build agree with the declared version ranges', () => {
  const manifest=JSON.parse(fs.readFileSync(new URL('../package.json',import.meta.url)));
  assert.deepEqual(manifest.engines,{node:'>=24.21.0 <25',pnpm:'>=11.21.0 <12'});
  const result=spawnSync(process.platform==='win32'?'python':'python3',['-c',
    'import sys; sys.path.insert(0,"tools"); from project import version_supported; assert version_supported("v24.22.1",(24,21,0),24); assert not version_supported("24.14.0",(24,21,0),24); assert not version_supported("25.0.0",(24,21,0),24); assert version_supported("11.25.0",(11,21,0),11); assert not version_supported("12.0.0",(11,21,0),11)'],{encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);
});
