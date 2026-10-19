import { useEffect, type ReactNode } from 'react';
import { X } from 'lucide-react';

export function Modal(props: {
  title: ReactNode;
  onClose?: () => void;
  children: ReactNode;
  footer?: ReactNode;
  wide?: boolean;
  full?: boolean;
}) {
  const { onClose } = props;
  useEffect(() => {
    if (!onClose) return;
    const h = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);

  return (
    <div className="modal-back" onMouseDown={(e) => e.target === e.currentTarget && onClose?.()}>
      <div className={`modal ${props.wide ? 'wide' : ''} ${props.full ? 'full' : ''}`} role="dialog" aria-modal="true">
        <div className="modal-head">
          <h2>{props.title}</h2>
          {onClose && (
            <button className="icon-btn" onClick={onClose} aria-label="닫기">
              <X size={20} />
            </button>
          )}
        </div>
        <div className="modal-body">{props.children}</div>
        {props.footer && <div className="modal-foot">{props.footer}</div>}
      </div>
    </div>
  );
}

/** 목록에서 고르거나 직접 입력 (input + datalist) */
export function ComboInput(props: {
  id: string;
  label: string;
  value: string;
  options: string[];
  placeholder?: string;
  onChange: (v: string) => void;
  autoFocus?: boolean;
}) {
  return (
    <label className="field">
      <span>{props.label}</span>
      <input
        list={`${props.id}-list`}
        value={props.value}
        placeholder={props.placeholder}
        onChange={(e) => props.onChange(e.target.value)}
        autoFocus={props.autoFocus}
        autoComplete="off"
      />
      <datalist id={`${props.id}-list`}>
        {props.options.map((o) => (
          <option key={o} value={o} />
        ))}
      </datalist>
    </label>
  );
}
