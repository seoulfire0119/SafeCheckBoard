import type { Building, BuildingState, SessionData, Team, TeamLevel, TimerSettings } from '../types';
import { floorLabel, parseFloorKey } from './building';

export function teamElapsed(t: Team, now: number) {
  if (t.status !== 'waiting' && t.entryAt != null) return Math.max(0, now - t.entryAt);
  if (t.status === 'paused') return Math.max(0, t.pausedMs ?? 0);
  return 0;
}

export function teamLevel(t: Team, s: TimerSettings, now: number): TeamLevel {
  if (t.status === 'waiting') return 'waiting';
  const min = teamElapsed(t, now) / 60000;
  if (min >= s.dangerMin) return 'danger';
  if (min >= s.warnMin) return 'warning';
  return t.status;
}

export const LEVEL: Record<TeamLevel, { label: string; color: string }> = {
  waiting: { label: '대기', color: '#9e9e9e' },
  active: { label: '진입중', color: '#2e7d32' },
  warning: { label: '경고', color: '#ef6c00' },
  danger: { label: '위험', color: '#c62828' },
  paused: { label: '일시정지', color: '#78909c' },
};

export function teamPlace(buildings: Building[], states: BuildingState[], key: string) {
  const p = parseFloorKey(key);
  if (!p || !buildings[p.b]) return '';
  const fl = floorLabel(buildings[p.b], states[p.b], p.f);
  return buildings.length > 1 ? `${buildings[p.b].name} ${fl}` : fl;
}

/** 크게 보일 이름 — 단대명(신수대)이 있으면 단대명, 없으면 1착대 */
export const teamMain = (t: Team) => t.unit || t.name;
/** 작게 붙는 이름 — 단대명이 있을 때만 착대 순번 */
export const teamSub = (t: Team) => (t.unit ? t.name : '');

export function teamTitle(t: Team) {
  return t.unit ? `${t.name}(${t.unit})` : t.name;
}

/** 진입 중(일시정지 포함)인 대를 층별로 묶는다 */
export function teamsByFloor(d: SessionData) {
  const m = new Map<string, Team[]>();
  for (const t of d.teams) {
    if (t.status === 'waiting' || !t.floorKey) continue;
    const list = m.get(t.floorKey) ?? [];
    list.push(t);
    m.set(t.floorKey, list);
  }
  return m;
}

/** 경고·위험 소리 (Web Audio) */
let audio: AudioContext | null = null;
export async function enableAlarmAudio() {
  const Ctx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  audio ??= new Ctx();
  if (audio.state !== 'running') await audio.resume();
  if (audio.state !== 'running') throw new Error('경고음을 켤 수 없습니다. 기기 소리 설정을 확인하세요.');
}

export function beep(danger: boolean) {
  try {
    const c = audio;
    if (!c || c.state !== 'running') return;
    const o = c.createOscillator();
    const g = c.createGain();
    o.connect(g);
    g.connect(c.destination);
    o.type = 'square';
    o.frequency.value = danger ? 1000 : 800;
    g.gain.value = 0.15;
    g.gain.exponentialRampToValueAtTime(0.001, c.currentTime + 0.5);
    o.start();
    o.stop(c.currentTime + 0.5);
    o.onended = () => { o.disconnect(); g.disconnect(); };
  } catch {
    /* 소리 못 내는 환경 */
  }
}
