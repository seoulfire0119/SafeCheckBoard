import { escapeHtml } from './format';

/** 엑셀에서 한글이 깨지지 않도록 BOM 을 붙인 CSV 를 내려받는다 */
export function downloadCsv(filename: string, header: string[], rows: (string | number)[][]) {
  const cell = (v: string | number) => {
    const raw = String(v ?? '');
    const s = typeof v === 'string' && /^[\s]*[=+@-]/.test(raw) ? `'${raw}` : raw;
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const text = [header, ...rows].map((r) => r.map(cell).join(',')).join('\r\n');
  const blob = new Blob(['﻿' + text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

/** 새 창에 표 형태 문서를 열고 인쇄 대화상자를 띄운다 */
export function printHtml(title: string, bodyHtml: string) {
  const html = `<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<style>
*{-webkit-print-color-adjust:exact;print-color-adjust:exact;box-sizing:border-box}
body{font-family:"Pretendard","Noto Sans KR","Malgun Gothic",sans-serif;margin:24px;color:#111;font-size:12px}
h1{font-size:18px;margin:0 0 4px}h2{font-size:14px;margin:18px 0 6px;border-left:4px solid #bf360c;padding-left:8px}
.meta{color:#555;margin-bottom:12px}
table{border-collapse:collapse;width:100%;margin-bottom:8px}
th,td{border:1px solid #999;padding:4px 6px;text-align:left;vertical-align:top}
th{background:#f3f3f3;white-space:nowrap}
pre{white-space:pre-wrap;font-family:inherit;margin:0}
@media print{body{margin:1cm}}
</style></head><body>${bodyHtml}<script>window.onload=function(){window.print()}</script></body></html>`;
  const w = window.open('', '_blank');
  if (!w) {
    alert('팝업이 차단되어 인쇄 창을 열 수 없습니다. 브라우저에서 팝업을 허용해 주세요.');
    return;
  }
  w.document.open();
  w.document.write(html);
  w.document.close();
}

export function table(header: string[], rows: (string | number)[][]) {
  const th = header.map((h) => `<th>${escapeHtml(h)}</th>`).join('');
  const tr = rows
    .map((r) => `<tr>${r.map((c) => `<td>${escapeHtml(String(c ?? '')).replace(/\n/g, '<br>')}</td>`).join('')}</tr>`)
    .join('');
  return `<table><thead><tr>${th}</tr></thead><tbody>${tr}</tbody></table>`;
}

export async function copyText(text: string) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand('copy');
    ta.remove();
    return ok;
  }
}
