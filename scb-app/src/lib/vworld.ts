// 브이월드(국토교통부 공간정보 오픈플랫폼)
//  - 지도 그림: WMTS 타일 (Base 일반 / Satellite 위성 / Hybrid 위성 위 도로·지명)
//  - 주소↔좌표: 지오코더 API, 장소 이름 찾기: 검색 API
//  지오코더·검색은 브라우저 직접 호출(CORS)을 막아 두어서 JSONP(script 태그)로 부른다.

export const VWORLD_KEY = import.meta.env.VITE_VWORLD_KEY as string;

export type BaseLayer = 'Satellite' | 'Base';

export const tileUrl = (layer: 'Base' | 'Satellite' | 'Hybrid') =>
  `https://api.vworld.kr/req/wmts/1.0.0/${VWORLD_KEY}/${layer}/{z}/{y}/{x}.${layer === 'Satellite' ? 'jpeg' : 'png'}`;

export const VWORLD_ATTR = '© <a href="https://www.vworld.kr" target="_blank" rel="noopener">VWorld</a>';

let seq = 0;
function jsonp<T>(url: string, timeoutMs = 8000): Promise<T> {
  return new Promise((resolve, reject) => {
    const cb = `__vw${Date.now()}${seq++}`;
    const s = document.createElement('script');
    const w = window as unknown as Record<string, unknown>;
    const done = () => {
      delete w[cb];
      s.remove();
      clearTimeout(t);
    };
    const t = setTimeout(() => {
      done();
      reject(new Error('브이월드 응답 없음'));
    }, timeoutMs);
    w[cb] = (data: T) => {
      done();
      resolve(data);
    };
    s.onerror = () => {
      done();
      reject(new Error('브이월드 연결 실패'));
    };
    s.src = `${url}&key=${VWORLD_KEY}&callback=${cb}`;
    document.head.appendChild(s);
  });
}

export interface Place {
  title: string;
  address: string;
  lat: number;
  lng: number;
}

interface VwResp {
  response: {
    status: string;
    result?: unknown;
    error?: { text?: string };
  };
}

/** 주소 → 좌표 (도로명 먼저, 안 되면 지번) */
export async function geocode(address: string): Promise<Place | null> {
  for (const type of ['road', 'parcel']) {
    const r = await jsonp<VwResp>(
      `https://api.vworld.kr/req/address?service=address&request=getcoord&version=2.0&crs=epsg:4326&refine=true&simple=false&format=json&type=${type}&address=${encodeURIComponent(address)}`,
    );
    if (r.response.status === 'OK') {
      const res = r.response.result as { point: { x: string; y: string } };
      const refined = (r.response as unknown as { refined?: { text?: string } }).refined?.text ?? address;
      return { title: refined, address: refined, lat: Number(res.point.y), lng: Number(res.point.x) };
    }
  }
  return null;
}

/** 좌표 → 주소 */
export async function reverseGeocode(lat: number, lng: number): Promise<string | null> {
  const r = await jsonp<VwResp>(
    `https://api.vworld.kr/req/address?service=address&request=getAddress&version=2.0&crs=epsg:4326&type=both&format=json&point=${lng},${lat}`,
  );
  if (r.response.status !== 'OK') return null;
  const list = r.response.result as { type: string; text: string }[];
  return (list.find((x) => x.type === 'road') ?? list[0])?.text ?? null;
}

/** 장소 이름·주소로 찾기 (예: ○○아파트, 마포구청) */
export async function searchPlace(query: string): Promise<Place[]> {
  const base = `https://api.vworld.kr/req/search?service=search&request=search&version=2.0&crs=EPSG:4326&size=8&page=1&format=json&errorformat=json&query=${encodeURIComponent(query)}`;
  const out: Place[] = [];
  const place = await jsonp<VwResp>(`${base}&type=place`).catch(() => null);
  const items = (place?.response.status === 'OK' ? (place.response.result as { items: unknown[] }).items : []) as {
    title: string;
    address: { road?: string; parcel?: string };
    point: { x: string; y: string };
  }[];
  const seen = new Set<string>();
  for (const it of items) {
    const address = it.address.road || it.address.parcel || '';
    const k = `${it.title}|${address}`;
    if (seen.has(k)) continue; // 같은 이름·주소가 분류만 달리 여러 번 나오는 것 합치기
    seen.add(k);
    out.push({ title: it.title, address, lat: Number(it.point.y), lng: Number(it.point.x) });
  }
  if (out.length === 0) {
    const g = await geocode(query).catch(() => null);
    if (g) out.push(g);
  }
  return out;
}

/** 위도·경도에서 북쪽 dy 미터, 동쪽 dx 미터 떨어진 점 */
export function offsetMeters(lat: number, lng: number, dx: number, dy: number) {
  const dLat = dy / 111320;
  const dLng = dx / (111320 * Math.cos((lat * Math.PI) / 180));
  return { lat: lat + dLat, lng: lng + dLng };
}
