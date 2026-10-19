import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * 표·양식처럼 글자를 계속 치는 화면용.
 * 내가 치는 동안(마지막 입력 후 2초)은 서버 값으로 덮어쓰지 않고,
 * 입력이 멈추면 0.7초 뒤 한 번에 저장한다.
 */
export function useSynced<T>(remote: T, save: (v: T) => Promise<void>) {
  const [value, setValue] = useState<T>(remote);
  const lastEdit = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout>>();
  const pending = useRef<T | null>(null);
  const saveRef = useRef(save);
  saveRef.current = save;
  const remoteJson = JSON.stringify(remote);

  useEffect(() => {
    if (Date.now() - lastEdit.current > 2000) setValue(JSON.parse(remoteJson) as T);
  }, [remoteJson]);

  const flush = useCallback(() => {
    clearTimeout(timer.current);
    if (pending.current !== null) {
      const v = pending.current;
      pending.current = null;
      saveRef.current(v).catch(() => {});
    }
  }, []);

  // 화면을 떠날 때 저장 안 된 입력이 있으면 마저 저장
  useEffect(() => flush, [flush]);

  const update = useCallback(
    (next: T | ((prev: T) => T)) => {
      setValue((prev) => {
        const v = typeof next === 'function' ? (next as (p: T) => T)(prev) : next;
        lastEdit.current = Date.now();
        pending.current = v;
        clearTimeout(timer.current);
        timer.current = setTimeout(flush, 700);
        return v;
      });
    },
    [flush],
  );

  return [value, update, flush] as const;
}
