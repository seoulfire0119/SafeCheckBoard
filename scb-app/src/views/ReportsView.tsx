import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import type { ActionRow, AgencyRow, SessionData } from '../types';
import { useSession } from '../session-context';
import { deleteBriefing, saveBriefing, saveField, subscribeBriefings, type BriefingRecord } from '../lib/session';
import { useSynced } from '../lib/useSynced';
import { copyText, printHtml, table } from '../lib/exporter';
import { dateTime, escapeHtml, hhmm } from '../lib/format';
import { teamPlace, teamTitle } from '../lib/teams';
import { STATUS, floorLabel, unitLabel } from '../lib/building';

type Tab = 'incident' | 'timeline' | 'agency' | 'briefing';
const TABS: { key: Tab; label: string }[] = [
  { key: 'incident', label: '재난발생현황' },
  { key: 'timeline', label: '시간대별 조치' },
  { key: 'agency', label: '유관기관 활동' },
  { key: 'briefing', label: '브리핑 자료' },
];

export function ReportsView() {
  const [tab, setTab] = useState<Tab>('incident');
  return (
    <div className="reports-view">
      <nav className="sub-tabs">
        {TABS.map((t) => (
          <button key={t.key} className={tab === t.key ? 'on' : ''} onClick={() => setTab(t.key)}>
            {t.label}
          </button>
        ))}
      </nav>
      <div className="report-body">
        {tab === 'incident' && <IncidentForm />}
        {tab === 'timeline' && <TimelineTable />}
        {tab === 'agency' && <AgencyTable />}
        {tab === 'briefing' && <Briefing />}
      </div>
    </div>
  );
}

// ── 공용 ────────────────────────────────────────────────────────────
interface FieldDef {
  key: string;
  label: string;
  ph?: string;
  multi?: boolean;
  suffix?: string;
  half?: boolean;
}

function FormGrid(props: {
  defs: FieldDef[];
  value: Record<string, string>;
  onChange: (k: string, v: string) => void;
  onCommit?: (k: string, label: string, before: string, after: string) => void;
}) {
  const focusVal = useRef('');
  return (
    <div className="form-grid">
      {props.defs.map((f) => (
        <label key={f.key} className={`field ${f.multi ? 'full' : f.half ? 'half' : ''}`}>
          <span>{f.label}</span>
          <div className="with-suffix">
            {f.multi ? (
              <textarea
                rows={4}
                value={props.value[f.key] ?? ''}
                placeholder={f.ph}
                onFocus={() => (focusVal.current = props.value[f.key] ?? '')}
                onChange={(e) => props.onChange(f.key, e.target.value)}
                onBlur={(e) => props.onCommit?.(f.key, f.label, focusVal.current, e.target.value)}
              />
            ) : (
              <input
                value={props.value[f.key] ?? ''}
                placeholder={f.ph}
                onFocus={() => (focusVal.current = props.value[f.key] ?? '')}
                onChange={(e) => props.onChange(f.key, e.target.value)}
                onBlur={(e) => props.onCommit?.(f.key, f.label, focusVal.current, e.target.value)}
              />
            )}
            {f.suffix && <em>{f.suffix}</em>}
          </div>
        </label>
      ))}
    </div>
  );
}

function ReportHead(props: { title: string; onCopy: () => void; onPrint: () => void; children?: ReactNode }) {
  return (
    <div className="report-head">
      <h2>{props.title}</h2>
      {props.children}
      <span className="grow" />
      <button className="btn small" onClick={props.onCopy}>
        📋 복사
      </button>
      <button className="btn small" onClick={props.onPrint}>
        🖨 인쇄
      </button>
    </div>
  );
}

const n = (s: string | undefined) => parseInt((s ?? '').replace(/[^\d-]/g, ''), 10) || 0;
const comma = (v: number) => v.toLocaleString('ko-KR');

function casualtyCounts(d: SessionData) {
  const rows = d.casualty.rows;
  const dead = rows.filter((r) => r.status === '지연환자').length;
  const injured = rows.filter((r) => r.status && r.status !== '지연환자').length;
  return { dead, injured };
}

// ── 재난발생현황 ───────────────────────────────────────────────────
const INCIDENT_DEFS: FieldDef[] = [
  { key: 'date', label: '일시', ph: '2026-10-19 14:32', half: true },
  { key: 'location', label: '장소', ph: '서울 마포구 ○○동 123', half: true },
  { key: 'target', label: '대상', ph: '주상복합 (지하2·지상25층)', half: true },
  { key: 'cause', label: '원인', ph: '주방 조리 중 실화 (추정)', half: true },
  { key: 'floors', label: '층수', ph: '25', suffix: '층', half: true },
  { key: 'area', label: '연면적', ph: '12,000', suffix: '㎡', half: true },
  { key: 'propReal', label: '재산피해 부동산', ph: '0', suffix: '천원', half: true },
  { key: 'propMove', label: '재산피해 동산', ph: '0', suffix: '천원', half: true },
];
const EQUIP_DEFS: FieldDef[] = [
  { key: 'eFire', label: '소방', suffix: '대', half: true },
  { key: 'eDistrict', label: '구청', suffix: '대', half: true },
  { key: 'ePolice', label: '경찰', suffix: '대', half: true },
  { key: 'eElec', label: '한전', suffix: '대', half: true },
  { key: 'eGas', label: '가스', suffix: '대', half: true },
  { key: 'eOther', label: '기타', suffix: '대', half: true },
];

function IncidentForm() {
  const { code, data, log, toast } = useSession();
  const save = useCallback(
    (v: Record<string, string>) => saveField(code, 'incident', v).catch((e: Error) => toast(`저장 실패: ${e.message}`, 'error')),
    [code, toast],
  );
  const [v, setV, flush] = useSynced<Record<string, string>>(data.incident, save);
  const { dead, injured } = casualtyCounts(data);
  const agencies = data.disasterResponse.agencyRows.filter((r) => r.agency);
  const personTotal = agencies.reduce((s, r) => s + n(r.person), 0);
  const equipTotal = EQUIP_DEFS.reduce((s, f) => s + n(v[f.key]), 0);
  const propTotal = n(v.propReal) + n(v.propMove);

  // 자동 집계값도 함께 저장해 둔다 (브리핑 자동채우기·Flutter 호환)
  const set = (k: string, val: string) => setV((p) => ({ ...p, [k]: val, dead: String(dead), injured: String(injured), personTotal: String(personTotal) }));
  const commit = (_k: string, label: string, before: string, after: string) => {
    flush();
    if (before !== after) log('보고서', `재난발생현황 ${label}: ${after || '(지움)'}`);
  };

  const text = () =>
    [
      '【재난발생현황】',
      '[발생개요]',
      `일시: ${v.date ?? ''}`,
      `장소: ${v.location ?? ''}`,
      `대상: ${v.target ?? ''}`,
      `건물구조: ${v.floors ?? ''}층 / ${v.area ?? ''}㎡`,
      `원인: ${v.cause ?? ''}`,
      '[피해상황]',
      `인명피해: 사망 ${dead}명 / 부상 ${injured}명`,
      `재산피해: ${comma(propTotal)}천원 (부동산 ${comma(n(v.propReal))} / 동산 ${comma(n(v.propMove))})`,
      '[동원상황]',
      `인원 총 ${personTotal}명${agencies.length ? ' — ' + agencies.map((r) => `${r.agency} ${r.person || 0}명`).join(', ') : ''}`,
      `장비 총 ${equipTotal}대 — ${EQUIP_DEFS.map((f) => `${f.label} ${n(v[f.key])}`).join(' / ')}`,
      '[주요활동사항]',
      v.activities ?? '',
    ].join('\n');

  return (
    <div className="report">
      <ReportHead
        title="재난발생현황"
        onCopy={async () => (await copyText(text())) && toast('복사됨')}
        onPrint={() => printHtml('재난발생현황', `<h1>재난발생현황</h1><pre>${escapeHtml(text())}</pre>`)}
      />
      <h3>발생개요 · 재산피해</h3>
      <FormGrid defs={INCIDENT_DEFS} value={v} onChange={set} onCommit={commit} />
      <div className="auto-box">
        <span>
          인명피해 (인명피해 화면에서 자동): 사망 <b>{dead}</b>명 · 부상 <b>{injured}</b>명
        </span>
        <span>
          재산피해 합계 <b>{comma(propTotal)}</b>천원
        </span>
        <span>
          동원 인원 (유관기관 활동에서 자동): <b>{personTotal}</b>명
        </span>
      </div>
      <h3>동원 장비 (총 {equipTotal}대)</h3>
      <FormGrid defs={EQUIP_DEFS} value={v} onChange={set} onCommit={commit} />
      <FormGrid
        defs={[{ key: 'activities', label: '주요활동사항', ph: '14:32 최초 신고접수 / 14:41 펌프차 1번 도착 / 15:10 연소저지선 확보…', multi: true }]}
        value={v}
        onChange={set}
        onCommit={commit}
      />
    </div>
  );
}

// ── 시간대별 조치현황 ───────────────────────────────────────────────
const HIGHLIGHTS = ['', '#ffcdd2', '#fff9c4', '#c8e6c9', '#bbdefb'];

function TimelineTable() {
  const { code, data, log, toast } = useSession();
  const save = useCallback(
    (rows: ActionRow[]) =>
      saveField(code, 'disasterResponse', { ...data.disasterResponse, actionRows: rows }).catch((e: Error) => toast(`저장 실패: ${e.message}`, 'error')),
    [code, data.disasterResponse, toast],
  );
  const [rows, setRows, flush] = useSynced<ActionRow[]>(data.disasterResponse.actionRows, save);
  const focusVal = useRef('');
  const set = (i: number, k: keyof ActionRow, val: string) => setRows((rs) => rs.map((r, j) => (j === i ? { ...r, [k]: val } : r)));
  const text = () => '[시간대별 조치현황]\n' + rows.map((r) => `${r.time}  ${r.content}`).join('\n');

  return (
    <div className="report">
      <ReportHead
        title="시간대별 조치현황"
        onCopy={async () => (await copyText(text())) && toast('복사됨')}
        onPrint={() => printHtml('시간대별 조치현황', `<h1>시간대별 조치현황</h1>${table(['시간', '조치사항'], rows.map((r) => [r.time, r.content]))}`)}
      >
        <ImportFromLog
          onPick={(items) => {
            setRows((rs) => [...rs, ...items]);
            log('보고서', `조치현황에 활동기록 ${items.length}건 가져오기`);
          }}
        />
      </ReportHead>
      <table className="edit-table">
        <thead>
          <tr>
            <th style={{ width: 90 }}>시간</th>
            <th>조치사항</th>
            <th style={{ width: 120 }}>강조</th>
            <th style={{ width: 44 }} />
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} style={r.highlight ? { background: r.highlight } : undefined}>
              <td>
                <input value={r.time} placeholder="14:32" onChange={(e) => set(i, 'time', e.target.value)} onBlur={flush} />
              </td>
              <td>
                <input
                  value={r.content}
                  placeholder="조치사항 입력"
                  onFocus={() => (focusVal.current = r.content)}
                  onChange={(e) => set(i, 'content', e.target.value)}
                  onBlur={(e) => {
                    flush();
                    if (e.target.value !== focusVal.current) log('보고서', `조치현황 ${r.time} ${e.target.value}`);
                  }}
                />
              </td>
              <td>
                <div className="colors small">
                  {HIGHLIGHTS.map((c) => (
                    <button
                      key={c || 'none'}
                      className={`swatch ${(r.highlight ?? '') === c ? 'on' : ''}`}
                      style={{ background: c || '#fff' }}
                      onClick={() =>
                        setRows((rs) =>
                          rs.map((x, j) => {
                            if (j !== i) return x;
                            const { highlight: _h, ...rest } = x;
                            return c ? { ...rest, highlight: c } : rest;
                          }),
                        )
                      }
                      aria-label={c ? '강조색' : '강조 없음'}
                    />
                  ))}
                </div>
              </td>
              <td>
                <button className="icon-btn" aria-label="행 삭제" onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))}>
                  ✕
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <button className="btn block dashed" onClick={() => setRows((rs) => [...rs, { time: hhmm(Date.now()), content: '' }])}>
        + 행 추가 (지금 시각)
      </button>
    </div>
  );
}

/** 활동 기록(상태·화점·진입대) 중 골라서 조치현황 표로 가져오기 */
function ImportFromLog({ onPick }: { onPick: (rows: ActionRow[]) => void }) {
  const { logs } = useSession();
  const [open, setOpen] = useState(false);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const cands = logs.filter((l) => ['화점', '진입대', '상태', '인명피해'].includes(l.category));
  if (!open)
    return (
      <button className="btn small" onClick={() => setOpen(true)}>
        ⤵ 활동기록에서 가져오기
      </button>
    );
  return (
    <div className="import-pop">
      <div className="import-list">
        {cands.length === 0 && <p className="hint">가져올 기록이 없습니다</p>}
        {cands.map((l) => (
          <label key={l.id} className="check">
            <input
              type="checkbox"
              checked={picked.has(l.id)}
              onChange={() =>
                setPicked((s) => {
                  const x = new Set(s);
                  if (x.has(l.id)) x.delete(l.id);
                  else x.add(l.id);
                  return x;
                })
              }
            />
            <time>{hhmm(l.at)}</time> {l.text}
          </label>
        ))}
      </div>
      <div className="row-btns">
        <button className="btn small ghost" onClick={() => setOpen(false)}>
          닫기
        </button>
        <button
          className="btn small primary"
          disabled={!picked.size}
          onClick={() => {
            onPick(cands.filter((l) => picked.has(l.id)).map((l) => ({ time: hhmm(l.at), content: l.text })));
            setPicked(new Set());
            setOpen(false);
          }}
        >
          {picked.size}건 가져오기
        </button>
      </div>
    </div>
  );
}

// ── 유관기관 활동사항 ───────────────────────────────────────────────
function AgencyTable() {
  const { code, data, log, toast } = useSession();
  const save = useCallback(
    (rows: AgencyRow[]) =>
      saveField(code, 'disasterResponse', { ...data.disasterResponse, agencyRows: rows }).catch((e: Error) => toast(`저장 실패: ${e.message}`, 'error')),
    [code, data.disasterResponse, toast],
  );
  const [rows, setRows, flush] = useSynced<AgencyRow[]>(data.disasterResponse.agencyRows, save);
  const focusVal = useRef('');
  const set = (i: number, k: keyof AgencyRow, val: string) => setRows((rs) => rs.map((r, j) => (j === i ? { ...r, [k]: val } : r)));
  const total = rows.reduce((s, r) => s + n(r.person), 0);
  const cols: { k: keyof AgencyRow; label: string; ph: string; w?: number }[] = [
    { k: 'agency', label: '기관명', ph: '마포경찰서', w: 160 },
    { k: 'person', label: '인원(명)', ph: '12', w: 80 },
    { k: 'arrive', label: '도착시간', ph: '14:50', w: 90 },
    { k: 'action', label: '조치내용', ph: '교통통제 및 주민 대피 유도' },
  ];
  const text = () =>
    `[유관기관 활동사항] 총 ${total}명\n` + rows.map((r, i) => `${i + 1}. ${r.agency} / ${r.person}명 / 도착 ${r.arrive} / ${r.action}`).join('\n');

  return (
    <div className="report">
      <ReportHead
        title={`유관기관 활동사항 (총 ${total}명)`}
        onCopy={async () => (await copyText(text())) && toast('복사됨')}
        onPrint={() =>
          printHtml(
            '유관기관 활동사항',
            `<h1>유관기관 활동사항</h1>${table(['연번', '기관명', '인원', '도착시간', '조치내용'], rows.map((r, i) => [i + 1, r.agency, r.person, r.arrive, r.action]))}`,
          )
        }
      />
      <table className="edit-table">
        <thead>
          <tr>
            <th style={{ width: 40 }}>#</th>
            {cols.map((c) => (
              <th key={c.k} style={c.w ? { width: c.w } : undefined}>
                {c.label}
              </th>
            ))}
            <th style={{ width: 44 }} />
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i}>
              <td className="num">{i + 1}</td>
              {cols.map((c) => (
                <td key={c.k}>
                  <input
                    value={r[c.k]}
                    placeholder={c.ph}
                    inputMode={c.k === 'person' ? 'numeric' : undefined}
                    onFocus={() => (focusVal.current = r[c.k])}
                    onChange={(e) => set(i, c.k, e.target.value)}
                    onBlur={(e) => {
                      flush();
                      if (e.target.value !== focusVal.current) log('보고서', `유관기관 ${r.agency || `#${i + 1}`} ${c.label}: ${e.target.value}`);
                    }}
                  />
                </td>
              ))}
              <td>
                <button className="icon-btn" aria-label="행 삭제" onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))}>
                  ✕
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <button className="btn block dashed" onClick={() => setRows((rs) => [...rs, { agency: '', person: '', arrive: hhmm(Date.now()), action: '' }])}>
        + 기관 추가
      </button>
    </div>
  );
}

// ── 브리핑 자료 (초동 / 중간 / 공식) ─────────────────────────────────
const BRIEF_TYPES = ['초동 브리핑', '중간 브리핑', '공식 보고서'];
const BRIEF_DEFS: FieldDef[][] = [
  [
    { key: 'f1Date', label: '발생 일시', ph: '2026-10-19 14:32', half: true },
    { key: 'f1Location', label: '발생 장소', ph: '서울 마포구 ○○동', half: true },
    { key: 'f1ResponseLevel', label: '대응단계', ph: '대응 1단계', half: true },
    { key: 'f1ExtRate', label: '진화율', suffix: '%', half: true },
    { key: 'f1Personnel', label: '투입 인력', suffix: '명', half: true },
    { key: 'f1Equipment', label: '투입 장비', suffix: '대', half: true },
    { key: 'f1Dead', label: '사망', suffix: '명', half: true },
    { key: 'f1Injured', label: '부상', suffix: '명', half: true },
    { key: 'f1Missing', label: '대피', suffix: '명', half: true },
    { key: 'f1Hazard', label: '위험 요소', ph: 'LPG, 유해화학물질', half: true },
    { key: 'f1Memo', label: '비고', ph: '구두 보고 특이사항', multi: true },
  ],
  [
    { key: 'f2Summary', label: '현황 요약', ph: '현재 상황을 간결하게', multi: true },
    { key: 'f2Tactic', label: '수색 전술', multi: true },
    { key: 'f2Rescue', label: '구조 현황', multi: true },
    { key: 'f2Teams', label: '편성 현황', multi: true },
    { key: 'f2Area', label: '수색 구역', multi: true },
    { key: 'f2Commander', label: '현장 지휘관', half: true },
    { key: 'f2Hazard', label: '위험 요소', half: true },
    { key: 'f2Timeline', label: '시간대별 상황일지', multi: true },
  ],
  [
    { key: 'f3Overview', label: '화재 개요', multi: true },
    { key: 'f3Dead', label: '사망', suffix: '명', half: true },
    { key: 'f3Injured', label: '부상', suffix: '명', half: true },
    { key: 'f3Missing', label: '실종', suffix: '명', half: true },
    { key: 'f3Resources', label: '투입 자원', multi: true },
    { key: 'f3Timeline', label: '대응 경과', multi: true },
    { key: 'f3Cause', label: '원인 추정', multi: true },
    { key: 'f3Issues', label: '문제점 및 개선사항', multi: true },
    { key: 'f3JointInvest', label: '합동 감식 현황', multi: true },
  ],
];

function autoFill(d: SessionData): Record<string, string> {
  const inc = d.incident;
  const { dead, injured } = casualtyCounts(d);
  const agencies = d.disasterResponse.agencyRows.filter((r) => r.agency);
  const timeline = d.disasterResponse.actionRows.filter((r) => r.content).map((r) => `${r.time} ${r.content}`).join('\n');
  const active = d.teams.filter((t) => t.status !== 'waiting');
  const people = agencies.reduce((s, r) => s + n(r.person), 0);
  const equip = ['eFire', 'eDistrict', 'ePolice', 'eElec', 'eGas', 'eOther'].reduce((s, k) => s + n(inc[k]), 0);
  const fo = d.fireOrigin;
  let origin = '';
  if (fo && d.buildings[fo.buildingIdx]) {
    const b = d.buildings[fo.buildingIdx];
    const st = d.states[fo.buildingIdx];
    const u = fo.unitId ? st.units.find((x) => x.id === fo.unitId) : null;
    origin = `${b.name} ${floorLabel(b, st, fo.floor)}${u ? ` ${unitLabel(b, u)}` : ''}`;
  }
  const statusLine = d.buildings
    .map((b, i) => {
      const c: Record<string, number> = {};
      for (const u of d.states[i].units) c[u.status] = (c[u.status] ?? 0) + 1;
      return `${b.name}: ${Object.entries(c)
        .map(([s, k]) => `${STATUS[s as keyof typeof STATUS].label} ${k}`)
        .join(', ')}`;
    })
    .join(' / ');
  const ps = d.personnelStats.reduce((a, s) => ({ e: a.e + s.selfEvac, r: a.r + s.rescued, nf: a.nf + s.notFound }), { e: 0, r: 0, nf: 0 });
  const overview = [
    inc.date && `일시: ${inc.date}`,
    inc.location && `장소: ${inc.location}`,
    inc.target && `대상: ${inc.target}`,
    inc.cause && `원인: ${inc.cause}`,
    origin && `화점(추정): ${origin}`,
  ]
    .filter(Boolean)
    .join('\n');
  return {
    f1Date: inc.date ?? '',
    f1Location: inc.location ?? '',
    f1Personnel: people ? String(people) : '',
    f1Equipment: equip ? String(equip) : '',
    f1Dead: String(dead),
    f1Injured: String(injured),
    f1Missing: String(ps.e),
    f1Hazard: origin ? `화점(추정) ${origin}` : '',
    f2Summary: [origin && `화점(추정) ${origin}`, statusLine, `자력대피 ${ps.e} · 구조 ${ps.r} · 미발견 ${ps.nf}`].filter(Boolean).join('\n'),
    f2Rescue: `구조 ${ps.r}명 · 미발견 ${ps.nf}명 · 환자 ${dead + injured}명 (사망 ${dead})`,
    f2Teams: active.map((t) => `${teamTitle(t)} — ${teamPlace(d.buildings, d.states, t.floorKey) || '위치 미지정'}${t.task ? ` / ${t.task}` : ''}`).join('\n'),
    f2Area: Array.from(new Set(active.map((t) => teamPlace(d.buildings, d.states, t.floorKey)).filter(Boolean))).join(', '),
    f2Timeline: timeline,
    f3Overview: overview,
    f3Dead: String(dead),
    f3Injured: String(injured),
    f3Resources: [people && `인원 ${people}명`, equip && `장비 ${equip}대`, ...agencies.map((r) => `${r.agency} ${r.person}명`)].filter(Boolean).join('\n'),
    f3Timeline: timeline,
    f3Cause: inc.cause ?? '',
  };
}

function Briefing() {
  const { code, data, log, toast } = useSession();
  const [type, setType] = useState(0);
  const [fields, setFields] = useState<Record<string, string>>({});
  const [title, setTitle] = useState('');
  const [editingId, setEditingId] = useState<string | undefined>();
  const [list, setList] = useState<BriefingRecord[]>([]);

  useEffect(() => subscribeBriefings(code, setList, (e) => toast(`브리핑 목록 오류: ${e.message}`, 'error')), [code, toast]);

  const defs = BRIEF_DEFS[type];
  const fill = () => {
    const auto = autoFill(data);
    const keys = defs.map((f) => f.key).filter((k) => auto[k]);
    setFields((prev) => ({ ...prev, ...Object.fromEntries(keys.map((k) => [k, auto[k]])) }));
    toast(keys.length ? `${keys.length}개 항목을 현장 데이터로 채웠습니다` : '채울 데이터가 없습니다');
  };

  const text = () => `【${BRIEF_TYPES[type]}】${title ? ` ${title}` : ''}\n` + defs.map((f) => `${f.label}: ${fields[f.key] ?? ''}${f.suffix && fields[f.key] ? f.suffix : ''}`).join('\n');
  const html = () =>
    `<h1>${BRIEF_TYPES[type]}</h1><div class="meta">${escapeHtml(title || data.title || code)} · ${dateTime(Date.now())}</div><table>${defs
      .map((f) => `<tr><th style="width:140px">${escapeHtml(f.label)}</th><td><pre>${escapeHtml((fields[f.key] ?? '') + (f.suffix && fields[f.key] ? f.suffix : ''))}</pre></td></tr>`)
      .join('')}</table>`;

  return (
    <div className="briefing">
      <div className="report">
        <ReportHead title="브리핑 자료" onCopy={async () => (await copyText(text())) && toast('복사됨')} onPrint={() => printHtml(BRIEF_TYPES[type], html())}>
          <div className="seg">
            {BRIEF_TYPES.map((t, i) => (
              <button key={t} className={type === i ? 'on' : ''} onClick={() => setType(i)}>
                {t}
              </button>
            ))}
          </div>
          <button className="btn small primary" onClick={fill}>
            ✨ 자동 채우기
          </button>
        </ReportHead>
        <div className="row-btns">
          <input value={title} placeholder="제목 (예: 2026-10-19 마포 주상복합 화재 초동)" onChange={(e) => setTitle(e.target.value)} />
          <button
            className="btn small"
            onClick={async () => {
              try {
                const t = title.trim() || `${BRIEF_TYPES[type]} ${hhmm(Date.now())}`;
                const id = await saveBriefing(code, { title: t, tabType: type, fields }, editingId);
                setEditingId(id);
                setTitle(t);
                log('보고서', `${BRIEF_TYPES[type]} 저장: ${t}`);
                toast('브리핑 게시판에 저장됨');
              } catch (e) {
                toast(`저장 실패: ${(e as Error).message}`, 'error');
              }
            }}
          >
            💾 {editingId ? '덮어쓰기' : '게시판에 저장'}
          </button>
          {editingId && (
            <button
              className="btn small ghost"
              onClick={() => {
                setEditingId(undefined);
                setTitle('');
                setFields({});
              }}
            >
              새로 쓰기
            </button>
          )}
        </div>
        <FormGrid defs={defs} value={fields} onChange={(k, v) => setFields((p) => ({ ...p, [k]: v }))} />
      </div>
      <aside className="brief-board">
        <h3>브리핑 게시판 ({list.length})</h3>
        {list.length === 0 && <p className="hint">저장된 브리핑이 없습니다</p>}
        <ul>
          {list.map((r) => (
            <li key={r.id} className={editingId === r.id ? 'on' : ''}>
              <button
                className="brief-item"
                onClick={() => {
                  setType(r.tabType);
                  setFields(r.fields);
                  setTitle(r.title);
                  setEditingId(r.id);
                }}
              >
                <span className="tag">{BRIEF_TYPES[r.tabType]?.split(' ')[0]}</span>
                <b>{r.title || '(제목 없음)'}</b>
                <small>{dateTime(r.updatedAt)}</small>
              </button>
              <button
                className="icon-btn"
                aria-label="삭제"
                onClick={async () => {
                  if (!confirm(`「${r.title}」을(를) 삭제할까요?`)) return;
                  await deleteBriefing(code, r.id).catch((e: Error) => toast(`삭제 실패: ${e.message}`, 'error'));
                  log('보고서', `브리핑 삭제: ${r.title}`);
                  if (editingId === r.id) setEditingId(undefined);
                }}
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      </aside>
    </div>
  );
}
