import { useState } from 'react'
import { createBuilding } from '../utils/building'
import './BuildingSetup.css'

const BUILDING_TYPES = [
  { key: 'apt',    label: '아파트',       icon: '🏢', startFloor: '1', endFloor: '21', defaultUnits: '4' },
  { key: 'house',  label: '단독주택',     icon: '🏠', startFloor: '1', endFloor: '3',  defaultUnits: '1' },
  { key: 'mixed',  label: '주상복합',     icon: '🏙', startFloor: '1', endFloor: '30', defaultUnits: '4' },
  { key: 'office', label: '업무복합시설', icon: '🏬', startFloor: '1', endFloor: '15', defaultUnits: '8' },
]

export default function BuildingSetup({ onStart, onCancel }) {
  const [buildingType, setBuildingType] = useState('apt')
  const [form, setForm] = useState({ name: '101동', startFloor: '1', endFloor: '21', defaultUnits: '4' })
  const [pinanFloors, setPinanFloors] = useState([])
  const [pinanInput, setPinanInput] = useState('')
  const [errors, setErrors] = useState({})

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  function selectType(t) {
    setBuildingType(t.key)
    setForm(f => ({
      ...f,
      startFloor: t.startFloor,
      endFloor: t.endFloor,
      defaultUnits: t.defaultUnits,
    }))
  }

  function addPinanFloor() {
    const f = parseInt(pinanInput)
    if (isNaN(f)) return
    if (!pinanFloors.includes(f)) setPinanFloors(prev => [...prev, f].sort((a, b) => a - b))
    setPinanInput('')
  }
  function removePinanFloor(f) {
    setPinanFloors(prev => prev.filter(x => x !== f))
  }

  function validate() {
    const e = {}
    if (!form.name.trim()) e.name = '필수 입력'
    ;['startFloor', 'endFloor', 'defaultUnits'].forEach(k => {
      if (!form[k].trim()) e[k] = '필수 입력'
      else if (isNaN(parseInt(form[k]))) e[k] = '정수 입력'
    })
    const sf = parseInt(form.startFloor), ef = parseInt(form.endFloor)
    if (!isNaN(sf) && !isNaN(ef) && sf > ef) e.endFloor = '끝 층은 시작 층 이상이어야 합니다'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  function submit(e) {
    e.preventDefault()
    if (!validate()) return
    onStart(createBuilding({
      name: form.name.trim(),
      startFloor: parseInt(form.startFloor),
      endFloor: parseInt(form.endFloor),
      defaultUnits: parseInt(form.defaultUnits),
      pinanFloors,
    }))
  }

  function floorLabel(f) {
    return f < 0 ? `B${Math.abs(f)}층` : `${f}층`
  }

  return (
    <div className="setup-bg">
      <div className="setup-card">
        {onCancel && (
          <button type="button" className="setup-cancel-btn" onClick={onCancel}>← 돌아가기</button>
        )}

        {/* 제목 + 건물 유형 드롭박스 */}
        <div className="setup-title-row">
          <h1 className="setup-title">🏢 건물 정보 입력</h1>
          <select
            className="type-select"
            value={buildingType}
            onChange={e => selectType(BUILDING_TYPES.find(t => t.key === e.target.value))}
          >
            {BUILDING_TYPES.map(t => (
              <option key={t.key} value={t.key}>{t.icon} {t.label}</option>
            ))}
          </select>
        </div>

        <form onSubmit={submit}>

          {/* 섹션 1: 기본 정보 */}
          <div className="setup-section">
            <div className="setup-section-header">
              <span className="setup-section-num">1</span>
              기본 정보
            </div>

            <div className="field">
              <label>동호수</label>
              <input
                value={form.name}
                onChange={e => set('name', e.target.value)}
                placeholder="예: 101동, A동"
              />
              {errors.name && <span className="err">{errors.name}</span>}
            </div>

            <div className="field-group">
              <div className="field-group-label">시작층 ~ 끝층</div>
              <div className="floor-range-row">
                <div className="field inline">
                  <input
                    value={form.startFloor}
                    onChange={e => set('startFloor', e.target.value)}
                    type="number"
                    placeholder="-2 또는 1"
                  />
                  {errors.startFloor && <span className="err">{errors.startFloor}</span>}
                </div>
                <span className="tilde">~</span>
                <div className="field inline">
                  <input
                    value={form.endFloor}
                    onChange={e => set('endFloor', e.target.value)}
                    type="number"
                    placeholder="21"
                  />
                  {errors.endFloor && <span className="err">{errors.endFloor}</span>}
                </div>
                <span className="floor-unit">층</span>
              </div>
            </div>

            <div className="field">
              <label>기본 세대수 <span className="label-hint">층당 기본 호실 수</span></label>
              <div className="inline-input-wrap">
                <input
                  value={form.defaultUnits}
                  onChange={e => set('defaultUnits', e.target.value)}
                  type="number" min="1"
                  placeholder="4"
                  className="input-narrow"
                />
                <span className="input-suffix">세대</span>
              </div>
              {errors.defaultUnits && <span className="err">{errors.defaultUnits}</span>}
            </div>
          </div>

          {/* 섹션 2: 피난층 추가 */}
          <div className="setup-section section-pinan">
            <div className="setup-section-header">
              <span className="setup-section-num num-pinan">2</span>
              피난층 추가
              <span className="section-header-hint">대피 집결 층 지정</span>
            </div>

            <div className="pinan-input-row">
              <input
                className="pinan-input"
                value={pinanInput}
                onChange={e => setPinanInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), addPinanFloor())}
                type="number"
                placeholder="층 번호 입력"
              />
              <button type="button" className="pinan-add-btn" onClick={addPinanFloor}>추가</button>
            </div>

            {pinanFloors.length > 0 ? (
              <div className="pinan-chips">
                {pinanFloors.map(f => (
                  <span key={f} className="pinan-chip">
                    🚨 {floorLabel(f)}
                    <button type="button" onClick={() => removePinanFloor(f)}>✕</button>
                  </span>
                ))}
              </div>
            ) : (
              <p className="empty-hint">지정된 피난층 없음</p>
            )}
          </div>

          <p className="hint">* 호실 번호: 층수 × 100 + 세대번호 &nbsp;(예: 1층 1호 → 101, 21층 2호 → 2102)</p>
          <button type="submit" className="submit-btn">대시보드 시작 →</button>
        </form>
      </div>
    </div>
  )
}
