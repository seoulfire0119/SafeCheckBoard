/** 국제 장애인 접근 표지(휠체어 탄 사람) 모양 — 피난약자 표시용 */
export function WheelchairIcon(props: { size?: number; className?: string; 'aria-label'?: string }) {
  const s = props.size ?? 24;
  return (
    <svg
      width={s}
      height={s}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.4}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={props.className}
      role="img"
      aria-label={props['aria-label']}
    >
      {/* 머리 */}
      <circle cx="10.5" cy="3.4" r="2.3" fill="currentColor" stroke="none" />
      {/* 몸통 → 엉덩이 → 무릎 → 발 */}
      <path d="M10.5 7.2v6.3h5.3l2.6 5.8h2.2" />
      {/* 팔 */}
      <path d="M10.5 10h4.3" />
      {/* 바퀴 (오른쪽 위가 열린 원) */}
      <path d="M7.2 10.4a6 6 0 1 0 7.9 8.1" />
    </svg>
  );
}
