/**
 * 현황판 되돌리기 — 바뀐 곳만 골라 적어 두었다가 그곳만 원래대로 돌린다.
 *  · id 가 있는 목록(호실·진입대)은 순서가 아니라 id 로 짚는다
 *  · 그사이 다른 사람이 같은 곳을 또 바꿨으면 덮어쓰지 않고 건너뛴다
 */
export type Seg = string | number | { id: string };
export interface Change {
  path: Seg[];
  before: unknown; // undefined = 없던 것
  after: unknown;
}

const equal = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
const record = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const keyed = (v: unknown[]) =>
  v.every((x) => record(x) && typeof x.id === 'string') && new Set(v.map((x) => (x as { id: string }).id)).size === v.length;

export function diffChanges(before: unknown, after: unknown, path: Seg[] = [], out: Change[] = []): Change[] {
  if (equal(before, after)) return out;
  if (Array.isArray(before) && Array.isArray(after)) {
    if (keyed(before) && keyed(after) && (before.length || after.length)) {
      const b = new Map(before.map((x) => [(x as { id: string }).id, x]));
      const a = new Map(after.map((x) => [(x as { id: string }).id, x]));
      for (const id of new Set([...b.keys(), ...a.keys()])) diffChanges(b.get(id), a.get(id), [...path, { id }], out);
      return out;
    }
    if (before.length === after.length) {
      before.forEach((v, i) => diffChanges(v, after[i], [...path, i], out));
      return out;
    }
  } else if (record(before) && record(after)) {
    for (const k of new Set([...Object.keys(before), ...Object.keys(after)])) diffChanges(before[k], after[k], [...path, k], out);
    return out;
  }
  out.push({ path, before: structuredClone(before), after: structuredClone(after) });
  return out;
}

function getAt(root: unknown, path: Seg[]): unknown {
  let cur: unknown = root;
  for (const seg of path) {
    if (cur == null || typeof cur !== 'object') return undefined;
    cur = typeof seg === 'object' ? (cur as unknown[]).find((x) => record(x) && x.id === seg.id) : (cur as Record<string | number, unknown>)[seg];
  }
  return cur;
}

function setAt(root: unknown, path: Seg[], value: unknown): boolean {
  const parent = getAt(root, path.slice(0, -1));
  if (parent == null || typeof parent !== 'object') return false;
  const last = path[path.length - 1];
  if (typeof last === 'object') {
    if (!Array.isArray(parent)) return false;
    const i = parent.findIndex((x) => record(x) && x.id === last.id);
    if (value === undefined) {
      if (i >= 0) parent.splice(i, 1);
    } else if (i >= 0) parent[i] = structuredClone(value);
    else parent.push(structuredClone(value));
    return true;
  }
  const obj = parent as Record<string | number, unknown>;
  if (value === undefined) delete obj[last];
  else obj[last] = structuredClone(value);
  return true;
}

/** root 를 직접 고친다. 돌린 곳 수와, 남이 또 바꿔서 건너뛴 곳 수를 돌려준다 */
export function applyUndo(root: unknown, changes: Change[]): { applied: number; skipped: number } {
  let applied = 0;
  let skipped = 0;
  for (const c of [...changes].reverse()) {
    if (!equal(getAt(root, c.path), c.after)) {
      skipped++;
      continue;
    }
    if (setAt(root, c.path, c.before)) applied++;
    else skipped++;
  }
  return { applied, skipped };
}
