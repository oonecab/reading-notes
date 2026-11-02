import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const policies = [
  ['reader', 'tools/reader-contract/check.mjs', 'reader-contract.json'],
  ['presentation', 'tools/check-presentation-contract.mjs', 'reader-presentation.json'],
];
function run(script, cwd) {
  const result = spawnSync(process.execPath, [path.join(root, script)], {
    cwd, encoding: 'utf8', timeout: 120000, maxBuffer: 16 * 1024 * 1024,
  });
  assert.ifError(result.error);
  return result;
}
for (const [name, script, policy] of policies) {
  test(`${name} CLI emits a nonempty, successful coverage report`, () => {
    const result = run(script, root);
    assert.equal(result.status, 0, result.stderr);
    assert.notEqual(result.stdout.trim(), '', 'CLI must actually execute its checks');
    const report = JSON.parse(result.stdout);
    assert.equal(report.status, 'passed');
    assert.deepEqual(report.errors, []);
    if (name === 'reader') assert.equal(report.pages, JSON.parse(fs.readFileSync(path.join(root, 'docs', policy))).pages.length);
    else assert.ok(report.books.length > 0, 'No books checked');
  });
  test(`${name} CLI rejects a malformed policy in an isolated working directory`, () => {
    const parent = path.join(root, 'tmp', 'cli-regressions');
    fs.mkdirSync(parent, { recursive: true });
    const fixture = fs.mkdtempSync(path.join(parent, 'invalid-'));
    try {
      fs.mkdirSync(path.join(fixture, 'docs'));
      fs.writeFileSync(path.join(fixture, 'docs', policy), '{invalid-json');
      const result = run(script, fixture);
      assert.notEqual(result.status, 0, 'Invalid policy must not silently succeed');
      assert.match(result.stderr, /SyntaxError/);
    } finally {
      assert.equal(path.dirname(fixture), parent);
      fs.rmSync(fixture, { recursive: true, force: true });
    }
  });
}

for (const name of ['reading-components','reading-typography','reading-presentation']) {
  test(`${name} CLI executes and reports all registered pages`, () => {
    const result=run(`tools/${name}/check.mjs`,root);
    assert.equal(result.status,0,result.stderr);
    assert.notEqual(result.stdout.trim(),'','CLI must execute');
    const report=JSON.parse(result.stdout);
    assert.equal(report.status,'passed');
    assert.equal(report.pages,JSON.parse(fs.readFileSync(path.join(root,'docs/reader-contract.json'))).pages.length);
  });
}
