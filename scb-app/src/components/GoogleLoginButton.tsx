import { useEffect, useState } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, googleLogin, logout } from '../firebase';
import { useToast } from '../session-context';
import { hasUnsavedChanges } from '../lib/save-status';

/** 현장 관리자용 Google 로그인. 일반 참여자는 쓰지 않아도 된다. */
export function GoogleLoginButton({ className = 'btn small on-soft' }: { className?: string }) {
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState('');
  useEffect(() => onAuthStateChanged(auth, (user) => setEmail(user?.isAnonymous ? '' : user?.email ?? '')), []);
  const toast = useToast();

  const run = async (fn: () => Promise<unknown>) => {
    if (hasUnsavedChanges()) { toast('미저장 변경을 먼저 저장하세요.', 'error'); return; }
    setBusy(true);
    try {
      await fn();
      location.reload();
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code !== 'auth/popup-closed-by-user' && code !== 'auth/cancelled-popup-request')
        toast(`Google 로그인 실패: ${(e as Error).message}`, 'error');
      setBusy(false);
    }
  };

  if (email)
    return (
      <span className="hint">
        관리자 로그인: {email}{' '}
        <button className={className} disabled={busy} onClick={() => {
          if (confirm('로그아웃하면 이 기기는 새 참여자(열람)로 시작합니다. 로그아웃할까요?')) void run(logout);
        }}>로그아웃</button>
      </span>
    );
  return (
    <button className={className} disabled={busy} onClick={() => void run(googleLogin)}>
      {busy ? 'Google 로그인 중…' : '관리자 로그인 (Google)'}
    </button>
  );
}
