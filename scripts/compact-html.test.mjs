import test from 'node:test';import assert from 'node:assert/strict';
import {compactHtml} from './compact-html.mjs';
import {fingerprint,differences} from './parity-lib.mjs';
test('attribute compaction preserves content fingerprints and byte-sensitive islands',()=>{
 const protectedHtml='<style>.x { color: red; }</style><script>const x="a";</script><pre id="pre"><code class="code">x &lt; y</code></pre><math id="math"><mi>x</mi></math><svg id="svg"><path d="M0 0"/></svg><textarea id="text">a b</textarea>';
 const html='<html><head><meta http-equiv="refresh" content="0;url=index.html"></head><body><section id="a" class="chapter" data-kind="test"><p class="two words" data-empty="" data-eq="a=b" data-quote="&quot;">Hello &amp; world</p>'+protectedHtml+'</section></body></html>';
 const result=compactHtml(html);
 assert.match(result,/<section id=a class=chapter data-kind=test>/);
 assert.ok(result.includes(protectedHtml));
 for(const attribute of ['class="two words"','data-empty=""','data-eq="a=b"','http-equiv="refresh"'])assert.ok(result.includes(attribute));
 assert.deepEqual(differences(fingerprint(html),fingerprint(result)),[]);
 assert.equal(compactHtml(result),result);
});

test('self-closing HTML syntax cannot swallow a slash into an attribute value',()=>{
 const html='<html><body><input id="control"/><div data-name="value"/></body></html>';
 assert.deepEqual(differences(fingerprint(html),fingerprint(compactHtml(html))),[]);
});
