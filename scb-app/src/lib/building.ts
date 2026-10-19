import type { Building, BuildingState, Unit, UnitStatus } from '../types';

export const STATUS: Record<UnitStatus, { label: string; color: string; icon: string }> = {
  unknown: { label: '미확인', color: '#757575', icon: '?' },
  confirmed: { label: '확인완료', color: '#2e7d32', icon: '✓' },
  danger: { label: '화재층', color: '#d32f2f', icon: '🔥' },
  fireFalseAlarm: { label: '연소확대층', color: '#ef6c00', icon: '⚠' },
  resourceBase: { label: '자원대기소', color: '#7b1fa2', icon: '◆' },
};

export const STATUS_ORDER: UnitStatus[] = ['unknown', 'confirmed', 'danger', 'fireFalseAlarm', 'resourceBase'];

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
  if (b.isHorizontal) return `${floor}구역`;
  if (floor < 0) return `B${Math.abs(floor)}F`;
  return `${floor}F`;
}

export function unitLabel(b: Building, u: Unit): string {
  if (b.isHorizontal) return `${u.floor}구역 ${u.unitIndex}번`;
  if (u.floor === rooftopFloor(b)) return `옥상 ${u.unitIndex}`;
  if (u.floor < 0) return `B${Math.abs(u.floor)}${String(u.unitIndex).padStart(2, '0')}호`;
  return `${u.number}호`;
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
