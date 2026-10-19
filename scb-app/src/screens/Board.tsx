import { useState } from 'react';
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

type View = 'status' | 'map' | 'casualty' | 'reports';
const VIEWS: { key: View; label: string; icon: string }[] = [
  { key: 'status', label: '현황판', icon: '🏢' },
  { key: 'map', label: '진압작전도', icon: '🗺️' },
  { key: 'casualty', label: '인명피해', icon: '🚑' },
  { key: 'reports', label: '보고서', icon: '📄' },
];

export function Board({ onLeave }: { onLeave: () => void }) {
  const { code, me, setMe, data, logs, toast, log } = useSession();
  const [view, setView] = useState<View>(() => (sessionStorage.getItem('scb.view') as View) || 'status');
  const [dialog, setDialog] = useState<null | 'me' | 'log' | 'code' | 'leave'>(null);

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
  })).filter((x) => x.n > 0 && x.s !== 'unknown');

  return (
    <div className="board">
      <TeamAlarm />
      <header className="topbar">
        <button className="title" onClick={() => setDialog('code')} title="세션 코드 보기">
          <span className="code-tag">{code}</span>
          <span className="site">{data.title || 'SafeCheckBoard'}</span>
        </button>
        <nav className="tabs" aria-label="화면 전환">
          {VIEWS.map((v) => (
            <button key={v.key} className={view === v.key ? 'on' : ''} onClick={() => pick(v.key)}>
              <span aria-hidden>{v.icon}</span> {v.label}
            </button>
          ))}
        </nav>
        <div className="top-right">
          <div className="status-chips">
            {data.fireOrigin && <span className="schip fire">🔥 화점</span>}
            {counts.map(({ s, n }) => (
              <span key={s} className="schip" style={{ background: STATUS[s].color }}>
                {STATUS[s].label} {n}
              </span>
            ))}
          </div>
          <button className="me-chip" onClick={() => setDialog('me')} title="기록자 정보 변경">
            👤 <span>{identityText(me)}</span>
          </button>
          <button className="btn small" onClick={() => setDialog('log')}>
            📋 기록 <b>{logs.length}</b>
          </button>
          <button className="icon-btn light" onClick={() => setDialog('leave')} aria-label="나가기" title="세션 나가기">
            ⎋
          </button>
        </div>
      </header>

      <main className="view">
        {view === 'status' && <StatusView />}
        {view === 'map' && <MapView />}
        {view === 'casualty' && <CasualtyView />}
        {view === 'reports' && <ReportsView />}
      </main>

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
          <p className="hint">아래 코드를 다른 사람에게 알려주세요. 처음 화면에서 코드를 입력하면 같은 보드를 봅니다.</p>
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
              <button className="btn primary" onClick={onLeave}>
                나가기
              </button>
            </>
          }
        >
          <p>처음 화면으로 돌아갑니다. 현장 데이터는 그대로 남아 있어서 코드 <b>{code}</b> 로 다시 들어올 수 있습니다.</p>
        </Modal>
      )}
    </div>
  );
}
