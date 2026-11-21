import assert from 'node:assert/strict';

export function verifyTocState(state, original, scripted, requiredGroup) {
  assert.deepEqual(state.links, original, 'TOC link order changed');
  assert.equal(state.summaryLinks, 0, 'Links inside summary');
  if (!scripted) {
    assert.equal(state.groups.length, 0, 'Unscripted TOC contains toggles');
    assert.equal(state.visible, original.length, 'Unscripted TOC hides links');
    return;
  }
  for (const group of state.groups) {
    assert(group.controls && group.matches === 1, 'Missing or ambiguous aria-controls');
    assert(['true','false'].includes(group.expanded), 'Missing aria-expanded');
    assert.equal(group.expanded === 'true', group.visible, 'Incorrect group visibility');
  }
  if (requiredGroup) assert(state.groups.some(g=>g.controls===requiredGroup && g.visible), 'Required group is closed');
}


export function expectedTocGroups(rows) {
  const groups = [];
  let parent;
  for (const {href, heading} of rows) {
    if (heading === 'h2') parent = {href, children:[]};
    else if (parent && heading === 'h3') {
      if (!parent.children.length) groups.push(parent);
      parent.children.push(href);
    } else parent = null;
  }
  return groups;
}

export function verifyPrintState(before, printing, after) {
  assert.deepEqual(printing,before.map(()=>'true'), 'Print must expand every group');
  assert.deepEqual(after,before,'Print must restore every group');
}

export function verifyGroupLayout(actual, rows, scripted) {
  assert(actual.stable, 'Repeated initialization changed the directory');
  assert.deepEqual(actual.groups,scripted ? expectedTocGroups(rows) : [], 'Incorrect parent or child grouping');
}
