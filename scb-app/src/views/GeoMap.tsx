import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Building2, Crosshair, Flame, HardHat, Hand, Layers, Lock, LockOpen, Printer, Route, Search, Trash2, Waves, X } from 'lucide-react';
import type { GeoItem, GeoLine, GeoState, MapDoc, SessionData } from '../types';
import { useNow, useSession } from '../session-context';
import { saveField, saveMap } from '../lib/session';
import { MAP_CATS, MAP_TYPES } from '../lib/mapTypes';
import { floorKey, floorLabel, floorsDescending, STATUS, unitLabel } from '../lib/building';
import { teamElapsed, teamLevel, teamMain, teamPlace, teamSub, teamTitle } from '../lib/teams';
import { mmss, uid } from '../lib/format';
import { geocode, offsetMeters, reverseGeocode, searchPlace, tileUrl, VWORLD_ATTR, type Place } from '../lib/vworld';
import { Inspector, MapTypeIcon } from './MapView';

const SEOUL = { lat: 37.5665, lng: 126.978 };

type Mode = { kind: 'select' } | { kind: 'place'; type: string; teamId?: string } | { kind: 'draw'; line: GeoLine['kind'] };

const emptyGeo = (lat: number, lng: number): GeoState => ({
  lat,
  lng,
  zoom: 18,
  layer: 'Satellite',
  locked: false,
  address: '',
  items: [],
  lines: [],
});

/**
 * 진압작전도 — 브이월드 지도 위에 소방차·용수·진입대를 놓는다.
 * 위치는 위도·경도로 저장되어 모든 기기에서 같은 자리에 보인다.
 */
export function GeoMap({ map, modeSwitch }: { map: MapDoc; modeSwitch: ReactNode }) {
  const { code, data, log, toast } = useSession();
  const now = useNow();
  const geo = map.geo;
  const elRef = useRef<HTMLDivElement>(null);
  const lmap = useRef<L.Map | null>(null);
  const layers = useRef<{ sat: L.TileLayer; hyb: L.TileLayer; base: L.TileLayer } | null>(null);
  const markerLayer = useRef<L.LayerGroup | null>(null);
  const lineLayer = useRef<L.LayerGroup | null>(null);
  const meMarker = useRef<L.CircleMarker | null>(null);
  const markers = useRef(new Map<string, L.Marker>());
  const dragging = useRef<string | null>(null); // 지금 끌고 있는 표시물 id
  const pending = useRef(new Map<string, { lat: number; lng: number; until: number }>());
  const iconHtml = useRef(new Map<string, string>());
  const [mode, setMode] = useState<Mode>({ kind: 'select' });
  const modeRef = useRef(mode);
  modeRef.current = mode;
  const [selId, setSelId] = useState<string | null>(null);
  const [palette, setPalette] = useState(() => window.innerWidth > 900);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Place[] | null>(null);
  const [locating, setLocating] = useState(false);
  const latestItems = useRef<GeoItem[] | null>(null);
  latestItems.current = geo?.items ?? null;
  const latestLines = useRef<GeoLine[]>([]);
  latestLines.current = geo?.lines ?? [];
  const lockedRef = useRef(false);
  lockedRef.current = geo?.locked ?? false;

  const persist = useCallback(
    (patch: Partial<GeoState>) => saveMap(code, { geo: patch as GeoState }).catch((e: Error) => toast(`작전도 저장 실패: ${e.message}`, 'error')),
    [code, toast],
  );

  // ── 처음 위치: 저장된 위치 → 내 GPS → 재난발생현황 장소 → 서울시청 ──
  useEffect(() => {
    if (geo) return;
    let cancelled = false;
    const start = async () => {
      const gps = await getGps().catch(() => null);
      if (cancelled) return;
      if (gps) return persist(emptyGeo(gps.lat, gps.lng));
      const loc = data.incident.location?.trim();
      const g = loc ? await geocode(loc).catch(() => null) : null;
      if (cancelled) return;
      persist(g ? { ...emptyGeo(g.lat, g.lng), address: g.address } : emptyGeo(SEOUL.lat, SEOUL.lng));
    };
    start();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [!!geo]);

  // ── 지도 만들기 (한 번) ──
  useEffect(() => {
    if (!elRef.current || lmap.current || !geo) return;
    const m = L.map(elRef.current, { zoomControl: false, maxZoom: 20, minZoom: 7, attributionControl: true }).setView([geo.lat, geo.lng], geo.zoom);
    L.control.zoom({ position: 'bottomright', zoomInTitle: '확대', zoomOutTitle: '축소' }).addTo(m);
    L.control.scale({ position: 'bottomleft', imperial: false }).addTo(m);
    const opt = { maxZoom: 20, maxNativeZoom: 19, attribution: VWORLD_ATTR };
    layers.current = {
      sat: L.tileLayer(tileUrl('Satellite'), opt),
      hyb: L.tileLayer(tileUrl('Hybrid'), opt),
      base: L.tileLayer(tileUrl('Base'), opt),
    };
    lineLayer.current = L.layerGroup().addTo(m);
    markerLayer.current = L.layerGroup().addTo(m);
    lmap.current = m;
    // 축소하면 표시물도 같이 작아지게 (18단계 확대가 원래 크기)
    const applyScale = () => {
      const z = m.getZoom();
      const k = Math.max(0.3, Math.min(1.4, Math.pow(2, z - 18)));
      const el = m.getContainer();
      el.style.setProperty('--mk-scale', String(k));
      el.classList.toggle('mk-small', k < 0.6);
    };
    applyScale();
    m.on('zoom zoomend', applyScale);
    return () => {
      m.remove();
      lmap.current = null;
      markers.current.clear();
      iconHtml.current.clear();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [!!geo]);

  // ── 배경 종류 (위성 / 일반) ──
  useEffect(() => {
    const m = lmap.current;
    const ly = layers.current;
    if (!m || !ly || !geo) return;
    for (const l of [ly.sat, ly.hyb, ly.base]) l.remove();
    if (geo.layer === 'Base') ly.base.addTo(m);
    else {
      ly.sat.addTo(m);
      ly.hyb.addTo(m);
    }
  }, [geo?.layer, geo]);

  // ── 고정: 모든 기기가 같은 위치·확대로 멈춘다 ──
  useEffect(() => {
    const m = lmap.current;
    if (!m || !geo) return;
    const handlers = [m.dragging, m.touchZoom, m.doubleClickZoom, m.scrollWheelZoom, m.boxZoom, m.keyboard];
    if (geo.locked) {
      m.setView([geo.lat, geo.lng], geo.zoom, { animate: false });
      handlers.forEach((h) => h.disable());
      m.getContainer().classList.add('locked');
    } else {
      handlers.forEach((h) => h.enable());
      m.getContainer().classList.remove('locked');
    }
  }, [geo?.locked, geo?.lat, geo?.lng, geo?.zoom, geo]);

  // ── 지도 누르기: 표시물 놓기 / 선택 해제 ──
  useEffect(() => {
    const m = lmap.current;
    if (!m) return;
    const onClick = (e: L.LeafletMouseEvent) => {
      const md = modeRef.current;
      if (md.kind !== 'place') return setSelId(null);
      const boardName = md.teamId?.startsWith('b:') ? md.teamId.slice(2) : null;
      const team = md.teamId && !boardName ? data.teams.find((t) => t.id === md.teamId) : undefined;
      const it: GeoItem = {
        id: uid(),
        type: md.type,
        lat: e.latlng.lat,
        lng: e.latlng.lng,
        ...(boardName ? { label: boardName } : {}),
        ...(team ? { teamId: team.id, color: team.color } : {}),
        ...(md.type === 'text' ? { label: '메모' } : {}),
      };
      persist({ items: [...(latestItems.current ?? []), it] });
      setSelId(it.id);
      setMode({ kind: 'select' });
      log('작전도', `${team ? teamTitle(team) : boardName ? `${boardName} 현황표` : MAP_TYPES[md.type]?.label} 배치`);
    };
    m.on('click', onClick);
    return () => {
      m.off('click', onClick);
    };
  }, [data.teams, persist, log]);

  // ── 선 그리기 (진입경로·수관) ──
  useEffect(() => {
    const m = lmap.current;
    if (!m || mode.kind !== 'draw') return;
    const el = m.getContainer();
    m.dragging.disable();
    let pts: L.LatLng[] = [];
    let last: L.Point | null = null;
    let preview: L.Polyline | null = null;
    const style = lineStyle(mode.line);
    const down = (e: PointerEvent) => {
      if ((e.target as Element).closest('.leaflet-control')) return;
      el.setPointerCapture(e.pointerId);
      const ll = m.mouseEventToLatLng(e as unknown as MouseEvent);
      pts = [ll];
      last = m.latLngToContainerPoint(ll);
      preview = L.polyline(pts, style).addTo(m);
    };
    const move = (e: PointerEvent) => {
      if (!preview || !last) return;
      const ll = m.mouseEventToLatLng(e as unknown as MouseEvent);
      const p = m.latLngToContainerPoint(ll);
      if (p.distanceTo(last) < 10) return;
      last = p;
      pts.push(ll);
      preview.setLatLngs(pts);
    };
    const up = () => {
      if (!preview) return;
      preview.remove();
      preview = null;
      if (pts.length >= 2) {
        const line: GeoLine = { id: uid(), kind: mode.line, pts: pts.flatMap((p) => [p.lat, p.lng]), color: style.color! };
        persist({ lines: [...latestLines.current, line] });
        log('작전도', `${mode.line === 'hose' ? '수관' : '진입경로'} 그리기`);
      }
      pts = [];
    };
    el.addEventListener('pointerdown', down);
    el.addEventListener('pointermove', move);
    el.addEventListener('pointerup', up);
    el.addEventListener('pointercancel', up);
    return () => {
      el.removeEventListener('pointerdown', down);
      el.removeEventListener('pointermove', move);
      el.removeEventListener('pointerup', up);
      el.removeEventListener('pointercancel', up);
      if (!lockedRef.current) m.dragging.enable();
      preview?.remove();
    };
  }, [mode, persist, log]);

  // ── 표시물 그리기 (데이터가 바뀔 때마다 맞춘다) ──
  // 끄는 도중에 모양을 새로 그리면 손가락에서 놓쳐 버리므로:
  //  · 끌고 있는 표시물은 건드리지 않는다
  //  · 모양(html)이 실제로 바뀐 것만 다시 그린다
  //  · 놓은 직후 서버 저장이 돌아오기 전까지는 놓은 자리를 유지한다
  useEffect(() => {
    const ml = markerLayer.current;
    if (!ml || !geo) return;
    const seen = new Set<string>();
    for (const it of geo.items) {
      if (it.type === 'team') {
        const t = data.teams.find((x) => x.id === it.teamId);
        if (!t || t.status === 'waiting') continue; // 철수·삭제된 대는 숨김
      }
      seen.add(it.id);
      const icon = makeIcon(it, data, now, selId === it.id);
      const html = String(icon.options.html);
      let mk = markers.current.get(it.id);
      if (!mk) {
        mk = L.marker([it.lat, it.lng], { icon, draggable: true, autoPan: true, keyboard: false, riseOnHover: true });
        const self = mk;
        mk.on('click', (e) => {
          L.DomEvent.stopPropagation(e);
          if (modeRef.current.kind === 'select') setSelId(it.id);
        });
        mk.on('dragstart', () => {
          dragging.current = it.id;
        });
        mk.on('dragend', () => {
          dragging.current = null;
          const p = self.getLatLng();
          pending.current.set(it.id, { lat: p.lat, lng: p.lng, until: Date.now() + 5000 });
          const items = (latestItems.current ?? []).map((x) => (x.id === it.id ? { ...x, lat: p.lat, lng: p.lng } : x));
          persist({ items });
          setSelId(it.id);
        });
        mk.addTo(ml);
        markers.current.set(it.id, mk);
        iconHtml.current.set(it.id, html);
      } else if (dragging.current !== it.id) {
        const pd = pending.current.get(it.id);
        const arrived = pd && Math.abs(pd.lat - it.lat) < 1e-9 && Math.abs(pd.lng - it.lng) < 1e-9;
        if (pd && !arrived && Date.now() < pd.until) {
          // 서버에 저장 중 — 놓은 자리 유지
        } else {
          pending.current.delete(it.id);
          const cur = mk.getLatLng();
          if (cur.lat !== it.lat || cur.lng !== it.lng) mk.setLatLng([it.lat, it.lng]);
        }
        if (iconHtml.current.get(it.id) !== html) {
          mk.setIcon(icon);
          iconHtml.current.set(it.id, html);
        }
      }
      mk.setZIndexOffset(it.type === 'team' ? 900 : it.type === 'fire' ? 800 : it.type === 'building' ? -500 : 0);
    }
    for (const [id, mk] of markers.current) {
      if (!seen.has(id) && dragging.current !== id) {
        mk.remove();
        markers.current.delete(id);
        iconHtml.current.delete(id);
      }
    }
  }, [geo, data, now, selId, persist]);

  // ── 현황판 → 지도: 고정된 뒤부터 화점·진입대·건물 현황표가 저절로 나타나고 사라진다 ──
  useEffect(() => {
    if (!geo?.locked) return;
    const r = syncWithBoard(geo.items, data, geo.lat, geo.lng);
    if (r) persist({ items: r.items });
  }, [geo, data, persist]);

  // ── 선 ──
  useEffect(() => {
    const ll = lineLayer.current;
    const m = lmap.current;
    if (!ll || !m || !geo) return;
    ll.clearLayers();
    for (const l of geo.lines) {
      const latlngs: L.LatLngTuple[] = [];
      for (let i = 0; i + 1 < l.pts.length; i += 2) latlngs.push([l.pts[i], l.pts[i + 1]]);
      const style = lineStyle(l.kind);
      const pl = L.polyline(latlngs, { ...style, color: l.color, weight: selId === l.id ? 9 : style.weight, opacity: selId === l.id ? 0.6 : 0.95 });
      pl.on('click', (e) => {
        L.DomEvent.stopPropagation(e);
        setSelId(l.id);
      });
      pl.addTo(ll);
      if (l.kind === 'route' && latlngs.length >= 2) {
        const a = m.latLngToContainerPoint(latlngs[latlngs.length - 2]);
        const b = m.latLngToContainerPoint(latlngs[latlngs.length - 1]);
        const deg = (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI;
        L.marker(latlngs[latlngs.length - 1], {
          icon: L.divIcon({ className: 'geo-arrow', html: `<div style="transform:rotate(${deg}deg);border-left-color:${l.color}"></div>`, iconSize: [22, 22], iconAnchor: [11, 11] }),
          interactive: false,
        }).addTo(ll);
      }
    }
  }, [geo, selId]);

  if (!geo)
    return (
      <div className="map-view">
        <div className="map-toolbar">{modeSwitch}</div>
        <div className="center-msg">
          <Crosshair size={28} />
          <p>현재 위치를 찾는 중… (위치 권한을 허용해 주세요)</p>
        </div>
      </div>
    );

  const sel = geo.items.find((x) => x.id === selId) ?? null;
  const selLine = geo.lines.find((x) => x.id === selId) ?? null;

  const goTo = (lat: number, lng: number, zoom = 18) => {
    lmap.current?.setView([lat, lng], zoom);
    if (geo.locked) persist({ lat, lng, zoom });
  };

  const locateMe = async () => {
    setLocating(true);
    try {
      const p = await getGps();
      meMarker.current?.remove();
      if (lmap.current)
        meMarker.current = L.circleMarker([p.lat, p.lng], { radius: 9, color: '#fff', weight: 3, fillColor: '#2563eb', fillOpacity: 1 }).addTo(lmap.current);
      goTo(p.lat, p.lng, 18);
      toast(`내 위치 (오차 약 ${Math.round(p.acc)}m)`);
    } catch (e) {
      toast(`위치를 찾을 수 없습니다: ${(e as Error).message}`, 'error');
    } finally {
      setLocating(false);
    }
  };

  const doSearch = async () => {
    const q = query.trim();
    if (!q) return;
    try {
      const r = await searchPlace(q);
      if (r.length === 0) toast('찾는 곳이 없습니다', 'error');
      setResults(r);
    } catch (e) {
      toast(`검색 실패: ${(e as Error).message}`, 'error');
    }
  };

  const toggleLock = async () => {
    const m = lmap.current;
    if (!m) return;
    if (geo.locked) {
      persist({ locked: false });
      log('작전도', '지도 고정 풀기');
      return;
    }
    const c = m.getCenter();
    const zoom = m.getZoom();
    const address = (await reverseGeocode(c.lat, c.lng).catch(() => null)) ?? '';
    persist({ locked: true, lat: c.lat, lng: c.lng, zoom, address });
    log('작전도', `지도 고정${address ? ` — ${address}` : ''}`);
    // 재난발생현황 장소가 비어 있으면 채워 준다
    if (address && !data.incident.location?.trim()) {
      saveField(code, 'incident', { ...data.incident, location: address }).catch(() => {});
      log('보고서', `재난발생현황 장소: ${address} (지도에서 자동)`);
    }
  };

  const patchSel = (patch: { label?: string; color?: string }) =>
    sel && persist({ items: geo.items.map((x) => (x.id === sel.id ? { ...x, ...patch } : x)) });

  const removeSelected = () => {
    if (sel) {
      persist({ items: geo.items.filter((x) => x.id !== sel.id) });
      const team = sel.teamId ? data.teams.find((t) => t.id === sel.teamId) : undefined;
      log('작전도', `${team ? teamTitle(team) : MAP_TYPES[sel.type]?.label ?? '표시물'} 삭제`);
    } else if (selLine) {
      persist({ lines: geo.lines.filter((x) => x.id !== selLine.id) });
      log('작전도', `${selLine.kind === 'hose' ? '수관' : '진입경로'} 삭제`);
    }
    setSelId(null);
  };

  return (
    <div className="map-view geo-wrap">
      <div className="map-toolbar">
        {modeSwitch}
        <button className={`btn small ${palette ? 'on' : ''}`} onClick={() => setPalette(!palette)}>
          <Layers size={16} /> 표시물
        </button>
        <span className="sep" />
        <form
          className="search geo-search"
          onSubmit={(e) => {
            e.preventDefault();
            doSearch();
          }}
        >
          <Search size={16} />
          <input value={query} placeholder="주소·건물 이름 검색" onChange={(e) => setQuery(e.target.value)} />
          {results && (
            <div className="geo-results">
              {results.map((r, i) => (
                <button
                  type="button"
                  key={i}
                  onClick={() => {
                    goTo(r.lat, r.lng, 18);
                    setResults(null);
                  }}
                >
                  <b>{r.title}</b>
                  <small>{r.address}</small>
                </button>
              ))}
              <button type="button" className="close" onClick={() => setResults(null)}>
                닫기
              </button>
            </div>
          )}
        </form>
        <button className="btn small" onClick={locateMe} disabled={locating}>
          <Crosshair size={16} /> {locating ? '찾는 중…' : '내 위치'}
        </button>
        <button className={`btn small ${geo.locked ? 'lock-on' : ''}`} onClick={toggleLock} title="지금 보이는 위치로 모든 기기의 지도를 고정">
          {geo.locked ? <Lock size={16} /> : <LockOpen size={16} />} {geo.locked ? '고정됨' : '이 위치로 고정'}
        </button>
        <div className="seg">
          <button className={geo.layer === 'Satellite' ? 'on' : ''} onClick={() => persist({ layer: 'Satellite' })}>
            위성
          </button>
          <button className={geo.layer === 'Base' ? 'on' : ''} onClick={() => persist({ layer: 'Base' })}>
            일반
          </button>
        </div>
        <span className="sep" />
        <button className={`btn small ${mode.kind === 'select' ? 'on' : ''}`} onClick={() => setMode({ kind: 'select' })}>
          <Hand size={16} /> 선택·이동
        </button>
        <button className={`btn small ${mode.kind === 'draw' && mode.line === 'route' ? 'on' : ''}`} onClick={() => setMode({ kind: 'draw', line: 'route' })}>
          <Route size={16} /> 진입경로
        </button>
        <button className={`btn small ${mode.kind === 'draw' && mode.line === 'hose' ? 'on' : ''}`} onClick={() => setMode({ kind: 'draw', line: 'hose' })}>
          <Waves size={16} /> 수관
        </button>
        <span className="grow" />
        <button className="btn small" onClick={() => window.print()}>
          <Printer size={16} /> 인쇄
        </button>
      </div>

      <div className="map-body">
        {palette && (
          <aside className="palette">
            <h4>건물 현황표</h4>
            <div className="pal-grid one">
              {data.buildings.map((bd) => {
                const placed = geo.items.some((x) => x.type === 'building' && x.label === bd.name);
                return (
                  <button
                    key={bd.name}
                    className={`pal team ${mode.kind === 'place' && mode.type === 'building' && mode.teamId === `b:${bd.name}` ? 'on' : ''}`}
                    disabled={placed}
                    onClick={() => setMode({ kind: 'place', type: 'building', teamId: `b:${bd.name}` })}
                  >
                    <Building2 size={16} className="ic-brand" />
                    {bd.name}
                    {placed && <small>배치됨</small>}
                  </button>
                );
              })}
            </div>
            {MAP_CATS.map((c) => (
              <div key={c.label}>
                <h4>{c.label}</h4>
                <div className="pal-grid">
                  {c.types
                    .filter((k) => k !== 'road')
                    .map((k) => (
                      <button
                        key={k}
                        className={`pal ${mode.kind === 'place' && mode.type === k && !mode.teamId ? 'on' : ''}`}
                        onClick={() => setMode({ kind: 'place', type: k })}
                      >
                        <span className="pal-ic" style={{ background: MAP_TYPES[k].color }}>
                          <MapTypeIcon type={k} size={18} />
                        </span>
                        {MAP_TYPES[k].short}
                      </button>
                    ))}
                </div>
              </div>
            ))}
          </aside>
        )}

        <div className="canvas-wrap">
          {mode.kind !== 'select' && (
            <div className="mode-hint">
              {mode.kind === 'place'
                ? `지도에서 놓을 곳을 누르세요 — ${mode.teamId?.startsWith('b:') ? `${mode.teamId.slice(2)} 현황표` : mode.teamId ? data.teams.find((t) => t.id === mode.teamId)?.name : MAP_TYPES[mode.type].label}`
                : `손가락(마우스)으로 그리세요 — ${mode.line === 'hose' ? '수관' : '진입경로'}`}
              <button className="btn tiny" onClick={() => setMode({ kind: 'select' })}>
                취소
              </button>
            </div>
          )}
          {!geo.locked && (
            <div className="geo-hint">
              현장이 화면 가운데 오도록 맞춘 뒤 <b>이 위치로 고정</b>을 누르세요. 그때부터 현황판의 화점·진입대·건물 현황이 지도에 저절로 나타납니다.
            </div>
          )}
          {geo.locked && geo.address && (
            <div className="geo-address">
              <Lock size={13} /> {geo.address}
            </div>
          )}
          <div ref={elRef} className={`geo-map mode-${mode.kind}`} />
        </div>

        {(sel || selLine) && (
          <aside className="map-inspector">
            {sel && <Inspector it={sel} data={data} now={now} onPatch={patchSel} />}
            {selLine && <p>{selLine.kind === 'hose' ? '수관' : '진입경로'} 선택됨</p>}
            <button className="btn danger small block" onClick={removeSelected}>
              <Trash2 size={16} /> 삭제
            </button>
            <button className="btn ghost small block" onClick={() => setSelId(null)}>
              <X size={16} /> 닫기
            </button>
          </aside>
        )}
      </div>
    </div>
  );
}

function lineStyle(kind: GeoLine['kind']): L.PolylineOptions {
  return kind === 'hose'
    ? { color: '#2563eb', weight: 6, dashArray: '12 8', lineCap: 'round' }
    : { color: '#ef4444', weight: 6, lineCap: 'round', lineJoin: 'round' };
}

function getGps(): Promise<{ lat: number; lng: number; acc: number }> {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error('이 기기는 위치 기능이 없습니다'));
    navigator.geolocation.getCurrentPosition(
      (p) => resolve({ lat: p.coords.latitude, lng: p.coords.longitude, acc: p.coords.accuracy }),
      (e) => reject(new Error(e.code === 1 ? '위치 권한이 꺼져 있습니다' : '위치를 받지 못했습니다')),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30000 },
    );
  });
}

/** 지도 표시물 모양 — 예전 작전도처럼 아이콘 위·이름 아래 타일 */
function makeIcon(it: GeoItem, data: SessionData, now: number, selected: boolean): L.DivIcon {
  const t = MAP_TYPES[it.type] ?? MAP_TYPES.text;
  const color = it.color ?? t.color;
  const sel = selected ? ' sel' : '';
  if (it.type === 'building') {
    const bi = data.buildings.findIndex((x) => x.name === it.label);
    if (bi >= 0) return boardIcon(bi, data, sel);
  }
  if (it.type === 'fire') {
    const html = renderToStaticMarkup(
      <div className={`mk-fire${sel}`}>
        <span className="ring" />
        <span className="dot">
          <Flame size={22} color="#fff" strokeWidth={2.4} />
        </span>
        <span className="mk-label red">{it.label || '화점(추정)'}</span>
      </div>,
    );
    return L.divIcon({ html, className: 'geo-mk', iconSize: [44, 44], iconAnchor: [22, 22] });
  }
  if (it.type === 'team') {
    const team = data.teams.find((x) => x.id === it.teamId);
    if (!team)
      return L.divIcon({ html: `<div class="mk-tile gone${sel}">삭제된 대</div>`, className: 'geo-mk', iconSize: [70, 30], iconAnchor: [35, 15] });
    const lv = teamLevel(team, data.timerSettings, now);
    const place = teamPlace(data.buildings, data.states, team.floorKey);
    const html = renderToStaticMarkup(
      <div className={`mk-team lv-${lv}${sel}`} style={{ background: team.color }}>
        <b>
          <HardHat size={15} color="#fff" strokeWidth={2.4} /> {teamMain(team)}
        </b>
        <small>{[teamSub(team), place, team.status === 'waiting' ? '대기' : mmss(teamElapsed(team, now))].filter(Boolean).join(' · ')}</small>
        {team.task && <span className="mk-label" style={{ color: team.color, borderColor: team.color }}>{team.task}</span>}
      </div>,
    );
    return L.divIcon({ html, className: 'geo-mk', iconSize: [120, 44], iconAnchor: [60, 22] });
  }
  if (it.type === 'text') {
    const html = renderToStaticMarkup(<div className={`mk-text${sel}`} style={{ color, borderColor: color }}>{it.label || '메모'}</div>);
    return L.divIcon({ html, className: 'geo-mk', iconSize: [120, 30], iconAnchor: [60, 15] });
  }
  const html = renderToStaticMarkup(
    <div className={`mk-tile${sel}`} style={{ background: color }}>
      <MapTypeIcon type={it.type} size={22} color="#fff" strokeWidth={2.2} />
      <span>{(it.label || t.short).slice(0, 6)}</span>
    </div>,
  );
  return L.divIcon({ html, className: 'geo-mk', iconSize: [58, 52], iconAnchor: [29, 26] });
}

/**
 * 현황판 → 지도 따라가기. 지도를 고정한 뒤부터 동작한다.
 *  · 건물마다 현황표 (고정한 자리 동쪽에 나란히)
 *  · 화점 지정 → 고정한 자리에 🔥, 해제 → 사라짐 (이름은 늘 최신)
 *  · 진입한 대 → 화점(없으면 고정한 자리) 둘레 25m 에 나타남. 철수하면 화면에서 숨김
 *  · 건물을 지우면 그 현황표도 지움
 * 처음 자리만 정해 주고, 사람이 끌어 옮긴 위치는 그대로 둔다. 바뀐 게 없으면 null.
 */
function syncWithBoard(items: GeoItem[], d: SessionData, lat: number, lng: number): { items: GeoItem[]; notes: string[] } | null {
  let out = items.map((x) => ({ ...x }));
  const notes: string[] = [];
  const names = new Set(d.buildings.map((b) => b.name));

  // 건물 현황표
  const before = out.length;
  out = out.filter((x) => !(x.id.startsWith('auto:board:') && !names.has(x.label ?? '')));
  if (out.length !== before) notes.push('지운 건물 현황표 정리');
  d.buildings.forEach((bd, i) => {
    if (out.some((x) => x.type === 'building' && x.label === bd.name)) return;
    out.push({ id: `auto:board:${bd.name}`, type: 'building', label: bd.name, ...offsetMeters(lat, lng, 75 + 85 * i, 0) });
    notes.push(`${bd.name} 현황표`);
  });

  // 화점
  const fo = d.fireOrigin;
  let anchor = { lat, lng };
  if (fo && d.buildings[fo.buildingIdx]) {
    const b = d.buildings[fo.buildingIdx];
    const st = d.states[fo.buildingIdx];
    const u = fo.unitId ? st.units.find((x) => x.id === fo.unitId) : null;
    const label = `화점(추정) ${b.name} ${floorLabel(b, st, fo.floor)}${u ? ` ${unitLabel(b, u)}` : ''}`;
    const ex = out.find((x) => x.type === 'fire');
    if (!ex) {
      out.push({ id: 'auto:fire', type: 'fire', lat, lng, label });
      notes.push('화점');
    } else {
      anchor = { lat: ex.lat, lng: ex.lng };
      if (isAutoFire(ex) && ex.label !== label) {
        ex.label = label;
        notes.push('화점 위치 갱신');
      }
    }
  } else if (out.some(isAutoFire)) {
    out = out.filter((x) => !isAutoFire(x));
    notes.push('화점 해제');
  }

  // 진입대
  const active = d.teams.filter((t) => t.status !== 'waiting');
  const missing = active.filter((t) => !out.some((x) => x.type === 'team' && x.teamId === t.id));
  const taken = out.filter((x) => x.type === 'team').length;
  missing.forEach((t, i) => {
    const slot = taken + i;
    const ang = ((-90 + 45 * slot) * Math.PI) / 180;
    const r = 25 + 12 * Math.floor(slot / 8);
    out.push({ id: `auto:team:${t.id}`, type: 'team', teamId: t.id, color: t.color, ...offsetMeters(anchor.lat, anchor.lng, Math.cos(ang) * r, -Math.sin(ang) * r) });
    notes.push(`${t.name} 진입`);
  });

  return notes.length ? { items: out, notes } : null;
}

/** 지도 위 건물 현황표 — 층마다 호실 색(상태), 화점, 진입대 점 */
function boardIcon(bi: number, data: SessionData, sel: string): L.DivIcon {
  const b = data.buildings[bi];
  const st = data.states[bi];
  const hidden = new Set(st.hiddenFloors);
  const floors = floorsDescending(b).filter((f) => !hidden.has(f));
  const cols = b.defaultUnits;
  const cell = cols > 10 ? 7 : cols > 6 ? 10 : 14;
  const row = Math.max(7, Math.min(13, Math.floor(220 / Math.max(floors.length, 1))));
  const fo = data.fireOrigin?.buildingIdx === bi ? data.fireOrigin : null;
  const counts: Record<string, number> = {};
  for (const u of st.units) counts[u.status] = (counts[u.status] ?? 0) + 1;
  const teamsAt = (f: number) => data.teams.filter((t) => t.status !== 'waiting' && t.floorKey === floorKey(bi, f));
  const w = 34 + cols * (cell + 1) + 28;
  const h = 26 + floors.length * (row + 1) + 8;
  const html = renderToStaticMarkup(
    <div className={`mk-board${sel}`} style={{ width: w }}>
      <div className="mb-head">
        <Building2 size={13} color="#fff" strokeWidth={2.4} />
        <b>{b.name}</b>
        {fo && <Flame size={13} color="#fde047" strokeWidth={2.6} />}
      </div>
      <div className="mb-rows">
        {floors.map((f) => {
          const units = st.units.filter((u) => u.floor === f).sort((x, y) => x.unitIndex - y.unitIndex);
          const fireRow = fo?.floor === f;
          return (
            <div key={f} className={`mb-row${fireRow ? ' fire' : ''}`} style={{ height: row }}>
              <span className="mb-fl" style={{ fontSize: Math.min(10, row) }}>
                {floorLabel(b, st, f)}
              </span>
              <span className="mb-cells" style={{ gridTemplateColumns: `repeat(${cols}, ${cell}px)` }}>
                {units.map((u) => (
                  <i
                    key={u.id}
                    className={fo?.unitId === u.id ? 'origin' : ''}
                    style={{ gridColumn: `${u.unitIndex} / span ${Math.min(u.spanCount, cols - u.unitIndex + 1)}`, background: STATUS[u.status].color }}
                  />
                ))}
              </span>
              <span className="mb-teams">
                {teamsAt(f).map((t) => (
                  <em key={t.id} style={{ background: t.color }} />
                ))}
              </span>
            </div>
          );
        })}
      </div>
      <div className="mb-foot">
        {(['danger', 'fireFalseAlarm', 'confirmed', 'unknown'] as const)
          .filter((k) => counts[k])
          .map((k) => (
            <span key={k}>
              <i style={{ background: STATUS[k].color }} />
              {STATUS[k].label} {counts[k]}
            </span>
          ))}
      </div>
    </div>,
  );
  return L.divIcon({ html, className: 'geo-mk', iconSize: [w, h + 18], iconAnchor: [w / 2, (h + 18) / 2] });
}

// 자동으로 생긴 화점 (사람이 이름을 바꾼 화점 표시는 건드리지 않는다)
const isAutoFire = (x: GeoItem) => x.type === 'fire' && (x.id === 'auto:fire' || !x.label || x.label.startsWith('화점(추정)'));
