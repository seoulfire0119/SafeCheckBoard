const test = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load-ts.cjs')();
const { createBuildingState, resizeBuilding, floorKey } = load('src/lib/building.ts');

function session(b) {
  return {
    buildings: [b],
    states: [createBuildingState(b)],
    personnelStats: [{ selfEvac: 0, rescued: 0, notFound: 0 }],
    teams: [],
    fireOrigin: null,
  };
}
const unitAt = (d, f, i) => d.states[0].units.find((u) => u.floor === f && u.unitIndex === i);

test('adding floors and units keeps existing unit states and moves rooftop up', () => {
  const b = { name: '101동', startFloor: 1, endFloor: 3, defaultUnits: 2, isHorizontal: false };
  const d = session(b);
  unitAt(d, 2, 1).status = 'danger';
  unitAt(d, 4, 1).memo = '옥상 문 잠김'; // 옥상층 (3층 위)
  d.teams.push({ id: '1', floorKey: floorKey(0, 4) });
  const lost = resizeBuilding(d, 0, { ...b, endFloor: 5, defaultUnits: 3 });
  assert.equal(lost, 0);
  assert.equal(unitAt(d, 2, 1).status, 'danger');
  assert.equal(unitAt(d, 6, 1).memo, '옥상 문 잠김');
  assert.equal(unitAt(d, 6, 1).id, '6-1');
  assert.equal(d.states[0].floorLabels['6'], '옥상층');
  assert.equal(d.states[0].floorLabels['4'], undefined);
  assert.ok(unitAt(d, 4, 3) && unitAt(d, 5, 2) && unitAt(d, 1, 3));
  assert.equal(d.states[0].units.length, 6 * 3);
  assert.equal(d.teams[0].floorKey, floorKey(0, 6));
});

test('removing floors reports lost data and clears fire origin on removed floor', () => {
  const b = { name: '101동', startFloor: -1, endFloor: 5, defaultUnits: 2, isHorizontal: false };
  const d = session(b);
  unitAt(d, 5, 2).vulnerable = true;
  d.fireOrigin = { buildingIdx: 0, unitId: '5-2', floor: 5, note: '', by: '', at: 0 };
  const lost = resizeBuilding(d, 0, { ...b, startFloor: 1, endFloor: 4 });
  assert.equal(lost, 1);
  assert.equal(d.fireOrigin, null);
  assert.equal(unitAt(d, -1, 1), undefined);
  assert.ok(unitAt(d, 5, 1)); // 새 옥상층
  assert.equal(d.states[0].floorLabels['5'], '옥상층');
});

test('cells that were left empty stay empty', () => {
  const b = { name: '상가', startFloor: 1, endFloor: 2, defaultUnits: 3, isHorizontal: true };
  const d = session(b);
  d.states[0].units = d.states[0].units.filter((u) => !(u.floor === 1 && u.unitIndex === 2));
  resizeBuilding(d, 0, { ...b, defaultUnits: 4 });
  assert.equal(unitAt(d, 1, 2), undefined);
  assert.ok(unitAt(d, 1, 4));
});
