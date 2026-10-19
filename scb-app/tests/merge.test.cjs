const test = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load-ts.cjs')();
const { mergeEdits, EditConflict } = load('src/lib/merge.ts');
const { teamElapsed, teamLevel } = load('src/lib/teams.ts');

test('independent report cells merge', () => {
  assert.deepEqual(mergeEdits({ a: 'old', b: 'old' }, { a: 'mine', b: 'old' }, { a: 'old', b: 'theirs' }), { a: 'mine', b: 'theirs' });
});
test('saving timeline never replaces agency rows', () => {
  const base = { actionRows: [{ id: '1', content: 'old' }] };
  const local = { actionRows: [{ id: '1', content: 'new' }] };
  assert.deepEqual(mergeEdits(base, local, { ...base, agencyRows: [{ id: 'a', person: '20' }] }), { ...local, agencyRows: [{ id: 'a', person: '20' }] });
});
test('concurrent additions both survive', () => {
  assert.deepEqual(mergeEdits([], [{ id: 'a', x: 1 }], [{ id: 'b', x: 2 }]), [{ id: 'b', x: 2 }, { id: 'a', x: 1 }]);
});
test('different marker moves merge by ID', () => {
  const base = [{ id: 'a', x: 0 }, { id: 'b', x: 0 }];
  assert.deepEqual(mergeEdits(base, [{ id: 'a', x: 1 }, base[1]], [base[0], { id: 'b', x: 2 }]), [{ id: 'a', x: 1 }, { id: 'b', x: 2 }]);
});
test('same marker independent properties merge', () => {
  assert.deepEqual(mergeEdits([{ id: 'a', x: 0, label: '' }], [{ id: 'a', x: 1, label: '' }], [{ id: 'a', x: 0, label: 'pump' }]), [{ id: 'a', x: 1, label: 'pump' }]);
});
test('overlapping cell edits are rejected', () => {
  assert.throws(() => mergeEdits({ a: 'old' }, { a: 'mine' }, { a: 'theirs' }), EditConflict);
});
test('remote deletion plus local edit is a conflict', () => {
  assert.throws(() => mergeEdits([{ id: 'a', x: 0 }], [{ id: 'a', x: 1 }], []), EditConflict);
});
test('local deletion preserves concurrent additions', () => {
  assert.deepEqual(mergeEdits([{ id: 'a' }], [], [{ id: 'a' }, { id: 'b' }]), [{ id: 'b' }]);
});
test('legacy row structural conflict is rejected', () => {
  assert.throws(() => mergeEdits([{ name: 'old' }], [], [{ name: 'new' }]), EditConflict);
});
test('equal concurrent edits are idempotent', () => {
  assert.equal(mergeEdits('old', 'new', 'new'), 'new');
});
test('paused teams continue accumulating time and become dangerous', () => {
  const team = { status: 'paused', entryAt: 1000, pausedMs: 2000 };
  assert.equal(teamElapsed(team, 1201000), 1200000);
  assert.equal(teamLevel(team, { warnMin: 15, dangerMin: 20 }, 1201000), 'danger');
});
test('paused team under threshold retains paused status', () => {
  assert.equal(teamLevel({ status: 'paused', entryAt: 1000 }, { warnMin: 15, dangerMin: 20 }, 2000), 'paused');
});
test('clock skew does not produce negative elapsed time', () => {
  assert.equal(teamElapsed({ status: 'active', entryAt: 10000 }, 1000), 0);
});
