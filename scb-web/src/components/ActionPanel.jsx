import { STATUS, STATUS_ORDER } from '../utils/status'
import ActivityLog from './ActivityLog'
import './ActionPanel.css'

export default function ActionPanel({
  selectedUnit, selectedFloors, selectedFloorUnits,
  buildingName, hiddenFloorsCount, isPendingActivation, log,
  onStatusChange, onMemoChange, onPinToggle, onHideFloors, onShowAllFloors,
  onVulnerableToggle, onRemoveUnit, onClose
}) {
  const hasSelection = selectedUnit || (selectedFloorUnits && selectedFloorUnits.length > 0) || isPendingActivation
  const hasFloorSelection = selectedFloors && selectedFloors.size > 0

  let title = '호실을 선택하세요'
  let subtitle = '그리드에서 호실을 탭하세요'
  let headerBg = 'transparent'

  if (isPendingActivation) {
    title = '호실 활성화'
    subtitle = '아래에서 상태를 선택하면 호실이 생성됩니다'
    headerBg = '#f5f5f5'
  } else if (hasFloorSelection) {
    const sorted = [...selectedFloors].sort((a, b) => a - b)
    title = selectedFloors.size === 1
      ? `${sorted[0]}층 전체`
      : `${selectedFloors.size}개 층 선택`
    subtitle = (buildingName ? `${buildingName} · ` : '') +
      (selectedFloors.size === 1
        ? `${selectedFloorUnits?.length ?? 0}개 호실`
        : `${sorted.map(f => `${f}층`).join(', ')} · ${selectedFloorUnits?.length ?? 0}개 호실`)
  } else if (selectedUnit) {
    title = `${selectedUnit.floor}층 ${selectedUnit.number}호`
    subtitle = (buildingName ? `${buildingName} · ` : '') + `상태: ${STATUS[selectedUnit.status].label}`
    headerBg = STATUS[selectedUnit.status].color + '26'
  }

  return (
    <div className="panel">
      {/* 선택 헤더 */}
      <div className="panel-header" style={{ background: headerBg }}>
        <div className="panel-header-text">
          <div className="panel-title">{title}</div>
          <div className="panel-subtitle">{subtitle}</div>
        </div>
        {onClose && (
          <button className="panel-close-btn" onClick={onClose} aria-label="닫기">✕ 닫기</button>
        )}
      </div>
      <hr className="panel-divider" />

      {/* 상태 버튼 + 노약자 */}
      <div className="status-btns">
        {STATUS_ORDER.map(k => {
          const s = STATUS[k]
          const isActive = selectedUnit?.status === k
          return (
            <button key={k} className={`status-btn ${isActive ? 'active' : ''}`}
              style={{ background: s.color, color: s.textColor, opacity: hasSelection ? 1 : 0.4 }}
              disabled={!hasSelection}
              onClick={() => onStatusChange(k)}>
              <span className="status-icon">{s.icon}</span>
              <span className="status-label">{s.label}</span>
            </button>
          )
        })}
        {/* 노약자 — 상태 버튼과 동일한 위치 */}
        <button
          className={`status-btn ${selectedUnit?.vulnerable ? 'active' : ''}`}
          style={{
            background: '#ffc107',
            color: '#5f3d00',
            opacity: selectedUnit ? 1 : 0.4,
          }}
          disabled={!selectedUnit}
          onClick={onVulnerableToggle}
        >
          <span className="status-label">노약자</span>
        </button>
      </div>

      {/* 공백으로 만들기 */}
      {selectedUnit && !hasFloorSelection && (
        <>
          <hr className="panel-divider" />
          <div className="floor-action-row">
            <button className="floor-action-btn unit-remove-btn" onClick={onRemoveUnit}>
              ☐ 공백으로 만들기
            </button>
          </div>
        </>
      )}

      {/* 층 숨기기 액션 */}
      {(hasFloorSelection || hiddenFloorsCount > 0) && (
        <>
          <hr className="panel-divider" />
          <div className="floor-action-row">
            {hasFloorSelection && (
              <button className="floor-action-btn floor-hide-action" onClick={onHideFloors}>
                선택 층 숨기기
              </button>
            )}
            {hiddenFloorsCount > 0 && (
              <button className="floor-action-btn floor-show-action" onClick={onShowAllFloors}>
                숨긴 층 표시 ({hiddenFloorsCount})
              </button>
            )}
          </div>
        </>
      )}

      <hr className="panel-divider" />

      {/* 메모 */}
      {selectedUnit && (
        <>
          <div className="memo-section">
            <div className="memo-header">
              <span>📝 메모</span>
              <button className="pin-btn" onClick={onPinToggle} title="메모 고정">
                {selectedUnit.memoPinned ? '📌' : '📍'}
              </button>
            </div>
            <textarea
              key={selectedUnit.id}
              className="memo-input"
              defaultValue={selectedUnit.memo}
              placeholder="메모를 입력하세요..."
              rows={3}
              onChange={e => onMemoChange(e.target.value)}
            />
          </div>
          <hr className="panel-divider" />
        </>
      )}

      {/* 활동 로그 */}
      <div className="log-header">
        <span>🕐 활동 로그</span>
        <span className="log-count">{log.length}건</span>
      </div>
      <div className="log-area">
        <ActivityLog entries={log} />
      </div>
    </div>
  )
}
