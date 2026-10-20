const test = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load-ts.cjs')();
const { diffChanges, applyUndo } = load('src/lib/undo.ts');

const unit = (id, status = 'unknown') => ({ id, floor: 4, unitIndex: Number(id.split('-')[1]), status, memo: '' });
const board = () => ({
  states: [{ units: [unit('4-1'), unit('4-2', 'danger'), unit('4-3')], hiddenFloors: [] }],
  fireOrigin: { buildingIdx: 0, unitId: '4-2', floor: 4 },
});

test('undo restores a whole-floor status change', () => {
  const before = board();
  const after = structuredClone(before);
  for (const u of after.states[0].units) u.status = 'confirmed';
  const changes = diffChanges(before, after);
  assert.equal(changes.length, 3);
  const cur = structuredClone(after);
  assert.deepEqual(applyUndo(cur, changes), { applied: 3, skipped: 0 });
  assert.deepEqual(cur, before);
});

test('undo skips places someone else changed afterwards', () => {
  const before = board();
  const after = structuredClone(before);
  for (const u of after.states[0].units) u.status = 'confirmed';
  const changes = diffChanges(before, after);
  const cur = structuredClone(after);
  cur.states[0].units[0].status = 'danger'; // 다른 사람이 4-1 을 다시 바꿈
  cur.states[0].units.reverse(); // 순서가 바뀌어도 id 로 찾는다
  assert.deepEqual(applyUndo(cur, changes), { applied: 2, skipped: 1 });
  const byId = Object.fromEntries(cur.states[0].units.map((u) => [u.id, u.status]));
  assert.deepEqual(byId, { '4-1': 'danger', '4-2': 'danger', '4-3': 'unknown' });
});

test('undo of removing and adding keyed items, and of clearing fire origin', () => {
  const before = board();
  const after = structuredClone(before);
  after.states[0].units = after.states[0].units.filter((u) => u.id !== '4-3');
  after.states[0].units.push(unit('4-4'));
  after.fireOrigin = null;
  const cur = structuredClone(after);
  applyUndo(cur, diffChanges(before, after));
  assert.deepEqual(cur.states[0].units.map((u) => u.id).sort(), ['4-1', '4-2', '4-3']);
  assert.deepEqual(cur.fireOrigin, before.fireOrigin);
});
