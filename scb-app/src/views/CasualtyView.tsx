import { useCallback, useRef, useState } from 'react';
import { Copy, Download, Plus, Printer } from 'lucide-react';
import type { CasualtyRow } from '../types';
import { useSession } from '../session-context';
import { saveField } from '../lib/session';
import { useSynced } from '../lib/useSynced';
import { maskName } from '../lib/format';
import { copyText, downloadCsv, printHtml, table } from '../lib/exporter';

export const TRIAGE = [
  { key: '지연환자', color: '#212121', fg: '#fff' },
  { key: '긴급환자', color: '#d32f2f', fg: '#fff' },
  { key: '응급환자', color: '#f9a825', fg: '#111' },
  { key: '비응급환자', color: '#2e7d32', fg: '#fff' },
];

const COLS: { key: keyof CasualtyRow; label: string; ph: string; w: string }[] = [
  { key: 'name', label: '성명(국적)', ph: '홍길동', w: '11%' },
  { key: 'gender', label: '성별', ph: '남/여', w: '6%' },
  { key: 'age', label: '연령', ph: '45', w: '6%' },
  { key: 'found', label: '발견장소', ph: '3층 복도', w: '12%' },
  { key: 'ambul', label: '구급대', ph: '○○구급대', w: '11%' },
  { key: 'hospital', label: '이송병원/현장처치', ph: '○○병원', w: '14%' },
  { key: 'injury', label: '부상정도(부위)', ph: '2도 화상/팔', w: '14%' },
  { key: 'etc', label: '기타', ph: '비고', w: '12%' },
];

const emptyRow = (): CasualtyRow => ({ status: '', name: '', gender: '', age: '', found: '', ambul: '', hospital: '', injury: '', etc: '' });

export function CasualtyView() {
  const { code, data, log, toast } = useSession();
  const save = useCallback(
    (rows: CasualtyRow[]) => saveField(code, 'casualty', { rows }).catch((e: Error) => toast(`저장 실패: ${e.message}`, 'error')),
    [code, toast],
  );
  const [rows, setRows, flush] = useSynced<CasualtyRow[]>(data.casualty.rows, save);
  const [focus, setFocus] = useState<string | null>(null);
  const [showNames, setShowNames] = useState(false);
  const focusVal = useRef('');

  const count = (k: string) => rows.filter((r) => r.status === k).length;
  const total = rows.filter((r) => r.status).length;
  const ps = data.personnelStats.reduce(
    (a, s) => ({ selfEvac: a.selfEvac + s.selfEvac, rescued: a.rescued + s.rescued, notFound: a.notFound + s.notFound }),
    { selfEvac: 0, rescued: 0, notFound: 0 },
  );

  const setCell = (i: number, k: keyof CasualtyRow, v: string) => setRows((rs) => rs.map((r, j) => (j === i ? { ...r, [k]: v } : r)));
  const header = ['연번', '구분', ...COLS.map((c) => c.label)];
  const asRows = (mask: boolean) =>
    rows.map((r, i) => [i + 1, r.status, ...COLS.map((c) => (c.key === 'name' && mask ? maskName(r.name) : r[c.key]))]);

  return (
    <div className="casualty-view">
      <div className="cv-top">
        <div className="triage-cards">
          <div className="tcard total">
            <span>환자 총계</span>
            <b>{total}</b>
          </div>
          {TRIAGE.map((t) => (
            <div key={t.key} className="tcard" style={{ background: t.color, color: t.fg }}>
              <span>{t.key.replace('환자', '')}</span>
              <b>{count(t.key)}</b>
            </div>
          ))}
          <div className="tcard ps">
            <span>건물 집계</span>
            <small>
              자력대피 <b>{ps.selfEvac}</b> · 구조 <b>{ps.rescued}</b> · 미발견 <b>{ps.notFound}</b>
            </small>
          </div>
        </div>
        <div className="row-btns">
          <label className="check">
            <input type="checkbox" checked={showNames} onChange={(e) => setShowNames(e.target.checked)} /> 성명 보이기
          </label>
          <button
            className="btn small"
            onClick={async () => {
              const t =
                `[인명피해] 총 ${total}명 (지연 ${count('지연환자')} / 긴급 ${count('긴급환자')} / 응급 ${count('응급환자')} / 비응급 ${count('비응급환자')})\n` +
                rows.map((r, i) => `${i + 1}. ${r.status || '-'} ${maskName(r.name)} ${r.gender} ${r.age}세 · 발견 ${r.found} · ${r.ambul} → ${r.hospital} · ${r.injury} ${r.etc}`).join('\n');
              (await copyText(t)) && toast('인명피해 현황 복사됨 (성명 가림)');
            }}
          >
            <Copy size={16} /> 복사
          </button>
          <button
            className="btn small"
            onClick={() =>
              printHtml(
                '인명피해상황',
                `<h1>인명피해상황</h1><div class="meta">${data.title || code} · 총 ${total}명 · 지연 ${count('지연환자')} / 긴급 ${count('긴급환자')} / 응급 ${count('응급환자')} / 비응급 ${count('비응급환자')}</div>${table(header, asRows(true))}`,
              )
            }
          >
            <Printer size={16} /> 인쇄
          </button>
          <button className="btn small" onClick={() => downloadCsv(`인명피해_${code}.csv`, header, asRows(true))}>
            <Download size={16} /> CSV
          </button>
        </div>
      </div>

      <div className="cv-table-wrap">
        <table className="cv-table">
          <colgroup>
            <col style={{ width: '4%' }} />
            <col style={{ width: '10%' }} />
            {COLS.map((c) => (
              <col key={c.key} style={{ width: c.w }} />
            ))}
          </colgroup>
          <thead>
            <tr>
              <th>#</th>
              <th>구분</th>
              {COLS.map((c) => (
                <th key={c.key}>{c.label}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => {
              const tri = TRIAGE.find((t) => t.key === r.status);
              return (
                <tr key={i}>
                  <td className="num">{i + 1}</td>
                  <td>
                    <select
                      value={r.status}
                      style={tri ? { background: tri.color, color: tri.fg } : undefined}
                      onChange={(e) => {
                        const v = e.target.value;
                        setCell(i, 'status', v);
                        log('인명피해', `환자 #${i + 1} 구분: ${r.status || '미분류'} → ${v || '미분류'}`);
                      }}
                    >
                      <option value="">구분</option>
                      {TRIAGE.map((t) => (
                        <option key={t.key}>{t.key}</option>
                      ))}
                    </select>
                  </td>
                  {COLS.map((c) => {
                    const id = `${i}-${c.key}`;
                    const masked = c.key === 'name' && !showNames && focus !== id;
                    return (
                      <td key={c.key}>
                        <input
                          value={masked ? maskName(r[c.key]) : r[c.key]}
                          placeholder={c.ph}
                          onFocus={() => {
                            setFocus(id);
                            focusVal.current = r[c.key];
                          }}
                          onChange={(e) => setCell(i, c.key, e.target.value)}
                          onBlur={(e) => {
                            setFocus(null);
                            const v = e.target.value;
                            flush();
                            if (v !== focusVal.current)
                              log('인명피해', `환자 #${i + 1} ${c.label}: ${c.key === 'name' ? maskName(v) : v || '(지움)'}`);
                          }}
                        />
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
        <button
          className="btn block dashed"
          onClick={() => {
            setRows((rs) => [...rs, emptyRow()]);
            log('인명피해', `환자 #${rows.length + 1} 행 추가`);
          }}
        >
          <Plus size={16} /> 환자 추가
        </button>
      </div>
    </div>
  );
}
