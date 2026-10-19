import { useEffect, useState } from 'react';
import { hasUnsavedChanges, retrySaves, useSaveStatus } from '../lib/save-status';
import { useSession } from '../session-context';

export function SaveIndicator() {
  const status = useSaveStatus();
  const { connected } = useSession();
  const [online, setOnline] = useState(navigator.onLine);
  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    const warn = (e: BeforeUnloadEvent) => { if (hasUnsavedChanges()) { e.preventDefault(); e.returnValue = ''; } };
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    window.addEventListener('beforeunload', warn);
    return () => { window.removeEventListener('online', on); window.removeEventListener('offline', off); window.removeEventListener('beforeunload', warn); };
  }, []);
  return <div className={`save-indicator ${!online || status.failed || !connected ? 'failed' : ''}`} role="status" aria-live="polite">
    {!online ? '통신 끊김 · 최신 현황 확인 불가' : status.failed ? `저장 실패 ${status.failed}건` : status.saving ? `저장 중 ${status.saving}건` : status.pending ? '입력 저장 대기' : !connected ? '서버 연결 확인 중 · 최신 현황 미확인' : '서버 저장 완료'}
    {online && status.failed > 0 && <button className="btn small" onClick={retrySaves}>다시 저장</button>}
  </div>;
}
