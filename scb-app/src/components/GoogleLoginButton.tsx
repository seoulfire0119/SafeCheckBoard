import { useEffect, useState } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, googleLogin, logout } from '../firebase';
import { useToast } from '../session-context';
import { hasUnsavedChanges } from '../lib/save-status';

/**
 * 지금 Google 로 로그인되어 있으면 그 이메일, 아니면 ''. 확인 전에는 null.
 * (익명 기기에 Google 을 연결한 경우도 로그인으로 본다 — 서버 규칙과 같은 기준)
 */
export function useGoogleEmail(): string | null {
  const [email, setEmail] = useState<string | null>(null);
  useEffect(
    () =>
      onAuthStateChanged(auth, (user) => {
        const google = user?.providerData.find((p) => p.providerId === 'google.com');
        setEmail(google ? google.email ?? user?.email ?? 'Google 계정' : '');
      }),
    [],
  );
  return email;
}

/** 현장 관리자용 Google 로그인. 일반 참여자는 쓰지 않아도 된다. */
export function GoogleLoginButton({ className = 'btn small on-soft', label = '관리자 로그인 (Google)' }: { className?: string; label?: string }) {
  const [busy, setBusy] = useState(false);
  const email = useGoogleEmail();
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
      {busy ? 'Google 로그인 중…' : label}
    </button>
  );
}
