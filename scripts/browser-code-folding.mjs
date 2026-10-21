// Uses native pointer/keyboard input: changing details.open is not a toggle test.
export async function checkCodeFold(page, selector = 'main details.code-details, main details.code-version') {
  const before = await page.evaluate(selector => {
    const fold = document.querySelector(selector);
    if (!fold) return null;
    const ancestors = [];
    for (let n = fold.parentElement; n; n = n.parentElement) {
      if (n.tagName === 'DETAILS' && !n.open) { ancestors.push(n); n.open = true; }
    }
    window.__rnFoldTest = { fold, ancestors, text: fold.querySelector('pre').textContent };
    const summary = fold.firstElementChild;
    summary.scrollIntoView({block:'center', behavior:'instant'});
    return {id:fold.id, summary:summary.textContent.trim(), open:fold.open};
  }, selector);
  if (!before) return {applicable:false};
  const check = (ok, message) => { if (!ok) throw new Error(message + ': ' + before.summary); };
  const measure = () => page.evaluate(() => {
    const {fold,text} = window.__rnFoldTest;
    return {open:fold.open, same_code:fold.querySelector('pre').textContent===text,
      width:document.documentElement.scrollWidth, viewport:innerWidth,
      visible:fold.querySelector('pre').checkVisibility(),
      focused:document.activeElement===fold.firstElementChild};
  });
  try {
    const point = await page.evaluate(() => {
      const s=window.__rnFoldTest.fold.firstElementChild;
      s.scrollIntoView({block:'center',behavior:'instant'});
      const r=s.getBoundingClientRect();
      return {x:r.left+Math.min(40,r.width/2),y:r.top+r.height/2};
    });
    await page.mouse.click(point.x,point.y,{label:'切换代码展开状态'});
    const mouse = await measure();
    check(mouse.open!==before.open, 'Native code fold did not toggle on click');
    check(mouse.visible===mouse.open && mouse.same_code, 'Code visibility or text differs');
    check(mouse.width<=mouse.viewport+1, 'Expanded code causes page overflow');
    await page.evaluate(() => window.__rnFoldTest.fold.firstElementChild.focus());
    await page.keyboard.press('Space');
    const keyboard = await measure();
    check(keyboard.open===before.open && keyboard.focused, 'Native code fold did not toggle on keyboard');
    check(keyboard.visible===keyboard.open && keyboard.same_code, 'Keyboard code visibility or text differs');
    check(keyboard.width<=keyboard.viewport+1, 'Expanded code causes page overflow');
    return {applicable:true,...before,mouse,keyboard};
  } finally {
    await page.evaluate(() => {
      for(const n of window.__rnFoldTest.ancestors)n.open=false;
      delete window.__rnFoldTest;
    });
  }
}
