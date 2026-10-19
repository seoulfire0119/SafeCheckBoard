import { useMemo, useState } from 'react';
import type { LogCategory } from '../types';
import { useSession } from '../session-context';
import { dateTime, hhmmss } from '../lib/format';
import { copyText, downloadCsv, printHtml, table } from '../lib/exporter';
import { Modal } from './Modal';

const CATS: LogCategory[] = ['상태', '화점', '진입대', '인명피해', '메모', '피난약자', '건물', '작전도', '보고서', '채팅', '세션'];

interface Row {
  at: number;
  cat: LogCategory;
  agency: string;
  dept: string;
  role: string;
  text: string;
}

/** 활동 기록 전체 보기 + 엑셀(CSV)·인쇄·복사 */
export function LogDialog({ onClose }: { onClose: () => void }) {
  const { code, data, logs, chat, toast } = useSession();
  const [cats, setCats] = useState<Set<LogCategory>>(() => new Set(CATS));
  const [who, setWho] = useState('');
  const [q, setQ] = useState('');
  const [newestFirst, setNewestFirst] = useState(true);

  const all: Row[] = useMemo(() => {
    const rows: Row[] = logs.map((l) => ({ at: l.at, cat: l.category, ...l.actor, text: l.text }));
    // 채팅도 같은 시간순 기록에 넣는다 (보낸이 = "기관 소속 담당")
    for (const m of chat) rows.push({ at: m.at, cat: '채팅', agency: '', dept: m.sender, role: '', text: m.text });
    return rows.sort((a, b) => a.at - b.at);
  }, [logs, chat]);

  const agencies = useMemo(() => Array.from(new Set(all.map((r) => r.agency).filter(Boolean))), [all]);

  const shown = useMemo(() => {
    const kw = q.trim();
    const r = all.filter(
      (x) =>
        cats.has(x.cat) &&
        (!who || x.agency === who) &&
        (!kw || `${x.text} ${x.agency} ${x.dept} ${x.role}`.includes(kw)),
    );
    return newestFirst ? [...r].reverse() : r;
  }, [all, cats, who, q, newestFirst]);

  const chronological = newestFirst ? [...shown].reverse() : shown;
  const fileBase = `현장기록_${data.title || code}_${new Date().toISOString().slice(0, 10)}`.replace(/[\\/:*?"<>|\s]+/g, '_');
  const header = ['시각', '분류', '기관', '소속', '담당', '내용'];
  const asRows = () => chronological.map((r) => [dateTime(r.at), r.cat, r.agency, r.dept, r.role, r.text]);

  const toggle = (c: LogCategory) =>
    setCats((s) => {
      const n = new Set(s);
      if (n.has(c)) n.delete(c);
      else n.add(c);
      return n;
    });

  return (
    <Modal
      title={`활동 기록 — ${shown.length}건`}
      onClose={onClose}
      full
      footer={
        <>
          <span className="hint">기록은 지울 수 없게 저장됩니다.</span>
          <span className="grow" />
          <button
            className="btn"
            onClick={async () => {
              const text = chronological.map((r) => `${hhmmss(r.at)} [${r.cat}] ${[r.agency, r.dept, r.role].filter(Boolean).join(' ')}: ${r.text}`).join('\n');
              (await copyText(text)) && toast(`${chronological.length}건 복사됨`);
            }}
          >
            📋 복사
          </button>
          <button
            className="btn"
            onClick={() =>
              printHtml(
                fileBase,
                `<h1>현장 활동 기록</h1><div class="meta">${data.title ? `${data.title} · ` : ''}세션 ${code} · 출력 ${dateTime(Date.now())} · ${chronological.length}건</div>${table(header, asRows())}`,
              )
            }
          >
            🖨 인쇄
          </button>
          <button className="btn primary" onClick={() => downloadCsv(`${fileBase}.csv`, header, asRows())}>
            ⬇ 엑셀(CSV) 받기
          </button>
        </>
      }
    >
      <div className="log-filters">
        <div className="chips">
          {CATS.map((c) => (
            <button key={c} className={`chip ${cats.has(c) ? 'on' : ''}`} onClick={() => toggle(c)}>
              {c}
            </button>
          ))}
          <button className="chip ghost" onClick={() => setCats(new Set(cats.size === CATS.length ? [] : CATS))}>
            {cats.size === CATS.length ? '모두 끄기' : '모두 켜기'}
          </button>
        </div>
        <div className="row-btns">
          <select value={who} onChange={(e) => setWho(e.target.value)}>
            <option value="">모든 기관</option>
            {agencies.map((a) => (
              <option key={a}>{a}</option>
            ))}
          </select>
          <input value={q} placeholder="검색 (예: 301호, 2착대)" onChange={(e) => setQ(e.target.value)} />
          <button className="btn small" onClick={() => setNewestFirst(!newestFirst)}>
            {newestFirst ? '↓ 최신순' : '↑ 시간순'}
          </button>
        </div>
      </div>
      <div className="log-table-wrap">
        <table className="log-table">
          <thead>
            <tr>
              <th>시각</th>
              <th>분류</th>
              <th>기록자</th>
              <th>내용</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((r, i) => (
              <tr key={i} className={`cat-${r.cat}`}>
                <td className="mono">{hhmmss(r.at)}</td>
                <td>
                  <span className="cat">{r.cat}</span>
                </td>
                <td className="who">{[r.agency, r.dept, r.role].filter(Boolean).join(' ')}</td>
                <td>{r.text}</td>
              </tr>
            ))}
            {shown.length === 0 && (
              <tr>
                <td colSpan={4} className="hint">
                  조건에 맞는 기록이 없습니다
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </Modal>
  );
}
