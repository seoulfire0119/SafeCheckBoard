import { useCallback, useEffect, useRef, useState } from 'react';
import { mergeEdits } from './merge';
import { markSave, newSaveId } from './save-status';
import { useSession } from '../session-context';

/** Serialize saves; retain failed drafts and their original edit base. */
export function useSynced<T>(remote: T, save: (value: T, base: T) => Promise<T | void>) {
  const { canEdit, toast } = useSession();
  const [value, setValue] = useState(remote);
  const draft = useRef(remote);
  const base = useRef(remote);
  const dirty = useRef(false);
  const running = useRef<Promise<boolean> | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>();
  const mounted = useRef(true);
  const saveRef = useRef(save);
  saveRef.current = save;
  const id = useRef(newSaveId());

  const flush = useCallback((): Promise<boolean> => {
    clearTimeout(timer.current);
    if (running.current) return running.current;
    if (!dirty.current) return Promise.resolve(true);
    const run = async () => {
      while (dirty.current) {
        const sent = structuredClone(draft.current);
        const before = structuredClone(base.current);
        markSave(id.current, 'saving');
        try {
          const saved = (await saveRef.current(sent, before)) ?? sent;
          const next = mergeEdits(sent, draft.current, saved);
          base.current = saved;
          draft.current = next;
          dirty.current = JSON.stringify(saved) !== JSON.stringify(next);
          if (mounted.current) setValue(next);
        } catch {
          markSave(id.current, 'failed', () => { void flush(); });
          return false;
        }
      }
      markSave(id.current);
      return true;
    };
    running.current = run().finally(() => { running.current = null; });
    return running.current;
  }, []);

  useEffect(() => {
    if (!dirty.current && !running.current) {
      base.current = remote;
      draft.current = remote;
      setValue(remote);
    }
  }, [remote]);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; void flush(); };
  }, [flush]);

  const update = useCallback((next: T | ((previous: T) => T)) => {
    if (!canEdit) { toast('열람 중에는 입력할 수 없습니다.', 'error'); return; }
    const v = typeof next === 'function' ? (next as (p: T) => T)(draft.current) : next;
    draft.current = v;
    dirty.current = true;
    setValue(v);
    markSave(id.current, 'pending');
    clearTimeout(timer.current);
    timer.current = setTimeout(() => { void flush(); }, 700);
  }, [flush, canEdit, toast]);

  return [value, update, flush] as const;
}
