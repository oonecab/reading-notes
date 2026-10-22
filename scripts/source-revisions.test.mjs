import test from 'node:test';
import assert from 'node:assert/strict';
import {sha} from './parity-lib.mjs';
import {reviewedIdentity} from '../src/lib/source-revisions.mjs';
test('later content requires a historical hash, unbroken review chain and bound review record',()=>{
  const original='<main id="topic"><details class="exercise" id="ex-1-1">question</details></main>';
  const html=original.replace('question','question and proof');
  const entry={html,metadata:{route:'book/notes/one.html',original_sha256:sha(original)}};
  const registry={pages:{[entry.metadata.route]:{original_sha256:sha(original),source_sha256:sha(html),history:[{from_sha256:sha(original),to_sha256:sha(html),reason:'reviewed proof',reviewed_anchors:['ex-1-1'],revision:'fixture'}]}}};
  const review={source_sha256:{[entry.metadata.route]:sha(html)}};
  assert.throws(()=>reviewedIdentity(entry,Buffer.from(original),{pages:{}},review),/Unreviewed/);
  reviewedIdentity(entry,Buffer.from(original),registry,review);
  assert.throws(()=>reviewedIdentity(entry,Buffer.from(original),registry,{}),/does not bind/);
  const bad={...entry,html:html.replace('id="ex-1-1"','id="ex-1-2"')};
  const row=registry.pages[entry.metadata.route];row.source_sha256=sha(bad.html);row.history[0].to_sha256=sha(bad.html);review.source_sha256[entry.metadata.route]=sha(bad.html);
  assert.throws(()=>reviewedIdentity(bad,Buffer.from(original),registry,review),/IDs changed/);
});

test('reviewed index moves preserve the relative order of all other historical anchors',()=>{
  const original='<main id="top"><nav id="index">索引</nav><section id="first">第一节</section><section id="second">第二节</section></main>';
  const revised='<main id="top"><section id="first">第一节</section><section id="second">第二节</section><nav id="index">索引</nav></main>';
  const check=(html,moves=['index'])=>{
    const route='book/notes/moved.html';
    const row={original_sha256:sha(original),source_sha256:sha(html),history:[{from_sha256:sha(original),to_sha256:sha(html),reason:'move the reviewed index',reviewed_anchors:['index'],anchor_order_change:moves,revision:'fixture'}]};
    return reviewedIdentity({html,metadata:{route,original_sha256:sha(original)}},Buffer.from(original),{pages:{[route]:row}},{source_sha256:{[route]:sha(html)}});
  };
  check(revised);
  const swapped=revised.replace('<section id="first">第一节</section><section id="second">第二节</section>','<section id="second">第二节</section><section id="first">第一节</section>');
  assert.throws(()=>check(swapped),/anchors removed or reordered/);
  assert.throws(()=>check(revised.replace('id="first"','id="missing"')),/anchor removed/);
  assert.throws(()=>check(revised,['missing']),/Undeclared moved anchor/);
  assert.throws(()=>check(revised,[]),/anchors removed or reordered/);
});
