import { useEffect, useState, type CSSProperties } from 'react';
import type { UnitStatus } from '../types';
import { useSession } from '../session-context';
import { floorLabel, STATUS, STATUS_ORDER, unitFullName } from '../lib/building';
import { hhmm } from '../lib/format';
import type { Selection } from './BuildingCard';

/** 오른쪽 "선택·상태" 패널 — 호실/층을 고르면 상태를 바꾸고 화점·메모를 남긴다 */
export function ActionPanel({ sel, onClear }: { sel: Selection | null; onClear: () => void }) {
  const { data, act, me, logs } = useSession();
  const b = sel ? data.buildings[sel.b] : null;
  const st = sel ? data.states[sel.b] : null;
  const unit = sel?.unitId && st ? st.units.find((u) => u.id === sel.unitId) ?? null : null;
  const floorUnits = sel && sel.unitId == null && sel.floor != null && st ? st.units.filter((u) => u.floor === sel.floor) : null;

  const [memo, setMemo] = useState(unit?.memo ?? '');
  const [floorName, setFloorName] = useState('');
  useEffect(() => setMemo(unit?.memo ?? ''), [unit?.id, unit?.memo]);
  useEffect(() => {
    if (b && st && sel?.floor != null) setFloorName(st.floorLabels[String(sel.floor)] ?? '');
  }, [b, st, sel?.floor]);

  if (!sel || !b || !st || (!unit && !floorUnits)) {
    const recent = logs.slice(-12).reverse();
    return (
      <div className="panel-empty">
        <p className="hint big">보드에서 호실을 누르거나, 층 이름(또는 ALL)을 눌러 층 전체를 선택하세요.</p>
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
            <h3>
              {floorLabel(b, st, unit.floor)} · {name.split(' ').pop()}
            </h3>
          </div>
          <button className="icon-btn" onClick={onClear} aria-label="선택 해제">
            ✕
          </button>
        </div>

        <h4>상태</h4>
        <div className="status-btns">
          {STATUS_ORDER.map((s) => (
            <button
              key={s}
              className={unit.status === s ? 'on' : ''}
              style={{ '--c': STATUS[s].color } as CSSProperties}
              onClick={() => setStatus(s)}
            >
              <span>{STATUS[s].icon}</span>
              {STATUS[s].label}
            </button>
          ))}
        </div>

        <div className="toggle-row">
          <button
            className={`btn ${isOrigin ? 'fire on' : 'fire'}`}
            onClick={() =>
              act(
                (d) => {
                  d.fireOrigin = isOrigin ? null : { buildingIdx: bi, unitId: unit.id, floor: unit.floor, note: '', by: `${me.dept} ${me.role}`, at: Date.now() };
                },
                '화점',
                isOrigin ? `화점(추정) 해제: ${name}` : `화점(추정) 지정: ${name}`,
              )
            }
          >
            🔥 {isOrigin ? '화점 해제' : '화점(추정) 지정'}
          </button>
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
            ♿ 피난약자 {unit.vulnerable ? '해제' : '표시'}
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
            ⇥ 오른쪽과 합치기
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
            ⇤ 나누기
          </button>
          <button
            className="btn small"
            onClick={() => {
              onClear();
              act(
                (d) => {
                  d.states[bi].units = d.states[bi].units.filter((x) => x.id !== unit.id);
                  if (d.fireOrigin?.buildingIdx === bi && d.fireOrigin.unitId === unit.id) d.fireOrigin = null;
                },
                '건물',
                `${name} 빈 칸으로 만들기`,
              );
            }}
          >
            ▢ 빈 칸으로
          </button>
        </div>
      </div>
    );
  }

  // ── 층 전체 ──
  const f = sel.floor!;
  const fl = floorLabel(b, st, f);
  const isFloorOrigin = fo?.buildingIdx === bi && fo.unitId == null && fo.floor === f;
  const counts = STATUS_ORDER.map((s) => [s, floorUnits!.filter((u) => u.status === s).length] as const).filter(([, n]) => n > 0);
  return (
    <div className="action-panel">
      <div className="ap-head">
        <div>
          <small>{b.name}</small>
          <h3>{fl} 전체</h3>
          <small>
            {floorUnits!.length}칸 · {counts.map(([s, n]) => `${STATUS[s].label} ${n}`).join(' · ')}
          </small>
        </div>
        <button className="icon-btn" onClick={onClear} aria-label="선택 해제">
          ✕
        </button>
      </div>
      <h4>층 전체 상태 바꾸기</h4>
      <div className="status-btns">
        {STATUS_ORDER.map((s) => (
          <button
            key={s}
            style={{ '--c': STATUS[s].color } as CSSProperties}
            onClick={() => {
              const n = floorUnits!.filter((u) => u.status !== s).length;
              if (n === 0) return;
              act(
                (d) => {
                  for (const u of d.states[bi].units) if (u.floor === f) u.status = s;
                },
                '상태',
                `${b.name} ${fl} 전체 ${n}칸 → ${STATUS[s].label}`,
              );
            }}
          >
            <span>{STATUS[s].icon}</span>
            {STATUS[s].label}
          </button>
        ))}
      </div>
      <div className="toggle-row">
        <button
          className={`btn ${isFloorOrigin ? 'fire on' : 'fire'}`}
          onClick={() =>
            act(
              (d) => {
                d.fireOrigin = isFloorOrigin ? null : { buildingIdx: bi, unitId: null, floor: f, note: '', by: `${me.dept} ${me.role}`, at: Date.now() };
              },
              '화점',
              isFloorOrigin ? `화점(추정) 해제: ${b.name} ${fl}` : `화점(추정) 지정: ${b.name} ${fl} (호실 미상)`,
            )
          }
        >
          🔥 {isFloorOrigin ? '화점 해제' : '이 층을 화점(추정)으로'}
        </button>
        <button
          className="btn"
          onClick={() => {
            onClear();
            act(
              (d) => {
                if (!d.states[bi].hiddenFloors.includes(f)) d.states[bi].hiddenFloors.push(f);
              },
              '건물',
              `${b.name} ${fl} 숨기기`,
            );
          }}
        >
          👁 이 층 숨기기
        </button>
      </div>
      <h4>층 이름</h4>
      <div className="row-btns">
        <input value={floorName} placeholder={fl} onChange={(e) => setFloorName(e.target.value)} />
        <button
          className="btn small"
          onClick={() =>
            act(
              (d) => {
                const k = String(f);
                if (floorName.trim()) d.states[bi].floorLabels[k] = floorName.trim();
                else delete d.states[bi].floorLabels[k];
              },
              '건물',
              `${b.name} ${fl} 이름 변경 → ${floorName.trim() || '(기본)'}`,
            )
          }
        >
          저장
        </button>
      </div>
    </div>
  );
}
