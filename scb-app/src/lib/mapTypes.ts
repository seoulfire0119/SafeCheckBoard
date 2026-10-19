export interface MapType {
  label: string;
  short: string;
  icon: string;
  color: string;
  w: number;
  h: number;
}

// Flutter 버전 진압작전도의 팔레트를 그대로 옮기고, 화점·진입구·메모를 더했다
export const MAP_CATS: { label: string; types: string[] }[] = [
  { label: '현장 표시', types: ['fire', 'entry', 'danger', 'text'] },
  { label: '건물/시설', types: ['building', 'entrance', 'road', 'fireHydrant'] },
  { label: '소방진압', types: ['pumpTruck', 'tankTruck', 'foamTruck', 'aerialLadder', 'articulatedLadder', 'supportTender'] },
  { label: '구조·구급', types: ['rescueVehicle', 'rescueBus', 'ambulance', 'ambulanceNP'] },
  { label: '지휘·지원', types: ['commandCar', 'headquartersCar', 'recoveryVehicle'] },
  { label: '유관기관', types: ['police', 'cityHall', 'districtOffice', 'gasAgency', 'electricAgency', 'healthCenter'] },
];

export const MAP_TYPES: Record<string, MapType> = {
  fire: { label: '화점(추정)', short: '화점', icon: '🔥', color: '#d50000', w: 64, h: 64 },
  entry: { label: '진입구', short: '진입구', icon: '➡️', color: '#00897b', w: 70, h: 40 },
  danger: { label: '위험구역', short: '위험', icon: '⚠️', color: '#ff6f00', w: 70, h: 40 },
  text: { label: '메모', short: '메모', icon: '📝', color: '#37474f', w: 110, h: 34 },

  building: { label: '건물', short: '건물', icon: '🏢', color: '#546e7a', w: 260, h: 170 },
  entrance: { label: '출입구', short: '출입구', icon: '🚪', color: '#00695c', w: 70, h: 40 },
  road: { label: '도로', short: '도로', icon: '🛣️', color: '#455a64', w: 360, h: 50 },
  fireHydrant: { label: '소화전', short: '소화전', icon: '🧯', color: '#d32f2f', w: 64, h: 40 },

  pumpTruck: { label: '펌프차', short: '펌프', icon: '🚒', color: '#c62828', w: 80, h: 42 },
  tankTruck: { label: '탱크차', short: '탱크', icon: '💧', color: '#1565c0', w: 80, h: 42 },
  foamTruck: { label: '화학차', short: '화학', icon: '🧪', color: '#6a1b9a', w: 80, h: 42 },
  aerialLadder: { label: '고가차', short: '고가', icon: '🪜', color: '#e65100', w: 80, h: 42 },
  articulatedLadder: { label: '굴절차', short: '굴절', icon: '🏗️', color: '#b71c1c', w: 80, h: 42 },
  supportTender: { label: '조연차', short: '조연', icon: '🛠️', color: '#795548', w: 80, h: 42 },

  rescueVehicle: { label: '구조공작차', short: '구조', icon: '🧰', color: '#1b5e20', w: 80, h: 42 },
  rescueBus: { label: '구조버스', short: '구조버스', icon: '🚌', color: '#33691e', w: 80, h: 42 },
  ambulance: { label: '구급차', short: '구급', icon: '🚑', color: '#2e7d32', w: 80, h: 42 },
  ambulanceNP: { label: '구급차(음압)', short: '음압', icon: '🚑', color: '#00695c', w: 80, h: 42 },

  commandCar: { label: '지휘차', short: '지휘', icon: '🚩', color: '#1565c0', w: 80, h: 42 },
  headquartersCar: { label: '본부차', short: '본부', icon: '🏛️', color: '#0d47a1', w: 80, h: 42 },
  recoveryVehicle: { label: '회복차', short: '회복', icon: '🛏️', color: '#4e342e', w: 80, h: 42 },

  police: { label: '경찰', short: '경찰', icon: '👮', color: '#1a237e', w: 70, h: 40 },
  cityHall: { label: '시청', short: '시청', icon: '🏛️', color: '#37474f', w: 70, h: 40 },
  districtOffice: { label: '구청', short: '구청', icon: '🏢', color: '#455a64', w: 70, h: 40 },
  gasAgency: { label: '가스', short: '가스', icon: '🔥', color: '#e65100', w: 70, h: 40 },
  electricAgency: { label: '전기', short: '전기', icon: '⚡', color: '#f9a825', w: 70, h: 40 },
  healthCenter: { label: '보건소', short: '보건소', icon: '🏥', color: '#00838f', w: 70, h: 40 },

  team: { label: '진입대', short: '진입대', icon: '⛑️', color: '#e53935', w: 96, h: 48 },
};

export const MAP_COLORS = ['#c62828', '#e65100', '#f9a825', '#2e7d32', '#00695c', '#1565c0', '#4a148c', '#880e4f', '#4e342e', '#546e7a'];

/** 사진을 줄여서 Firestore 문서(1MB) 안에 들어가게 만든다 */
export async function compressImage(file: File, maxChars = 800_000): Promise<{ url: string; w: number; h: number }> {
  const src = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = () => rej(new Error('이미지를 읽을 수 없습니다'));
      i.src = src;
    });
    let maxSide = 1800;
    for (let attempt = 0; attempt < 8; attempt++) {
      const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
      const w = Math.round(img.naturalWidth * scale);
      const h = Math.round(img.naturalHeight * scale);
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      const g = c.getContext('2d')!;
      g.fillStyle = '#fff';
      g.fillRect(0, 0, w, h);
      g.drawImage(img, 0, 0, w, h);
      for (const q of [0.82, 0.7, 0.6]) {
        const url = c.toDataURL('image/jpeg', q);
        if (url.length <= maxChars) return { url, w, h };
      }
      maxSide = Math.round(maxSide * 0.8);
    }
    throw new Error('이미지가 너무 큽니다');
  } finally {
    URL.revokeObjectURL(src);
  }
}
