import type { Identity } from '../types';

const KEY = 'scb.identity';

// 목록에서 고르거나 직접 입력할 수 있다 (input + datalist)
export const AGENCY_PRESETS = ['소방', '경찰', '구청', '시청', '한국전력', '도시가스', '보건소', '군부대', '기타'];

export const DEPT_PRESETS: Record<string, string[]> = {
  소방: ['현장지휘팀', '119안전센터', '구조대', '구급대', '화재조사', '상황실', '소방서 지휘부', '119특수구조단'],
  경찰: ['지구대', '파출소', '경찰서 상황실', '교통과', '형사과'],
  구청: ['안전총괄과', '재난안전과', '보건소', '주민센터'],
  시청: ['재난안전대책본부', '안전총괄실'],
  한국전력: ['배전운영부', '긴급복구반'],
  도시가스: ['안전관리팀', '긴급출동반'],
  보건소: ['신속대응반', '현장응급의료소'],
};

export const ROLE_PRESETS = [
  '현장지휘관',
  '지휘팀장',
  '상황관리',
  '기록·통신',
  '진압대장',
  '구조대장',
  '구급대장',
  '대원',
  '연락관',
  '통제관',
];

export function loadIdentity(): Identity | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const v = JSON.parse(raw) as Identity;
    if (!v.agency || !v.dept || !v.role) return null;
    return v;
  } catch {
    return null;
  }
}

export function saveIdentity(v: Identity) {
  try {
    localStorage.setItem(KEY, JSON.stringify(v));
  } catch {
    /* 사생활 보호 모드 등 — 이번 접속에서만 쓴다 */
  }
}

export function identityText(v: Identity) {
  return `${v.agency} ${v.dept} ${v.role}`;
}

/** 채팅 보낸이 (Firestore 규칙상 30자 이하) */
export function chatSender(v: Identity) {
  const s = identityText(v);
  return s.length > 30 ? s.slice(0, 30) : s;
}
