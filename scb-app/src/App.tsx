import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, ArrowRight, Flame, Lock, LogIn, Plus, UserRound } from 'lucide-react';
import type { Identity, SessionData } from './types';
import { identityText, loadIdentity, saveIdentity } from './lib/identity';
import { addLog, createSession, generateCode, sessionExists, subscribeSession } from './lib/session';
import { createBuildingState } from './lib/building';
import { IdentityDialog } from './components/IdentityDialog';
import { BuildingForm } from './screens/BuildingForm';
import { Board } from './screens/Board';
import { SessionProvider, useToast } from './session-context';
import { usingEmulator } from './firebase';
import { GoogleLoginButton, useGoogleEmail } from './components/GoogleLoginButton';
import { loadSessionCache } from './lib/offline';

type Phase = { kind: 'home' } | { kind: 'setup' } | { kind: 'session'; code: string };

// 주소창에 ?s=코드 를 남겨서 새로고침해도 같은 세션으로 돌아온다
function codeFromUrl() {
  const c = new URLSearchParams(location.search).get('s');
  return c && /^[A-Z0-9]{6}$/.test(c.toUpperCase()) ? c.toUpperCase() : null;
}
function setUrlCode(code: string | null) {
  const u = new URL(location.href);
  if (code) u.searchParams.set('s', code);
  else u.searchParams.delete('s');
  history.replaceState(null, '', u);
}

export default function App() {
  const [me, setMeState] = useState<Identity | null>(loadIdentity);
  const [askId, setAskId] = useState<null | (() => void)>(null);
  const urlCode = codeFromUrl();
  const [phase, setPhase] = useState<Phase>(urlCode ? { kind: 'session', code: urlCode } : { kind: 'home' });

  const setMe = useCallback((v: Identity) => {
    saveIdentity(v);
    setMeState(v);
  }, []);

  // 세션에 들어가기 전에 항상 기록자 정보를 확인받는다
  const withIdentity = (next: () => void) => setAskId(() => next);

  const goHome = useCallback(() => {
    setUrlCode(null);
    setPhase({ kind: 'home' });
  }, []);

  let body;
  if (phase.kind === 'session' && me) {
    body = <SessionLoader code={phase.code} me={me} setMe={setMe} onLeave={goHome} />;
  } else if (phase.kind === 'session' && !me) {
    body = <IdentityDialog initial={null} onSave={setMe} />;
  } else if (phase.kind === 'setup') {
    body = (
      <NewSession
        onBack={goHome}
        onCreated={(code) => {
          setUrlCode(code);
          setPhase({ kind: 'session', code });
        }}
        me={me!}
      />
    );
  } else {
    body = (
      <Home
        me={me}
        onEditMe={() => withIdentity(() => {})}
        onNew={() => withIdentity(() => setPhase({ kind: 'setup' }))}
        onJoin={(code) =>
          withIdentity(() => {
            setUrlCode(code);
            setPhase({ kind: 'session', code });
          })
        }
      />
    );
  }

  return (
    <>
      {usingEmulator && <div className="emu-banner">개발용 · 로컬 에뮬레이터 데이터</div>}
      {body}
      {askId && (
        <IdentityDialog
          initial={me}
          onClose={() => setAskId(null)}
          onSave={(v) => {
            setMe(v);
            const next = askId;
            setAskId(null);
            next();
          }}
        />
      )}
    </>
  );
}

function Logo() {
  return (
    <div className="logo">
      <div className="logo-mark">
        <Flame size={34} strokeWidth={2.2} />
      </div>
      <div>
        <h1>SafeCheckBoard</h1>
        <p>현장안전보드 · 화재현장 확인 시스템</p>
      </div>
    </div>
  );
}

function Home(props: { me: Identity | null; onEditMe: () => void; onNew: () => void; onJoin: (code: string) => void }) {
  const [code, setCode] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const googleEmail = useGoogleEmail();

  const join = async () => {
    const c = code.trim().toUpperCase();
    if (c.length !== 6) return setErr('세션 코드는 6자리입니다');
    setBusy(true);
    setErr('');
    try {
      if (!(await sessionExists(c))) setErr(`세션을 찾을 수 없습니다: ${c}`);
      else props.onJoin(c);
    } catch (e) {
      setErr(`연결 오류: ${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="home">
      <Logo />
      {props.me && (
        <button className="me-chip big" onClick={props.onEditMe}>
          <UserRound size={18} /> {identityText(props.me)} <small>변경</small>
        </button>
      )}
      <div className="home-cards">
        <section className="card">
          <div className="card-icon">
            <Plus size={22} />
          </div>
          <h2>새 현장 시작</h2>
          {googleEmail ? (
            <>
              <p className="hint">새 세션을 만들고 6자리 코드를 받습니다. 코드를 공유하면 다른 사람도 같은 화면을 봅니다.</p>
              <button className="btn primary block" onClick={props.onNew}>
                새 세션 시작
              </button>
            </>
          ) : (
            <>
              <p className="hint">
                <Lock size={14} /> 새 현장은 <b>관리자(Google 로그인)</b>만 열 수 있습니다. 현장에 참여만 하는 분은 오른쪽에서 코드를 입력하세요.
              </p>
              {googleEmail === '' && <GoogleLoginButton className="btn primary block" label="관리자 로그인 후 새 현장 시작" />}
            </>
          )}
        </section>
        <section className="card">
          <div className="card-icon alt">
            <LogIn size={22} />
          </div>
          <h2>진행 중인 현장 참여</h2>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (!busy) join();
            }}
          >
            <input
              className="code-input"
              value={code}
              maxLength={6}
              placeholder="코드 6자리"
              autoCapitalize="characters"
              onChange={(e) => setCode(e.target.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase())}
            />
            {err && <p className="error">{err}</p>}
            <button className="btn block" disabled={busy}>
              {busy ? '연결 중…' : '참여하기'} {!busy && <ArrowRight size={18} />}
            </button>
          </form>
        </section>
      </div>
      {googleEmail && (
        <div className="home-admin">
          <GoogleLoginButton />
          <p className="hint">관리자로 로그인되어 있습니다. 다른 PC에서도 같은 계정으로 로그인하면 같은 관리 권한을 씁니다.</p>
        </div>
      )}
    </div>
  );
}

function NewSession(props: { me: Identity; onBack: () => void; onCreated: (code: string) => void }) {
  const toast = useToast();
  const [title, setTitle] = useState('');
  const [busy, setBusy] = useState(false);
  const googleEmail = useGoogleEmail();
  if (googleEmail === '')
    return (
      <div className="setup">
        <button className="btn ghost" onClick={props.onBack}>
          <ArrowLeft size={18} /> 처음으로
        </button>
        <section className="card">
          <h2>관리자 로그인이 필요합니다</h2>
          <p className="hint">새 현장은 관리자(Google 로그인)만 열 수 있습니다.</p>
          <GoogleLoginButton className="btn primary block" label="관리자 로그인 (Google)" />
        </section>
      </div>
    );
  return (
    <div className="setup">
      <button className="btn ghost" onClick={props.onBack}>
        <ArrowLeft size={18} /> 처음으로
      </button>
      <section className="card">
        <h2>새 현장 — 첫 건물 정보</h2>
        <BuildingForm
          submitLabel="현장 보드 시작"
          busy={busy}
          onSubmit={async (b) => {
            setBusy(true);
            try {
              const code = generateCode();
              await createSession(code, title.trim(), b, createBuildingState(b));
              await addLog(code, props.me, '세션', `세션 생성 — ${title.trim() || '현장'} / ${b.name}`);
              props.onCreated(code);
            } catch (e) {
              const denied = (e as { code?: string }).code === 'permission-denied';
              toast(denied ? '세션 생성 실패: 관리자(Google) 로그인이 필요합니다. 로그인 후 다시 시도하세요.' : `세션 생성 실패: ${(e as Error).message}`, 'error');
              setBusy(false);
            }
          }}
        >
          <label className="field">
            <span>현장명 (선택)</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="예) 마포구 ○○동 주상복합 화재" />
          </label>
        </BuildingForm>
      </section>
    </div>
  );
}

function SessionLoader(props: { code: string; me: Identity; setMe: (v: Identity) => void; onLeave: () => void }) {
  const { code, onLeave } = props;
  // 이 기기에 저장해 둔 마지막 화면이 있으면 먼저 보여 준다 (통신이 끊긴 채 새로고침해도 보이게).
  // 서버와 연결되면 바로 최신으로 바뀌고, 그 전까지는 권한 확인이 안 되어 읽기 전용이다.
  const [data, setData] = useState<SessionData | null | undefined>(() => loadSessionCache(code)?.value);
  const [err, setErr] = useState('');

  useEffect(() => {
    return subscribeSession(
      code,
      (d) => setData((prev) => (prev ? prev : d)),
      (e) => setErr(e.message),
    );
  }, [code]);

  // 입장 기록 (한 번만)
  useEffect(() => {
    if (data) addLog(code, props.me, '세션', '세션 입장').catch(() => {});
  }, [code, !!data]); // 처음 불러왔을 때 한 번만

  if (err && !data)
    return (
      <div className="center-msg">
        <p className="error">연결 오류: {err}</p>
        <button className="btn" onClick={onLeave}>
          처음으로
        </button>
      </div>
    );
  if (data === undefined) return <div className="center-msg">불러오는 중…</div>;
  if (data === null)
    return (
      <div className="center-msg">
        <p>세션 {code} 을(를) 찾을 수 없습니다.</p>
        <button className="btn" onClick={onLeave}>
          처음으로
        </button>
      </div>
    );
  if (data.buildings.length === 0)
    return (
      <div className="center-msg">
        <p>이전 현장에 저장된 건물 정보가 없습니다. 새 현장을 시작해 주세요.</p>
        <p className="code-big">{code}</p>
        <button className="btn" onClick={onLeave}>처음으로</button>
      </div>
    );

  return (
    <SessionProvider code={code} me={props.me} setMe={props.setMe} initial={data} onGone={onLeave}>
      <Board onLeave={onLeave} />
    </SessionProvider>
  );
}
