import { useState, useCallback, useEffect } from 'react'
import { STATUS, STATUS_ORDER } from '../utils/status'
import BuildingGrid from '../components/BuildingGrid'
import ActionPanel from '../components/ActionPanel'
import './Dashboard.css'

export default function Dashboard({ buildings, onAddBuilding, onRemoveBuilding, onBack }) {
  const [buildingStates, setBuildingStates] = useState(
    () => buildings.map(b => ({ units: [...b.units], hiddenFloors: new Set(), floorLabels: {} }))
  )
  const [personnelStats, setPersonnelStats] = useState(
    () => buildings.map(() => ({ selfEvac: 0, rescued: 0, notFound: 0 }))
  )
  const [activeBuildingIdx, setActiveBuildingIdx] = useState(null)
  const [selectedId, setSelectedId] = useState(null)
  const [selectedFloors, setSelectedFloors] = useState(new Set())
  const [panelOpen, setPanelOpen] = useState(false)
  const [pendingEmpty, setPendingEmpty] = useState(null) // { floor, unitIndex }
  const [log, setLog] = useState([])

  // 새 건물 추가 시 상태 동기화
  useEffect(() => {
    setBuildingStates(prev => {
      if (prev.length >= buildings.length) return prev
      return [...prev, { units: [...buildings[prev.length].units], hiddenFloors: new Set(), floorLabels: {} }]
    })
    setPersonnelStats(prev => {
      if (prev.length >= buildings.length) return prev
      return [...prev, { selfEvac: 0, rescued: 0, notFound: 0 }]
    })
  }, [buildings.length])

  const activeState = activeBuildingIdx !== null ? buildingStates[activeBuildingIdx] : null
  const selectedUnit = activeState?.units.find(u => u.id === selectedId) ?? null
  const selectedFloorUnits = selectedFloors.size > 0 && activeState
    ? activeState.units.filter(u => selectedFloors.has(u.floor))
    : null
  const activeBuildingName = activeBuildingIdx !== null ? buildings[activeBuildingIdx]?.name : null

  const closePanel = useCallback(() => {
    setPanelOpen(false)
    setSelectedId(null)
    setSelectedFloors(new Set())
    setActiveBuildingIdx(null)
    setPendingEmpty(null)
  }, [])

  const handleUnitTap = useCallback((buildingIdx, unit) => {
    setActiveBuildingIdx(buildingIdx)
    setSelectedId(unit.id)
    setSelectedFloors(new Set())
    setPanelOpen(true)
  }, [])

  const handleFloorTap = useCallback((buildingIdx, floor) => {
    const switching = activeBuildingIdx !== null && activeBuildingIdx !== buildingIdx
    setActiveBuildingIdx(buildingIdx)
    setSelectedId(null)
    setSelectedFloors(prev => {
      const base = switching ? new Set() : prev
      const next = new Set(base)
      if (next.has(floor)) next.delete(floor)
      else next.add(floor)
      return next
    })
    setPanelOpen(true)
  }, [activeBuildingIdx])

  const handleStatusChange = useCallback((newStatus) => {
    if (activeBuildingIdx === null) return

    // 빈 셀 활성화: 상태 선택 시 비로소 유닛 생성
    if (pendingEmpty) {
      const { floor, unitIndex } = pendingEmpty
      const newUnit = {
        id: `${floor}-${unitIndex}`,
        floor, unitIndex,
        number: floor * 100 + unitIndex,
        status: newStatus,
        memo: '', memoPinned: false,
      }
      setBuildingStates(prev => {
        const next = [...prev]
        const state = next[activeBuildingIdx]
        if (state.units.find(u => u.id === newUnit.id)) return prev
        next[activeBuildingIdx] = { ...state, units: [...state.units, newUnit] }
        return next
      })
      setLog(l => [{
        id: Date.now() + Math.random(),
        unitName: `[${buildings[activeBuildingIdx].name}] ${floor}층 ${newUnit.number}호`,
        from: 'empty', to: newStatus, time: new Date()
      }, ...l])
      setSelectedId(newUnit.id)
      setPendingEmpty(null)
      return
    }

    setBuildingStates(prev => {
      const next = [...prev]
      const state = next[activeBuildingIdx]
      next[activeBuildingIdx] = {
        ...state,
        units: state.units.map(u => {
          const inFloors = selectedFloors.size > 0 && selectedFloors.has(u.floor)
          const isSelected = u.id === selectedId
          if (!inFloors && !isSelected) return u
          if (u.status === newStatus) return u
          setLog(l => [{
            id: Date.now() + Math.random(),
            unitName: `[${buildings[activeBuildingIdx].name}] ${u.floor}층 ${u.number}호`,
            from: u.status, to: newStatus, time: new Date()
          }, ...l])
          return { ...u, status: newStatus }
        })
      }
      return next
    })
  }, [activeBuildingIdx, selectedId, selectedFloors, buildings, pendingEmpty])

  const handleMemoChange = useCallback((memo) => {
    if (!selectedId || activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      next[activeBuildingIdx] = {
        ...next[activeBuildingIdx],
        units: next[activeBuildingIdx].units.map(u =>
          u.id === selectedId ? { ...u, memo } : u
        )
      }
      return next
    })
  }, [selectedId, activeBuildingIdx])

  const handlePinToggle = useCallback(() => {
    if (!selectedId || activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      next[activeBuildingIdx] = {
        ...next[activeBuildingIdx],
        units: next[activeBuildingIdx].units.map(u =>
          u.id === selectedId ? { ...u, memoPinned: !u.memoPinned } : u
        )
      }
      return next
    })
  }, [selectedId, activeBuildingIdx])

  const handleHideFloors = useCallback(() => {
    if (activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      const newHidden = new Set(next[activeBuildingIdx].hiddenFloors)
      selectedFloors.forEach(f => newHidden.add(f))
      next[activeBuildingIdx] = { ...next[activeBuildingIdx], hiddenFloors: newHidden }
      return next
    })
    setSelectedFloors(new Set())
    setPanelOpen(false)
    setActiveBuildingIdx(null)
  }, [activeBuildingIdx, selectedFloors])

  const handleShowAllFloors = useCallback(() => {
    if (activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      next[activeBuildingIdx] = { ...next[activeBuildingIdx], hiddenFloors: new Set() }
      return next
    })
  }, [activeBuildingIdx])

  const handleRemoveBuilding = useCallback((idx) => {
    if (activeBuildingIdx === idx) {
      setSelectedId(null)
      setSelectedFloors(new Set())
      setActiveBuildingIdx(null)
      setPanelOpen(false)
    } else if (activeBuildingIdx !== null && activeBuildingIdx > idx) {
      setActiveBuildingIdx(prev => prev - 1)
    }
    setBuildingStates(prev => prev.filter((_, i) => i !== idx))
    setPersonnelStats(prev => prev.filter((_, i) => i !== idx))
    onRemoveBuilding(idx)
  }, [activeBuildingIdx, onRemoveBuilding])

  const handlePersonnelChange = useCallback((buildingIdx, field, value) => {
    const stored = value === '' ? '' : Math.max(0, parseInt(value) || 0)
    setPersonnelStats(prev => {
      const next = [...prev]
      next[buildingIdx] = { ...next[buildingIdx], [field]: stored }
      return next
    })
  }, [])

  const handleShowFloors = useCallback((buildingIdx, floors) => {
    setBuildingStates(prev => {
      const next = [...prev]
      const newHidden = new Set(next[buildingIdx].hiddenFloors)
      floors.forEach(f => newHidden.delete(f))
      next[buildingIdx] = { ...next[buildingIdx], hiddenFloors: newHidden }
      return next
    })
  }, [])

  const handleEmptyTap = useCallback((buildingIdx, floor, unitIndex) => {
    setActiveBuildingIdx(buildingIdx)
    setSelectedId(null)
    setSelectedFloors(new Set())
    setPendingEmpty({ floor, unitIndex })
    setPanelOpen(true)
  }, [])

  const handleVulnerableToggle = useCallback(() => {
    if (!selectedId || activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      next[activeBuildingIdx] = {
        ...next[activeBuildingIdx],
        units: next[activeBuildingIdx].units.map(u =>
          u.id === selectedId ? { ...u, vulnerable: !u.vulnerable } : u
        )
      }
      return next
    })
  }, [selectedId, activeBuildingIdx])

  const handleRemoveUnit = useCallback(() => {
    if (!selectedId || activeBuildingIdx === null) return
    setBuildingStates(prev => {
      const next = [...prev]
      next[activeBuildingIdx] = {
        ...next[activeBuildingIdx],
        units: next[activeBuildingIdx].units.filter(u => u.id !== selectedId)
      }
      return next
    })
    setSelectedId(null)
    setPanelOpen(false)
    setActiveBuildingIdx(null)
  }, [selectedId, activeBuildingIdx])

  const handleFloorLabelChange = useCallback((buildingIdx, floor, label) => {
    setBuildingStates(prev => {
      const next = [...prev]
      const fl = { ...next[buildingIdx].floorLabels }
      if (label === '') delete fl[floor]
      else fl[floor] = label
      next[buildingIdx] = { ...next[buildingIdx], floorLabels: fl }
      return next
    })
  }, [])

  const totalUnits = buildingStates.reduce((s, st) => s + st.units.length, 0)

  return (
    <div className="dash-root">
      <header className="dash-header">
        <button className="back-btn" onClick={onBack}>←</button>
        <h2 className="dash-title">SCB</h2>
        <span className="total-label">총 {totalUnits}실</span>
      </header>

      <div className="dash-body">
        <div className="buildings-area">
          {buildings.map((building, idx) => {
            const state = buildingStates[idx]
            if (!state) return null
            const isActive = activeBuildingIdx === idx
            const counts = STATUS_ORDER.reduce((acc, k) => {
              acc[k] = state.units.filter(u => u.status === k).length
              return acc
            }, {})

            const pstat = personnelStats[idx] ?? { selfEvac: 0, rescued: 0, notFound: 0 }

            return (
              <div key={idx} className={`building-col ${isActive ? 'building-col-active' : ''}`}>
                {/* 인명현황 전광판 */}
                <div className="personnel-board">
                  <div className="personnel-board-title">인명현황</div>
                  <div className="personnel-board-stats">
                    <div className="personnel-stat">
                      <span className="personnel-stat-label">자력대피</span>
                      <input
                        className="personnel-stat-input pstat-evac"
                        type="number" min="0"
                        value={pstat.selfEvac}
                        onChange={e => handlePersonnelChange(idx, 'selfEvac', e.target.value)}
                      />
                    </div>
                    <span className="personnel-stat-sep">/</span>
                    <div className="personnel-stat">
                      <span className="personnel-stat-label">구조완료</span>
                      <input
                        className="personnel-stat-input pstat-rescue"
                        type="number" min="0"
                        value={pstat.rescued}
                        onChange={e => handlePersonnelChange(idx, 'rescued', e.target.value)}
                      />
                    </div>
                    <span className="personnel-stat-sep">/</span>
                    <div className="personnel-stat">
                      <span className="personnel-stat-label">미발견</span>
                      <input
                        className="personnel-stat-input pstat-notfound"
                        type="number" min="0"
                        value={pstat.notFound}
                        onChange={e => handlePersonnelChange(idx, 'notFound', e.target.value)}
                      />
                    </div>
                  </div>
                </div>
                <div className="bcol-header">
                  <span className="bcol-name">{building.name}</span>
                  <div className="bcol-chips">
                    {STATUS_ORDER.map(k => counts[k] > 0 && (
                      <span key={k} className="bcol-chip" title={STATUS[k].label}
                        style={{ background: STATUS[k].color, color: STATUS[k].textColor }}>
                        {STATUS[k].icon}{counts[k]}
                      </span>
                    ))}
                  </div>
                  <button
                    className="bcol-remove-btn"
                    title={`${building.name} 삭제`}
                    onClick={() => handleRemoveBuilding(idx)}
                  >✕</button>
                </div>
                <div className="bcol-body">
                  <BuildingGrid
                    building={building}
                    units={state.units}
                    selectedId={isActive ? selectedId : null}
                    selectedFloors={isActive ? selectedFloors : new Set()}
                    hiddenFloors={state.hiddenFloors}
                    floorLabels={state.floorLabels}
                    onUnitTap={unit => handleUnitTap(idx, unit)}
                    onFloorTap={floor => handleFloorTap(idx, floor)}
                    onShowFloors={floors => handleShowFloors(idx, floors)}
                    onEmptyTap={(floor, unitIndex) => handleEmptyTap(idx, floor, unitIndex)}
                    onFloorLabelChange={(floor, label) => handleFloorLabelChange(idx, floor, label)}
                  />
                </div>
              </div>
            )
          })}

          {/* 건물 추가 슬롯 */}
          {buildings.length < 3 && (
            <div className="building-col-add" onClick={onAddBuilding}>
              <div className="add-building-plus">+</div>
              <div className="add-building-label">건물 추가하기</div>
            </div>
          )}
        </div>

        {panelOpen && <div className="panel-backdrop" onClick={closePanel} />}

        <div className={`panel-area ${panelOpen ? 'panel-open' : ''}`}>
          <div className="panel-drag-handle" onClick={closePanel} />
          <ActionPanel
            selectedUnit={selectedUnit}
            selectedFloors={selectedFloors}
            selectedFloorUnits={selectedFloorUnits}
            buildingName={activeBuildingName}
            hiddenFloorsCount={activeState?.hiddenFloors.size ?? 0}
            isPendingActivation={!!pendingEmpty}
            log={log}
            onStatusChange={handleStatusChange}
            onMemoChange={handleMemoChange}
            onPinToggle={handlePinToggle}
            onHideFloors={handleHideFloors}
            onShowAllFloors={handleShowAllFloors}
            onVulnerableToggle={handleVulnerableToggle}
            onRemoveUnit={handleRemoveUnit}
            onClose={closePanel}
          />
        </div>
      </div>
    </div>
  )
}
