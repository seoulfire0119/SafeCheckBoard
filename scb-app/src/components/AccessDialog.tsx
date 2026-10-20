import { useEffect, useState } from 'react';
import { useSession } from '../session-context';
import { deviceUid } from '../firebase';
import { setMemberRole, setSessionClosed, subscribeMembers, type Member } from '../lib/access';
import { identityText } from '../lib/identity';
import { hasUnsavedChanges } from '../lib/save-status';
import { Modal } from './Modal';
import { GoogleLoginButton } from './GoogleLoginButton';

export function AccessDialog({ onClose }: { onClose: () => void }) {
  const { code, access, data, me, toast } = useSession();
  const [members, setMembers] = useState<Member[]>([]);
  const [uid, setUid] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => { void deviceUid().then(setUid); }, []);
  useEffect(() => {
    if (access !== 'owner') return;
    return subscribeMembers(code, setMembers, (e) => toast(e.message, 'error'));
  }, [code, access, toast]);
  const run = async (fn: () => Promise<unknown>) => {
    setBusy(true);
    try { await fn(); } catch (e) { toast((e as Error).message, 'error'); }
    finally { setBusy(false); }
  };
  return <Modal title="참여 권한 · 현장 종료" onClose={onClose}>
    <p>내 기기: <code>{uid}</code></p>
    <p className="hint">새로 참여한 기기는 열람만 가능합니다. 개설자가 아래에서 편집 권한을 부여합니다. 기록자 이름은 직접 입력한 정보이며 실명 인증은 아닙니다.</p>
    <p>{identityText(me)}</p>
    {access === 'owner' ? <>
      <ul className="access-list">{members.map((m) => <li key={m.uid}>
        <span>{m.name || '참여 기기'}</span>
        <code>{m.uid}</code>
        {m.role === 'owner' ? <b>개설자</b> : <select aria-label={`${m.uid} 참여 권한`} disabled={busy} value={m.role}
          onChange={(e) => { void run(() => setMemberRole(code, m.uid, e.target.value as 'editor' | 'viewer')); }}>
          <option value="viewer">열람</option><option value="editor">편집</option>
        </select>}
      </li>)}</ul>
      <button className="btn danger" disabled={busy} onClick={() => {
        if (!data.closed && hasUnsavedChanges()) { toast('미저장 변경을 먼저 저장하세요.', 'error'); return; }
        if (confirm(data.closed ? '현장을 다시 열까요?' : '현장을 종료하고 모든 입력을 잠글까요?')) void run(() => setSessionClosed(code, !data.closed));
      }}>{data.closed ? '현장 다시 열기' : '현장 종료 · 읽기 전용으로 잠금'}</button>
    </> : <>
      <p>개설자에게 위 기기 번호를 알려주고 편집 권한을 요청하세요.</p>
      <GoogleLoginButton className="btn small" />
      <p className="hint">현장 관리자는 관리용 Google 계정으로 로그인하면 관리 권한이 적용됩니다.</p>
    </>}
  </Modal>;
}
