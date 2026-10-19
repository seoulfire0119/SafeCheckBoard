import { useEffect, useState } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, googleLogin } from '../firebase';
import { useToast } from '../session-context';
import { hasUnsavedChanges } from '../lib/save-status';

export function GoogleLoginButton() {
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState('');
  useEffect(() => onAuthStateChanged(auth, (user) => setEmail(user?.isAnonymous ? '' : user?.email ?? '')), []);
  const toast = useToast();
  return <button className="btn" disabled={busy} onClick={async () => {
    if (hasUnsavedChanges()) { toast('미저장 변경을 먼저 저장하세요.', 'error'); return; }
    setBusy(true);
    try {
      await googleLogin();
      location.reload();
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code !== 'auth/popup-closed-by-user' && code !== 'auth/cancelled-popup-request')
        toast(`Google 로그인 실패: ${(e as Error).message}`, 'error');
      setBusy(false);
    }
  }}>{busy ? 'Google 로그인 중…' : email ? `${email} · 계정 변경` : 'Google 계정으로 로그인'}</button>;
}
