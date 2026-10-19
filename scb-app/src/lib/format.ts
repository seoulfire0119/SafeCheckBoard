const p2 = (n: number) => String(n).padStart(2, '0');

export function hhmmss(ms: number) {
  const d = new Date(ms);
  return `${p2(d.getHours())}:${p2(d.getMinutes())}:${p2(d.getSeconds())}`;
}

export function hhmm(ms: number) {
  const d = new Date(ms);
  return `${p2(d.getHours())}:${p2(d.getMinutes())}`;
}

export function dateTime(ms: number) {
  const d = new Date(ms);
  return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())} ${hhmmss(ms)}`;
}

export function mmss(ms: number) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${p2(Math.floor(s / 60))}:${p2(s % 60)}`;
}

export function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

/** 성명 가리기: 홍길동(한국) → 홍●●(한국) */
export function maskName(s: string) {
  const name = s.trim();
  if (!name) return '';
  const i = name.indexOf('(');
  const base = i >= 0 ? name.slice(0, i) : name;
  const rest = i >= 0 ? name.slice(i) : '';
  const chars = Array.from(base);
  if (chars.length <= 1) return name;
  return chars[0] + '●'.repeat(chars.length - 1) + rest;
}

export function uid() {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}
