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
import { diffChanges, type Change } from './undo';
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
  MapItem,
  MapLine,
  GeoItem,
  GeoLine,
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
    createdAt: raw.createdAt instanceof Timestamp ? raw.createdAt.toMillis() : num(raw.createdAt),
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
/** 돌려주는 값: 실제로 바뀐 곳 목록 (되돌리기용). 바뀐 게 없으면 빈 목록 */
export async function mutateSession(code: string, fn: (d: SessionData) => void, audit?: { actor: Identity; category: LogCategory; text: string; at: number }): Promise<Change[]> {
  const actorUid = await deviceUid();
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(sessionRef(code));
    if (!snap.exists()) throw new Error('세션이 없습니다');
    const before = parseSession(snap.data());
    const after = structuredClone(before);
    fn(after);
    const patch: Record<string, unknown> = {};
    const changes: Change[] = [];
    for (const k of MUTABLE_KEYS) {
      if (JSON.stringify(before[k]) !== JSON.stringify(after[k])) {
        patch[k] = after[k];
        diffChanges(before[k], after[k], [k], changes);
      }
    }
    if (Object.keys(patch).length === 0) return changes;
    patch.updatedAt = serverTimestamp();
    tx.update(sessionRef(code), patch as Record<string, never>);
    if (audit) tx.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: audit.at, actor: audit.actor, actorUid,
      category: audit.category, text: audit.text.slice(0, 500),
    });
    return changes;
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

/**
 * 작전도는 세 곳에 나눠 저장한다.
 *  · secondary/map    — 모드·지도 위치·고정·도면 크기 (작고 가벼움)
 *  · secondary/mapBg  — 도면 사진 (무거움, 바꿀 때만 저장)
 *  · mapObjects/{id}  — 표시물·선 하나하나 (놓은 사람 by — 본인과 관리자만 고치고 지울 수 있게 서버 규칙으로 막음)
 * 예전 현장은 표시물·사진이 secondary/map 안에 들어 있으므로 함께 읽고, 관리자가 열면 옮긴다(migrateLegacyMap).
 */
export interface LegacyMap {
  planItems: MapItem[];
  planLines: MapLine[];
  geoItems: GeoItem[];
  geoLines: GeoLine[];
  bg: string | null;
}
export const hasLegacy = (l: LegacyMap) => !!(l.planItems.length || l.planLines.length || l.geoItems.length || l.geoLines.length || l.bg);

type MapObjectDoc = Record<string, unknown> & { space: 'geo' | 'plan'; kind: 'item' | 'line'; by?: string | null };

function parseMapDoc(m: Record<string, unknown>): MapDoc {
  const g = m.geo ? obj(m.geo) : null;
  return {
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
  };
}

/** 세 곳을 모두 지켜보다가 합친 작전도를 넘겨준다 */
export function subscribeMap(code: string, cb: (m: MapDoc, legacy: LegacyMap) => void, onError: (e: Error) => void) {
  let base: MapDoc | null = null;
  let bg: string | null | undefined; // undefined = mapBg 문서 없음 (예전 현장)
  let objects: { id: string; d: MapObjectDoc }[] = [];
  const emit = () => {
    if (!base) return;
    const ids = new Set(objects.map((o) => o.id));
    const pick = (space: string, kind: string) =>
      objects
        .filter((o) => o.d.space === space && o.d.kind === kind)
        .map((o) => {
          const { space: _s, kind: _k, updatedAt: _u, ...rest } = o.d;
          return { ...rest, id: o.id, by: typeof rest.by === 'string' ? rest.by : undefined };
        });
    // 아직 옮기지 않은 예전 표시물. 화면에서는 놓은 사람 기록을 지워서 관리자만 다루게 한다(옮기기 전까지)
    const legacyOf = <T extends { id: string }>(list: T[]) => list.filter((x) => !ids.has(safeObjId(x.id)));
    const strip = <T extends { by?: string }>(list: T[]) => list.map((x) => ({ ...x, by: undefined }));
    const legacy: LegacyMap = {
      planItems: legacyOf(base.items),
      planLines: legacyOf(base.lines),
      geoItems: legacyOf(base.geo?.items ?? []),
      geoLines: legacyOf(base.geo?.lines ?? []),
      bg: base.bg,
    };
    cb(
      {
        ...base,
        bg: bg !== undefined ? bg : base.bg,
        items: [...strip(legacy.planItems), ...(pick('plan', 'item') as MapItem[])],
        lines: [...strip(legacy.planLines), ...(pick('plan', 'line') as MapLine[])],
        geo: base.geo
          ? {
              ...base.geo,
              items: [...strip(legacy.geoItems), ...(pick('geo', 'item') as GeoItem[])],
              lines: [...strip(legacy.geoLines), ...(pick('geo', 'line') as GeoLine[])],
            }
          : null,
      },
      legacy,
    );
  };
  const u1 = onSnapshot(doc(db, 'sessions', code, 'secondary', 'map'), { includeMetadataChanges: true }, (snap) => {
    if (snap.metadata.hasPendingWrites) return;
    base = snap.exists() ? parseMapDoc(snap.data()) : EMPTY_MAP;
    emit();
  }, onError);
  // 서버 규칙이 아직 예전 버전이면 새 저장 위치(mapBg·mapObjects)를 못 읽는다.
  // 그때는 예전 방식 작전도만 보여 주고, 알림은 한 번만 한다 (작전도 자체는 계속 보이게)
  const partial = (e: Error & { code?: string }) => {
    if (e.code !== 'permission-denied') return onError(e);
    emit();
    onError(Object.assign(new Error('서버 보안 규칙이 아직 새 버전이 아닙니다. 예전 표시물만 보이며, 새 표시물 저장은 규칙을 배포해야 됩니다.'), { code: 'rules-outdated' }));
  };
  const u2 = onSnapshot(doc(db, 'sessions', code, 'secondary', 'mapBg'), (snap) => {
    bg = snap.exists() ? (typeof snap.data().bg === 'string' ? snap.data().bg : null) : undefined;
    emit();
  }, partial);
  // 표시물은 내가 놓은 것이 저장되기 전에도 바로 보이게(낙관적) 한다. 거절되면 저절로 되돌아간다
  const u3 = onSnapshot(collection(db, 'sessions', code, 'mapObjects'), (snap) => {
    objects = snap.docs.map((d) => ({ id: d.id, d: d.data() as MapObjectDoc }));
    emit();
  }, partial);
  return () => { u1(); u2(); u3(); };
}

/** 표시물 주인이 아니어서 고칠 수 없음 — 다시 시도해도 같으므로 "미저장"으로 남기지 않는다 */
export class MapEditDenied extends Error {
  code = 'permission-denied';
}

/** Firestore 문서 이름에 쓸 수 없는 '/' 를 바꾼다 */
export const safeObjId = (id: string) => (id.replace(/\//g, '∕').slice(0, 300) || 'x');
const objRef = (code: string, id: string) => doc(db, 'sessions', code, 'mapObjects', safeObjId(id));
const cleanObj = (o: object) => JSON.parse(JSON.stringify(o)) as Record<string, unknown>;

async function commitWithLog(code: string, text: string, fill: (b: ReturnType<typeof writeBatch>) => void, track = true) {
  const actorUid = await deviceUid();
  const actor = loadIdentity() ?? { agency: '', dept: '', role: '' };
  const run = async () => {
    const b = writeBatch(db);
    fill(b);
    b.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: Date.now(), actor, actorUid, category: '작전도', text: text.slice(0, 500),
    });
    await b.commit();
  };
  return track ? trackedSave(run) : run();
}

/** 표시물·선 하나 놓기 (놓은 사람 = 이 기기) */
export async function addMapObject(code: string, space: 'geo' | 'plan', kind: 'item' | 'line', o: { id: string } & object, text: string) {
  const by = await deviceUid();
  const { id, ...rest } = cleanObj(o) as { id: string } & Record<string, unknown>;
  return commitWithLog(code, text, (b) => b.set(objRef(code, id), { ...rest, space, kind, by, updatedAt: serverTimestamp() }));
}

/** 표시물·선 하나 고치기 — 남의 것이면 서버가 거절한다 */
export function updateMapObject(code: string, id: string, patch: object, text: string) {
  const { id: _id, by: _by, ...rest } = cleanObj(patch) as Record<string, unknown>;
  return commitWithLog(code, text, (b) => b.update(objRef(code, id), { ...rest, updatedAt: serverTimestamp() }));
}

export function removeMapObject(code: string, id: string, text: string) {
  return commitWithLog(code, text, (b) => b.delete(objRef(code, id)));
}

/**
 * 여러 개를 한 번에 놓거나 지운다 (현황판 따라가기·자동 배치·도면 바꿀 때 위치 맞추기).
 * upserts 의 by 는 부르는 쪽이 정한다 (저절로 생긴 표시물은 null).
 */
export function saveMapObjects(
  code: string,
  space: 'geo' | 'plan',
  kind: 'item' | 'line',
  upserts: ({ id: string; by?: string | null } & object)[],
  removes: string[],
  text: string,
  opts: { track?: boolean } = {},
) {
  if (!upserts.length && !removes.length) return Promise.resolve();
  return commitWithLog(
    code,
    text,
    (b) => {
      for (const o of upserts) {
        const { id, ...rest } = cleanObj(o) as { id: string } & Record<string, unknown>;
        b.set(objRef(code, id), { ...rest, by: typeof o.by === 'string' ? o.by : null, space, kind, updatedAt: serverTimestamp() });
      }
      for (const id of removes) b.delete(objRef(code, id));
    },
    opts.track !== false,
  );
}

/** 도면 사진 저장·지우기 (무거운 사진은 따로 저장) */
export async function saveMapBg(code: string, bg: string | null, bgW: number, bgH: number) {
  const actorUid = await deviceUid();
  const actor = loadIdentity() ?? { agency: '', dept: '', role: '' };
  return trackedSave(async () => {
    const mapRef = doc(db, 'sessions', code, 'secondary', 'map');
    const exists = (await getDoc(mapRef)).exists();
    const b = writeBatch(db);
    b.set(doc(db, 'sessions', code, 'secondary', 'mapBg'), { bg, updatedAt: serverTimestamp() });
    if (exists) b.update(mapRef, { bg: null, bgW, bgH, updatedAt: serverTimestamp() });
    else b.set(mapRef, { ...EMPTY_MAP, bgW, bgH, updatedAt: serverTimestamp() });
    b.set(doc(collection(db, 'sessions', code, 'logs')), {
      at: serverTimestamp(), atMs: Date.now(), actor, actorUid, category: '작전도', text: bg ? '도면 사진 올림' : '도면 사진 지움',
    });
    await b.commit();
  });
}

/**
 * 예전 방식(문서 하나에 다 들어 있던) 작전도를 새 방식으로 옮긴다. 관리자만 할 수 있다.
 * 놓은 사람 기록이 있으면 그대로 옮기고, 없으면 관리자만 다룰 수 있는 표시물이 된다.
 */
export async function migrateLegacyMap(code: string, raw: LegacyMap) {
  const all: { space: 'geo' | 'plan'; kind: 'item' | 'line'; o: { id: string } & Record<string, unknown> }[] = [
    ...raw.planItems.map((o) => ({ space: 'plan' as const, kind: 'item' as const, o: o as unknown as { id: string } & Record<string, unknown> })),
    ...raw.planLines.map((o) => ({ space: 'plan' as const, kind: 'line' as const, o: o as unknown as { id: string } & Record<string, unknown> })),
    ...raw.geoItems.map((o) => ({ space: 'geo' as const, kind: 'item' as const, o: o as unknown as { id: string } & Record<string, unknown> })),
    ...raw.geoLines.map((o) => ({ space: 'geo' as const, kind: 'line' as const, o: o as unknown as { id: string } & Record<string, unknown> })),
  ];
  for (let i = 0; i < all.length; i += 400) {
    const b = writeBatch(db);
    for (const { space, kind, o } of all.slice(i, i + 400)) {
      const { id, by, ...rest } = cleanObj(o) as { id: string } & Record<string, unknown>;
      b.set(objRef(code, id), { ...rest, space, kind, by: typeof by === 'string' ? by : null, updatedAt: serverTimestamp() });
    }
    await b.commit();
  }
  const mapRef = doc(db, 'sessions', code, 'secondary', 'map');
  const snap = await getDoc(mapRef);
  const b = writeBatch(db);
  if (raw.bg) b.set(doc(db, 'sessions', code, 'secondary', 'mapBg'), { bg: raw.bg, updatedAt: serverTimestamp() });
  b.update(mapRef, {
    items: [], lines: [], bg: null, updatedAt: serverTimestamp(),
    ...(snap.data()?.geo ? { 'geo.items': [], 'geo.lines': [] } : {}),
  });
  await b.commit();
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
