import { useEffect } from 'react';
import { Undo2, X } from 'lucide-react';
import { useSession } from '../session-context';

const SHOW_MS = 12000;

/** 방금 바꾼 것을 화면 아래에 잠깐 보여 주고 「되돌리기」를 할 수 있게 한다 */
export function UndoBar() {
  const { lastAction, undo, dismissUndo, canEdit } = useSession();
  useEffect(() => {
    if (!lastAction) return;
    const t = setTimeout(dismissUndo, SHOW_MS);
    return () => clearTimeout(t);
  }, [lastAction, dismissUndo]);
  if (!lastAction || !canEdit) return null;
  return (
    <div className="undo-bar" role="status">
      <span className="undo-text">{lastAction.text}</span>
      <button className="btn small" onClick={() => void undo()}>
        <Undo2 size={16} /> 되돌리기
      </button>
      <button className="icon-btn" onClick={dismissUndo} aria-label="닫기">
        <X size={18} />
      </button>
    </div>
  );
}
