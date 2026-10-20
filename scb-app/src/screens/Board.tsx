import { useEffect, useState } from 'react';
import { Building2, ClipboardList, FileText, Flame, LogOut, Map as MapIcon, Minimize, Ambulance, UserRound, type LucideIcon } from 'lucide-react';
import { useSession } from '../session-context';
import { identityText } from '../lib/identity';
import { STATUS, STATUS_ORDER } from '../lib/building';
import { IdentityDialog } from '../components/IdentityDialog';
import { Modal } from '../components/Modal';
import { LogDialog } from '../components/LogDialog';
import { StatusView } from '../views/StatusView';
import { MapView } from '../views/MapView';
import { CasualtyView } from '../views/CasualtyView';
import { ReportsView } from '../views/ReportsView';
import { copyText } from '../lib/exporter';
import { TeamAlarm } from '../components/TeamsPanel';
import { AccessDialog } from '../components/AccessDialog';
import { SaveIndicator } from '../components/SaveIndicator';
import { discardSaves, hasUnsavedChanges, retrySaves, useSaveStatus } from '../lib/save-status';
import { LEVEL, teamLevel, teamTitle } from '../lib/teams';
import { useNow } from '../session-context';
import { SummaryBar } from '../components/SummaryBar';
import { UndoBar } from '../components/UndoBar';
import { ErrorBoundary } from '../components/ErrorBoundary';

type View = 'status' | 'map' | 'casualty' | 'reports';
const VIEWS: { key: View; label: string; icon: LucideIcon }[] = [
  { key: 'status', label: '현황판', icon: Building2 },
  { key: 'map', label: '진압작전도', icon: MapIcon },
  { key: 'casualty', label: '인명피해', icon: Ambulance },
  { key: 'reports', label: '보고서', icon: FileText },
];

export function Board({ onLeave }: { onLeave: () => void }) {
  const { code, me, setMe, data, logs, toast, log, access, canEdit, connected } = useSession();
  const [view, setView] = useState<View>(() => {
    try { const saved = sessionStorage.getItem('scb.view'); return VIEWS.find((v) => v.key === saved)?.key ?? 'status'; }
    catch { return 'status'; }
  });
  const [dialog, setDialog] = useState<null | 'me' | 'log' | 'code' | 'leave' | 'access'>(null);
  const [large, setLarge] = useState(false);
  const now = useNow();
  const saveStatus = useSaveStatus();
  const unsaved = saveStatus.pending + saveStatus.saving + saveStatus.failed;
  useEffect(() => {
    document.body.classList.add('in-session');
    return () => document.body.classList.remove('in-session');
  }, []);
  // 전체화면: 브라우저 주소창뿐 아니라 앱 위쪽 띠(탭·버튼·저장 상태)도 숨기고 화면만 크게 본다.
  // 전체화면을 못 하는 기기(아이폰 등)에서도 위쪽 띠는 숨긴다. Esc·뒤로가기로 나와도 맞춰진다.
  const [full, setFull] = useState(false);
  useEffect(() => {
    const sync = () => { if (!document.fullscreenElement) setFull(false); };
    document.addEventListener('fullscreenchange', sync);
    return () => document.removeEventListener('fullscreenchange', sync);
  }, []);
  const enterFull = () => {
    setFull(true);
    void document.documentElement.requestFullscreen?.().catch(() => {});
  };
  const exitFull = () => {
    setFull(false);
    if (document.fullscreenElement) void document.exitFullscreen().catch(() => {});
  };
  // 현장에 들어와 있는 동안 화면이 꺼지거나 잠기지 않게 (모니터·태블릿에 띄워 두는 용도)
  useEffect(() => {
    type Lock = { release: () => Promise<void> };
    const wl = (navigator as Navigator & { wakeLock?: { request: (t: 'screen') => Promise<Lock> } }).wakeLock;
    if (!wl) return;
    let lock: Lock | null = null;
    let gone = false;
    const get = () => {
      if (document.visibilityState !== 'visible') return;
      wl.request('screen').then((l) => { if (gone) void l.release(); else lock = l; }).catch(() => {});
    };
    get();
    // 다른 앱을 보다 돌아오면 다시 켠다 (브라우저가 화면이 가려지면 자동으로 풀기 때문)
    document.addEventListener('visibilitychange', get);
    return () => {
      gone = true;
      document.removeEventListener('visibilitychange', get);
      void lock?.release().catch(() => {});
    };
  }, []);
  const alerts = data.teams.filter((t) => ['warning', 'danger'].includes(teamLevel(t, data.timerSettings, now)));

  const pick = (v: View) => {
    setView(v);
    try {
      sessionStorage.setItem('scb.view', v);
    } catch {
      /* 무시 */
    }
  };

  const counts = STATUS_ORDER.map((s) => ({
    s,
    n: data.states.reduce((sum, st) => sum + st.units.filter((u) => u.status === s).length, 0),
  })).filter((x) => x.n > 0);

  return (
    <div className={`board ${large ? 'large-text' : ''} ${full ? 'full' : ''}`}>
      {full && (
        <div className="full-bar">
          {/* 숨긴 띠의 중요한 경보는 여기서 계속 보여 준다 */}
          {saveStatus.failed > 0 && <strong className="warn">저장 실패 {saveStatus.failed}건</strong>}
          {alerts.map((t) => (
            <strong key={t.id} className="warn" style={{ color: LEVEL[teamLevel(t, data.timerSettings, now)].color }}>
              {teamTitle(t)} {LEVEL[teamLevel(t, data.timerSettings, now)].label}
            </strong>
          ))}
          <button className="btn small" onClick={exitFull}>
            <Minimize size={16} /> 전체화면 끝내기
          </button>
        </div>
      )}
      <header className="topbar">
        <button className="title" onClick={() => setDialog('code')} title="세션 코드 보기">
          <span className="code-tag">{code}</span>
          <span className="site">{data.title || 'SafeCheckBoard'}</span>
        </button>
        <nav className="tabs" aria-label="화면 전환">
          {VIEWS.map((v) => (
            <button key={v.key} className={view === v.key ? 'on' : ''} onClick={() => pick(v.key)}>
              <v.icon size={18} aria-hidden />
              <span>{v.label}</span>
            </button>
          ))}
        </nav>
        <div className="top-right">
          <button className="btn small" onClick={() => setLarge(!large)}>글자 {large ? '기본' : '확대'}</button>
          <button className="btn small" onClick={enterFull}>전체화면</button>
          <button className="btn small" onClick={() => setDialog('access')}>{access === 'owner' ? '권한 관리' : canEdit ? '편집 권한' : '열람 권한'}</button>
          <div className="status-chips">
            {data.fireOrigin && <span className="schip fire">
                <Flame size={13} /> 화점
              </span>}
            {counts.map(({ s, n }) => (
              <span key={s} className="schip" style={{ background: STATUS[s].color }}>
                {STATUS[s].label} {n}
              </span>
            ))}
          </div>
          <button className="me-chip" onClick={() => setDialog('me')} title="기록자 정보 변경">
            <UserRound size={16} />
            <span>{identityText(me)}</span>
          </button>
          <button className="btn small" onClick={() => setDialog('log')}>
            <ClipboardList size={17} /> 기록 <b className="count">{logs.length}</b>
          </button>
          <button className="icon-btn light" onClick={() => setDialog('leave')} aria-label="나가기" title="세션 나가기">
            <LogOut size={18} />
          </button>
        </div>
      </header>

      <div className="safety-strip">
        <SaveIndicator /><TeamAlarm />
        {data.closed && <strong>종료된 현장 · 읽기 전용</strong>}
        {alerts.map((t) => <strong key={t.id} style={{ color: LEVEL[teamLevel(t, data.timerSettings, now)].color }}>{teamTitle(t)} {LEVEL[teamLevel(t, data.timerSettings, now)].label}</strong>)}
      </div>
      <SummaryBar data={data} now={now} />
      {!canEdit && (
        <p className="read-only-notice">
          {data.closed
            ? '현장이 종료되어 입력이 잠겼습니다.'
            : !connected
              ? '서버와 연결되지 않아 이 기기에 저장된 마지막 화면을 보여 주고 있습니다. 연결되면 자동으로 최신 현황으로 바뀝니다.'
              : '열람 중입니다. 편집하려면 권한 관리에서 기기 번호를 확인하고 개설자에게 알려주세요.'}
        </p>
      )}

      <main className="view" data-readonly={!canEdit}>
        <ErrorBoundary key={view} name={VIEWS.find((v) => v.key === view)?.label ?? view}>
          {view === 'status' && <StatusView />}
          {view === 'map' && <MapView />}
          {view === 'casualty' && <CasualtyView />}
          {view === 'reports' && <ReportsView />}
        </ErrorBoundary>
      </main>
      <UndoBar />

      {dialog === 'access' && <AccessDialog onClose={() => setDialog(null)} />}

      {dialog === 'me' && (
        <IdentityDialog
          initial={me}
          onClose={() => setDialog(null)}
          onSave={(v) => {
            const before = identityText(me);
            setMe(v);
            setDialog(null);
            if (before !== identityText(v)) log('세션', `기록자 변경: ${before} → ${identityText(v)}`);
          }}
        />
      )}
      {dialog === 'log' && <LogDialog onClose={() => setDialog(null)} />}
      {dialog === 'code' && (
        <Modal title="세션 참여 코드" onClose={() => setDialog(null)}>
          <p className="hint">코드를 아는 사람은 현장을 열람할 수 있습니다. 편집은 개설자가 권한을 부여해야 합니다. 코드를 필요한 참여자에게만 공유하세요.</p>
          <p className="code-big">{code}</p>
          <div className="row-btns">
            <button
              className="btn"
              onClick={async () => {
                (await copyText(code)) && toast(`코드 ${code} 복사됨`);
              }}
            >
              코드 복사
            </button>
            <button
              className="btn"
              onClick={async () => {
                const url = `${location.origin}${location.pathname}?s=${code}`;
                (await copyText(url)) && toast('바로 들어오는 링크 복사됨');
              }}
            >
              링크 복사
            </button>
          </div>
        </Modal>
      )}
      {dialog === 'leave' && (
        <Modal
          title="세션 나가기"
          onClose={() => setDialog(null)}
          footer={
            <>
              <button className="btn ghost" onClick={() => setDialog(null)}>
                취소
              </button>
              {unsaved > 0 && (
                <button className="btn" onClick={retrySaves}>
                  다시 저장
                </button>
              )}
              <button className={`btn ${unsaved > 0 ? 'danger' : 'primary'}`} onClick={() => {
                if (hasUnsavedChanges() && !confirm('저장되지 않은 변경은 사라집니다. 그래도 나갈까요?')) return;
                discardSaves();
                onLeave();
              }}>
                {unsaved > 0 ? '저장 안 하고 나가기' : '나가기'}
              </button>
            </>
          }
        >
          <p>처음 화면으로 돌아갑니다. 현장 데이터는 그대로 남아 있어서 코드 <b>{code}</b> 로 다시 들어올 수 있습니다.</p>
          {unsaved > 0 && (
            <p className="error">
              아직 서버에 저장되지 않은 변경이 {unsaved}건 있습니다
              {saveStatus.failed > 0 ? ` (저장 실패 ${saveStatus.failed}건)` : ''}. 「다시 저장」을 눌러 보고, 그래도 안 되면 저장하지 않고 나갈 수 있습니다.
            </p>
          )}
        </Modal>
      )}
    </div>
  );
}
