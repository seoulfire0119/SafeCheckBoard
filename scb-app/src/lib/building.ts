import type { Building, BuildingState, Unit, UnitStatus } from '../types';

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

export function floorKey(buildingIdx: number, floor: number) {
  return `${buildingIdx}_${floor}`;
}

export function parseFloorKey(key: string): { b: number; f: number } | null {
  const [a, c] = key.split('_').map(Number);
  if (!Number.isFinite(a) || !Number.isFinite(c)) return null;
  return { b: a, f: c };
}
