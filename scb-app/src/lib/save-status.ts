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
    markSave(id, 'failed', () => { void trackedSave(operation, id).catch(() => {}); });
    throw e;
  }
}
