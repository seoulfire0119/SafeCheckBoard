import { useEffect, useState, type CSSProperties } from 'react';
import { ArrowDownToLine, ArrowUpToLine, Columns2, EyeOff, Flame, Layers, MousePointerClick, Pencil, SquareDashed, SquareSplitHorizontal, TriangleAlert, X } from 'lucide-react';
import { Modal } from './Modal';
import type { Building, BuildingState, Unit, UnitStatus } from '../types';
import { STATUS_ICON } from './icons';
import { WheelchairIcon } from './WheelchairIcon';
import { useSession } from '../session-context';
import { baseFloorLabel, baseUnitLabel, bulkStatusRisks, floorLabel, floorsDescending, STATUS, STATUS_ORDER, unitFullName } from '../lib/building';
import { hhmm } from '../lib/format';
import type { Selection } from './BuildingCard';

/** 오른쪽 "선택·상태" 패널 — 호실/층을 고르면 상태를 바꾸고 화점·메모를 남긴다 */
export function ActionPanel({ sel, onClear, onSelect }: { sel: Selection | null; onClear: () => void; onSelect: (s: Selection | null) => void }) {
  const { data, act, logs } = useSession();
  const b = sel ? data.buildings[sel.b] : null;
  const st = sel ? data.states[sel.b] : null;
  const unit = sel?.unitId && st ? st.units.find((u) => u.id === sel.unitId) ?? null : null;
  const floorUnits = sel && sel.unitId == null && sel.floor != null && st ? st.units.filter((u) => u.floor === sel.floor) : null;
  const multiUnits = sel?.units?.length && st ? st.units.filter((u) => sel.units!.includes(u.id)) : null;

  const [memo, setMemo] = useState(unit?.memo ?? '');
  const [renaming, setRenaming] = useState(false);
  useEffect(() => setRenaming(false), [sel?.unitId, sel?.floor, sel?.b]);
  useEffect(() => setMemo(unit?.memo ?? ''), [unit?.id, unit?.memo]);
  const floorGuard = useRiskGuard(sel?.b ?? 0);

  if (!sel || !b || !st || (!unit && !floorUnits && !multiUnits?.length)) {
    const recent = logs.slice(-12).reverse();
    return (
      <div className="panel-empty">
        <div className="empty-state">
          <MousePointerClick size={28} />
          <b>호실을 선택하세요</b>
          <p className="hint">보드에서 호실을 누르거나, 층 이름(또는 ALL)을 눌러 층 전체를 고릅니다.</p>
          <p className="hint">여러 층을 한 번에 바꾸려면 층 이름(ALL)을 누르고 「아래 전부 / 위 전부」를 고르세요.</p>
        </div>
        <h3>최근 기록</h3>
        <ul className="mini-log">
          {recent.length === 0 && <li className="hint">아직 기록이 없습니다</li>}
          {recent.map((l) => (
            <li key={l.id}>
              <time>{hhmm(l.at)}</time>
              <span className="who">{l.actor.dept} {l.actor.role}</span>
              <span>{l.text}</span>
            </li>
          ))}
        </ul>
      </div>
    );
  }

  const bi = sel.b;
  const fo = data.fireOrigin;

  // ── 여러 칸 ──
  if (multiUnits?.length) return <MultiPanel bi={bi} b={b} st={st} units={multiUnits} onClear={onClear} />;

  // ── 호실 ──
  if (unit) {
    const name = unitFullName(b, st, unit);
    const isOrigin = fo?.buildingIdx === bi && fo.unitId === unit.id;
    const setStatus = (s: UnitStatus) =>
      unit.status !== s &&
      act(
        (d) => {
          const u = d.states[bi].units.find((x) => x.id === unit.id);
          if (u) u.status = s;
        },
        '상태',
        `${name}: ${STATUS[unit.status].label} → ${STATUS[s].label}`,
      );
    const commitMemo = () => {
      if (memo.trim() === unit.memo) return;
      act(
        (d) => {
          const u = d.states[bi].units.find((x) => x.id === unit.id);
          if (u) u.memo = memo.trim();
        },
        '메모',
        memo.trim() ? `${name} 메모: ${memo.trim()}` : `${name} 메모 삭제`,
      );
    };
    const canMerge = unit.unitIndex + unit.spanCount <= b.defaultUnits;
    return (
      <div className="action-panel">
        <div className="ap-head">
          <div>
            <small>{b.name}</small>
            <h3 className="with-edit">
              {floorLabel(b, st, unit.floor)} · {unit.label || baseUnitLabel(b, unit)}
              <button className={`icon-btn small ${renaming ? 'on' : ''}`} onClick={() => setRenaming(!renaming)} aria-label="호실 이름 바꾸기">
                <Pencil size={16} />
              </button>
            </h3>
            {unit.label && <small>원래 {baseUnitLabel(b, unit)}</small>}
          </div>
          <button className="icon-btn" onClick={onClear} aria-label="선택 해제">
            <X size={20} />
          </button>
        </div>
        {renaming && (
          <RenameBox
            current={unit.label ?? ''}
            original={baseUnitLabel(b, unit)}
            presets={UNIT_PRESETS}
            onSave={(v) => {
              setRenaming(false);
              if (v === (unit.label ?? '')) return;
              act(
                (d) => {
                  const u = d.states[bi].units.find((x) => x.id === unit.id);
                  if (!u) return;
                  if (v) u.label = v;
                  else delete u.label;
                },
                '건물',
                `${b.name} ${floorLabel(b, st, unit.floor)} ${unit.label || baseUnitLabel(b, unit)} 이름 → ${v || baseUnitLabel(b, unit)}`,
              );
            }}
          />
        )}

        <h4>상태</h4>
        <div className="status-btns">
          {STATUS_ORDER.map((s) => (
            <button
              key={s}
              className={unit.status === s ? 'on' : ''}
              style={{ '--c': STATUS[s].color } as CSSProperties}
              onClick={() => setStatus(s)}
            >
              {statusIcon(s)}
              {STATUS[s].label}
            </button>
          ))}
        </div>

        <div className="toggle-row">
          {/* 화점(추정) 지정은 쓰지 않는다. 예전에 지정해 둔 것만 지울 수 있게 해제 버튼을 남긴다 */}
          {isOrigin && (
            <button
              className="btn fire on"
              onClick={() =>
                act(
                  (d) => {
                    d.fireOrigin = null;
                  },
                  '화점',
                  `화점(추정) 해제: ${name}`,
                )
              }
            >
              <Flame size={18} /> 화점 해제
            </button>
          )}
          <button
            className={`btn ${unit.vulnerable ? 'on' : ''}`}
            onClick={() =>
              act(
                (d) => {
                  const u = d.states[bi].units.find((x) => x.id === unit.id);
                  if (u) u.vulnerable = !u.vulnerable;
                },
                '피난약자',
                `${name} 피난약자 ${unit.vulnerable ? '해제' : '표시'}`,
              )
            }
          >
            <WheelchairIcon size={20} /> 피난약자 {unit.vulnerable ? '해제' : '표시'}
          </button>
        </div>
        {isOrigin && fo && (
          <p className="hint">
            {hhmm(fo.at)} · {fo.by} 지정
          </p>
        )}

        <h4>
          메모
          <label className="pin">
            <input
              type="checkbox"
              checked={unit.memoPinned}
              onChange={() =>
                act((d) => {
                  const u = d.states[bi].units.find((x) => x.id === unit.id);
                  if (u) u.memoPinned = !u.memoPinned;
                })
              }
            />
            보드에 표시
          </label>
        </h4>
        <textarea
          value={memo}
          rows={3}
          placeholder="특이사항 (예: 거주자 2명, 문 잠김)"
          onChange={(e) => setMemo(e.target.value)}
          onBlur={commitMemo}
        />
        {memo.trim() !== unit.memo && (
          <button className="btn primary small" onClick={commitMemo}>
            메모 저장
          </button>
        )}

        <h4>칸 편집</h4>
        <div className="row-btns">
          <button
            className="btn small"
            disabled={!canMerge}
            onClick={() =>
              act(
                (d) => {
                  const s = d.states[bi];
                  const u = s.units.find((x) => x.id === unit.id);
                  if (!u) return;
                  const next = u.unitIndex + u.spanCount;
                  s.units = s.units.filter((x) => !(x.floor === u.floor && x.unitIndex === next));
                  u.spanCount += 1;
                },
                '건물',
                `${name} 오른쪽 칸과 합치기`,
              )
            }
          >
            <Columns2 size={16} /> 오른쪽과 합치기
          </button>
          <button
            className="btn small"
            disabled={unit.spanCount <= 1}
            onClick={() =>
              act(
                (d) => {
                  const s = d.states[bi];
                  const u = s.units.find((x) => x.id === unit.id);
                  if (!u || u.spanCount <= 1) return;
                  const freed = u.unitIndex + u.spanCount - 1;
                  u.spanCount -= 1;
                  s.units.push({
                    id: `${u.floor}-${freed}`,
                    floor: u.floor,
                    unitIndex: freed,
                    number: u.floor > 0 ? u.floor * 100 + freed : -(Math.abs(u.floor) * 100 + freed),
                    status: 'unknown',
                    memo: '',
                    memoPinned: false,
                    vulnerable: false,
                    spanCount: 1,
                  });
                },
                '건물',
                `${name} 칸 나누기`,
              )
            }
          >
            <SquareSplitHorizontal size={16} /> 나누기
          </button>
          <button
            className="btn small"
            onClick={() => {
              const lose = [
                isOrigin && '화점(추정) 표시',
                unit.status !== 'unknown' && `「${STATUS[unit.status].label}」 상태`,
                unit.memo && `메모 "${unit.memo.slice(0, 30)}"`,
                unit.vulnerable && '피난약자 표시',
              ].filter(Boolean) as string[];
              floorGuard.ask(`${name}을(를) 빈 칸으로 만들까요?`, lose.length ? [`이 칸의 ${lose.join(', ')}이(가) 함께 지워집니다.`] : [], () => {
                onClear();
                act(
                  (d) => {
                    d.states[bi].units = d.states[bi].units.filter((x) => x.id !== unit.id);
                    if (d.fireOrigin?.buildingIdx === bi && d.fireOrigin.unitId === unit.id) d.fireOrigin = null;
                  },
                  '건물',
                  `${name} 빈 칸으로 만들기`,
                );
              });
            }}
          >
            <SquareDashed size={16} /> 빈 칸으로
          </button>
        </div>
        {floorGuard.dialog}
      </div>
    );
  }

  // ── 층 전체 ──
  const f = sel.floor!;
  const fl = floorLabel(b, st, f);
  const isFloorOrigin = fo?.buildingIdx === bi && fo.unitId == null && fo.floor === f;
  const counts = STATUS_ORDER.map((s) => [s, floorUnits!.filter((u) => u.status === s).length] as const).filter(([, n]) => n > 0);
  const hidden = new Set(st.hiddenFloors);
  const visible = floorsDescending(b).filter((x) => !hidden.has(x));
  // 고른 층에서 아래(또는 위) 층을 모두 골라 "여러 칸 선택"으로 넘긴다
  const pickFloors = (dir: 'down' | 'up' | 'ground') => {
    const i = visible.indexOf(f);
    const floors =
      dir === 'down' ? visible.slice(i) : dir === 'up' ? visible.slice(0, i + 1) : visible.filter((x) => x <= f && x >= 1);
    const ids = st.units.filter((u) => floors.includes(u.floor)).map((u) => u.id);
    if (ids.length) onSelect({ b: bi, unitId: null, floor: null, units: ids });
  };
  return (
    <div className="action-panel">
      <div className="ap-head">
        <div>
          <small>{b.name}</small>
          <h3 className="with-edit">
            {fl} 전체
            <button className={`icon-btn small ${renaming ? 'on' : ''}`} onClick={() => setRenaming(!renaming)} aria-label="층 이름 바꾸기">
              <Pencil size={16} />
            </button>
          </h3>
          <small>
            {floorUnits!.length}칸 · {counts.map(([s, n]) => `${STATUS[s].label} ${n}`).join(' · ')}
          </small>
        </div>
        <button className="icon-btn" onClick={onClear} aria-label="선택 해제">
          <X size={20} />
        </button>
      </div>
      {renaming && (
        <RenameBox
          current={st.floorLabels[String(f)] ?? ''}
          original={baseFloorLabel(b, f)}
          presets={FLOOR_PRESETS}
          onSave={(v) => {
            setRenaming(false);
            const k = String(f);
            if (v === (st.floorLabels[k] ?? '')) return;
            act(
              (d) => {
                if (v) d.states[bi].floorLabels[k] = v;
                else delete d.states[bi].floorLabels[k];
              },
              '건물',
              `${b.name} ${fl} 층 이름 → ${v || baseFloorLabel(b, f)}`,
            );
          }}
        />
      )}
      <h4>층 전체 상태 바꾸기</h4>
      <div className="status-btns">
        {STATUS_ORDER.map((s) => (
          <button
            key={s}
            style={{ '--c': STATUS[s].color } as CSSProperties}
            onClick={() => {
              const n = floorUnits!.filter((u) => u.status !== s).length;
              if (n === 0) return;
              const text = `${b.name} ${fl} 전체 ${n}칸 → ${STATUS[s].label}`;
              floorGuard.guard(floorUnits!, s, text, () =>
                act(
                  (d) => {
                    for (const u of d.states[bi].units) if (u.floor === f) u.status = s;
                  },
                  '상태',
                  text,
                ),
              );
            }}
          >
            {statusIcon(s)}
            {STATUS[s].label}
          </button>
        ))}
      </div>
      <div className="range-box">
        <b>
          <Layers size={16} /> 여러 층 한 번에 고르기
        </b>
        <div className="row-btns">
          <button className="btn small" onClick={() => pickFloors('down')}>
            <ArrowDownToLine size={16} /> {fl}부터 아래 전부
          </button>
          <button className="btn small" onClick={() => pickFloors('up')}>
            <ArrowUpToLine size={16} /> {fl}부터 위 전부
          </button>
        </div>
        {f > 1 && visible.some((x) => x < 0) && (
          <button className="btn small" onClick={() => pickFloors('ground')}>
            <ArrowDownToLine size={16} /> {fl}~1F (지하 빼고)
          </button>
        )}
      </div>
      {isFloorOrigin && (
        <button
          className="btn fire on"
          onClick={() => act((d) => void (d.fireOrigin = null), '화점', `화점(추정) 해제: ${b.name} ${fl}`)}
        >
          <Flame size={18} /> 이 층 화점 표시 해제
        </button>
      )}
      <details className="more">
        <summary>
          <EyeOff size={16} /> 층 숨기기
        </summary>
        <p className="hint">층 숨기기: 상관없는 층을 접어서 보드를 짧게 만듭니다. 접힌 줄을 누르면 다시 보입니다.</p>
        <button
          className="btn small"
          onClick={() => {
            // 숨기면 큰 화면에서 안 보이게 되므로 중요한 것이 있는 층은 한 번 묻는다
            const fireN = floorUnits!.filter((u) => u.status === 'danger' || u.status === 'fireFalseAlarm').length;
            const vulnN = floorUnits!.filter((u) => u.vulnerable).length;
            const teamsHere = data.teams.filter((t) => t.status !== 'waiting' && t.floorKey === `${bi}_${f}`);
            const risks = [
              (isFloorOrigin || floorUnits!.some((u) => fo?.buildingIdx === bi && fo.unitId === u.id)) && '이 층에 화점(추정)이 있습니다.',
              fireN > 0 && `화재층·연소확대층 ${fireN}칸이 있습니다.`,
              vulnN > 0 && `피난약자 ${vulnN}칸이 있습니다.`,
              teamsHere.length > 0 && `진입 중인 대가 있습니다 (${teamsHere.map((t) => t.name).join(', ')}).`,
            ].filter(Boolean) as string[];
            floorGuard.ask(`${b.name} ${fl}을(를) 숨길까요?`, risks, () => {
              onClear();
              act(
                (d) => {
                  if (!d.states[bi].hiddenFloors.includes(f)) d.states[bi].hiddenFloors.push(f);
                },
                '건물',
                `${b.name} ${fl} 숨기기`,
              );
            });
          }}
        >
          <EyeOff size={16} /> 이 층 숨기기
        </button>
      </details>
      {floorGuard.dialog}
    </div>
  );
}

type PendingChange = { title: string; risks: string[]; run: () => void };


/**
 * 여러 칸을 한꺼번에 바꿀 때 실수하기 쉬운 경우(화점·화재층·피난약자 등)를 먼저 묻는다.
 * 걸리는 게 없으면 바로 바꾼다.
 */
function useRiskGuard(bi: number) {
  const { data } = useSession();
  const [pending, setPending] = useState<PendingChange | null>(null);
  const guard = (units: Unit[], next: UnitStatus, title: string, run: () => void) => ask(title, bulkStatusRisks(data, bi, units, next), run);
  /** 걸리는 게 있으면 묻고, 없으면 바로 한다 */
  const ask = (title: string, risks: string[], run: () => void) => {
    if (risks.length) setPending({ title, risks, run });
    else run();
  };
  const dialog = pending && (
    <Modal
      title="한 번 더 확인해 주세요"
      onClose={() => setPending(null)}
      footer={
        <>
          <button className="btn ghost" onClick={() => setPending(null)}>
            취소
          </button>
          <button
            className="btn danger"
            onClick={() => {
              pending.run();
              setPending(null);
            }}
          >
            그래도 바꾸기
          </button>
        </>
      }
    >
      <p>
        <b>{pending.title}</b>
      </p>
      <ul className="risk-list">
        {pending.risks.map((r) => (
          <li key={r}>
            <TriangleAlert size={16} /> {r}
          </li>
        ))}
      </ul>
      <p className="hint">계속하시겠습니까? 바꾼 뒤에도 화면 아래 「되돌리기」로 바로 원래대로 돌릴 수 있습니다.</p>
    </Modal>
  );
  return { guard, ask, dialog };
}

function statusIcon(s: UnitStatus) {
  const I = STATUS_ICON[s];
  return <I size={18} />;
}

/** "1F~7F" 처럼 고른 칸의 층 범위를 글자로 */
function floorRangeText(b: Building, st: BuildingState, units: Unit[]) {
  const fs = Array.from(new Set(units.map((u) => u.floor))).sort((x, y) => y - x);
  if (fs.length === 1) return floorLabel(b, st, fs[0]);
  const vis = floorsDescending(b).filter((x) => !st.hiddenFloors.includes(x));
  const i1 = vis.indexOf(fs[0]);
  const i2 = vis.indexOf(fs[fs.length - 1]);
  const contiguous = i1 >= 0 && i2 >= 0 && i2 - i1 + 1 === fs.length;
  return contiguous
    ? `${floorLabel(b, st, fs[fs.length - 1])}~${floorLabel(b, st, fs[0])}`
    : fs.map((x) => floorLabel(b, st, x)).join(', ');
}

/** 여러 칸을 한꺼번에 — 예) 1F~7F 전부 확인완료 */
function MultiPanel({ bi, b, st, units, onClear }: { bi: number; b: Building; st: BuildingState; units: Unit[]; onClear: () => void }) {
  const { act } = useSession();
  const { guard, dialog } = useRiskGuard(bi);
  const range = floorRangeText(b, st, units);
  const floors = new Set(units.map((u) => u.floor)).size;
  const counts = STATUS_ORDER.map((s) => [s, units.filter((u) => u.status === s).length] as const).filter(([, n]) => n > 0);
  const ids = new Set(units.map((u) => u.id));
  return (
    <div className="action-panel">
      <div className="ap-head">
        <div>
          <small>{b.name}</small>
          <h3>{range}</h3>
          <small>
            {floors}개 층 · {units.length}칸 선택 · {counts.map(([s, n]) => `${STATUS[s].label} ${n}`).join(' · ')}
          </small>
        </div>
        <button className="icon-btn" onClick={onClear} aria-label="선택 해제">
          <X size={20} />
        </button>
      </div>
      <h4>선택한 {units.length}칸 상태 한 번에 바꾸기</h4>
      <div className="status-btns">
        {STATUS_ORDER.map((s) => (
          <button
            key={s}
            style={{ '--c': STATUS[s].color } as CSSProperties}
            onClick={() => {
              const n = units.filter((u) => u.status !== s).length;
              if (n === 0) return;
              const text = `${b.name} ${range} ${n}칸 → ${STATUS[s].label}`;
              guard(units, s, text, () =>
                act(
                  (d) => {
                    for (const u of d.states[bi].units) if (ids.has(u.id)) u.status = s;
                  },
                  '상태',
                  text,
                ),
              );
            }}
          >
            {statusIcon(s)}
            {STATUS[s].label}
          </button>
        ))}
      </div>
      {dialog}
    </div>
  );
}

const FLOOR_PRESETS = ['L', 'M', 'LB', 'G', 'P', '로비', '필로티', '주차장', '기계실층', '중층'];
const UNIT_PRESETS = ['주차장', '기계실', '전기실', '관리실', '상가', '창고', '계단실', '승강기', '공용부', '빈 세대'];

/** 이름 바꾸기 — 버튼으로 고르거나 직접 쓰기, 비우면 원래 이름 */
function RenameBox(props: { current: string; original: string; presets: string[]; onSave: (v: string) => void }) {
  const [v, setV] = useState(props.current);
  return (
    <div className="rename-box">
      <div className="row-btns">
        <input
          value={v}
          autoFocus
          placeholder={`원래 이름: ${props.original}`}
          onChange={(e) => setV(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && props.onSave(v.trim())}
        />
        <button className="btn small primary" onClick={() => props.onSave(v.trim())}>
          저장
        </button>
      </div>
      <div className="chips">
        {props.presets.map((p) => (
          <button key={p} className="chip" onClick={() => props.onSave(p)}>
            {p}
          </button>
        ))}
      </div>
      {props.current && (
        <button className="btn tiny ghost" onClick={() => props.onSave('')}>
          원래 이름({props.original})으로 되돌리기
        </button>
      )}
    </div>
  );
}
