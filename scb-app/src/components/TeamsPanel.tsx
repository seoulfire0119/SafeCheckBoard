import { useEffect, useRef, useState } from 'react';
import type { Team } from '../types';
import { useNow, useSession } from '../session-context';
import { floorKey, floorLabel, floorsDescending } from '../lib/building';
import { beep, LEVEL, teamElapsed, teamLevel, teamPlace, teamTitle } from '../lib/teams';
import { TEAM_COLORS } from '../lib/session';
import { mmss, uid } from '../lib/format';
import { Modal } from './Modal';

export const TASK_PRESETS = ['인명검색', '화재진압', '배연', '구조', '수관연장', '방어(연소저지)', '응급처치', '대기·교대'];

/** 진입대(착대) 관리 — 어느 대가 어느 층에서 무엇을 하는지, 얼마나 있었는지 */
export function TeamsPanel() {
  const { data, act } = useSession();
  const now = useNow();
  const [edit, setEdit] = useState<Team | 'new' | null>(null);
  const [settings, setSettings] = useState(false);
  const place = (t: Team) => teamPlace(data.buildings, data.states, t.floorKey) || '위치 미지정';

  const update = (t: Team, fn: (x: Team) => void, text: string) =>
    act(
      (d) => {
        const x = d.teams.find((y) => y.id === t.id);
        if (x) fn(x);
      },
      '진입대',
      text,
    );

  const active = data.teams.filter((t) => t.status !== 'waiting');
  return (
    <div className="teams-panel">
      <div className="tp-summary">
        {(['active', 'warning', 'danger', 'paused', 'waiting'] as const).map((lv) => {
          const n = data.teams.filter((t) => teamLevel(t, data.timerSettings, now) === lv).length;
          return (
            <span key={lv} style={{ color: LEVEL[lv].color }}>
              {LEVEL[lv].label} <b>{n}</b>
            </span>
          );
        })}
        <button className="icon-btn" title="타이머 설정" onClick={() => setSettings(true)}>
          ⚙
        </button>
      </div>
      {active.length === 0 && <p className="hint">진입한 대가 없습니다. 아래에서 대를 골라 [진입]을 누르세요.</p>}

      <ul className="team-list">
        {data.teams.map((t) => {
          const lv = teamLevel(t, data.timerSettings, now);
          return (
            <li key={t.id} className={`team lv-${lv}`} style={{ borderLeftColor: t.color }}>
              <div className="team-top">
                <span className="tdot" style={{ background: t.color }} />
                <b>{t.name}</b>
                <span className="tunit">{t.unit}</span>
                <span className="grow" />
                <span className="tlevel" style={{ background: LEVEL[lv].color }}>
                  {LEVEL[lv].label}
                </span>
                <span className="ttime">{mmss(teamElapsed(t, now))}</span>
              </div>
              <div className="team-mid" onClick={() => setEdit(t)} role="button" tabIndex={0}>
                📍 {place(t)} {t.task && <>· 🛠 {t.task}</>} <small>✎</small>
              </div>
              <div className="team-btns">
                {t.status === 'waiting' && (
                  <button
                    className="btn small go"
                    onClick={() =>
                      update(
                        t,
                        (x) => {
                          x.status = 'active';
                          x.entryAt = Date.now();
                          x.pausedMs = null;
                        },
                        `${teamTitle(t)} 진입 — ${place(t)}${t.task ? ` / ${t.task}` : ''}`,
                      )
                    }
                  >
                    ▶ 진입
                  </button>
                )}
                {t.status === 'active' && (
                  <button
                    className="btn small"
                    onClick={() =>
                      update(
                        t,
                        (x) => {
                          x.pausedMs = x.entryAt ? Date.now() - x.entryAt : 0;
                          x.status = 'paused';
                        },
                        `${teamTitle(t)} 일시정지 (${mmss(teamElapsed(t, now))})`,
                      )
                    }
                  >
                    ⏸ 정지
                  </button>
                )}
                {t.status === 'paused' && (
                  <button
                    className="btn small go"
                    onClick={() =>
                      update(
                        t,
                        (x) => {
                          x.entryAt = Date.now() - (x.pausedMs ?? 0);
                          x.pausedMs = null;
                          x.status = 'active';
                        },
                        `${teamTitle(t)} 재개`,
                      )
                    }
                  >
                    ▶ 재개
                  </button>
                )}
                {t.status !== 'waiting' && (
                  <button
                    className="btn small"
                    onClick={() =>
                      update(
                        t,
                        (x) => {
                          x.status = 'waiting';
                          x.entryAt = null;
                          x.pausedMs = null;
                        },
                        `${teamTitle(t)} 철수 (활동 ${mmss(teamElapsed(t, now))}) — ${place(t)}`,
                      )
                    }
                  >
                    ⏹ 철수
                  </button>
                )}
              </div>
            </li>
          );
        })}
      </ul>
      <button className="btn block" onClick={() => setEdit('new')}>
        + 대 추가
      </button>

      {edit && <TeamDialog team={edit === 'new' ? null : edit} onClose={() => setEdit(null)} />}
      {settings && <TimerSettingsDialog onClose={() => setSettings(false)} />}
    </div>
  );
}

function TeamDialog({ team, onClose }: { team: Team | null; onClose: () => void }) {
  const { data, act } = useSession();
  const nextNum = Math.max(0, ...data.teams.map((t) => parseInt(t.name, 10) || 0)) + 1;
  const [unit, setUnit] = useState(team?.unit ?? '');
  const [name, setName] = useState(team?.name ?? `${nextNum}착대`);
  const [key, setKey] = useState(team?.floorKey ?? '');
  const [task, setTask] = useState(team?.task ?? '');
  const [confirmDel, setConfirmDel] = useState(false);

  const save = () => {
    const place = teamPlace(data.buildings, data.states, key) || '위치 미지정';
    if (team) {
      const changes: string[] = [];
      if (team.floorKey !== key) changes.push(`위치 ${teamPlace(data.buildings, data.states, team.floorKey) || '미지정'} → ${place}`);
      if (team.task !== task.trim()) changes.push(`임무 ${task.trim() || '없음'}`);
      if (team.unit !== unit.trim() || team.name !== name.trim()) changes.push(`이름 ${name.trim()}(${unit.trim()})`);
      act(
        (d) => {
          const x = d.teams.find((y) => y.id === team.id);
          if (!x) return;
          x.unit = unit.trim();
          x.name = name.trim() || x.name;
          x.floorKey = key;
          x.task = task.trim();
        },
        changes.length ? '진입대' : undefined,
        `${teamTitle(team)} ${changes.join(', ')}`,
      );
    } else {
      const t: Team = {
        id: uid(),
        name: name.trim() || `${nextNum}착대`,
        unit: unit.trim(),
        color: TEAM_COLORS[data.teams.length % TEAM_COLORS.length],
        floorKey: key,
        task: task.trim(),
        status: 'waiting',
        entryAt: null,
        pausedMs: null,
      };
      act((d) => void d.teams.push(t), '진입대', `대 추가: ${teamTitle(t)} — ${place}`);
    }
    onClose();
  };

  return (
    <Modal
      title={team ? `${team.name} 편집` : '대 추가'}
      onClose={onClose}
      footer={
        <>
          {team && (
            <button className="btn danger ghost" onClick={() => setConfirmDel(true)}>
              삭제
            </button>
          )}
          <span className="grow" />
          <button className="btn ghost" onClick={onClose}>
            취소
          </button>
          <button className="btn primary" onClick={save}>
            저장
          </button>
        </>
      }
    >
      <div className="row2">
        <label className="field">
          <span>대 이름</span>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className="field">
          <span>단대명</span>
          <input value={unit} onChange={(e) => setUnit(e.target.value)} placeholder="예) 신수대, 성산119" autoFocus={!team} />
        </label>
      </div>
      <label className="field">
        <span>활동 위치</span>
        <select value={key} onChange={(e) => setKey(e.target.value)}>
          <option value="">선택 안 함</option>
          {data.buildings.map((b, bi) => (
            <optgroup key={bi} label={b.name}>
              {floorsDescending(b).map((f) => (
                <option key={f} value={floorKey(bi, f)}>
                  {b.name} {floorLabel(b, data.states[bi], f)}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </label>
      <label className="field">
        <span>임무</span>
        <input value={task} onChange={(e) => setTask(e.target.value)} placeholder="예) 인명검색" />
      </label>
      <div className="chips">
        {TASK_PRESETS.map((p) => (
          <button key={p} type="button" className={`chip ${task === p ? 'on' : ''}`} onClick={() => setTask(p)}>
            {p}
          </button>
        ))}
      </div>
      {confirmDel && team && (
        <div className="confirm-box">
          <p>{teamTitle(team)} 을(를) 목록에서 지울까요?</p>
          <button
            className="btn danger"
            onClick={() => {
              act((d) => void (d.teams = d.teams.filter((x) => x.id !== team.id)), '진입대', `대 삭제: ${teamTitle(team)}`);
              onClose();
            }}
          >
            삭제
          </button>
        </div>
      )}
    </Modal>
  );
}

function TimerSettingsDialog({ onClose }: { onClose: () => void }) {
  const { data, act } = useSession();
  const [warn, setWarn] = useState(String(data.timerSettings.warnMin));
  const [danger, setDanger] = useState(String(data.timerSettings.dangerMin));
  const [sound, setSound] = useState(() => localStorage.getItem('scb.sound') !== '0');
  return (
    <Modal
      title="진입 타이머 설정"
      onClose={onClose}
      footer={
        <>
          <button className="btn ghost" onClick={onClose}>
            취소
          </button>
          <button
            className="btn primary"
            onClick={() => {
              const w = Math.max(1, parseInt(warn, 10) || 15);
              const dg = Math.max(w + 1, parseInt(danger, 10) || 20);
              try {
                localStorage.setItem('scb.sound', sound ? '1' : '0');
              } catch {
                /* 무시 */
              }
              act(
                (d) => void (d.timerSettings = { warnMin: w, dangerMin: dg }),
                '진입대',
                `타이머 기준 변경: 경고 ${w}분 / 위험 ${dg}분`,
              );
              onClose();
            }}
          >
            저장
          </button>
        </>
      }
    >
      <div className="row2">
        <label className="field">
          <span>경고 (분)</span>
          <input inputMode="numeric" value={warn} onChange={(e) => setWarn(e.target.value)} />
        </label>
        <label className="field">
          <span>위험 (분)</span>
          <input inputMode="numeric" value={danger} onChange={(e) => setDanger(e.target.value)} />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" checked={sound} onChange={(e) => setSound(e.target.checked)} /> 이 기기에서 경고음 울리기
      </label>
    </Modal>
  );
}

/** 어느 화면을 보고 있든 경고·위험으로 넘어가면 알리고, 그 뒤 30초마다 다시 울린다 */
export function TeamAlarm() {
  const { data, toast } = useSession();
  const now = useNow();
  const prev = useRef<Map<string, string>>(new Map());
  useEffect(() => {
    const sound = localStorage.getItem('scb.sound') !== '0';
    for (const t of data.teams) {
      const lv = teamLevel(t, data.timerSettings, now);
      const before = prev.current.get(t.id);
      if (before && before !== lv && (lv === 'warning' || lv === 'danger')) {
        toast(`${lv === 'danger' ? '🚨' : '⚠'} ${teamTitle(t)} ${LEVEL[lv].label} — ${mmss(teamElapsed(t, now))} 경과`, lv === 'danger' ? 'error' : 'info');
        if (sound) beep(lv === 'danger');
      } else if (sound && (lv === 'warning' || lv === 'danger') && Math.floor(teamElapsed(t, now) / 1000) % 30 === 0) {
        beep(lv === 'danger');
      }
      prev.current.set(t.id, lv);
    }
  }, [now, data.teams, data.timerSettings, toast]);
  return null;
}
