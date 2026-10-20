import { Clock, HardHat, UserRound } from 'lucide-react';
import type { SessionData } from '../types';
import { teamLevel } from '../lib/teams';

const p2 = (n: number) => String(n).padStart(2, '0');

/** 재난발생현황의 "일시"(예: 2026-10-19 14:32)를 읽는다. 못 읽으면 null */
function parseIncidentDate(s: string | undefined): number | null {
  const m = s?.trim().match(/^(\d{4})[-.\/](\d{1,2})[-.\/](\d{1,2})[ T]+(\d{1,2}):(\d{2})/);
  if (!m) return null;
  const t = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]).getTime();
  return Number.isFinite(t) ? t : null;
}

/**
 * 큰 화면에서 한눈에 보는 요약 — 경과시간 · 진입대 · 인명 (진압작전도 탭에서만 보임)
 * 경과시간은 재난발생현황 일시(최초 신고)가 있으면 그때부터, 없으면 현장을 연 때부터.
 */
export function SummaryBar({ data, now }: { data: SessionData; now: number }) {
  const start = parseIncidentDate(data.incident.date) ?? (data.createdAt || null);
  const elapsed = start ? Math.max(0, now - start) : null;
  const sec = elapsed == null ? 0 : Math.floor(elapsed / 1000);

  const active = data.teams.filter((t) => t.status !== 'waiting');
  const levels = active.map((t) => teamLevel(t, data.timerSettings, now));
  const danger = levels.filter((l) => l === 'danger').length;
  const warning = levels.filter((l) => l === 'warning').length;

  const sum = (k: 'selfEvac' | 'rescued' | 'notFound') => data.personnelStats.reduce((n, s) => n + s[k], 0);
  const rows = data.casualty.rows.filter((r) => r.status);
  const tri = (k: string) => rows.filter((r) => r.status === k).length;


  return (
    <div className="summary-bar">
      <div className="sm" title={start ? `기준 ${new Date(start).toLocaleString('ko-KR')}` : ''}>
        <Clock size={18} />
        <span>경과</span>
        <b>{elapsed == null ? '–' : `${Math.floor(sec / 3600)}:${p2(Math.floor((sec % 3600) / 60))}:${p2(sec % 60)}`}</b>
      </div>
      <div className={`sm ${danger ? 'danger' : warning ? 'warning' : ''}`}>
        <HardHat size={18} />
        <span>진입대</span>
        <b>{active.length}</b>
        {(danger > 0 || warning > 0) && (
          <em>
            {danger > 0 && `위험 ${danger}`} {warning > 0 && `경고 ${warning}`}
          </em>
        )}
      </div>
      <div className={`sm ${sum('notFound') ? 'danger' : ''}`}>
        <UserRound size={18} />
        <span>인명</span>
        <b>
          자력대피 {sum('selfEvac')} · 구조 {sum('rescued')} · <i className={sum('notFound') ? 'red' : ''}>미발견 {sum('notFound')}</i>
        </b>
      </div>
      {rows.length > 0 && (
        <div className="sm">
          <span>환자</span>
          <b>
            {rows.length}명 <small>(긴급 {tri('긴급환자')} · 응급 {tri('응급환자')} · 비응급 {tri('비응급환자')} · 지연 {tri('지연환자')})</small>
          </b>
        </div>
      )}
    </div>
  );
}
