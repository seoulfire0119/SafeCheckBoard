import { STATUS } from '../utils/status'
import './ActivityLog.css'

function fmt(d) {
  return d.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

export default function ActivityLog({ entries }) {
  if (entries.length === 0) {
    return <div className="log-empty">변경 기록이 없습니다</div>
  }
  return (
    <div className="log-list">
      {entries.map(e => (
        <div key={e.id} className="log-item">
          <div className="log-time">{fmt(e.time)}</div>
          <div className="log-content">
            <span className="log-unit">{e.unitName}</span>
            <span className="log-arrow">
              <span className="log-badge" style={{ background: STATUS[e.from].color, color: STATUS[e.from].textColor }}>
                {STATUS[e.from].label}
              </span>
              {' → '}
              <span className="log-badge" style={{ background: STATUS[e.to].color, color: STATUS[e.to].textColor }}>
                {STATUS[e.to].label}
              </span>
            </span>
          </div>
        </div>
      ))}
    </div>
  )
}
