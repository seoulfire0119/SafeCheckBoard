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
  Timestamp,
  updateDoc,
  deleteDoc,
  writeBatch,
} from 'firebase/firestore';
import { db, deviceUid } from '../firebase';
import { mergeEdits } from './merge';
import { trackedSave } from './save-status';
import { joinSession } from './access';
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
import { chatSender, loadIdentity } from './identity';

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
    ...(str(m.label) ? { label: str(m.label) } : {}),
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
  const strRow = (r: unknown, index: number) => {
    const m = obj(r);
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(m)) out[k] = String(v ?? '');
    out.id ||= `legacy-${index}`;
    return out;
  };

  return {
    ownerId: str(raw.ownerId),
    closed: raw.closed === true,
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
  await joinSession(code, chatSender(loadIdentity() ?? { agency: '', dept: '', role: '' }));
  return (await getDoc(sessionRef(code))).exists();
}

export async function createSession(code: string, title: string, building: Building, state: BuildingState) {
  const uid = await deviceUid();
  const batch = writeBatch(db);
  batch.set(sessionRef(code), {
    ownerId: uid,
    closed: false,
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
  batch.set(doc(db, 'sessions', code, 'members', uid), { role: 'owner', name: '현장 개설자', joinedAt: serverTimestamp() });
  await batch.commit();
}

export function subscribeSession(code: string, cb: (d: SessionData | null) => void, onError: (e: Error) => void, connection?: (connected: boolean) => void) {
  let cancelled = false;
  let stop = () => {};
  joinSession(code, chatSender(loadIdentity() ?? { agency: '', dept: '', role: '' })).then(() => {
    if (!cancelled) stop = onSnapshot(sessionRef(code), { includeMetadataChanges: true }, (snap) => {
      connection?.(!snap.metadata.fromCache && !snap.metadata.hasPendingWrites);
      if (!snap.metadata.hasPendingWrites) cb(snap.exists() ? parseSession(snap.data()) : null);
    }, onError);
  }).catch(onError);
  return () => { cancelled = true; stop(); };
}

type Mutable = Pick<SessionData, 'title' | 'buildings' | 'states' | 'personnelStats' | 'teams' | 'timerSettings' | 'fireOrigin'>;
const MUTABLE_KEYS: (keyof Mutable)[] = ['title', 'buildings', 'states', 'personnelStats', 'teams', 'timerSettings', 'fireOrigin'];

/**
 * 여러 사람이 동시에 고쳐도 서로 덮어쓰지 않도록 트랜잭션으로
 * "최신 문서를 읽고 → 바꾸고 → 바뀐 칸만 저장" 한다.
 */
export async function mutateSession(code: string, fn: (d: SessionData) => void, audit?: { actor: Identity; category: LogCategory; text: string; at: number }) {
  const actorUid = await deviceUid();
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
    if (audit) tx.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: audit.at, actor: audit.actor, actorUid,
      category: audit.category, text: audit.text.slice(0, 500),
    });
  });
}

/** 보고서류(incident / disasterResponse / casualty)는 칸 하나를 통째로 저장 */
export async function saveField<T>(code: string, key: 'incident' | 'disasterResponse' | 'casualty', value: T, base: T): Promise<T> {
  const actorUid = await deviceUid();
  const actor = loadIdentity() ?? { agency: '', dept: '', role: '' };
  return runTransaction(db, async (tx) => {
    const ref = sessionRef(code);
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new Error('세션이 없습니다');
    const merged = mergeEdits(base, value, parseSession(snap.data())[key] as T);
    tx.update(ref, { [key]: merged, updatedAt: serverTimestamp() });
    if (JSON.stringify(merged) !== JSON.stringify(parseSession(snap.data())[key])) tx.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: Date.now(), actor, actorUid,
      category: key === 'casualty' ? '인명피해' : '보고서',
      text: key === 'casualty' ? '환자 목록 변경 저장' : key === 'incident' ? '재난발생현황 변경 저장' : '대응활동 보고서 변경 저장',
    });
    return merged;
  });
}

// ── 활동 로그 ────────────────────────────────────────────────────────
/** at: 실제로 누른 시각 (저장이 늦어져도 기록 순서가 뒤바뀌지 않게) */
export async function addLog(code: string, actor: Identity, category: LogCategory, text: string, at = Date.now()) {
  const actorUid = await deviceUid();
  await addDoc(collection(db, 'sessions', code, 'logs'), {
    at: serverTimestamp(),
    atMs: at,
    actor,
    actorUid,
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
  const actorUid = await deviceUid();
  await addDoc(collection(db, 'sessions', code, 'chat'), {
    sender: chatSender(me),
    actorUid,
    text: text.slice(0, 500),
    timestamp: serverTimestamp(),
  });
}

// ── 진압작전도 (sessions/{code}/secondary/map) ───────────────────────
export const EMPTY_MAP: MapDoc = { mode: 'map', geo: null, bg: null, bgW: 1600, bgH: 1000, items: [], lines: [] };

export function subscribeMap(code: string, cb: (m: MapDoc) => void, onError: (e: Error) => void) {
  return onSnapshot(
    doc(db, 'sessions', code, 'secondary', 'map'),
    { includeMetadataChanges: true },
    (snap) => {
      if (snap.metadata.hasPendingWrites) return;
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

/** 표시물 주인이 아니어서 고칠 수 없음 — 다시 시도해도 같으므로 "미저장"으로 남기지 않는다 */
export class MapEditDenied extends Error {
  code = 'permission-denied';
}

/**
 * 지도 표시물·선 고치기 — 저장하는 순간의 최신 작전도를 읽어서 그 위에 바꾼다.
 * 내 화면의 옛 작전도를 기준으로 합치지 않으므로, 여러 기기가 동시에 놓고·옮기고·지워도
 * "같은 항목을 수정했습니다" 충돌이 나지 않는다.
 * fn 이 null 을 돌려주면(바뀔 게 없으면) 저장하지 않는다.
 */
export function updateGeo(
  code: string,
  fn: (geo: GeoState) => Partial<Pick<GeoState, 'items' | 'lines'>> | null,
  logText: string,
  opts: { track?: boolean } = {},
) {
  return editMapLists(code, 'geo', fn as unknown as (m: Record<string, unknown>) => Record<string, unknown[]> | null, logText, opts);
}

/** 도면 모드 표시물·선 — updateGeo 와 같은 방식 */
export function updatePlan(
  code: string,
  fn: (m: Pick<MapDoc, 'items' | 'lines'>) => Partial<Pick<MapDoc, 'items' | 'lines'>> | null,
  logText: string,
) {
  return editMapLists(code, 'plan', fn as unknown as (m: Record<string, unknown>) => Record<string, unknown[]> | null, logText, {});
}

async function editMapLists(
  code: string,
  where: 'geo' | 'plan',
  fn: (m: Record<string, unknown>) => Record<string, unknown[]> | null,
  logText: string,
  opts: { track?: boolean },
) {
  const actorUid = await deviceUid();
  const actor = loadIdentity() ?? { agency: '', dept: '', role: '' };
  const run = () => runTransaction(db, async (tx) => {
    const ref = doc(db, 'sessions', code, 'secondary', 'map');
    const snap = await tx.get(ref);
    const raw = snap.exists() ? snap.data() : {};
    const g = where === 'geo' ? obj(raw.geo) : { ...EMPTY_MAP, ...raw };
    if (where === 'geo' && !Array.isArray(g.items)) throw new MapEditDenied('작전도 지도가 아직 준비되지 않았습니다. 잠시 후 다시 해 주세요.');
    const out = fn({ ...g, items: structuredClone(arr(g.items)), lines: structuredClone(arr(g.lines)) });
    if (!out) return false;
    const prefix = where === 'geo' ? 'geo.' : '';
    const patch: Record<string, unknown> = { updatedAt: serverTimestamp() };
    if (out.items) patch[`${prefix}items`] = JSON.parse(JSON.stringify(out.items));
    if (out.lines) patch[`${prefix}lines`] = JSON.parse(JSON.stringify(out.lines));
    if (snap.exists()) tx.update(ref, patch as Record<string, never>);
    else tx.set(ref, { ...EMPTY_MAP, ...patch });
    tx.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: Date.now(), actor, actorUid,
      category: '작전도', text: logText.slice(0, 500),
    });
    return true;
  });
  return opts.track === false ? run() : trackedSave(run);
}

export async function saveMap(code: string, patch: Partial<MapDoc>, base: MapDoc) {
  const actorUid = await deviceUid();
  const actor = loadIdentity() ?? { agency: '', dept: '', role: '' };
  // Firestore 는 undefined 값을 못 받으므로 JSON 왕복으로 지운다
  const clean = JSON.parse(JSON.stringify(patch)) as Partial<MapDoc>;
  return trackedSave(() => runTransaction(db, async (tx) => {
    const ref = doc(db, 'sessions', code, 'secondary', 'map');
    const snap = await tx.get(ref);
    const current = { ...EMPTY_MAP, ...snap.data() } as MapDoc;
    const merged = { ...current };
    for (const key of Object.keys(clean) as (keyof MapDoc)[]) {
      const local = key === 'geo' && clean.geo ? { ...base.geo, ...clean.geo } : clean[key];
      (merged as unknown as Record<string, unknown>)[key] = mergeEdits(base[key], local, current[key]);
    }
    tx.set(ref, { ...merged, updatedAt: serverTimestamp() });
    tx.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: Date.now(), actor, actorUid,
      category: '작전도', text: '작전도 변경 저장',
    });
    return merged;
  }));
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
