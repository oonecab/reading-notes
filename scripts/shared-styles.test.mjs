import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import test from 'node:test';
import { sharedAsset } from '../src/lib/controlled-html.mjs';

test('shared CSS composition preserves cascade order and rejects cycles and escaped paths', () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rn-shared-styles-'));
  fs.mkdirSync(path.join(base, 'src/styles'), { recursive: true });
  const write = (name, text) => fs.writeFileSync(path.join(base, 'src/styles', name), text);
  try {
    write('base.css', 'p{color:green}\n');
    write('book.css', '/* RN:include styles/base.css */p{color:black}');
    assert.equal(sharedAsset('styles/book.css', base), 'p{color:green}\np{color:black}');
    write('base.css', '/* RN:include styles/book.css */');
    assert.throws(() => sharedAsset('styles/book.css', base), /Circular/);
    write('book.css', '/* RN:include ../secret.css */');
    assert.throws(() => sharedAsset('styles/book.css', base), /only include styles/);
    assert.throws(() => sharedAsset('styles/../../secret.css', base), /Invalid/);
    write('book.css', '/* RN:include scripts/source.js */');
    assert.throws(() => sharedAsset('styles/book.css', base), /only include styles/);
  } finally {
    fs.rmSync(base, { recursive: true, force: true });
  }
});
