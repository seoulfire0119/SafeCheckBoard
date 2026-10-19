import { useRef, useState, type CSSProperties, type PointerEvent as RPointerEvent } from 'react';
import { Accessibility, BoxSelect, Building2, ChevronDown, Flame, HardHat, Minus, Plus, StickyNote, X } from 'lucide-react';
import type { Building, PersonnelStats, Unit } from '../types';
import { useNow, useSession } from '../session-context';
import { floorKey, floorLabel, floorsDescending, rooftopFloor, STATUS, unitLabel } from '../lib/building';
import { LEVEL, teamElapsed, teamLevel, teamsByFloor } from '../lib/teams';
import { mmss } from '../lib/format';
import { Modal } from './Modal';

export interface Selection {
  b: number;
  unitId: string | null; // 호실 선택
  floor: number | null; // 층 전체 선택 (unitId 가 null 일 때)
  units?: string[]; // 여러 칸 선택 (범위 선택·드래그)
}

/** 층 범위(위→아래 순서의 visible 층 목록 기준)와 칸 범위로 호실 id 목록을 구한다 */
export function unitsInRange(units: Unit[], floors: number[], f1: number, f2: number, s1 = 0, s2 = 0) {
  const i1 = floors.indexOf(f1);
  const i2 = floors.indexOf(f2);
  if (i1 < 0 || i2 < 0) return [];
  const pick = new Set(floors.slice(Math.min(i1, i2), Math.max(i1, i2) + 1));
  const all = s1 === 0 || s2 === 0;
  const lo = Math.min(s1, s2);
  const hi = Math.max(s1, s2);
  return units
    .filter((u) => pick.has(u.floor) && (all || (u.unitIndex <= hi && u.unitIndex + u.spanCount - 1 >= lo)))
    .map((u) => u.id);
}

const STAT_FIELDS: { key: keyof PersonnelStats; label: string; color: string }[] = [
  { key: 'selfEvac', label: '자력대피', color: '#00e08a' },
  { key: 'rescued', label: '구조완료', color: '#38bdf8' },
  { key: 'notFound', label: '미발견', color: '#ff5b5b' },
];

export function BuildingCard(props: {
  idx: number;
  building: Building;
  selection: Selection | null;
  onSelect: (s: Selection | null) => void;
  canAdd: boolean;
  onAdd: () => void;
}) {
  const { idx, building: b, selection } = props;
  const { data, act } = useSession();
  const now = useNow();
  const state = data.states[idx];
  const stats = data.personnelStats[idx];
  const [editStat, setEditStat] = useState<keyof PersonnelStats | null>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const byFloor = teamsByFloor(data);
  const roof = rooftopFloor(b);
  const fo = data.fireOrigin && data.fireOrigin.buildingIdx === idx ? data.fireOrigin : null;
  const hidden = new Set(state.hiddenFloors);
  const [rangeMode, setRangeMode] = useState(false);
  const drag = useRef<{ f: number; s: number; moved: boolean } | null>(null);
  const suppressClick = useRef(false);
  const multi = new Set(selection?.units ?? []);
  const visibleFloors = floorsDescending(b).filter((f) => !hidden.has(f));

  // 숨긴 층은 연속된 묶음으로 한 줄에 접어 보여준다
  const rows: ({ kind: 'floor'; f: number } | { kind: 'hidden'; floors: number[] })[] = [];
  for (const f of floorsDescending(b)) {
    if (hidden.has(f)) {
      const last = rows[rows.length - 1];
      if (last?.kind === 'hidden') last.floors.push(f);
      else rows.push({ kind: 'hidden', floors: [f] });
    } else rows.push({ kind: 'floor', f });
  }

  const pickUnit = (u: Unit, f: number) => {
    if (suppressClick.current) return;
    if (!rangeMode) return props.onSelect({ b: idx, unitId: u.id, floor: f });
    const next = new Set(multi);
    if (next.has(u.id)) next.delete(u.id);
    else next.add(u.id);
    props.onSelect(next.size ? { b: idx, unitId: null, floor: null, units: [...next] } : null);
  };
  const pickFloor = (f: number, floorSel: boolean) => {
    if (suppressClick.current) return;
    if (!rangeMode) return props.onSelect(floorSel ? null : { b: idx, unitId: null, floor: f });
    const ids = state.units.filter((u) => u.floor === f).map((u) => u.id);
    const next = new Set(multi);
    const allIn = ids.every((id) => next.has(id));
    for (const id of ids) {
      if (allIn) next.delete(id);
      else next.add(id);
    }
    props.onSelect(next.size ? { b: idx, unitId: null, floor: null, units: [...next] } : null);
  };

  // 끌어서 범위 선택 — 범위 모드(손가락) 또는 마우스
  const cellAt = (x: number, y: number) => {
    const el = document.elementFromPoint(x, y)?.closest('[data-floor]') as HTMLElement | null;
    if (!el || !el.closest(`[data-bgrid="${idx}"]`)) return null;
    return { f: Number(el.dataset.floor), s: Number(el.dataset.slot) };
  };
  const onDown = (e: RPointerEvent) => {
    if (!rangeMode && e.pointerType !== 'mouse') return;
    if (e.button !== 0) return;
    const c = cellAt(e.clientX, e.clientY);
    drag.current = c ? { ...c, moved: false } : null;
  };
  const onMove = (e: RPointerEvent) => {
    const d = drag.current;
    if (!d) return;
    const c = cellAt(e.clientX, e.clientY);
    if (!c || (c.f === d.f && c.s === d.s && !d.moved)) return;
    d.moved = true;
    const ids = unitsInRange(state.units, visibleFloors, d.f, c.f, d.s, c.s);
    props.onSelect(ids.length ? { b: idx, unitId: null, floor: null, units: ids } : null);
  };
  const onUp = () => {
    if (drag.current?.moved) {
      suppressClick.current = true;
      setTimeout(() => (suppressClick.current = false), 80);
    }
    drag.current = null;
  };

  const cols = b.defaultUnits;
  const gridStyle: CSSProperties = {
    gridTemplateColumns: `minmax(46px,auto) 34px repeat(${cols}, minmax(42px, 1fr)) minmax(0, auto)`,
  };
  const minWidth = 46 + 34 + cols * 46 + 90;

  return (
    <section className="bcard" style={{ minWidth: Math.min(minWidth, 900), flexGrow: cols + 3 }}>
      <div className="pboard">
        {STAT_FIELDS.map((s) => (
          <button key={s.key} className="pstat" onClick={() => setEditStat(s.key)}>
            <span>{s.label}</span>
            <b style={{ color: s.color }}>{stats[s.key]}</b>
          </button>
        ))}
      </div>
      <div className="bhead">
        <Building2 size={18} className="ic-brand" />
        <b className="bname">{b.name}</b>
        <small className="bmeta-txt">
          {floorsDescending(b).length}
          {b.isHorizontal ? '구역' : '층'} · {state.units.length}칸
        </small>
        <span className="grow" />
        <button
          className={`btn tiny ${rangeMode ? 'on' : ''}`}
          onClick={() => setRangeMode(!rangeMode)}
          aria-pressed={rangeMode}
          title="손가락으로 끌거나 여러 칸을 눌러 한꺼번에 선택"
        >
          <BoxSelect size={14} /> {rangeMode ? '범위 선택 중' : '범위 선택'}
        </button>
        {props.canAdd && (
          <button className="btn tiny" onClick={props.onAdd}>
            <Plus size={14} /> 건물
          </button>
        )}
        {data.buildings.length > 1 && (
          <button className="icon-btn" aria-label="건물 제거" onClick={() => setConfirmRemove(true)}>
            <X size={18} />
          </button>
        )}
      </div>

      <div className="grid-scroll">
        <div
          className={`bgrid ${rangeMode ? 'range' : ''}`}
          style={gridStyle}
          data-bgrid={idx}
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          onPointerLeave={(e) => e.pointerType === 'mouse' && onUp()}
        >
          {rows.map((r) => {
            if (r.kind === 'hidden')
              return (
                <button
                  key={`h${r.floors[0]}`}
                  className="hidden-row"
                  style={{ gridColumn: '1 / -1' }}
                  onClick={() =>
                    act(
                      (d) => {
                        d.states[idx].hiddenFloors = d.states[idx].hiddenFloors.filter((f) => !r.floors.includes(f));
                      },
                      '건물',
                      `${b.name} 숨긴 ${b.isHorizontal ? '구역' : '층'} 다시 표시: ${r.floors.map((f) => floorLabel(b, state, f)).join(', ')}`,
                    )
                  }
                >
                  <ChevronDown size={14} /> 숨긴 {b.isHorizontal ? '구역' : '층'} {r.floors.length}개 ({floorLabel(b, state, r.floors[r.floors.length - 1])}~
                  {floorLabel(b, state, r.floors[0])}) — 눌러서 표시
                </button>
              );
            const f = r.f;
            const units = state.units.filter((u) => u.floor === f).sort((a, c) => a.unitIndex - c.unitIndex);
            const floorSel = selection?.unitId == null && selection?.floor === f;
            const teams = byFloor.get(floorKey(idx, f)) ?? [];
            const vuln = units.filter((u) => u.vulnerable).length;
            const floorFire = fo && fo.unitId == null && fo.floor === f;
            const cells: JSX.Element[] = [];
            let slot = 1;
            while (slot <= cols) {
              const u = units.find((x) => x.unitIndex === slot);
              if (u) {
                const span = Math.max(1, Math.min(u.spanCount, cols - slot + 1));
                cells.push(
                  <UnitCell
                    key={u.id}
                    b={b}
                    u={u}
                    span={span}
                    selected={selection?.unitId === u.id}
                    multi={multi.has(u.id)}
                    origin={!!fo && fo.unitId === u.id}
                    onClick={() => pickUnit(u, f)}
                  />,
                );
                slot += span;
              } else {
                const s = slot;
                cells.push(
                  <button
                    key={`e${f}-${s}`}
                    className="ucell empty"
                    title="빈 칸 — 눌러서 호실 활성화"
                    onClick={() =>
                      act(
                        (d) => {
                          const st = d.states[idx];
                          if (!st.units.some((x) => x.floor === f && x.unitIndex === s))
                            st.units.push({
                              id: `${f}-${s}`,
                              floor: f,
                              unitIndex: s,
                              number: f > 0 ? f * 100 + s : -(Math.abs(f) * 100 + s),
                              status: 'unknown',
                              memo: '',
                              memoPinned: false,
                              vulnerable: false,
                              spanCount: 1,
                            });
                        },
                        '건물',
                        `${b.name} ${floorLabel(b, state, f)} ${s}번째 칸 활성화`,
                      )
                    }
                  >
                    <Plus size={16} />
                  </button>,
                );
                slot++;
              }
            }
            return (
              <div key={f} className={`frow ${floorSel ? 'sel' : ''} ${teams.length ? 'has-team' : ''}`} style={{ display: 'contents' }}>
                <button
                  className={`flabel ${f === roof ? 'roof' : ''} ${floorSel ? 'sel' : ''}`}
                  style={teams.length ? { boxShadow: `inset 4px 0 0 ${teams[0].color}` } : undefined}
                  data-floor={f}
                  data-slot={0}
                  onClick={() => pickFloor(f, floorSel)}
                >
                  {floorFire && <Flame size={14} className="fire-dot" />}
                  {floorLabel(b, state, f)}
                  {vuln > 0 && <span className="vbadge">약자 {vuln}</span>}
                </button>
                <button className={`allbtn ${floorSel ? 'sel' : ''}`} data-floor={f} data-slot={0} onClick={() => pickFloor(f, floorSel)}>
                  ALL
                </button>
                {cells}
                <div className="fteams">
                  {teams.map((t) => {
                    const lv = teamLevel(t, data.timerSettings, now);
                    return (
                      <span
                        key={t.id}
                        className={`tpill lv-${lv}`}
                        style={{ background: t.color }}
                        title={`${t.name} ${t.unit} ${t.task} · ${LEVEL[lv].label}`}
                      >
                        <HardHat size={13} /> {t.name}
                        {t.unit && <small>{t.unit}</small>}
                        <i>{mmss(teamElapsed(t, now))}</i>
                      </span>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {editStat && (
        <StatDialog
          label={STAT_FIELDS.find((s) => s.key === editStat)!.label}
          value={stats[editStat]}
          onClose={() => setEditStat(null)}
          onSave={(v) => {
            const before = stats[editStat];
            const label = STAT_FIELDS.find((s) => s.key === editStat)!.label;
            setEditStat(null);
            if (v !== before)
              act(
                (d) => {
                  d.personnelStats[idx][editStat] = v;
                },
                '인명피해',
                `${b.name} ${label}: ${before}명 → ${v}명`,
              );
          }}
        />
      )}
      {confirmRemove && (
        <Modal
          title="건물 제거"
          onClose={() => setConfirmRemove(false)}
          footer={
            <>
              <button className="btn ghost" onClick={() => setConfirmRemove(false)}>
                취소
              </button>
              <button
                className="btn danger"
                onClick={() => {
                  setConfirmRemove(false);
                  props.onSelect(null);
                  act(
                    (d) => {
                      if (d.buildings.length <= 1) return;
                      d.buildings.splice(idx, 1);
                      d.states.splice(idx, 1);
                      d.personnelStats.splice(idx, 1);
                      if (d.fireOrigin?.buildingIdx === idx) d.fireOrigin = null;
                      else if (d.fireOrigin && d.fireOrigin.buildingIdx > idx) d.fireOrigin.buildingIdx--;
                      for (const t of d.teams) {
                        const [bi, fl] = t.floorKey.split('_').map(Number);
                        if (!t.floorKey) continue;
                        if (bi === idx) t.floorKey = '';
                        else if (bi > idx) t.floorKey = `${bi - 1}_${fl}`;
                      }
                    },
                    '건물',
                    `건물 제거: ${b.name}`,
                  );
                }}
              >
                제거
              </button>
            </>
          }
        >
          <p>
            <b>{b.name}</b> 을(를) 보드에서 제거할까요? 이 건물의 호실 상태와 메모가 모두 사라집니다.
          </p>
        </Modal>
      )}
    </section>
  );
}

function UnitCell(props: { b: Building; u: Unit; span: number; selected: boolean; multi: boolean; origin: boolean; onClick: () => void }) {
  const { u } = props;
  const st = STATUS[u.status];
  return (
    <button
      className={`ucell st-${u.status} ${props.selected ? 'sel' : ''} ${props.multi ? 'msel' : ''} ${props.origin ? 'origin' : ''}`}
      data-floor={u.floor}
      data-slot={u.unitIndex}
      style={{ gridColumn: `span ${props.span}`, background: u.status === 'unknown' ? undefined : st.color }}
      onClick={props.onClick}
      title={`${unitLabel(props.b, u)} · ${st.label}${u.memo ? ` · ${u.memo}` : ''}`}
    >
      <span className="unum">{unitLabel(props.b, u).replace(/^.*구역 /, '')}</span>
      {u.memoPinned && u.memo ? <span className="umemo">{u.memo}</span> : u.status !== 'unknown' && <span className="ust">{st.label}</span>}
      {u.vulnerable && <Accessibility size={13} className="uv" aria-label="피난약자" />}
      {!u.memoPinned && u.memo && <StickyNote size={12} className="um" aria-label="메모 있음" />}
      {props.origin && <Flame size={16} className="uorigin" aria-label="화점" />}
    </button>
  );
}

function StatDialog(props: { label: string; value: number; onClose: () => void; onSave: (v: number) => void }) {
  const [v, setV] = useState(props.value);
  return (
    <Modal
      title={props.label}
      onClose={props.onClose}
      footer={
        <>
          <button className="btn ghost" onClick={props.onClose}>
            취소
          </button>
          <button className="btn primary" onClick={() => props.onSave(v)}>
            확인
          </button>
        </>
      }
    >
      <div className="stepper">
        <button className="btn" onClick={() => setV(Math.max(0, v - 1))} aria-label="빼기">
          <Minus size={20} />
        </button>
        <input
          inputMode="numeric"
          value={v}
          onChange={(e) => setV(Math.min(999, Math.max(0, parseInt(e.target.value.replace(/\D/g, '') || '0', 10))))}
          onKeyDown={(e) => e.key === 'Enter' && props.onSave(v)}
        />
        <span>명</span>
        <button className="btn" onClick={() => setV(Math.min(999, v + 1))} aria-label="더하기">
          <Plus size={20} />
        </button>
      </div>
    </Modal>
  );
}
