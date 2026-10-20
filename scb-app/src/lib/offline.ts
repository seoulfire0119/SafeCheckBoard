import type { MapDoc, SessionData } from '../types';

/**
 * 통신이 끊긴 채로 새로고침해도 마지막 화면은 보이도록 이 기기에 저장해 둔다.
 * 환자 목록(성명 등 민감정보)은 저장하지 않는다. 채팅·기록도 저장하지 않는다.
 * 저장한 화면은 서버와 다시 연결되기 전까지 읽기 전용으로만 보인다.
 */
const sessionKey = (code: string) => `scb.cache.session.${code}`;
const mapKey = (code: string) => `scb.cache.map.${code}`;
const MAX_AGE = 3 * 24 * 60 * 60 * 1000; // 사흘 지난 것은 버린다

function write(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify({ savedAt: Date.now(), value }));
  } catch {
    /* 저장 공간이 없거나 막혀 있으면 그냥 넘어간다 */
  }
}

function read<T>(key: string): { savedAt: number; value: T } | null {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const v = JSON.parse(raw) as { savedAt: number; value: T };
    if (!v || typeof v.savedAt !== 'number' || Date.now() - v.savedAt > MAX_AGE) {
      localStorage.removeItem(key);
      return null;
    }
    return v;
  } catch {
    return null;
  }
}

export function saveSessionCache(code: string, d: SessionData) {
  write(sessionKey(code), { ...d, casualty: { rows: [] } });
}

export function loadSessionCache(code: string) {
  return read<SessionData>(sessionKey(code));
}

export function saveMapCache(code: string, m: MapDoc) {
  write(mapKey(code), m);
}

export function loadMapCache(code: string) {
  return read<MapDoc>(mapKey(code));
}
