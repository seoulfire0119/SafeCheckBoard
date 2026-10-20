import { useState, type CSSProperties } from 'react';
import { Building2, CarFront, ChevronDown, Flame, HardHat, Minus, Pencil, Plus, StickyNote, TriangleAlert, X } from 'lucide-react';
import type { Building, PersonnelStats, Unit } from '../types';
import { useNow, useSession } from '../session-context';
import { floorKey, floorLabel, floorsDescending, isParking, resizeBuilding, rooftopFloor, STATUS, unitLabel } from '../lib/building';
import { LEVEL, teamElapsed, teamLevel, teamMain, teamsByFloor } from '../lib/teams';
import { mmss } from '../lib/format';
import { Modal } from './Modal';
import { WheelchairIcon } from './WheelchairIcon';

export interface Selection {
  b: number;
  unitId: string | null; // 호실 선택
  floor: number | null; // 층 전체 선택 (unitId 가 null 일 때)
  units?: string[]; // 여러 칸 선택 (층 「아래 전부 / 위 전부」)
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
  const [renaming, setRenaming] = useState(false);
  const byFloor = teamsByFloor(data);
  const roof = rooftopFloor(b);
  const fo = data.fireOrigin && data.fireOrigin.buildingIdx === idx ? data.fireOrigin : null;
  const hidden = new Set(state.hiddenFloors);
  const multi = new Set(selection?.units ?? []);

  // 숨긴 층은 연속된 묶음으로 한 줄에 접어 보여준다
  const rows: ({ kind: 'floor'; f: number } | { kind: 'hidden'; floors: number[] })[] = [];
  for (const f of floorsDescending(b)) {
    if (hidden.has(f)) {
      const last = rows[rows.length - 1];
      if (last?.kind === 'hidden') last.floors.push(f);
      else rows.push({ kind: 'hidden', floors: [f] });
    } else rows.push({ kind: 'floor', f });
  }

  const cols = b.defaultUnits;
  const hasTeams = data.teams.some((t) => t.status !== 'waiting' && t.floorKey.startsWith(`${idx}_`));
  const gridStyle: CSSProperties = {
    // 칸 최소 너비는 CSS 변수(--ucol) — 휴대폰에서는 좁게 해서 화면 안에 들어오게 한다
    gridTemplateColumns: `minmax(var(--flcol, 56px),auto) var(--allcol, 40px) repeat(${cols}, minmax(var(--ucol, 140px), 1fr)) ${hasTeams ? 'var(--tcol, 78px)' : '0px'}`,
    // 줄 수 — 휴대폰에서는 칸 높이를 "화면 높이 ÷ 줄 수"로 맞춰 건물 전체가 한 화면에 들어오게 한다
    ['--rows' as string]: rows.length,
  };
  // 호수(1501호)가 잘리지 않을 만큼은 넓게 — 건물이 많으면 옆으로 밀어서 봄
  // 칸 + 칸 사이 간격(5px) + 안쪽 여백까지 더해서 옆으로 넘치지 않게
  const minWidth = 56 + 40 + cols * 140 + (hasTeams ? 78 : 0) + (cols + 3) * 5 + 24;

  return (
    <section className="bcard" style={{ minWidth: Math.min(minWidth, 900), flexGrow: cols + 3, flexShrink: 0 }}>
      <div className="pboard">
        {STAT_FIELDS.map((s) => (
          <button key={s.key} className="pstat" onClick={() => setEditStat(s.key)}>
            <span>{s.label}</span>
            <b style={{ color: s.color }}>{stats[s.key]}</b>
          </button>
        ))}
      </div>
      <div className="bhead">
        {isParking(b) ? <CarFront size={18} className="ic-brand" /> : <Building2 size={18} className="ic-brand" />}
        <b className="bname">{b.name}</b>
        <button className="icon-btn small" onClick={() => setRenaming(true)} aria-label="건물 정보 수정" title="건물 이름·층·호실 수 수정">
          <Pencil size={15} />
        </button>
        <small className="bmeta-txt">
          {floorsDescending(b).length}
          {b.isHorizontal && !isParking(b) ? '구역' : '층'} · {state.units.length}칸
        </small>
        <span className="grow" />
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
        <div className="bgrid" style={gridStyle}>
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
                    onClick={() => props.onSelect({ b: idx, unitId: u.id, floor: f })}
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
                  onClick={() => props.onSelect(floorSel ? null : { b: idx, unitId: null, floor: f })}
                >
                  {floorFire && <Flame size={14} className="fire-dot" />}
                  {floorLabel(b, state, f)}
                  {vuln > 0 && (
                    <span className="vbadge" title={`피난약자 ${vuln}칸`}>
                      <TriangleAlert size={11} strokeWidth={2.8} />
                      {vuln}
                    </span>
                  )}
                </button>
                <button className={`allbtn ${floorSel ? 'sel' : ''}`} onClick={() => props.onSelect(floorSel ? null : { b: idx, unitId: null, floor: f })}>
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
                        <b>
                          <HardHat size={12} /> {teamMain(t)}
                        </b>
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
      {renaming && (
        <BuildingEditDialog
          idx={idx}
          onClose={() => setRenaming(false)}
          onSave={(nb) => {
            setRenaming(false);
            const notes: string[] = [];
            if (nb.name !== b.name) notes.push(`이름 ${b.name} → ${nb.name}`);
            if (nb.startFloor !== b.startFloor || nb.endFloor !== b.endFloor)
              notes.push(`${b.isHorizontal && !isParking(b) ? '구역' : '층'} ${b.startFloor}~${b.endFloor} → ${nb.startFloor}~${nb.endFloor}`);
            if (nb.defaultUnits !== b.defaultUnits) notes.push(`층당 칸 ${b.defaultUnits} → ${nb.defaultUnits}`);
            if (!notes.length) return;
            act(
              (d) => {
                // 최신 건물 정보에 내가 바꾼 항목만 덮어쓴다 (그사이 다른 기기가 바꾼 항목은 유지)
                const cur = d.buildings[idx];
                if (!cur) return;
                const next = { ...cur };
                if (nb.name !== b.name) next.name = nb.name;
                if (nb.startFloor !== b.startFloor) next.startFloor = nb.startFloor;
                if (nb.endFloor !== b.endFloor) next.endFloor = nb.endFloor;
                if (nb.defaultUnits !== b.defaultUnits) next.defaultUnits = nb.defaultUnits;
                if (next.startFloor > next.endFloor) return;
                resizeBuilding(d, idx, next);
              },
              '건물',
              `건물 정보 수정 (${b.name}): ${notes.join(', ')}`,
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
      className={`ucell st-${u.status} ${props.selected ? 'sel' : ''} ${props.multi ? 'msel' : ''} ${props.origin ? 'origin' : ''} ${u.vulnerable ? 'vuln' : ''}`}
      style={{ gridColumn: `span ${props.span}`, background: u.status === 'unknown' ? undefined : st.color }}
      onClick={props.onClick}
      title={`${unitLabel(props.b, u)} · ${st.label}${u.memo ? ` · ${u.memo}` : ''}`}
    >
      <span className="unum">
        {u.vulnerable && <WheelchairIcon size={32} className="uv" aria-label="피난약자" />}
        <span className="unum-txt">{u.label || unitLabel(props.b, u).replace(/^.*구역 /, '')}</span>
      </span>
      <span className="ust">{SHORT[u.status] ?? st.label}</span>
      {u.memoPinned && u.memo && <span className="umemo">{u.memo}</span>}
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

const NAME_PRESETS = ['101동', '102동', '103동', 'A동', 'B동', '본관', '별관', '상가동', '지하주차장'];

/** 0층은 없으므로 건너뛴다 (1층 아래는 지하 1층) */
const stepFloor = (f: number, d: number) => (f + d === 0 ? f + 2 * d : f + d);

/** 건물 정보 수정 — 이름, 층 범위, 층당 호실 수 (늘리기·줄이기) */
function BuildingEditDialog(props: { idx: number; onClose: () => void; onSave: (b: Building) => void }) {
  const { data } = useSession();
  const ob = data.buildings[props.idx];
  const parking = isParking(ob);
  const [name, setName] = useState(ob.name);
  const [start, setStart] = useState(ob.startFloor);
  const [end, setEnd] = useState(ob.endFloor);
  const [units, setUnits] = useState(ob.defaultUnits);
  const nb: Building = { ...ob, name: name.trim(), startFloor: start, endFloor: end, defaultUnits: units };
  const err = !nb.name ? '이름을 입력하세요' : start > end ? '맨 아래가 맨 위보다 높습니다' : end - start > 120 ? '층(구역) 수가 너무 많습니다 (최대 120)' : '';
  const changedShape = start !== ob.startFloor || end !== ob.endFloor || units !== ob.defaultUnits;
  // 미리 해 보고 없어지는 칸 수를 알려 준다
  const lost = !err && changedShape ? resizeBuilding(structuredClone(data), props.idx, nb) : 0;
  const fu = ob.isHorizontal && !parking ? '구역' : '층';
  const flabel = (f: number) => (parking ? `B${-f}` : ob.isHorizontal ? `${f}구역` : f < 0 ? `B${-f}F` : `${f}F`);

  return (
    <Modal
      title="건물 정보 수정"
      onClose={props.onClose}
      footer={
        <>
          <button className="btn ghost" onClick={props.onClose}>
            취소
          </button>
          <button className={`btn ${lost ? 'danger' : 'primary'}`} disabled={!!err} onClick={() => props.onSave(nb)}>
            {lost ? `${lost}칸 지우고 저장` : '저장'}
          </button>
        </>
      }
    >
      <label className="field">
        <span>{parking ? '주차장 이름' : ob.isHorizontal ? '시설명' : '건물명 / 동 이름'}</span>
        <input value={name} maxLength={30} placeholder="예) 101동" onChange={(e) => setName(e.target.value)} />
      </label>
      <div className="chips">
        {NAME_PRESETS.map((p) => (
          <button key={p} className="chip" onClick={() => setName(p)}>
            {p}
          </button>
        ))}
      </div>

      <div className="bedit-steps">
        {parking ? (
          <Stepper label="지하 몇 층까지" value={`B1 ~ B${-start}`} onMinus={() => setStart(Math.min(-1, start + 1))} onPlus={() => setStart(Math.max(-10, start - 1))} minusOff={start >= -1} plusOff={start <= -10} />
        ) : (
          <>
            <Stepper label={`맨 위 ${fu}`} value={flabel(end)} onMinus={() => setEnd(stepFloor(end, -1))} onPlus={() => setEnd(stepFloor(end, 1))} minusOff={end <= start} />
            <Stepper label={`맨 아래 ${fu}`} value={flabel(start)} onMinus={() => setStart(stepFloor(start, -1))} onPlus={() => setStart(stepFloor(start, 1))} plusOff={start >= end} />
          </>
        )}
        <Stepper
          label={parking ? '층당 구역 수' : ob.isHorizontal ? '구역당 구획수' : '층당 호실(세대) 수'}
          value={`${units}${parking ? '구역' : '칸'}`}
          onMinus={() => setUnits(units - 1)}
          onPlus={() => setUnits(units + 1)}
          minusOff={units <= 1}
          plusOff={units >= 30}
        />
      </div>

      {!ob.isHorizontal && <p className="hint">옥상층은 맨 위층 위로 자동으로 따라갑니다. 1층 아래는 지하 1층(B1F)입니다.</p>}
      {changedShape && !err && (
        <p className="hint">
          늘어난 층·칸은 새로 생기고, 남아 있는 층·칸의 상태·메모·피난약자 표시는 그대로입니다.
        </p>
      )}
      {lost > 0 && <p className="error">줄어드는 층·칸 중 {lost}칸에 상태·메모·피난약자 표시가 있습니다. 저장하면 함께 지워집니다.</p>}
      {err && <p className="error">{err}</p>}
    </Modal>
  );
}

function Stepper(props: { label: string; value: string; onMinus: () => void; onPlus: () => void; minusOff?: boolean; plusOff?: boolean }) {
  return (
    <div className="bedit-step">
      <span>{props.label}</span>
      <button className="btn small icon-only" disabled={props.minusOff} onClick={props.onMinus} aria-label={`${props.label} 줄이기`}>
        <Minus size={18} />
      </button>
      <b>{props.value}</b>
      <button className="btn small icon-only" disabled={props.plusOff} onClick={props.onPlus} aria-label={`${props.label} 늘리기`}>
        <Plus size={18} />
      </button>
    </div>
  );
}

// 칸 안에 호수 옆에 나란히 쓰는 짧은 상태 이름
const SHORT: Partial<Record<Unit['status'], string>> = { fireFalseAlarm: '연소확대', resourceBase: '자원대기' };
