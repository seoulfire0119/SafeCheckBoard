// Firestore 문서 구조는 Flutter 버전(sessions/{code})과 같은 키를 쓴다.
// 새로 생긴 것: teams, timerSettings, fireOrigin, title, logs 서브컬렉션, secondary/map 문서

export type UnitStatus = 'unknown' | 'confirmed' | 'danger' | 'fireFalseAlarm' | 'resourceBase';

export interface Building {
  name: string;
  startFloor: number;
  endFloor: number;
  defaultUnits: number; // 층(구역)당 세대(구획)수
  isHorizontal: boolean; // 가로형(시장·의료) / 세로형(아파트·빌딩)
}

export interface Unit {
  id: string; // `${floor}-${unitIndex}`
  floor: number;
  unitIndex: number;
  number: number;
  status: UnitStatus;
  memo: string;
  memoPinned: boolean;
  vulnerable: boolean; // 피난약자
  spanCount: number; // 병합 칸 수
  label?: string; // 사람이 붙인 이름 (예: 주차장, 기계실) — 없으면 호수
}

export interface BuildingState {
  units: Unit[];
  hiddenFloors: number[];
  floorLabels: Record<string, string>; // floor → 표시 이름
}

export interface PersonnelStats {
  selfEvac: number;
  rescued: number;
  notFound: number;
}

export type TeamBase = 'waiting' | 'active' | 'paused';
export type TeamLevel = TeamBase | 'warning' | 'danger';

export interface Team {
  id: string;
  name: string; // 1착대, 2착대 …
  unit: string; // 단대명 (예: 신수대)
  color: string;
  floorKey: string; // `${buildingIdx}_${floor}` 또는 ''
  task: string; // 임무 (예: 인명검색, 화재진압)
  status: TeamBase;
  entryAt: number | null; // 진입 시각(ms)
  pausedMs: number | null; // 일시정지 시점까지 경과(ms)
}

export interface TimerSettings {
  warnMin: number;
  dangerMin: number;
}

export interface FireOrigin {
  buildingIdx: number;
  unitId: string | null; // null 이면 층 전체
  floor: number;
  note: string;
  by: string;
  at: number;
}

export interface SessionData {
  ownerId: string;
  closed: boolean;
  title: string;
  createdAt: number; // 현장(세션)을 연 시각 ms — 0 이면 모름
  buildings: Building[];
  states: BuildingState[];
  personnelStats: PersonnelStats[];
  teams: Team[];
  timerSettings: TimerSettings;
  fireOrigin: FireOrigin | null;
  incident: Record<string, string>;
  disasterResponse: { actionRows: ActionRow[]; agencyRows: AgencyRow[] };
  casualty: { rows: CasualtyRow[] };
}

export interface ActionRow {
  id?: string;
  time: string;
  content: string;
  highlight?: string;
}

export interface AgencyRow {
  id?: string;
  agency: string;
  person: string;
  arrive: string;
  action: string;
}

export interface CasualtyRow {
  id?: string;
  status: string; // 지연환자/긴급환자/응급환자/비응급환자
  name: string;
  gender: string;
  age: string;
  found: string;
  ambul: string;
  hospital: string;
  injury: string;
  etc: string;
}

export interface Identity {
  agency: string; // 기관
  dept: string; // 소속
  role: string; // 담당
}

export type LogCategory =
  | '세션'
  | '건물'
  | '상태'
  | '메모'
  | '피난약자'
  | '화점'
  | '진입대'
  | '인명피해'
  | '작전도'
  | '보고서'
  | '채팅';

export interface LogItem {
  id: string;
  at: number;
  actor: Identity;
  category: LogCategory;
  text: string;
}

export interface ChatMessage {
  id: string;
  sender: string;
  text: string;
  at: number;
}

// ── 진압작전도 ──
export interface MapItem {
  id: string;
  type: string; // MAP_TYPES 의 키, 'team', 'fire', 'text'
  x: number;
  y: number;
  w?: number;
  h?: number;
  label?: string;
  color?: string;
  rot?: number;
  teamId?: string;
  scale?: number; // 표시물 크기 배율 (1 = 원래 크기)
  by?: string; // 놓은 사람(기기) UID — 본인과 관리자만 고치고 지울 수 있다
}

export interface MapLine {
  id: string;
  by?: string;
  kind: 'route' | 'hose' | 'line';
  points: number[]; // x1,y1,x2,y2,…
  color: string;
}

// 지도(브이월드) 위 표시물 — 위치를 위도·경도로 저장해 어느 기기에서 봐도 같은 자리
export interface GeoItem {
  id: string;
  type: string;
  lat: number;
  lng: number;
  label?: string;
  color?: string;
  teamId?: string;
  scale?: number; // 표시물 크기 배율 (1 = 원래 크기)
  by?: string; // 놓은 사람(기기) UID — 본인과 관리자만 고치고 지울 수 있다
}

export interface GeoLine {
  id: string;
  by?: string;
  kind: 'route' | 'hose' | 'line';
  pts: number[]; // lat1,lng1,lat2,lng2,…
  color: string;
}

export interface GeoState {
  lat: number;
  lng: number;
  zoom: number;
  layer: 'Satellite' | 'Base';
  locked: boolean; // 고정: 모든 기기에서 같은 위치·확대로 멈춤
  address: string;
  items: GeoItem[];
  lines: GeoLine[];
}

export interface MapDoc {
  mode: 'map' | 'plan'; // 지도(브이월드) / 도면(사진 올리기)
  geo: GeoState | null;
  bg: string | null; // 배경 이미지 dataURL (도면·지도 캡처)
  bgW: number;
  bgH: number;
  items: MapItem[];
  lines: MapLine[];
}
