import test from 'node:test';import assert from 'node:assert/strict';
import {checkReaderPage,isPdf,reviewedQuestions} from '../tools/reader-contract/check.mjs';
const policy={page:'book/notes/ch.html',sections:[{id:'s1',annotation:'required'}],questions:['ex-1']};
const source={route:'book/assets/source.pdf',pages:20};
const html=`<html><body><main><section id="s1"><h2>概念</h2><details class="reading-notes" data-notes-for="s1" open><summary>理解</summary><div class="reading-notes-body">先明确对象与条件，再按定义推导结果。这个补充解释应与当前小节对应，并且在关闭脚本后仍能够直接在正文中阅读，不能留空或借用上一节的说明。</div></details><details class="exercise" id="ex-1"><summary>习题</summary><div class="exercise-question"><p class="rn-exercise-label">原题</p><div class="question-translation" lang="zh-CN">请证明以下命题，并说明所有必要的条件。</div><details class="original-question"><summary>英文原题</summary><p lang="en">Prove the claim.</p></details><a href="../assets/source.pdf#page=4">PDF 4</a></div></details></section></main><aside id="annotation-rail"><a id="annotation-context-link"></a><div id="annotation-content"></div></aside><script id="reading-notes-controller"></script></body></html>`;
test('reader contract accepts complete translation, binding and PDF locator',()=>assert.equal(checkReaderPage(html,policy,source).questions,1));
test('Chinese question is required without a full English original',()=>{
 const chineseOnly=html.replace(/<details class="original-question">[\s\S]*?<\/details>/,'');
 assert.equal(checkReaderPage(chineseOnly,policy,source).questions,1);
 const translation=html.match(/<div class="question-translation"[\s\S]*?<\/div>/)[0];
 const reversed=html.replace(translation,'').replace('</details><a href="../assets', '</details>'+translation+'<a href="../assets');
 assert.throws(()=>checkReaderPage(reversed,policy,source),/must precede English/);
 assert.throws(()=>checkReaderPage(html.replace('class="original-question"','class="original-question" open'),policy,source),/English original disclosure/);
});
test('a short quoted English word in a Chinese erratum remains in context',()=>{
 const optional={...policy,chinese_translation_required:false};
 const chinese=html.replace(/<div class="question-translation"[\s\S]*?<\/div>/,'<p>请证明下列命题。原文使用 <span lang="en">nondistinct</span>，本题校注说明此词。</p>').replace(/<details class="original-question">[\s\S]*?<\/details>/,'');
 assert.doesNotThrow(()=>checkReaderPage(chinese,optional,source));
});
test('answer prose cannot be styled as a component label',()=>{
 const changed=html.replace('</section>','<div class="answer"><p class="rn-exercise-label">线程共享描述符表，所以主线程关闭描述符后，工作线程不能继续使用它。</p></div></section>');
 assert.throws(()=>checkReaderPage(changed,policy,source),/label contains body text/);
});
for(const [name,change,expected] of [
 ['zero annotations',s=>s.replace(/<details class="reading-notes"[\s\S]*?<\/details>/,''),/Missing reading annotations/],
 ['missing section binding',s=>s.replace('data-notes-for="s1"','data-notes-for="absent"'),/Missing required annotation/],
 ['English-only question',s=>s.replace(/<div class="question-translation"[\s\S]*?<\/div>/,''),/Chinese question task missing/],
 ['source label opens overview',s=>s.replace('../assets/source.pdf#page=4','book_overview.html#source'),/PDF link missing/],
 ['out of range PDF page',s=>s.replace('#page=4','#page=21'),/PDF link missing/],
 ['internal delivery status',s=>s.replace('请证明','已完成本地验收。请证明'),/Internal workflow copy/],
 ['unregistered teaching section',s=>s.replace('</main>','<section id="s2"><h2>新增</h2></section></main>'),/Unreviewed section inventory/]
])test(name,()=>assert.throws(()=>checkReaderPage(change(html),policy,source),expected));
test('PDF identity is checked independently from link label',()=>{
 assert.equal(isPdf('../assets/source.pdf#page=4',policy,source),true);
 for(const h of ['../assets/another.pdf#page=4','../assets/source.pdf#page=0','https://elsewhere.test/source.pdf#page=4'])assert.equal(isPdf(h,policy,source),false);
});
test('Chinese text does not conceal a deleted condition or wrong source page',()=>{
 const review=reviewedQuestions(html);
 for(const changed of [html.replace('所有必要的条件','相关计算结果'),html.replace('#page=4','#page=5')])
  assert.throws(()=>checkReaderPage(changed,policy,source,review),/changed after source review/);
});
test('review covers referenced inputs as well as the question text',()=>{
 const linked=html.replace('</section>','<p id="input">输入是严格递增的整数序列。</p></section>').replace('请证明','<a href="#input">给定输入</a>请证明');
 assert.throws(()=>checkReaderPage(linked.replace('严格递增','任意'),policy,source,reviewedQuestions(linked)),/changed after source review/);
});
test('unfolded arbitrary index is rejected',()=>{
 const changed=html.replace('</section>','<nav class="exercise-index"><a href="#ex-1">习题</a></nav></section>');
 assert.throws(()=>checkReaderPage(changed,policy,source),/shared disclosure/);
});
test('heading references bind the following material, not only the heading',()=>{
 const linked=html.replace('</section>','<h3 id="input">前置程序</h3><pre><code>return x + 1;</code></pre><h3>另一主题</h3></section>').replace('请证明','<a href="#input">原程序</a>请证明');
 assert.throws(()=>checkReaderPage(linked.replace('return x + 1;','return x - 1;'),policy,source,reviewedQuestions(linked)),/changed after source review/);
});
test('explicit nested section inventory covers each subsection and its annotation',()=>{
 const nested=html.replace('</section>','<section id="s1-1"><h3>子节</h3><details class="reading-notes" data-notes-for="s1-1" open><summary>理解</summary><div class="reading-notes-body">本子节把新约束与已有替换相结合，再统一参数和返回值。每个新的子节必须独立说明条件、共享关系和边界，不能借用父节的注解作为已经覆盖的证据。</div></details></section></section>');
 const p={...policy,section_scope:'all-descendants',sections:[...policy.sections,{id:'s1-1',parent:'s1',annotation:'required'}]};
 assert.equal(checkReaderPage(nested,p,source).annotations,2);
 assert.throws(()=>checkReaderPage(nested,{...p,sections:policy.sections},source),/Unreviewed section inventory/);
 assert.throws(()=>checkReaderPage(nested.replace('data-notes-for="s1-1"','data-notes-for="missing"'),p,source),/Missing required annotation/);
 assert.throws(()=>checkReaderPage(nested,{...p,sections:[policy.sections[0],{...p.sections[1],parent:'other'}]},source),/Wrong subsection parent/);
});
