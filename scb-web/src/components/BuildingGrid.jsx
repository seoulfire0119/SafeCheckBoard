import { useState, useRef } from 'react'
import { getFloorsDesc, getUnitsOnFloor } from '../utils/building'
import { STATUS } from '../utils/status'
import './BuildingGrid.css'

function getFloorLabel(floor) {
  return floor < 0 ? `B${Math.abs(floor)}` : `${floor}F`
}

function buildSegments(floors, hiddenFloors) {
  const segments = []
  let i = 0
  while (i < floors.length) {
    if (hiddenFloors.has(floors[i])) {
      const group = []
      while (i < floors.length && hiddenFloors.has(floors[i])) {
        group.push(floors[i])
        i++
      }
      segments.push({ type: 'hidden', floors: group })
    } else {
      segments.push({ type: 'visible', floor: floors[i] })
      i++
    }
  }
  return segments
}

export default function BuildingGrid({
  building, units, selectedId, selectedFloors,
  hiddenFloors, floorLabels, onUnitTap, onFloorTap, onShowFloors,
  onEmptyTap, onFloorLabelChange
}) {
  const [editingFloor, setEditingFloor] = useState(null)
  const [editingValue, setEditingValue] = useState('')
  const inputRef = useRef(null)

  const floors = getFloorsDesc(building)
  const maxUnits = building.maxUnits
  const colHeaders = Array.from({ length: maxUnits }, (_, i) => i + 1)
  const segments = buildSegments(floors, hiddenFloors)

  function startEdit(floor) {
    setEditingFloor(floor)
    setEditingValue(floorLabels?.[floor] ?? getFloorLabel(floor))
    setTimeout(() => inputRef.current?.select(), 0)
  }

  function commitEdit(floor) {
    onFloorLabelChange?.(floor, editingValue.trim())
    setEditingFloor(null)
  }

  return (
    <div className="grid-wrap">
      {/* 헤더 행 */}
      <div className="grid-row">
        <div className="floor-label" />
        <div className="all-btn-placeholder" />
        {colHeaders.map(i => (
          <div key={i} className="unit-header">{i}호</div>
        ))}
      </div>
      <hr className="grid-divider" />

      {segments.map((seg, idx) => {
        if (seg.type === 'hidden') {
          const min = Math.min(...seg.floors)
          const max = Math.max(...seg.floors)
          const rangeLabel = seg.floors.length === 1
            ? getFloorLabel(min)
            : `${getFloorLabel(min)} ~ ${getFloorLabel(max)}`
          return (
            <div key={`h-${idx}`} className="hidden-seg-row" onClick={() => onShowFloors(seg.floors)}>
              <span className="hidden-seg-label">{rangeLabel}</span>
              <div className="hidden-seg-line" />
              <span className="hidden-seg-action">▼ {seg.floors.length}층 펼치기</span>
            </div>
          )
        }

        const floor = seg.floor
        const floorUnits = getUnitsOnFloor(units, floor)
        const unitMap = Object.fromEntries(floorUnits.map(u => [u.unitIndex, u]))
        const isFloorSel = selectedFloors.has(floor)
        const isPinan = building.pinanFloors?.includes(floor)
        const customLabel = floorLabels?.[floor]
        const displayLabel = customLabel ?? getFloorLabel(floor)
        const isEditing = editingFloor === floor

        return (
          <div key={floor} className="grid-row">
            {/* 층 라벨 - 클릭 시 편집 */}
            <div className={`floor-label ${isPinan ? 'floor-label-pinan' : ''}`}>
              {isEditing ? (
                <input
                  ref={inputRef}
                  className="floor-label-input"
                  value={editingValue}
                  onChange={e => setEditingValue(e.target.value)}
                  onBlur={() => commitEdit(floor)}
                  onKeyDown={e => {
                    if (e.key === 'Enter') { e.preventDefault(); commitEdit(floor) }
                    if (e.key === 'Escape') setEditingFloor(null)
                  }}
                />
              ) : (
                <span
                  className={`floor-label-text ${customLabel ? 'floor-label-custom' : ''}`}
                  title="클릭하여 층 이름 변경"
                  onClick={() => startEdit(floor)}
                >
                  {displayLabel}
                </span>
              )}
              {isPinan && !isEditing && <span className="pinan-badge">피난</span>}
            </div>

            <button
              className="all-btn"
              style={{ background: isFloorSel ? '#3f51b5' : '', color: isFloorSel ? '#fff' : '' }}
              onClick={() => onFloorTap(floor)}
            >
              ALL
            </button>

            {colHeaders.map(i => {
              const unit = unitMap[i]
              if (!unit) {
                return (
                  <div
                    key={i}
                    className="unit-cell empty-activatable"
                    title="클릭하여 호실 활성화"
                    onClick={() => onEmptyTap?.(floor, i)}
                  />
                )
              }
              const s = STATUS[unit.status]
              const sel = unit.id === selectedId
              const shadows = [
                sel ? '0 0 0 2.5px #000' : '',
                unit.vulnerable ? '0 0 0 4px #ffc107' : ''
              ].filter(Boolean).join(', ')
              return (
                <div
                  key={i}
                  className={`unit-cell ${sel ? 'selected' : ''}`}
                  style={{ background: s.color, color: s.textColor, boxShadow: shadows || undefined }}
                  onClick={() => onUnitTap(unit)}
                >
                  <span className="unit-num">{unit.number}호</span>
                  {unit.memo && (
                    <span className={`memo-dot ${unit.memoPinned ? 'memo-dot-pinned' : ''}`} />
                  )}
                </div>
              )
            })}
          </div>
        )
      })}
    </div>
  )
}
