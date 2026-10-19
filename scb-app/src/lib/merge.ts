/** Preserve unrelated remote edits; reject overlapping edits instead of losing data. */
export class EditConflict extends Error {
  constructor() { super('다른 기기에서 같은 항목을 수정했습니다. 입력을 복사한 뒤 최신 내용을 불러와 다시 적용하세요.'); }
}
const equal = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
const record = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const keyed = (v: unknown[]): v is (Record<string, unknown> & { id: string })[] =>
  v.every((x) => record(x) && typeof x.id === 'string') && new Set(v.map((x) => (x as { id: string }).id)).size === v.length;

export function mergeEdits<T>(base: T, local: T, remote: T): T {
  if (equal(base, local)) return remote;
  if (equal(base, remote) || equal(local, remote)) return local;
  if (Array.isArray(base) && Array.isArray(local) && Array.isArray(remote)) {
    if (keyed(base) && keyed(local) && keyed(remote)) {
      const b = new Map(base.map((x) => [x.id, x]));
      const l = new Map(local.map((x) => [x.id, x]));
      const r = new Map(remote.map((x) => [x.id, x]));
      const ids = [...remote.map((x) => x.id), ...local.filter((x) => !r.has(x.id)).map((x) => x.id)];
      return ids.map((id) => mergeEdits(b.get(id), l.get(id), r.get(id))).filter((x) => x !== undefined) as T;
    }
    // Legacy rows have no IDs: do not guess identity after inserting/deleting rows.
    if (base.length === local.length && base.length === remote.length)
      return base.map((v, i) => mergeEdits(v, local[i], remote[i])) as T;
    throw new EditConflict();
  }
  if (record(base) && record(local) && record(remote)) {
    const out: Record<string, unknown> = {};
    for (const key of new Set([...Object.keys(base), ...Object.keys(local), ...Object.keys(remote)])) {
      const value = mergeEdits(base[key], local[key], remote[key]);
      if (value !== undefined) out[key] = value;
    }
    return out as T;
  }
  throw new EditConflict();
}
