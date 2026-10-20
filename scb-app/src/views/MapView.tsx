import { useCallback, useEffect, useMemo, useRef, useState, type PointerEvent as RPointerEvent } from 'react';
import { Building2, FileImage, Flame, Grid3x3, Map as MapIcon, Hand, HardHat, ImageUp, Maximize, MapPin, Minus, Plus, Printer, Route, Sparkles, Trash2, Waves, Wrench } from 'lucide-react';
import type { MapDoc, MapItem, MapLine, SessionData, Team } from '../types';
import { MAP_ICON } from '../components/icons';
import { GeoMap } from './GeoMap';
import { useNow, useSession } from '../session-context';
import {
  addMapObject,
  EMPTY_MAP,
  hasLegacy,
  migrateLegacyMap,
  removeMapObject,
  saveMap,
  saveMapBg,
  saveMapObjects,
  subscribeMap,
  updateMapObject,
  type LegacyMap,
} from '../lib/session';
import { loadMapCache, saveMapCache } from '../lib/offline';
import { deviceUid } from '../firebase';
import { PaletteDrawer, PaletteGroup } from '../components/PaletteGroup';
import { canTouch, compressImage, itemScale, MAP_CATS, MAP_COLORS, MAP_TYPES, SCALE_MAX, SCALE_MIN, SCALE_STEP } from '../lib/mapTypes';
import { floorLabel, floorsDescending, parseFloorKey, unitLabel } from '../lib/building';
import { LEVEL, teamElapsed, teamLevel, teamMain, teamPlace, teamSub, teamTitle } from '../lib/teams';
import { escapeHtml, mmss, uid } from '../lib/format';
import { printHtml } from '../lib/exporter';

const W = 1600;
type Mode = { kind: 'select' } | { kind: 'place'; type: string; teamId?: string } | { kind: 'draw'; line: MapLine['kind'] };

type Drag =
  | { kind: 'pan'; sx: number; sy: number; cx: number; cy: number; scale: number }
  | { kind: 'move'; id: string; dx: number; dy: number; moved: boolean }
  | { kind: 'resize'; id: string }
  | { kind: 'draw'; line: MapLine }
  | null;

const sizeOf = (it: MapItem) => ({ w: it.w ?? MAP_TYPES[it.type]?.w ?? 80, h: it.h ?? MAP_TYPES[it.type]?.h ?? 42 });

const warnedMapErrors = new Set<string>();
const migrationFailed = new Set<string>();

export function MapView() {
  const { code, data, toast, canEdit, access } = useSession();
  const now = useNow();
  // 통신이 끊긴 채 새로고침해도 마지막 작전도는 보이게 (이 기기에 저장해 둔 것)
  const cached = useMemo(() => loadMapCache(code)?.value ?? null, [code]);
  const [map, setMap] = useState<MapDoc>(cached ?? EMPTY_MAP);
  const [loaded, setLoaded] = useState(!!cached);
  const [mode, setMode] = useState<Mode>({ kind: 'select' });
  const [selId, setSelId] = useState<string | null>(null);
  const [bgDim, setBgDim] = useState(0.85);
  const [grid, setGrid] = useState(true);
  const [palette, setPalette] = useState(() => window.innerWidth > 900);
  // 확대(zoom)와 보는 위치(cx, cy = 화면 가운데 좌표)
  const [cam, setCam] = useState({ z: 1, cx: W / 2, cy: 500 });
  const [busy, setBusy] = useState(false);
  const drag = useRef<Drag>(null);
  const [draft, setDraft] = useState<MapLine | null>(null);
  const mapRef = useRef(map);
  const remoteBase = useRef(map);
  const editable = useRef(canEdit);
  editable.current = canEdit;
  mapRef.current = map;
  const svgRef = useRef<SVGSVGElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const isOwner = access === 'owner';
  const legacyRef = useRef<LegacyMap | null>(null);
  const [legacyTick, setLegacyTick] = useState(0);
  useEffect(
    () =>
      subscribeMap(
        code,
        (m, legacy) => {
          remoteBase.current = m;
          setLoaded(true);
          // 끄는 중에는 내 화면 위치를 유지 (놓으면 저장되고 다시 맞춰진다)
          if (!drag.current) setMap(m);
          if (hasLegacy(legacy)) {
            legacyRef.current = legacy;
            setLegacyTick((n) => n + 1);
          }
        },
        (e) => {
          // 같은 알림이 탭을 오갈 때마다 반복해서 뜨지 않게 한 번만
          const key = `${code}:${(e as { code?: string }).code ?? e.message}`;
          if (warnedMapErrors.has(key)) return;
          warnedMapErrors.add(key);
          toast(`작전도 불러오기 실패: ${e.message}`, 'error');
        },
      ),
    [code, toast],
  );
  useEffect(() => {
    const t = setTimeout(() => saveMapCache(code, remoteBase.current), 1500);
    return () => clearTimeout(t);
  }, [code, map]);

  // 예전 방식으로 저장된 작전도는 관리자가 열면 새 방식(표시물 하나씩 저장)으로 옮긴다
  // 실패하면(예: 서버 규칙이 아직 예전 버전) 이번 접속 동안은 다시 시도하지 않는다 — 작전도가 바뀔 때마다 실패 알림이 반복되지 않게
  const migrating = useRef(false);
  useEffect(() => {
    const legacy = legacyRef.current;
    if (!legacy || !isOwner || !canEdit || migrating.current || migrationFailed.has(code)) return;
    migrating.current = true;
    migrateLegacyMap(code, legacy)
      .then(() => { legacyRef.current = null; })
      .catch((e: Error & { code?: string }) => {
        migrationFailed.add(code);
        // 규칙이 예전 버전이라 못 옮긴 경우는 작전도는 예전 방식대로 잘 보이므로 조용히 넘어간다
        if (e.code !== 'permission-denied') toast(`예전 작전도 옮기기 실패: ${e.message}`, 'error');
      })
      .finally(() => { migrating.current = false; });
  }, [legacyTick, isOwner, canEdit, code, toast]);

  const H = map.bg ? Math.round((W * map.bgH) / map.bgW) : 1000;
  const vw = W / cam.z;
  const vh = H / cam.z;
  const clampCam = (c: { z: number; cx: number; cy: number }) => {
    const z = Math.max(1, Math.min(4, c.z));
    const hw = W / z / 2;
    const hh = H / z / 2;
    return { z, cx: Math.max(hw, Math.min(W - hw, c.cx)), cy: Math.max(hh, Math.min(H - hh, c.cy)) };
  };
  const view = clampCam(cam);
  const zoomBy = (f: number) => setCam((c) => clampCam({ ...c, z: c.z * f }));

  const persist = useCallback(
    (patch: Partial<MapDoc>) => {
      if (!editable.current) { setMap(remoteBase.current); toast('열람 중에는 작전도를 수정할 수 없습니다.', 'error'); return Promise.resolve(); }
      return saveMap(code, patch, remoteBase.current).catch((e: Error) => {
      setMap(remoteBase.current);
      toast(`작전도 저장 실패: ${e.message}`, 'error');
      });
    },
    [code, toast],
  );

  // ── 표시물·선 고치기: 본인이 놓은 것만, 관리자는 전부 (서버 규칙으로도 막음) ──
  const [myUid, setMyUid] = useState('');
  useEffect(() => { void deviceUid().then(setMyUid); }, []);
  const mayTouch = (x: { by?: string }) => canTouch(x, myUid, isOwner);
  const fail = (e: Error & { code?: string }) => {
    setMap(remoteBase.current);
    toast(e.code === 'permission-denied' ? '다른 사람이 놓은 것은 관리자만 고치거나 지울 수 있습니다.' : `작전도 저장 실패: ${e.message}`, 'error');
  };
  const okToEdit = (x?: { by?: string }) => {
    if (!editable.current) { toast('열람 중에는 작전도를 수정할 수 없습니다.', 'error'); return false; }
    if (x && !mayTouch(x)) { toast('다른 사람이 놓은 것은 관리자만 고치거나 지울 수 있습니다.', 'error'); return false; }
    return true;
  };
  const itemName = (it: MapItem) => it.label || MAP_TYPES[it.type]?.label || it.type;

  const toSvg = (e: { clientX: number; clientY: number }) => {
    const svg = svgRef.current!;
    const pt = svg.createSVGPoint();
    pt.x = e.clientX;
    pt.y = e.clientY;
    const p = pt.matrixTransform(svg.getScreenCTM()!.inverse());
    return { x: Math.max(0, Math.min(W, p.x)), y: Math.max(0, Math.min(H, p.y)) };
  };


  // ── 포인터 ──
  const onDown = (e: RPointerEvent<SVGSVGElement>) => {
    if (!canEdit && mode.kind !== 'select') return;
    const p = toSvg(e);
    if (mode.kind === 'place') {
      const team = mode.teamId ? data.teams.find((x) => x.id === mode.teamId) : undefined;
      const it: MapItem = {
        id: uid(),
        type: mode.type,
        x: Math.round(p.x),
        y: Math.round(p.y),
        ...(mode.teamId ? { teamId: mode.teamId, color: team?.color } : {}),
        ...(mode.type === 'text' ? { label: '메모' } : {}),
        by: myUid,
      };
      if (!okToEdit()) return;
      setMap((m) => ({ ...m, items: [...m.items, it] }));
      addMapObject(code, 'plan', 'item', it, `표시물 추가: ${itemName(it)}`).catch(fail);
      setSelId(it.id);
      setMode({ kind: 'select' });
      return;
    }
    if (mode.kind === 'draw') {
      const line: MapLine = {
        id: uid(),
        kind: mode.line,
        points: [Math.round(p.x), Math.round(p.y)],
        color: mode.line === 'hose' ? '#1565c0' : mode.line === 'route' ? '#d50000' : '#263238',
        by: myUid,
      };
      drag.current = { kind: 'draw', line };
      setDraft(line);
      e.currentTarget.setPointerCapture(e.pointerId);
      return;
    }
    const el = (e.target as Element).closest('[data-id]') as HTMLElement | null;
    const id = el?.dataset.id ?? null;
    const role = el?.dataset.role;
    setSelId(id);
    if (!id) {
      // 빈 곳을 끌면 화면 이동 (확대했을 때)
      if (view.z > 1) {
        const r = svgRef.current!.getBoundingClientRect();
        e.currentTarget.setPointerCapture(e.pointerId);
        drag.current = { kind: 'pan', sx: e.clientX, sy: e.clientY, cx: view.cx, cy: view.cy, scale: Math.max(vw / r.width, vh / r.height) };
      }
      return;
    }
    const it = map.items.find((x) => x.id === id);
    if (!it) return; // 선(line) 선택
    if (!canEdit || !mayTouch(it)) return; // 남이 놓은 표시물은 선택만 (관리자는 전부 옮길 수 있음)
    e.currentTarget.setPointerCapture(e.pointerId);
    drag.current = role === 'resize' ? { kind: 'resize', id } : { kind: 'move', id, dx: p.x - it.x, dy: p.y - it.y, moved: false };
  };

  const onMove = (e: RPointerEvent<SVGSVGElement>) => {
    const d = drag.current;
    if (!d) return;
    if (d.kind === 'pan') {
      setCam(clampCam({ z: view.z, cx: d.cx - (e.clientX - d.sx) * d.scale, cy: d.cy - (e.clientY - d.sy) * d.scale }));
      return;
    }
    const p = toSvg(e);
    if (d.kind === 'draw') {
      const pts = d.line.points;
      const lx = pts[pts.length - 2];
      const ly = pts[pts.length - 1];
      if (Math.hypot(p.x - lx, p.y - ly) < 14) return;
      d.line = { ...d.line, points: [...pts, Math.round(p.x), Math.round(p.y)] };
      setDraft(d.line);
      return;
    }
    setMap((m) => ({
      ...m,
      items: m.items.map((it) => {
        if (it.id !== d.id) return it;
        if (d.kind === 'move') {
          d.moved = true;
          return { ...it, x: Math.round(p.x - d.dx), y: Math.round(p.y - d.dy) };
        }
        const s = itemScale(it);
        const w = Math.max(40, Math.round(((p.x - it.x) * 2) / s));
        const h = Math.max(30, Math.round(((p.y - it.y) * 2) / s));
        return { ...it, w, h };
      }),
    }));
  };

  const onUp = () => {
    const d = drag.current;
    drag.current = null;
    if (!d || d.kind === 'pan') return;
    if (d.kind === 'draw') {
      setDraft(null);
      if (d.line.points.length >= 4 && okToEdit()) {
        const line = d.line;
        setMap((m) => ({ ...m, lines: [...m.lines, line] }));
        addMapObject(code, 'plan', 'line', line, `${line.kind === 'hose' ? '수관' : '진입경로'} 그리기`).catch(fail);
      }
    } else if (d.kind === 'resize' || d.moved) {
      const it = mapRef.current.items.find((x) => x.id === d.id);
      if (it) {
        const patch = d.kind === 'resize' ? { w: it.w, h: it.h } : { x: it.x, y: it.y };
        updateMapObject(code, d.id, patch, `표시물 ${d.kind === 'resize' ? '크기 변경' : '이동'}: ${itemName(it)}`).catch(fail);
      }
    }
  };

  const sel = map.items.find((x) => x.id === selId) ?? null;
  const selLine = map.lines.find((x) => x.id === selId) ?? null;

  const selTouchable = sel ? mayTouch(sel) : selLine ? mayTouch(selLine) : false;

  const removeSelected = () => {
    if (sel) {
      if (!okToEdit(sel)) return;
      setMap((m) => ({ ...m, items: m.items.filter((x) => x.id !== sel.id) }));
      removeMapObject(code, sel.id, `표시물 삭제: ${itemName(sel)}`).catch(fail);
    } else if (selLine) {
      if (!okToEdit(selLine)) return;
      setMap((m) => ({ ...m, lines: m.lines.filter((x) => x.id !== selLine.id) }));
      removeMapObject(code, selLine.id, `${selLine.kind === 'hose' ? '수관' : '진입경로'} 삭제`).catch(fail);
    }
    setSelId(null);
  };

  const patchSel = (patch: Partial<MapItem>) => {
    if (!sel || !okToEdit(sel)) return;
    setMap((m) => ({ ...m, items: m.items.map((x) => (x.id === sel.id ? { ...x, ...patch } : x)) }));
    updateMapObject(code, sel.id, patch, `표시물 수정: ${itemName(sel)}`).catch(fail);
  };

  const uploadBg = async (f: File) => {
    if (!okToEdit()) return;
    setBusy(true);
    try {
      const { url, w, h } = await compressImage(f);
      // 배경 비율이 바뀌면 기존 표시물 위치를 새 높이에 맞춰 늘린다 (내가 고칠 수 있는 것만)
      const newH = Math.round((W * h) / w);
      const ratio = newH / H;
      const items = map.items.filter((it) => mayTouch(it)).map((it) => ({ ...it, y: Math.round(it.y * ratio) }));
      const lines = map.lines.filter((l) => mayTouch(l)).map((l) => ({ ...l, points: l.points.map((v, i) => (i % 2 ? Math.round(v * ratio) : v)) }));
      await saveMapBg(code, url, w, h);
      if (ratio !== 1) {
        await saveMapObjects(code, 'plan', 'item', items, [], '도면 크기에 맞춰 표시물 위치 조정');
        await saveMapObjects(code, 'plan', 'line', lines, [], '도면 크기에 맞춰 선 위치 조정');
        if (items.length < map.items.length || lines.length < map.lines.length)
          toast('다른 사람이 놓은 표시물은 위치를 그대로 두었습니다. 필요하면 관리자가 옮겨 주세요.');
      }
    } catch (e) {
      setMap(remoteBase.current);
      toast(`도면 등록 실패: ${(e as Error).message}`, 'error');
    } finally {
      setBusy(false);
    }
  };

  // 자동 배치는 다른 사람의 표시물도 옮기므로 관리자만
  const runAuto = () => {
    if (!isOwner || !okToEdit()) return;
    const before = new Map(map.items.map((x) => [x.id, x]));
    const { items, summary } = autoLayout(map.items, data, H);
    const changed = items
      .filter((x) => JSON.stringify(before.get(x.id)) !== JSON.stringify(x))
      .map((x) => ({ ...x, by: before.has(x.id) ? x.by ?? null : myUid }));
    setMap((m) => ({ ...m, items }));
    saveMapObjects(code, 'plan', 'item', changed, [], `자동 배치: ${summary}`).catch(fail);
    toast(`자동 배치: ${summary}`);
  };

  const print = () => {
    const svg = svgRef.current;
    if (!svg) return;
    const clone = svg.cloneNode(true) as SVGSVGElement;
    clone.querySelectorAll('.no-print').forEach((n) => n.remove());
    clone.setAttribute('width', '100%');
    clone.setAttribute('viewBox', `0 0 ${W} ${H}`);
    printHtml(
      '진압작전도',
      `<h1>진압작전도</h1><div class="meta">${escapeHtml(data.title || code)} · ${new Date().toLocaleString('ko-KR')}</div>${clone.outerHTML}${teamLegendHtml(data, now)}`,
    );
  };

  const placedTeam = new Set(map.items.filter((i) => i.teamId).map((i) => i.teamId!));

  const modeSwitch = (
    <div className="seg mode-switch">
      <button
        className={map.mode === 'map' ? 'on' : ''}
        onClick={() => {
          if (map.mode === 'map') return;
          setMap({ ...map, mode: 'map' });
          persist({ mode: 'map' });
        }}
      >
        <MapIcon size={15} /> 지도
      </button>
      <button
        className={map.mode === 'plan' ? 'on' : ''}
        onClick={() => {
          if (map.mode === 'plan') return;
          setMap({ ...map, mode: 'plan' });
          persist({ mode: 'plan' });
        }}
      >
        <FileImage size={15} /> 도면
      </button>
    </div>
  );

  if (loaded && map.mode === 'map') return <GeoMap map={map} modeSwitch={modeSwitch} />;

  return (
    <div className="map-view">
      <div className="map-toolbar">
        {modeSwitch}
        <span className="sep" />
        <button className={`btn small ${mode.kind === 'select' ? 'on' : ''}`} onClick={() => setMode({ kind: 'select' })}>
          <Hand size={16} /> 선택·이동
        </button>
        <button
          className={`btn small ${mode.kind === 'draw' && mode.line === 'route' ? 'on' : ''}`}
          onClick={() => setMode({ kind: 'draw', line: 'route' })}
        >
          <Route size={16} /> 진입경로
        </button>
        <button
          className={`btn small ${mode.kind === 'draw' && mode.line === 'hose' ? 'on' : ''}`}
          onClick={() => setMode({ kind: 'draw', line: 'hose' })}
        >
          <Waves size={16} /> 수관
        </button>
        <span className="sep" />
        <button
          className="btn small primary"
          onClick={runAuto}
          disabled={!isOwner}
          title={isOwner ? '건물·화점·진입대를 현황판 정보대로 자동으로 놓습니다' : '자동 배치는 관리자만 할 수 있습니다 (다른 사람의 표시물도 옮기므로)'}
        >
          <Sparkles size={16} /> 자동 배치
        </button>
        <button className="btn small" disabled={busy} onClick={() => fileRef.current?.click()}>
          <ImageUp size={16} /> {busy ? '올리는 중…' : map.bg ? '도면 바꾸기' : '도면 사진 올리기'}
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            e.target.value = '';
            if (f) uploadBg(f);
          }}
        />
        {map.bg && (
          <>
            <label className="dim">
              흐리게
              <input type="range" min={0.2} max={1} step={0.05} value={bgDim} onChange={(e) => setBgDim(Number(e.target.value))} />
            </label>
            <button
              className="btn small ghost"
              onClick={() => {
                if (!okToEdit()) return;
                setMap({ ...map, bg: null });
                saveMapBg(code, null, map.bgW, map.bgH).catch(fail);

              }}
            >
              배경 지우기
            </button>
          </>
        )}
        <button className={`btn small ${grid ? 'on-soft' : ''}`} onClick={() => setGrid(!grid)} aria-pressed={grid}>
          <Grid3x3 size={16} /> 격자
        </button>
        <span className="grow" />
        <div className="zoom">
          <button className="btn small icon-only" onClick={() => zoomBy(1 / 1.4)} aria-label="축소">
            <Minus size={16} />
          </button>
          <span>{Math.round(view.z * 100)}%</span>
          <button className="btn small icon-only" onClick={() => zoomBy(1.4)} aria-label="확대">
            <Plus size={16} />
          </button>
          <button className="btn small icon-only" onClick={() => setCam({ z: 1, cx: W / 2, cy: H / 2 })} aria-label="전체 보기" title="전체 보기">
            <Maximize size={16} />
          </button>
        </div>
        <button className="btn small" onClick={print}>
          <Printer size={16} /> 인쇄
        </button>
      </div>

      <div className="map-body">
        <PaletteDrawer open={palette} onToggle={() => setPalette(!palette)}>
            <PaletteGroup title="진입대">
            <div className="pal-grid">
              {data.teams.map((t) => (
                <button
                  key={t.id}
                  className={`pal team ${mode.kind === 'place' && mode.teamId === t.id ? 'on' : ''}`}
                  style={{ borderColor: t.color }}
                  disabled={placedTeam.has(t.id)}
                  onClick={() => setMode({ kind: 'place', type: 'team', teamId: t.id })}
                  title={placedTeam.has(t.id) ? '이미 배치됨' : `${teamTitle(t)} 놓기`}
                >
                  <HardHat size={16} style={{ color: t.color }} />
                  {t.name}
                  {placedTeam.has(t.id) && <small>배치됨</small>}
                </button>
              ))}
            </div>
            </PaletteGroup>
            {MAP_CATS.map((c) => (
              <PaletteGroup key={c.label} title={c.label}>
                <div className="pal-grid">
                  {c.types.map((k) => (
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
              </PaletteGroup>
            ))}
        </PaletteDrawer>

        <div className="canvas-wrap">
          {mode.kind !== 'select' && (
            <div className="mode-hint">
              {mode.kind === 'place'
                ? `놓을 곳을 누르세요 — ${mode.teamId ? data.teams.find((t) => t.id === mode.teamId)?.name : MAP_TYPES[mode.type].label}`
                : `손가락(마우스)으로 그리세요 — ${mode.line === 'hose' ? '수관' : '진입경로'}`}
              <button className="btn tiny" onClick={() => setMode({ kind: 'select' })}>
                취소
              </button>
            </div>
          )}
          {!loaded && <div className="mode-hint">작전도 불러오는 중…</div>}
          <svg
            ref={svgRef}
            className={`map-svg mode-${mode.kind}`}
            viewBox={`${view.cx - vw / 2} ${view.cy - vh / 2} ${vw} ${vh}`}
            preserveAspectRatio="xMidYMid meet"
            onPointerDown={onDown}
            onPointerMove={onMove}
            onPointerUp={onUp}
            onPointerCancel={onUp}
            onWheel={(e) => {
              if (!e.ctrlKey && !e.metaKey && Math.abs(e.deltaY) < 40) return;
              const p = toSvg(e);
              setCam((c) => {
                const z = Math.max(1, Math.min(4, c.z * (e.deltaY < 0 ? 1.2 : 1 / 1.2)));
                // 마우스가 가리키는 곳을 중심으로 확대
                return clampCam({ z, cx: p.x + (c.cx - p.x) * (c.z / z), cy: p.y + (c.cy - p.y) * (c.z / z) });
              });
            }}
            xmlns="http://www.w3.org/2000/svg"
          >
            <defs>
              <marker id="arrow-red" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
                <path d="M0,0 L10,5 L0,10 z" fill="#d50000" />
              </marker>
              <filter id="sh" x="-20%" y="-20%" width="140%" height="160%">
                <feDropShadow dx="0" dy="3" stdDeviation="3" floodColor="#0f172a" floodOpacity="0.28" />
              </filter>
              <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                <path d="M40 0H0V40" fill="none" stroke="#e2e8f0" strokeWidth="1" />
              </pattern>
            </defs>
            <rect x={0} y={0} width={W} height={H} fill="#fff" />
            {map.bg && <image href={map.bg} x={0} y={0} width={W} height={H} opacity={bgDim} preserveAspectRatio="none" />}
            {grid && <rect className="no-print" x={0} y={0} width={W} height={H} fill="url(#grid)" opacity={map.bg ? 0.35 : 1} />}

            {/* 건물·도로 같은 큰 것을 먼저 그려서 차량이 위에 오게 */}
            {[...map.items]
              .sort((a, b) => zOrder(a) - zOrder(b))
              .map((it) => (
                <ItemShape key={it.id} it={it} data={data} now={now} selected={selId === it.id} />
              ))}
            {[...map.lines, ...(draft ? [draft] : [])].map((l) => (
              <polyline
                key={l.id}
                data-id={l.id}
                points={l.points.join(' ')}
                fill="none"
                stroke={l.color}
                strokeWidth={l.kind === 'hose' ? 7 : 6}
                strokeDasharray={l.kind === 'hose' ? '16 8' : undefined}
                strokeLinecap="round"
                strokeLinejoin="round"
                markerEnd={l.kind === 'route' ? 'url(#arrow-red)' : undefined}
                opacity={selId === l.id ? 0.6 : 0.9}
              />
            ))}
          </svg>
          {map.items.length === 0 && map.lines.length === 0 && loaded && (
            <div className="map-empty">
              <p>
                <Sparkles size={16} /> <b>자동 배치</b>를 누르면 현황판의 건물·화점·진입대가 바로 놓입니다.
              </p>
              <p className="hint">도면이나 네이버지도 캡처 사진을 [도면·지도 올리기]로 넣으면 그 위에 표시됩니다.</p>
            </div>
          )}
        </div>

        {(sel || selLine) && (
          <aside className="map-inspector">
            {sel && <Inspector it={sel} data={data} now={now} onPatch={patchSel} readOnly={!canEdit || !selTouchable} />}
            {selLine && <p>{selLine.kind === 'hose' ? '수관' : '진입경로'} 선택됨</p>}
            {canEdit && !selTouchable && <p className="hint">다른 사람이 놓은 것입니다. 관리자만 고치거나 지울 수 있습니다.</p>}
            {canEdit && selTouchable && (
              <button className="btn danger small block" onClick={removeSelected}>
                <Trash2 size={16} /> 삭제
              </button>
            )}
            <button className="btn ghost small block" onClick={() => setSelId(null)}>
              닫기
            </button>
          </aside>
        )}
      </div>
    </div>
  );
}

const zOrder = (it: MapItem) => (it.type === 'road' ? 0 : it.type === 'building' ? 1 : it.type === 'fire' ? 3 : it.type === 'team' ? 4 : 2);

/** 표시물 하나 — 크기 배율은 표시물 가운데를 기준으로 키우고 줄인다 */
function ItemShape(props: { it: MapItem; data: SessionData; now: number; selected: boolean }) {
  const { it } = props;
  const s = itemScale(it);
  if (s === 1) return <ItemBody {...props} />;
  return (
    <g transform={`translate(${it.x} ${it.y}) scale(${s}) translate(${-it.x} ${-it.y})`}>
      <ItemBody {...props} />
    </g>
  );
}

function ItemBody({ it, data, now, selected }: { it: MapItem; data: SessionData; now: number; selected: boolean }) {
  const t = MAP_TYPES[it.type] ?? MAP_TYPES.text;
  const { w, h } = sizeOf(it);
  const color = it.color ?? t.color;
  const x = it.x - w / 2;
  const y = it.y - h / 2;
  const selRect = selected && (
    <rect className="no-print" x={x - 6} y={y - 6} width={w + 12} height={h + 12} rx={8} fill="none" stroke="#2563eb" strokeWidth={3} strokeDasharray="8 5" />
  );

  if (it.type === 'building' || it.type === 'road') {
    // 현황판 건물과 이름이 같으면 층 구분선을 그려서 화점·진입대 층이 보이게 한다
    const bi = it.type === 'building' ? data.buildings.findIndex((b) => b.name === it.label) : -1;
    const floors = bi >= 0 ? floorsDescending(data.buildings[bi]) : [];
    const band = floors.length ? (h - 40) / floors.length : 0;
    const fireFloor = data.fireOrigin?.buildingIdx === bi ? data.fireOrigin.floor : null;
    const teamFloors = new Map<number, string>();
    for (const t of data.teams) {
      const p = t.status !== 'waiting' ? parseFloorKey(t.floorKey) : null;
      if (p && p.b === bi && !teamFloors.has(p.f)) teamFloors.set(p.f, t.color);
    }
    return (
      <g data-id={it.id}>
        <rect x={x} y={y} width={w} height={h} rx={8} fill={color} fillOpacity={it.type === 'road' ? 0.55 : 0.1} stroke={color} strokeWidth={2.5} />
        {it.type === 'building' && <path d={`M${x} ${y + 30}V${y + 8}a8 8 0 0 1 8-8H${x + w - 8}a8 8 0 0 1 8 8V${y + 30}Z`} fill={color} />}
        {floors.map((f, i) => {
          const fy = y + 34 + i * band;
          const hot = f === fireFloor;
          const tc = teamFloors.get(f);
          return (
            <g key={f} pointerEvents="none">
              {(hot || tc) && <rect x={x + 2} y={fy} width={w - 4} height={band} fill={hot ? '#ff1744' : tc} fillOpacity={hot ? 0.28 : 0.16} />}
              {i > 0 && <line x1={x} y1={fy} x2={x + w} y2={fy} stroke={color} strokeOpacity={0.35} strokeWidth={1} />}
              {band >= 11 && (
                <text x={x + 8} y={fy + band / 2 + 4} fontSize={Math.min(13, band - 2)} fill={hot ? '#b91c1c' : '#334155'} fontWeight={hot || tc ? 700 : 500}>
                  {floorLabel(data.buildings[bi], data.states[bi], f)}
                </text>
              )}
            </g>
          );
        })}
        {it.type === 'road' && <line x1={x + 10} y1={it.y} x2={x + w - 10} y2={it.y} stroke="#fff" strokeWidth={3} strokeDasharray="18 12" />}
        {it.type === 'building' && <Building2 x={x + 9} y={y + 5} size={20} color="#fff" strokeWidth={2.2} />}
        <text x={it.type === 'building' ? x + 36 : x + 12} y={it.type === 'building' ? y + 22 : it.y + 6} fontSize={18} fontWeight={700} fill="#fff">
          {it.label || t.label}
        </text>
        {selRect}
        {selected && <rect className="no-print" data-id={it.id} data-role="resize" x={x + w - 14} y={y + h - 14} width={28} height={28} rx={4} fill="#2563eb" />}
      </g>
    );
  }

  if (it.type === 'fire') {
    return (
      <g data-id={it.id}>
        <circle cx={it.x} cy={it.y} r={34} fill="#ff1744" fillOpacity={0.25}>
          <animate attributeName="r" values="30;46;30" dur="1.4s" repeatCount="indefinite" />
          <animate attributeName="fill-opacity" values="0.35;0.05;0.35" dur="1.4s" repeatCount="indefinite" />
        </circle>
        <circle cx={it.x} cy={it.y} r={26} fill="#dc2626" stroke="#fff" strokeWidth={3} filter="url(#sh)" />
        <Flame x={it.x - 15} y={it.y - 16} size={30} color="#fff" strokeWidth={2.2} />
        <Label x={it.x} y={it.y + 52} text={it.label || '화점(추정)'} color="#d50000" />
        {selRect}
      </g>
    );
  }

  if (it.type === 'team') {
    const team = data.teams.find((x) => x.id === it.teamId);
    if (!team) {
      return (
        <g data-id={it.id} opacity={0.5}>
          <rect x={x} y={y} width={w} height={h} rx={10} fill="#9e9e9e" />
          <text x={it.x} y={it.y + 6} fontSize={16} textAnchor="middle" fill="#fff">
            (삭제된 대)
          </text>
          {selRect}
        </g>
      );
    }
    const lv = teamLevel(team, data.timerSettings, now);
    const place = teamPlace(data.buildings, data.states, team.floorKey);
    const sub = [teamSub(team), place, team.status === 'waiting' ? '대기' : mmss(teamElapsed(team, now))].filter(Boolean).join(' · ');
    const tw = Math.max(w, 130, Array.from(sub).length * 9 + 24);
    return (
      <g data-id={it.id}>
        <rect
          x={it.x - tw / 2}
          y={y}
          width={tw}
          height={h + 12}
          rx={12}
          fill={team.color}
          filter="url(#sh)"
          stroke={lv === 'danger' ? '#b91c1c' : lv === 'warning' ? '#f97316' : '#fff'}
          strokeWidth={lv === 'danger' || lv === 'warning' ? 6 : 2.5}
        >
          {lv === 'danger' && <animate attributeName="stroke-opacity" values="1;0.2;1" dur="0.8s" repeatCount="indefinite" />}
        </rect>
        <HardHat x={it.x - 46} y={y + 7} size={22} color="#fff" strokeWidth={2.2} />
        <text x={it.x + 12} y={y + 25} fontSize={19} fontWeight={800} textAnchor="middle" fill="#fff">
          {teamMain(team)}
        </text>
        <text x={it.x} y={y + 49} fontSize={14} fontWeight={500} textAnchor="middle" fill="#fff" fillOpacity={0.92}>
          {sub}
        </text>
        {team.task && <Label x={it.x} y={y + h + 34} text={team.task} color={team.color} />}
        {selRect}
      </g>
    );
  }

  if (it.type === 'text') {
    return (
      <g data-id={it.id}>
        <Label x={it.x} y={it.y + 8} text={it.label || '메모'} color={color} big />
        {selRect}
      </g>
    );
  }

  return (
    <g data-id={it.id}>
      <rect x={x} y={y} width={w} height={h} rx={12} fill={color} stroke="#fff" strokeWidth={2} filter="url(#sh)" />
      <MapTypeIcon type={it.type} x={it.x - 13} y={y + 8} size={26} color="#fff" strokeWidth={2.2} />
      <text x={it.x} y={y + h - 10} fontSize={14} fontWeight={700} textAnchor="middle" fill="#fff">
        {(it.label || t.short).slice(0, 6)}
      </text>
      {selRect}
    </g>
  );
}

function Label({ x, y, text, color, big }: { x: number; y: number; text: string; color: string; big?: boolean }) {
  const fs = big ? 22 : 16;
  const w = Math.max(40, Array.from(text).length * fs * 0.95 + 16);
  return (
    <g>
      <rect x={x - w / 2} y={y - fs - 2} width={w} height={fs + 12} rx={8} fill="#fff" stroke={color} strokeWidth={1.5} filter="url(#sh)" />
      <text x={x} y={y + 2} fontSize={fs} fontWeight={700} textAnchor="middle" fill={color}>
        {text}
      </text>
    </g>
  );
}

export function Inspector({
  it,
  data,
  now,
  onPatch,
  readOnly,
}: {
  it: Pick<MapItem, 'id' | 'type' | 'label' | 'color' | 'teamId' | 'scale'>;
  data: SessionData;
  now: number;
  onPatch: (p: { label?: string; color?: string; scale?: number }) => void;
  readOnly?: boolean;
}) {
  const sizeBox = readOnly ? null : <SizeControl scale={itemScale(it)} onChange={(scale) => onPatch({ scale })} />;
  const t = MAP_TYPES[it.type];
  const [label, setLabel] = useState(it.label ?? '');
  useEffect(() => setLabel(it.label ?? ''), [it.id, it.label]);
  if (it.type === 'team') {
    const team = data.teams.find((x) => x.id === it.teamId);
    if (!team) return <p>삭제된 진입대입니다.</p>;
    const lv = teamLevel(team, data.timerSettings, now);
    return (
      <div className="insp">
        <h3 style={{ color: team.color }}>
          <HardHat size={18} /> {teamTitle(team)}
        </h3>
        <p>
          <span className="tlevel" style={{ background: LEVEL[lv].color }}>
            {LEVEL[lv].label}
          </span>{' '}
          {mmss(teamElapsed(team, now))}
        </p>
        <p>
          <MapPin size={15} /> {teamPlace(data.buildings, data.states, team.floorKey) || '위치 미지정'}
        </p>
        {team.task && (
          <p>
            <Wrench size={15} /> {team.task}
          </p>
        )}
        {sizeBox}
        <p className="hint">대 정보는 현황판 → 진입대 탭에서 바꿉니다.</p>
      </div>
    );
  }
  return (
    <div className="insp">
      <h3>
        <span className="pal-ic" style={{ background: it.color ?? t?.color }}>
          <MapTypeIcon type={it.type} size={16} />
        </span>
        {t?.label ?? it.type}
      </h3>
      <label className="field">
        <span>표시 이름</span>
        <input
          value={label}
          placeholder={t?.label}
          disabled={readOnly}
          onChange={(e) => setLabel(e.target.value)}
          onBlur={() => label !== (it.label ?? '') && onPatch({ label: label.trim() })}
          onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
        />
      </label>
      {it.type !== 'fire' && !readOnly && (
        <div className="colors">
          {MAP_COLORS.map((c) => (
            <button key={c} className={`swatch ${it.color === c ? 'on' : ''}`} style={{ background: c }} onClick={() => onPatch({ color: c })} aria-label={c} />
          ))}
        </div>
      )}
      {sizeBox}
      {(it.type === 'building' || it.type === 'road') && <p className="hint">오른쪽 아래 파란 네모를 끌면 가로·세로를 따로 바꿀 수 있습니다.</p>}
    </div>
  );
}

/** 표시물 크기 — − / + 로 25%씩, 가운데 숫자를 누르면 원래 크기 */
function SizeControl({ scale, onChange }: { scale: number; onChange: (s: number) => void }) {
  const set = (v: number) => onChange(Math.round(Math.max(SCALE_MIN, Math.min(SCALE_MAX, v)) * 100) / 100);
  return (
    <div className="size-ctl">
      <span>크기</span>
      <button className="btn small icon-only" disabled={scale <= SCALE_MIN} onClick={() => set(scale - SCALE_STEP)} aria-label="작게">
        <Minus size={18} />
      </button>
      <button className="btn small size-val" disabled={scale === 1} onClick={() => set(1)} title="원래 크기로">
        {Math.round(scale * 100)}%
      </button>
      <button className="btn small icon-only" disabled={scale >= SCALE_MAX} onClick={() => set(scale + SCALE_STEP)} aria-label="크게">
        <Plus size={18} />
      </button>
    </div>
  );
}

/**
 * 자동 배치 — 현황판 데이터로 작전도를 채운다.
 *  · 건물마다 사각형 (없을 때만 새로)
 *  · 화점: 건물 사각형 안에서 층(위아래)·호실(좌우) 비율 위치
 *  · 진입 중인 대: 해당 층 높이에 건물 양옆으로 줄 세움
 *  · 지휘차: 없으면 첫 건물 왼쪽 아래
 * 사람이 옮긴 차량·선은 건드리지 않는다.
 */
function autoLayout(items: MapItem[], d: SessionData, H: number) {
  const out = items.map((x) => ({ ...x }));
  const n = d.buildings.length;
  const notes: string[] = [];
  const rects = d.buildings.map((b, i) => {
    let it = out.find((x) => x.type === 'building' && x.label === b.name);
    if (!it) {
      const w = n > 2 ? 300 : 360;
      const h = Math.min(H * 0.5, 120 + floorsDescending(b).length * 14);
      it = { id: uid(), type: 'building', x: Math.round((W * (i + 1)) / (n + 1)), y: Math.round(H * 0.45), w, h: Math.round(h), label: b.name };
      out.push(it);
      notes.push(`건물 ${b.name}`);
    }
    const { w, h } = sizeOf(it);
    return { left: it.x - w / 2, top: it.y - h / 2, w, h };
  });

  const floorY = (bi: number, floor: number) => {
    const fl = floorsDescending(d.buildings[bi]);
    const idx = Math.max(0, fl.indexOf(floor));
    const r = rects[bi];
    return r.top + 34 + ((idx + 0.5) / fl.length) * (r.h - 40);
  };

  const fo = d.fireOrigin;
  if (fo && rects[fo.buildingIdx]) {
    const b = d.buildings[fo.buildingIdx];
    const st = d.states[fo.buildingIdx];
    const u = fo.unitId ? st.units.find((x) => x.id === fo.unitId) : null;
    const r = rects[fo.buildingIdx];
    const x = u ? r.left + ((u.unitIndex - 0.5 + (u.spanCount - 1) / 2) / b.defaultUnits) * r.w : r.left + r.w / 2;
    const label = `화점(추정) ${floorLabel(b, st, fo.floor)}${u ? ` ${unitLabel(b, u)}` : ''}`;
    const y = floorY(fo.buildingIdx, fo.floor);
    const ex = out.find((x) => x.type === 'fire');
    if (ex) Object.assign(ex, { x: Math.round(x), y: Math.round(y), label });
    else out.push({ id: uid(), type: 'fire', x: Math.round(x), y: Math.round(y), label });
    notes.push('화점');
  }

  // 진입대: 해당 층 높이에 건물 왼쪽·오른쪽을 번갈아 세우고, 같은 쪽에서 겹치면 아래로 민다
  const used: Record<string, number[]> = {};
  let placed = 0;
  const active = d.teams
    .filter((t: Team) => t.status !== 'waiting' && parseFloorKey(t.floorKey) && rects[parseFloorKey(t.floorKey)!.b])
    .sort((a, b) => parseFloorKey(b.floorKey)!.f - parseFloorKey(a.floorKey)!.f);
  active.forEach((t: Team, i) => {
    const p = parseFloorKey(t.floorKey)!;
    const r = rects[p.b];
    const left = i % 2 === 0;
    const side = `${p.b}${left ? 'L' : 'R'}`;
    const x = left ? r.left - 90 : r.left + r.w + 90;
    let y = floorY(p.b, p.f);
    const taken = (used[side] ??= []);
    while (taken.some((v) => Math.abs(v - y) < 74)) y += 74;
    taken.push(y);
    const ex = out.find((x) => x.type === 'team' && x.teamId === t.id);
    if (ex) Object.assign(ex, { x: Math.round(x), y: Math.round(y) });
    else out.push({ id: uid(), type: 'team', teamId: t.id, color: t.color, x: Math.round(x), y: Math.round(y) });
    placed++;
  });
  if (placed) notes.push(`진입대 ${placed}`);

  if (!out.some((x) => x.type === 'commandCar') && rects[0]) {
    out.push({ id: uid(), type: 'commandCar', x: Math.round(Math.max(60, rects[0].left - 120)), y: Math.round(Math.min(H - 40, rects[0].top + rects[0].h + 70)) });
    notes.push('지휘차');
  }
  return { items: out, summary: notes.length ? notes.join(', ') : '바뀐 것 없음' };
}

function teamLegendHtml(d: SessionData, now: number) {
  const rows = d.teams
    .filter((t) => t.status !== 'waiting')
    .map(
      (t) =>
        `<tr><td><span style="display:inline-block;width:12px;height:12px;border-radius:50%;background:${t.color}"></span> ${escapeHtml(teamTitle(t))}</td><td>${escapeHtml(
          teamPlace(d.buildings, d.states, t.floorKey),
        )}</td><td>${escapeHtml(t.task)}</td><td>${LEVEL[teamLevel(t, d.timerSettings, now)].label} ${mmss(teamElapsed(t, now))}</td></tr>`,
    )
    .join('');
  return rows ? `<h2>진입대 현황</h2><table><thead><tr><th>대</th><th>위치</th><th>임무</th><th>상태</th></tr></thead><tbody>${rows}</tbody></table>` : '';
}

export function MapTypeIcon({ type, ...rest }: { type: string } & import('lucide-react').LucideProps) {
  const I = MAP_ICON[type] ?? Flame;
  return <I {...rest} />;
}
