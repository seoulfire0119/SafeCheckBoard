import { useState } from 'react';
import type { Identity } from '../types';
import { AGENCY_PRESETS, DEPT_PRESETS, ROLE_PRESETS } from '../lib/identity';
import { Modal } from './Modal';

/**
 * 세션에 들어갈 때 "누가 기록하는지" 정한다.
 * 아래 버튼에서 고르거나, 칸에 직접 쓰면 된다.
 */
export function IdentityDialog(props: { initial: Identity | null; onSave: (v: Identity) => void; onClose?: () => void }) {
  const [v, setV] = useState<Identity>(props.initial ?? { agency: '소방', dept: '', role: '' });
  const ok = v.agency.trim() && v.dept.trim() && v.role.trim();
  const depts = DEPT_PRESETS[v.agency.trim()] ?? [];

  const save = () => {
    if (!ok) return;
    props.onSave({ agency: v.agency.trim(), dept: v.dept.trim(), role: v.role.trim() });
  };

  return (
    <Modal
      title="기록자 정보"
      onClose={props.onClose}
      footer={
        <>
          {props.onClose && (
            <button className="btn ghost" onClick={props.onClose}>
              취소
            </button>
          )}
          <button className="btn primary" disabled={!ok} onClick={save}>
            확인
          </button>
        </>
      }
    >
      <p className="hint">모든 기록에 아래 정보가 함께 남습니다. 버튼에서 고르거나, 목록에 없으면 칸에 직접 입력하세요.</p>
      <form
        className="identity-form"
        onSubmit={(e) => {
          e.preventDefault();
          save();
        }}
      >
        <Field
          label="기관"
          value={v.agency}
          placeholder="예) 소방"
          options={AGENCY_PRESETS}
          onChange={(x, picked) => setV({ ...v, agency: x, dept: picked ? '' : v.dept })}
        />
        <Field
          label="소속"
          value={v.dept}
          placeholder="예) 마포소방서 현장지휘팀"
          options={depts}
          onChange={(x) => setV({ ...v, dept: x })}
        />
        <Field label="담당" value={v.role} placeholder="예) 상황관리" options={ROLE_PRESETS} onChange={(x) => setV({ ...v, role: x })} />
        <button type="submit" hidden />
      </form>
    </Modal>
  );
}

function Field(props: {
  label: string;
  value: string;
  placeholder: string;
  options: string[];
  onChange: (v: string, picked: boolean) => void;
}) {
  return (
    <div className="id-field">
      <label className="field">
        <span>{props.label}</span>
        <input value={props.value} placeholder={props.placeholder} onChange={(e) => props.onChange(e.target.value, false)} autoComplete="off" />
      </label>
      {props.options.length > 0 && (
        <div className="chips" aria-label={`${props.label} 빠른 선택`}>
          {props.options.map((o) => (
            <button type="button" key={o} className={`chip ${props.value === o ? 'on' : ''}`} onClick={() => props.onChange(o, true)}>
              {o}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
