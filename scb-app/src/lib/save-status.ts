import { useSyncExternalStore } from 'react';

type Task = { state: 'pending' | 'saving' | 'failed'; retry?: () => void };
const tasks = new Map<string, Task>();
const listeners = new Set<() => void>();
let snapshot = { pending: 0, saving: 0, failed: 0 };
let sequence = 0;
const emit = () => {
  snapshot = { pending: 0, saving: 0, failed: 0 };
  for (const task of tasks.values()) snapshot[task.state]++;
  listeners.forEach((f) => f());
};
export const newSaveId = () => `save-${++sequence}`;
export function markSave(id: string, state?: Task['state'], retry?: () => void) {
  if (state) tasks.set(id, { state, retry });
  else tasks.delete(id);
  emit();
}
export function retrySaves() {
  for (const task of [...tasks.values()]) if (task.state === 'failed') task.retry?.();
}
export function hasUnsavedChanges() { return tasks.size > 0; }
/** 세션을 나갈 때 남은 저장 대기·실패 항목을 버린다 */
export function discardSaves() {
  tasks.clear();
  emit();
}

// 다시 시도해도 똑같이 실패하는 오류 (권한 없음·현장 종료·세션 없음 등)
const PERMANENT = new Set(['permission-denied', 'not-found', 'invalid-argument', 'unauthenticated']);
const isPermanent = (e: unknown) => PERMANENT.has((e as { code?: string }).code ?? '');
export function useSaveStatus() {
  return useSyncExternalStore((f) => { listeners.add(f); return () => { listeners.delete(f); }; }, () => snapshot);
}

export async function trackedSave<T>(operation: () => Promise<T>, id = newSaveId()): Promise<T> {
  markSave(id, 'saving');
  try {
    const result = await operation();
    markSave(id);
    return result;
  } catch (e) {
    // 재시도해도 소용없는 실패는 "미저장"으로 남겨 두지 않는다 (호출한 쪽에서 오류를 알림)
    if (isPermanent(e)) markSave(id);
    else markSave(id, 'failed', () => { void trackedSave(operation, id).catch(() => {}); });
    throw e;
  }
}
