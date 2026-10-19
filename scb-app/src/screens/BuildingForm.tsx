import { useState, type FormEvent, type ReactNode } from 'react';
import { Building2, Store } from 'lucide-react';
import type { Building } from '../types';

/** 건물 정보 입력 (새 세션 시작 / 건물 추가 공용) */
export function BuildingForm(props: { submitLabel: string; onSubmit: (b: Building) => void; busy?: boolean; children?: ReactNode }) {
  const [horizontal, setHorizontal] = useState(false);
  const [name, setName] = useState('');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [units, setUnits] = useState('');
  const [err, setErr] = useState('');

  const s = parseInt(start, 10);
  const e = parseInt(end, 10);
  const u = parseInt(units, 10);

  const submit = (ev: FormEvent) => {
    ev.preventDefault();
    if (!name.trim()) return setErr(horizontal ? '시설명을 입력하세요' : '건물명을 입력하세요');
    if (!Number.isFinite(s) || !Number.isFinite(e)) return setErr('층(구역) 범위를 숫자로 입력하세요');
    if (s > e) return setErr(horizontal ? '시작 구역은 끝 구역보다 작거나 같아야 합니다' : '시작층은 끝층보다 작거나 같아야 합니다');
    if (!Number.isFinite(u) || u < 1 || u > 30) return setErr('세대(구획)수는 1~30 사이로 입력하세요');
    if (e - s > 120) return setErr('층(구역) 수가 너무 많습니다 (최대 120)');
    setErr('');
    props.onSubmit({ name: name.trim(), startFloor: s, endFloor: e, defaultUnits: u, isHorizontal: horizontal });
  };

  const fu = horizontal ? '구역' : '층';
  return (
    <form className="building-form" onSubmit={submit}>
      <div className="seg big">
        <button type="button" className={!horizontal ? 'on' : ''} onClick={() => setHorizontal(false)}>
          <Building2 size={26} />
          <b>세로형</b>
          <small>아파트·빌딩</small>
        </button>
        <button type="button" className={horizontal ? 'on' : ''} onClick={() => setHorizontal(true)}>
          <Store size={26} />
          <b>가로형</b>
          <small>시장·의료시설</small>
        </button>
      </div>
      {props.children}
      <label className="field">
        <span>{horizontal ? '시설명' : '건물명 / 동 이름'}</span>
        <input value={name} onChange={(x) => setName(x.target.value)} placeholder={horizontal ? '예) 문기시장' : '예) 101동'} />
      </label>
      <div className="row2">
        <label className="field">
          <span>시작 {fu}</span>
          <input inputMode="numeric" value={start} onChange={(x) => setStart(x.target.value)} placeholder={horizontal ? '1' : '1 (지하: -2)'} />
        </label>
        <label className="field">
          <span>끝 {fu}</span>
          <input inputMode="numeric" value={end} onChange={(x) => setEnd(x.target.value)} placeholder={horizontal ? '5' : '15'} />
        </label>
        <label className="field">
          <span>{horizontal ? '구역당 구획수' : '층당 세대수'}</span>
          <input inputMode="numeric" value={units} onChange={(x) => setUnits(x.target.value)} placeholder={horizontal ? '10' : '4'} />
        </label>
      </div>
      {!horizontal && <p className="hint">지하층은 음수로 입력 (예: -2). 옥상층은 자동으로 추가됩니다.</p>}
      {Number.isFinite(s) && Number.isFinite(e) && Number.isFinite(u) && s <= e && u >= 1 && (
        <Preview s={s} e={e} u={u} horizontal={horizontal} />
      )}
      {err && <p className="error">{err}</p>}
      <button className="btn primary block" type="submit" disabled={props.busy}>
        {props.busy ? '만드는 중…' : props.submitLabel}
      </button>
    </form>
  );
}

function Preview({ s, e, u, horizontal }: { s: number; e: number; u: number; horizontal: boolean }) {
  const floors: number[] = [];
  for (let f = e; f >= s; f--) if (f !== 0) floors.push(f);
  if (!horizontal) floors.unshift(e + 1);
  const show = floors.slice(0, 8);
  const cols = Math.min(u, 8);
  return (
    <div className="preview">
      <div className="preview-grid" style={{ gridTemplateColumns: `44px repeat(${cols}, 1fr)` }}>
        {show.map((f) => (
          <div key={f} style={{ display: 'contents' }}>
            <div className="pv-label">{!horizontal && f === e + 1 ? '옥상' : horizontal ? `${f}구역` : f < 0 ? `B${-f}` : `${f}F`}</div>
            {Array.from({ length: cols }, (_, i) => (
              <div key={i} className="pv-cell" />
            ))}
          </div>
        ))}
      </div>
      <p className="hint">
        총 {floors.length}
        {horizontal ? '구역' : '층'} × {u} = {floors.length * u}칸{floors.length > 8 || u > 8 ? ' (일부만 미리보기)' : ''}
      </p>
    </div>
  );
}
