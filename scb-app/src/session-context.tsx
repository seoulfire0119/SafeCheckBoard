import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { ChatMessage, Identity, LogCategory, LogItem, SessionData } from './types';
import { addLog, mutateSession, subscribeChat, subscribeLogs, subscribeSession } from './lib/session';
import { trackedSave } from './lib/save-status';
import { subscribeAccess, type AccessRole } from './lib/access';
import { applyUndo, type Change } from './lib/undo';
import { saveSessionCache } from './lib/offline';

interface Toast {
  id: number;
  text: string;
  kind: 'info' | 'error';
}

interface Ctx {
  access: AccessRole;
  canEdit: boolean;
  connected: boolean;
  code: string;
  me: Identity;
  setMe: (v: Identity) => void;
  data: SessionData;
  logs: LogItem[];
  chat: ChatMessage[];
  /** 세션 문서를 고치고(트랜잭션), 로그를 남긴다 */
  act: (fn: (d: SessionData) => void, category?: LogCategory, text?: string) => Promise<void>;
  /** 이 기기에서 방금 한 현황판 변경 (되돌리기용) */
  lastAction: UndoEntry | null;
  undo: () => Promise<void>;
  dismissUndo: () => void;
  log: (category: LogCategory, text: string, at?: number) => void;
  toast: (text: string, kind?: Toast['kind']) => void;
}

export interface UndoEntry {
  id: number;
  category: LogCategory;
  text: string;
  changes: Change[];
}

const SessionCtx = createContext<Ctx | null>(null);

export function useSession() {
  const c = useContext(SessionCtx);
  if (!c) throw new Error('SessionProvider 밖에서 사용됨');
  return c;
}

const ToastCtx = createContext<(text: string, kind?: Toast['kind']) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastHost({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const seq = useRef(0);
  const toast = useCallback((text: string, kind: Toast['kind'] = 'info') => {
    const id = ++seq.current;
    setItems((v) => [...v, { id, text, kind }]);
    setTimeout(() => setItems((v) => v.filter((t) => t.id !== id)), kind === 'error' ? 6000 : 2500);
  }, []);
  return (
    <ToastCtx.Provider value={toast}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} className={`toast ${t.kind}`}>
            {t.text}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

export function SessionProvider(props: {
  code: string;
  me: Identity;
  setMe: (v: Identity) => void;
  initial: SessionData;
  onGone: () => void;
  children: ReactNode;
}) {
  const { code, me, setMe, onGone } = props;
  const toast = useToast();
  const [data, setData] = useState<SessionData>(props.initial);
  const [logs, setLogs] = useState<LogItem[]>([]);
  const [chat, setChat] = useState<ChatMessage[]>([]);
  const [access, setAccess] = useState<AccessRole>('viewer');
  const [connected, setConnected] = useState(false);
  const canEdit = access !== 'viewer' && !data.closed;
  const meRef = useRef(me);
  meRef.current = me;

  useEffect(() => {
    const err = (e: Error) => { setConnected(false); toast(`연결 오류: ${e.message}`, 'error'); };
    const u1 = subscribeSession(code, (d) => (d ? setData(d) : onGone()), err, setConnected);
    const u2 = subscribeLogs(code, setLogs, err);
    const u3 = subscribeChat(code, setChat, err);
    const u4 = subscribeAccess(code, setAccess, err);
    return () => {
      u1();
      u2();
      u3();
      u4();
    };
  }, [code, onGone, toast]);

  const log = useCallback(
    (category: LogCategory, text: string, at?: number) => {
      if (!canEdit) return;
      addLog(code, meRef.current, category, text, at).catch((e: Error) => toast(`기록 저장 실패: ${e.message}`, 'error'));
    },
    [code, toast, canEdit],
  );

  const [lastAction, setLastAction] = useState<UndoEntry | null>(null);
  const undoSeq = useRef(0);

  const act = useCallback(
    async (fn: (d: SessionData) => void, category?: LogCategory, text?: string) => {
      if (!canEdit) { toast(data.closed ? '종료된 현장입니다.' : '열람 권한입니다. 개설자에게 편집 권한을 요청하세요.', 'error'); return; }
      const at = Date.now();
      const actor = { ...meRef.current };
      try {
        // Only display committed state; commit its audit record in the same transaction.
        const changes = await trackedSave(() => mutateSession(code, fn, category && text ? { actor, category, text, at } : undefined));
        if (category && text && changes.length) setLastAction({ id: ++undoSeq.current, category, text, changes });
      } catch (e) {
        toast(`저장 실패: ${(e as Error).message}`, 'error');
      }
    },
    [code, toast, canEdit, data.closed],
  );

  // 되돌리기: 방금 바꾼 곳만 원래대로. 그사이 남이 또 바꾼 곳은 건드리지 않는다
  const undo = useCallback(async () => {
    const e = lastAction;
    if (!e) return;
    setLastAction(null);
    if (!canEdit) return;
    let result = { applied: 0, skipped: 0 };
    try {
      await trackedSave(() =>
        mutateSession(
          code,
          (d) => { result = applyUndo(d, e.changes); },
          { actor: { ...meRef.current }, category: e.category, text: `되돌림: ${e.text}`, at: Date.now() },
        ),
      );
      if (result.applied === 0) toast('다른 사람이 이미 바꿔서 되돌릴 것이 없습니다.', 'error');
      else if (result.skipped) toast(`되돌렸습니다. 그사이 다른 사람이 바꾼 ${result.skipped}곳은 그대로 두었습니다.`);
      else toast('되돌렸습니다');
    } catch (err) {
      toast(`되돌리기 실패: ${(err as Error).message}`, 'error');
    }
  }, [lastAction, canEdit, code, toast]);
  const dismissUndo = useCallback(() => setLastAction(null), []);

  // 통신이 끊겨도 마지막 화면은 보이게 이 기기에 저장 (환자 목록 제외)
  useEffect(() => {
    const t = setTimeout(() => saveSessionCache(code, data), 1000);
    return () => clearTimeout(t);
  }, [code, data]);

  const value = useMemo<Ctx>(
    () => ({ code, me, setMe, data, logs, chat, act, log, toast, access, canEdit, connected, lastAction, undo, dismissUndo }),
    [code, me, setMe, data, logs, chat, act, log, toast, access, canEdit, connected, lastAction, undo, dismissUndo],
  );
  return <SessionCtx.Provider value={value}>{props.children}</SessionCtx.Provider>;
}

/** 1초마다 다시 그리기 (진입 타이머용) */
export function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}
