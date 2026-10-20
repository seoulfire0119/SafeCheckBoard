import type { Building, BuildingState, SessionData, Unit, UnitStatus } from '../types';

export const STATUS: Record<UnitStatus, { label: string; color: string }> = {
  unknown: { label: '미확인', color: '#64748b' },
  confirmed: { label: '확인완료', color: '#16a34a' },
  danger: { label: '화재층', color: '#dc2626' },
  fireFalseAlarm: { label: '연소확대층', color: '#ea580c' },
  resourceBase: { label: '자원대기소', color: '#7c3aed' },
};

export const STATUS_ORDER: UnitStatus[] = ['unknown', 'confirmed', 'danger', 'fireFalseAlarm', 'resourceBase'];

/** 지하주차장: 가로형이면서 지하층만 있음 (줄 = B1·B2, 칸 = A·B·C 구역) */
export const isParking = (b: Building) => b.isHorizontal && b.endFloor < 0;

/** 1 → A, 2 → B … 27 → AA */
export function zoneLetter(n: number): string {
  let s = '';
  for (let x = n; x > 0; x = Math.floor((x - 1) / 26)) s = String.fromCharCode(65 + ((x - 1) % 26)) + s;
  return s;
}

export function rooftopFloor(b: Building): number | null {
  return b.isHorizontal ? null : b.endFloor + 1;
}

/** 유효 층 목록 (0층 제외, 세로형은 옥상층 포함), 오름차순 */
export function floorsOf(b: Building): number[] {
  const out: number[] = [];
  for (let f = b.startFloor; f <= b.endFloor; f++) if (f !== 0) out.push(f);
  if (!b.isHorizontal) out.push(b.endFloor + 1);
  return out;
}

export function floorsDescending(b: Building): number[] {
  return floorsOf(b).sort((a, c) => c - a);
}

export function unitId(floor: number, unitIndex: number) {
  return `${floor}-${unitIndex}`;
}

export function unitNumber(floor: number, unitIndex: number) {
  return floor > 0 ? floor * 100 + unitIndex : -(Math.abs(floor) * 100 + unitIndex);
}

export function newUnit(floor: number, unitIndex: number): Unit {
  return {
    id: unitId(floor, unitIndex),
    floor,
    unitIndex,
    number: unitNumber(floor, unitIndex),
    status: 'unknown',
    memo: '',
    memoPinned: false,
    vulnerable: false,
    spanCount: 1,
  };
}

export function createBuildingState(b: Building): BuildingState {
  const units: Unit[] = [];
  for (const f of floorsOf(b)) for (let i = 1; i <= b.defaultUnits; i++) units.push(newUnit(f, i));
  const floorLabels: Record<string, string> = {};
  const roof = rooftopFloor(b);
  if (roof != null) floorLabels[String(roof)] = '옥상층';
  return { units, hiddenFloors: [], floorLabels };
}

export function floorLabel(b: Building, state: BuildingState | undefined, floor: number): string {
  const custom = state?.floorLabels[String(floor)];
  if (custom) return custom;
  if (b.isHorizontal && floor < 0) return `B${Math.abs(floor)}`;
  if (b.isHorizontal) return `${floor}구역`;
  if (floor < 0) return `B${Math.abs(floor)}F`;
  return `${floor}F`;
}

/** 원래 호수 (예: 301호, B101호, 옥상 1) */
export function baseUnitLabel(b: Building, u: Unit): string {
  if (b.isHorizontal && u.floor < 0) return `${zoneLetter(u.unitIndex)}구역`;
  if (b.isHorizontal) return `${u.floor}구역 ${u.unitIndex}번`;
  if (u.floor === rooftopFloor(b)) return `옥상 ${u.unitIndex}`;
  if (u.floor < 0) return `B${Math.abs(u.floor)}${String(u.unitIndex).padStart(2, '0')}호`;
  return `${u.number}호`;
}

/** 보이는 호실 이름 — 붙인 이름(주차장 등)이 있으면 그것 */
export function unitLabel(b: Building, u: Unit): string {
  return u.label || baseUnitLabel(b, u);
}

/** 원래 층 이름 (예: 3F, B1F, 2구역) */
export function baseFloorLabel(b: Building, floor: number): string {
  if (b.isHorizontal && floor < 0) return `B${Math.abs(floor)}`;
  if (b.isHorizontal) return `${floor}구역`;
  if (floor < 0) return `B${Math.abs(floor)}F`;
  return `${floor}F`;
}

/** 로그용 전체 이름: "101동 3F 301호" */
export function unitFullName(b: Building, state: BuildingState | undefined, u: Unit): string {
  return `${b.name} ${floorLabel(b, state, u.floor)} ${unitLabel(b, u)}`;
}

/**
 * 건물의 층 범위·층당 칸 수를 바꾼다 (잘못 만든 건물 고치기).
 *  · 남는 층·칸의 상태·메모·피난약자·이름은 그대로 둔다
 *  · 옥상층은 새 꼭대기 위로 옮겨 간다
 *  · 새로 생긴 층·칸만 채우고, 원래 비워 둔 칸은 그대로 비워 둔다
 *  · 없어지는 층에 있던 화점·진입대 위치는 지운다
 * 돌려주는 값: 없어진 칸 중 상태·메모·피난약자가 적혀 있던 칸 수
 */
export function resizeBuilding(d: SessionData, idx: number, nb: Building): number {
  const ob = d.buildings[idx];
  const st = d.states[idx];
  const oldRoof = rooftopFloor(ob);
  const newRoof = rooftopFloor(nb);
  const roofMoves = oldRoof != null && newRoof != null && oldRoof !== newRoof;
  const floors = new Set(floorsOf(nb));
  const moveFloor = (f: number) => (roofMoves && f === oldRoof ? newRoof! : f);
  // 옥상이 내려오는 자리에 있던 보통 층은 없어진다
  const survives = (f: number) => floors.has(moveFloor(f)) && !(roofMoves && f === newRoof);

  const ids = new Map<string, string>();
  const units: Unit[] = [];
  let lost = 0;
  for (const u of st.units) {
    if (!survives(u.floor) || u.unitIndex > nb.defaultUnits) {
      if (u.status !== 'unknown' || u.memo || u.vulnerable) lost++;
      continue;
    }
    const f = moveFloor(u.floor);
    const moved = { ...u, spanCount: Math.min(u.spanCount, nb.defaultUnits - u.unitIndex + 1) };
    if (f !== u.floor) Object.assign(moved, { floor: f, id: unitId(f, u.unitIndex), number: unitNumber(f, u.unitIndex) });
    ids.set(u.id, moved.id);
    units.push(moved);
  }
  const oldFloors = new Set(floorsOf(ob).filter(survives).map(moveFloor));
  for (const f of floors) {
    for (let i = 1; i <= nb.defaultUnits; i++) {
      if (oldFloors.has(f) && i <= ob.defaultUnits) continue; // 원래 있던 자리 (비워 둔 칸 포함)
      if (units.some((u) => u.floor === f && u.unitIndex <= i && i < u.unitIndex + u.spanCount)) continue;
      units.push(newUnit(f, i));
    }
  }

  const labels: Record<string, string> = {};
  for (const [k, v] of Object.entries(st.floorLabels)) {
    const f = Number(k);
    if (survives(f)) labels[String(moveFloor(f))] = v;
  }
  if (newRoof != null && !labels[String(newRoof)]) labels[String(newRoof)] = '옥상층';

  d.buildings[idx] = nb;
  d.states[idx] = {
    units,
    hiddenFloors: st.hiddenFloors.filter(survives).map(moveFloor),
    floorLabels: labels,
  };

  const fo = d.fireOrigin;
  if (fo && fo.buildingIdx === idx) {
    if (!survives(fo.floor)) d.fireOrigin = null;
    else {
      fo.floor = moveFloor(fo.floor);
      if (fo.unitId) fo.unitId = ids.get(fo.unitId) ?? null;
    }
  }
  for (const t of d.teams) {
    const p = parseFloorKey(t.floorKey);
    if (!p || p.b !== idx) continue;
    t.floorKey = survives(p.f) ? floorKey(idx, moveFloor(p.f)) : '';
  }
  return lost;
}

/**
 * 여러 칸을 한꺼번에 바꾸기 전에 확인할 것 — 실수로 중요한 표시를 덮어쓰지 않게.
 *  · 화점(추정)으로 지정된 칸·층이 섞여 있음
 *  · 화재층·연소확대층·자원대기소였던 칸이 다른 상태로 바뀜
 *  · 확인완료였던 칸이 미확인으로 되돌아감
 *  · 피난약자 칸을 확인완료로 한꺼번에 처리함
 * 없으면 빈 목록.
 */
export function bulkStatusRisks(d: SessionData, bi: number, units: Unit[], next: UnitStatus): string[] {
  const b = d.buildings[bi];
  const st = d.states[bi];
  if (!b || !st) return [];
  const fo = d.fireOrigin;
  const changing = units.filter((u) => u.status !== next);
  const names = (us: Unit[]) => {
    const n = us.slice(0, 4).map((u) => unitLabel(b, u)).join(', ');
    return us.length > 4 ? `${n} 외 ${us.length - 4}칸` : n;
  };
  const out: string[] = [];
  if (fo && fo.buildingIdx === bi && next !== 'danger') {
    const fu = fo.unitId ? changing.find((u) => u.id === fo.unitId) : null;
    if (fu) out.push(`${floorLabel(b, st, fu.floor)} ${unitLabel(b, fu)}은(는) 화점(추정)으로 지정된 칸입니다.`);
    else if (!fo.unitId && changing.some((u) => u.floor === fo.floor)) out.push(`${floorLabel(b, st, fo.floor)}은(는) 화점(추정) 층입니다.`);
  }
  const important: UnitStatus[] = ['danger', 'fireFalseAlarm', 'resourceBase', ...(next === 'unknown' ? (['confirmed'] as UnitStatus[]) : [])];
  for (const s of important) {
    if (s === next) continue;
    const us = changing.filter((u) => u.status === s);
    if (us.length) out.push(`「${STATUS[s].label}」 ${us.length}칸 (${names(us)})이 「${STATUS[next].label}」(으)로 바뀝니다.`);
  }
  if (next === 'confirmed') {
    const v = changing.filter((u) => u.vulnerable);
    if (v.length) out.push(`피난약자 ${v.length}칸 (${names(v)})이 포함되어 있습니다. 대피·구조를 확인했는지 확인하세요.`);
  }
  return out;
}

export function floorKey(buildingIdx: number, floor: number) {
  return `${buildingIdx}_${floor}`;
}

export function parseFloorKey(key: string): { b: number; f: number } | null {
  const [a, c] = key.split('_').map(Number);
  if (!Number.isFinite(a) || !Number.isFinite(c)) return null;
  return { b: a, f: c };
}
