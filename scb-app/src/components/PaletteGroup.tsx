import { useState, type ReactNode } from 'react';
import { ChevronDown, ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * 표시물 목록 서랍 — 접으면 옆으로 스윽 들어가고 손잡이(책갈피)만 남는다.
 * 손잡이를 누르면 다시 나온다. onMoved: 다 움직인 뒤 (지도 크기 다시 맞추기용)
 */
export function PaletteDrawer(props: { open: boolean; onToggle: () => void; onMoved?: () => void; children: ReactNode }) {
  return (
    <div
      className={`pal-drawer ${props.open ? 'open' : ''}`}
      onTransitionEnd={(e) => {
        if (e.target === e.currentTarget) props.onMoved?.();
      }}
    >
      <aside className="palette" aria-hidden={!props.open}>
        {props.children}
      </aside>
      <button type="button" className="pal-tab" onClick={props.onToggle} aria-expanded={props.open}>
        {props.open ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
        <span>{props.open ? '표시물 목록 접기' : '표시물 목록 보기'}</span>
      </button>
    </div>
  );
}

const KEY = 'scb.paletteClosed';

function loadClosed(): string[] {
  try {
    const v = JSON.parse(localStorage.getItem(KEY) ?? '[]');
    return Array.isArray(v) ? v : [];
  } catch {
    return [];
  }
}

/** 표시물 목록의 분류 하나 — 제목을 누르면 접고 편다 (기기에 기억) */
export function PaletteGroup({ title, children }: { title: string; children: ReactNode }) {
  const [open, setOpen] = useState(() => !loadClosed().includes(title));
  const toggle = () => {
    const next = !open;
    setOpen(next);
    try {
      const closed = loadClosed().filter((t) => t !== title);
      if (!next) closed.push(title);
      localStorage.setItem(KEY, JSON.stringify(closed));
    } catch {
      /* 저장이 안 되면 이번 접속에서만 기억 */
    }
  };
  return (
    <div className="pal-group">
      <button type="button" className="pal-head" onClick={toggle} aria-expanded={open}>
        {open ? <ChevronDown size={15} /> : <ChevronRight size={15} />}
        {title}
      </button>
      {open && children}
    </div>
  );
}
