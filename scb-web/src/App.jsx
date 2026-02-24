import { useState } from 'react'
import BuildingSetup from './pages/BuildingSetup'
import Dashboard from './pages/Dashboard'

function App() {
  const [buildings, setBuildings] = useState([])
  const [adding, setAdding] = useState(false)

  const handleStart = (building) => {
    setBuildings(prev => [...prev, building])
    setAdding(false)
  }

  if (buildings.length === 0 || adding) {
    return (
      <BuildingSetup
        onStart={handleStart}
        onCancel={buildings.length > 0 ? () => setAdding(false) : null}
      />
    )
  }

  return (
    <Dashboard
      buildings={buildings}
      onAddBuilding={() => setAdding(true)}
      onRemoveBuilding={idx => setBuildings(prev => prev.filter((_, i) => i !== idx))}
      onBack={() => setBuildings([])}
    />
  )
}

export default App
