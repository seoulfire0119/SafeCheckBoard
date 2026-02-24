export const STATUS = {
  unknown:          { key: 'unknown',          label: '미확인',       color: '#9e9e9e', textColor: '#000000de', icon: '?' },
  empty:            { key: 'empty',            label: '부재',         color: '#64b5f6', textColor: '#000000de', icon: '—' },
  confirmed:        { key: 'confirmed',        label: '확인 완료',    color: '#66bb6a', textColor: '#ffffff',   icon: '✓' },
  danger:           { key: 'danger',           label: '발화층',       color: '#ef5350', textColor: '#ffffff',   icon: '🔥' },
  fire_spread:      { key: 'fire_spread',      label: '화재확산',     color: '#ff7043', textColor: '#ffffff',   icon: '🌫' },
  resource_wait:    { key: 'resource_wait',    label: '자원대기소',   color: '#ffa726', textColor: '#000000de', icon: '⛺' },
  forward_cmd:      { key: 'forward_cmd',      label: '전진지휘소',   color: '#5c6bc0', textColor: '#ffffff',   icon: '📍' },
  resource_forward: { key: 'resource_forward', label: '자원+전진지휘', color: '#7c3aed', textColor: '#ffffff',   icon: '⛺📍' },
}

export const STATUS_ORDER = ['unknown', 'empty', 'confirmed', 'danger', 'fire_spread', 'resource_wait', 'forward_cmd', 'resource_forward']
