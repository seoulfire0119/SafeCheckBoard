import {
  addDoc,
  collection,
  doc,
  getDoc,
  limitToLast,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  deleteDoc,
} from 'firebase/firestore';
import { db } from '../firebase';
import type {
  Building,
  BuildingState,
  ChatMessage,
  Identity,
  LogCategory,
  GeoState,
  LogItem,
  MapDoc,
  SessionData,
  Team,
  Unit,
} from '../types';
import { chatSender } from './identity';

export const TEAM_COLORS = ['#e53935', '#ff6d00', '#f9a825', '#43a047', '#1e88e5', '#3949ab', '#8e24aa'];

export function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const buf = new Uint32Array(6);
  crypto.getRandomValues(buf);
  return Array.from(buf, (n) => chars[n % chars.length]).join('');
}

export function defaultTeams(): Team[] {
  return [1, 2, 3].map((n) => ({
    id: String(n),
    name: `${n}착대`,
    unit: '',
    color: TEAM_COLORS[n - 1],
    floorKey: '',
    task: '',
    status: 'waiting',
    entryAt: null,
    pausedMs: null,
  }));
}

const sessionRef = (code: string) => doc(db, 'sessions', code);

// ── 읽기 (Flutter 버전이 쓴 문서도 읽을 수 있게 방어적으로) ─────────────
const num = (v: unknown, d = 0) => (typeof v === 'number' && Number.isFinite(v) ? v : d);
const str = (v: unknown, d = '') => (typeof v === 'string' ? v : d);
const obj = (v: unknown) => (v && typeof v === 'object' ? (v as Record<string, unknown>) : {});
const arr = (v: unknown) => (Array.isArray(v) ? (v as unknown[]) : []);

function parseUnit(u: unknown): Unit {
  const m = obj(u);
  return {
    id: str(m.id),
    floor: num(m.floor),
    unitIndex: num(m.unitIndex, 1),
    number: num(m.number),
    status: (['unknown', 'confirmed', 'danger', 'fireFalseAlarm', 'resourceBase'].includes(str(m.status))
      ? m.status
      : 'unknown') as Unit['status'],
    memo: str(m.memo),
    memoPinned: m.memoPinned === true,
    vulnerable: m.vulnerable === true,
    spanCount: Math.max(1, num(m.spanCount, 1)),
  };
}

export function parseSession(raw: Record<string, unknown>): SessionData {
  const buildings: Building[] = arr(raw.buildings).map((b) => {
    const m = obj(b);
    return {
      name: str(m.name, '건물'),
      startFloor: num(m.startFloor, 1),
      endFloor: num(m.endFloor, 1),
      defaultUnits: Math.max(1, num(m.defaultUnits, 1)),
      isHorizontal: m.isHorizontal === true,
    };
  });
  const states: BuildingState[] = arr(raw.states).map((s) => {
    const m = obj(s);
    const labels: Record<string, string> = {};
    for (const [k, v] of Object.entries(obj(m.floorLabels))) if (typeof v === 'string') labels[k] = v;
    return {
      units: arr(m.units).map(parseUnit),
      hiddenFloors: arr(m.hiddenFloors).filter((x): x is number => typeof x === 'number'),
      floorLabels: labels,
    };
  });
  while (states.length < buildings.length) states.push({ units: [], hiddenFloors: [], floorLabels: {} });
  const personnelStats = arr(raw.personnelStats).map((s) => {
    const m = obj(s);
    return { selfEvac: num(m.selfEvac), rescued: num(m.rescued), notFound: num(m.notFound) };
  });
  while (personnelStats.length < buildings.length) personnelStats.push({ selfEvac: 0, rescued: 0, notFound: 0 });

  const teams: Team[] = Array.isArray(raw.teams)
    ? arr(raw.teams).map((t, i) => {
        const m = obj(t);
        const st = str(m.status);
        return {
          id: str(m.id, String(i + 1)),
          name: str(m.name, `${i + 1}착대`),
          unit: str(m.unit),
          color: str(m.color, TEAM_COLORS[i % TEAM_COLORS.length]),
          floorKey: str(m.floorKey),
          task: str(m.task),
          status: (st === 'active' || st === 'paused' ? st : 'waiting') as Team['status'],
          entryAt: typeof m.entryAt === 'number' ? m.entryAt : null,
          pausedMs: typeof m.pausedMs === 'number' ? m.pausedMs : null,
        };
      })
    : defaultTeams();

  const ts = obj(raw.timerSettings);
  const fo = raw.fireOrigin ? obj(raw.fireOrigin) : null;
  const incident: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj(raw.incident))) incident[k] = String(v ?? '');
  const dr = obj(raw.disasterResponse);
  const strRow = (r: unknown) => {
    const m = obj(r);
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(m)) out[k] = String(v ?? '');
    return out;
  };

  return {
    title: str(raw.title),
    buildings,
    states,
    personnelStats,
    teams,
    timerSettings: { warnMin: num(ts.warnMin, 15), dangerMin: num(ts.dangerMin, 20) },
    fireOrigin: fo
      ? {
          buildingIdx: num(fo.buildingIdx),
          unitId: typeof fo.unitId === 'string' ? fo.unitId : null,
          floor: num(fo.floor),
          note: str(fo.note),
          by: str(fo.by),
          at: num(fo.at),
        }
      : null,
    incident,
    disasterResponse: {
      actionRows: arr(dr.actionRows).map(strRow) as unknown as SessionData['disasterResponse']['actionRows'],
      agencyRows: arr(dr.agencyRows).map(strRow) as unknown as SessionData['disasterResponse']['agencyRows'],
    },
    casualty: {
      rows: arr(obj(raw.casualty).rows).map(strRow) as unknown as SessionData['casualty']['rows'],
    },
  };
}

// ── 세션 ─────────────────────────────────────────────────────────────
export async function sessionExists(code: string) {
  return (await getDoc(sessionRef(code))).exists();
}

export async function createSession(code: string, title: string, building: Building, state: BuildingState) {
  await setDoc(sessionRef(code), {
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    title,
    buildings: [building],
    states: [state],
    personnelStats: [{ selfEvac: 0, rescued: 0, notFound: 0 }],
    log: [],
    teams: defaultTeams(),
    timerSettings: { warnMin: 15, dangerMin: 20 },
    fireOrigin: null,
  });
}

export function subscribeSession(code: string, cb: (d: SessionData | null) => void, onError: (e: Error) => void) {
  return onSnapshot(
    sessionRef(code),
    (snap) => cb(snap.exists() ? parseSession(snap.data()) : null),
    onError,
  );
}

type Mutable = Pick<SessionData, 'title' | 'buildings' | 'states' | 'personnelStats' | 'teams' | 'timerSettings' | 'fireOrigin'>;
const MUTABLE_KEYS: (keyof Mutable)[] = ['title', 'buildings', 'states', 'personnelStats', 'teams', 'timerSettings', 'fireOrigin'];

/**
 * 여러 사람이 동시에 고쳐도 서로 덮어쓰지 않도록 트랜잭션으로
 * "최신 문서를 읽고 → 바꾸고 → 바뀐 칸만 저장" 한다.
 */
export async function mutateSession(code: string, fn: (d: SessionData) => void) {
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(sessionRef(code));
    if (!snap.exists()) throw new Error('세션이 없습니다');
    const before = parseSession(snap.data());
    const after = structuredClone(before);
    fn(after);
    const patch: Record<string, unknown> = {};
    for (const k of MUTABLE_KEYS) {
      if (JSON.stringify(before[k]) !== JSON.stringify(after[k])) patch[k] = after[k];
    }
    if (Object.keys(patch).length === 0) return;
    patch.updatedAt = serverTimestamp();
    tx.update(sessionRef(code), patch as Record<string, never>);
  });
}

/** 보고서류(incident / disasterResponse / casualty)는 칸 하나를 통째로 저장 */
export async function saveField(code: string, key: 'incident' | 'disasterResponse' | 'casualty', value: unknown) {
  await updateDoc(sessionRef(code), { [key]: value, updatedAt: serverTimestamp() });
}

// ── 활동 로그 ────────────────────────────────────────────────────────
/** at: 실제로 누른 시각 (저장이 늦어져도 기록 순서가 뒤바뀌지 않게) */
export async function addLog(code: string, actor: Identity, category: LogCategory, text: string, at = Date.now()) {
  await addDoc(collection(db, 'sessions', code, 'logs'), {
    at: serverTimestamp(),
    atMs: at,
    actor,
    category,
    text: text.slice(0, 500),
  });
}

export function subscribeLogs(code: string, cb: (items: LogItem[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    query(collection(db, 'sessions', code, 'logs'), orderBy('atMs')),
    (snap) =>
      cb(
        snap.docs.map((d) => {
          const m = d.data();
          const a = obj(m.actor);
          return {
            id: d.id,
            at: num(m.atMs, Date.now()),
            actor: { agency: str(a.agency), dept: str(a.dept), role: str(a.role) },
            category: str(m.category, '세션') as LogCategory,
            text: str(m.text),
          };
        }),
      ),
    onError,
  );
}

// ── 채팅 ─────────────────────────────────────────────────────────────
export function subscribeChat(code: string, cb: (items: ChatMessage[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    query(collection(db, 'sessions', code, 'chat'), orderBy('timestamp'), limitToLast(300)),
    (snap) =>
      cb(
        snap.docs.map((d) => {
          const m = d.data({ serverTimestamps: 'estimate' });
          const t = m.timestamp instanceof Timestamp ? m.timestamp.toMillis() : Date.now();
          return { id: d.id, sender: str(m.sender), text: str(m.text), at: t };
        }),
      ),
    onError,
  );
}

export async function sendChat(code: string, me: Identity, text: string) {
  await addDoc(collection(db, 'sessions', code, 'chat'), {
    sender: chatSender(me),
    text: text.slice(0, 500),
    timestamp: serverTimestamp(),
  });
}

// ── 진압작전도 (sessions/{code}/secondary/map) ───────────────────────
export const EMPTY_MAP: MapDoc = { mode: 'map', geo: null, bg: null, bgW: 1600, bgH: 1000, items: [], lines: [] };

export function subscribeMap(code: string, cb: (m: MapDoc) => void, onError: (e: Error) => void) {
  return onSnapshot(
    doc(db, 'sessions', code, 'secondary', 'map'),
    (snap) => {
      if (!snap.exists()) return cb(EMPTY_MAP);
      const m = snap.data();
      const g = m.geo ? obj(m.geo) : null;
      cb({
        mode: m.mode === 'plan' ? 'plan' : 'map',
        geo: g
          ? {
              lat: num(g.lat, 37.5665),
              lng: num(g.lng, 126.978),
              zoom: num(g.zoom, 18),
              layer: g.layer === 'Base' ? 'Base' : 'Satellite',
              locked: g.locked === true,
              address: str(g.address),
              items: arr(g.items) as GeoState['items'],
              lines: arr(g.lines) as GeoState['lines'],
            }
          : null,
        bg: typeof m.bg === 'string' ? m.bg : null,
        bgW: num(m.bgW, 1600),
        bgH: num(m.bgH, 1000),
        items: arr(m.items) as MapDoc['items'],
        lines: arr(m.lines) as MapDoc['lines'],
      });
    },
    onError,
  );
}

export async function saveMap(code: string, patch: Partial<MapDoc>) {
  // Firestore 는 undefined 값을 못 받으므로 JSON 왕복으로 지운다
  const clean = JSON.parse(JSON.stringify(patch)) as Partial<MapDoc>;
  await setDoc(doc(db, 'sessions', code, 'secondary', 'map'), { ...clean, updatedAt: serverTimestamp() }, { merge: true });
}

// ── 브리핑 게시판 (sessions/{code}/briefings) ────────────────────────
// Flutter 버전은 최상위 briefings 컬렉션을 썼지만, 목록 조회 규칙이 동작하지 않아
// 세션 코드를 아는 사람만 보도록 세션 아래로 옮겼다.
export interface BriefingRecord {
  id: string;
  title: string;
  tabType: number; // 0 초동, 1 중간, 2 공식
  updatedAt: number;
  fields: Record<string, string>;
}

export function subscribeBriefings(code: string, cb: (items: BriefingRecord[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    collection(db, 'sessions', code, 'briefings'),
    (snap) =>
      cb(
        snap.docs
          .map((d) => {
            const m = d.data({ serverTimestamps: 'estimate' });
            const fields: Record<string, string> = {};
            for (const [k, v] of Object.entries(obj(m.fields))) fields[k] = String(v ?? '');
            return {
              id: d.id,
              title: str(m.title),
              tabType: num(m.tabType),
              updatedAt: m.updatedAt instanceof Timestamp ? m.updatedAt.toMillis() : Date.now(),
              fields,
            };
          })
          .sort((a, b) => b.updatedAt - a.updatedAt),
      ),
    onError,
  );
}

export async function saveBriefing(code: string, rec: Omit<BriefingRecord, 'id' | 'updatedAt'>, id?: string) {
  if (id) {
    await updateDoc(doc(db, 'sessions', code, 'briefings', id), {
      title: rec.title,
      tabType: rec.tabType,
      fields: rec.fields,
      sessionCode: code,
      updatedAt: serverTimestamp(),
    });
    return id;
  }
  const ref = await addDoc(collection(db, 'sessions', code, 'briefings'), {
    sessionCode: code,
    title: rec.title,
    tabType: rec.tabType,
    fields: rec.fields,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return ref.id;
}

export async function deleteBriefing(code: string, id: string) {
  await deleteDoc(doc(db, 'sessions', code, 'briefings', id));
}
