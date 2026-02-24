export function generateFloors(start, end) {
  const floors = []
  for (let i = start; i <= end; i++) {
    if (i !== 0) floors.push(i)
  }
  return floors
}

// exceptions: { 21: 2, 1: 3, ... } (층 번호 → 세대 수)
export function createBuilding({ name, startFloor, endFloor, defaultUnits, exceptions = {}, pinanFloors = [] }) {
  const units = []
  const floors = generateFloors(startFloor, endFloor)
  let maxUnits = defaultUnits

  for (const floor of floors) {
    const count = exceptions[floor] !== undefined ? Number(exceptions[floor]) : defaultUnits
    if (count > maxUnits) maxUnits = count
    for (let i = 1; i <= count; i++) {
      units.push({
        id: `${floor}-${i}`,
        floor,
        unitIndex: i,
        number: floor * 100 + i, // 1층1호=101, 21층1호=2101
        status: 'unknown',
        memo: '',
        memoPinned: false,
        vulnerable: false,
      })
    }
  }

  return { name, startFloor, endFloor, defaultUnits, exceptions, units, maxUnits, pinanFloors }
}

export function getFloorsDesc(b) {
  return generateFloors(b.startFloor, b.endFloor).sort((a, z) => z - a)
}

export function getUnitsOnFloor(units, floor) {
  return units.filter(u => u.floor === floor).sort((a, b) => a.unitIndex - b.unitIndex)
}
