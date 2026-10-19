import { useCallback, useState } from 'react';
import { useSession } from '../session-context';
import { BuildingCard, type Selection } from '../components/BuildingCard';
import { ActionPanel } from '../components/ActionPanel';
import { TeamsPanel } from '../components/TeamsPanel';
import { ChatPanel } from '../components/ChatPanel';
import { Modal } from '../components/Modal';
import { BuildingForm } from '../screens/BuildingForm';
import { createBuildingState } from '../lib/building';

type Tab = 'select' | 'teams' | 'chat';

export function StatusView() {
  const { data, act, chat } = useSession();
  const [sel, setSel] = useState<Selection | null>(null);
  const [tab, setTab] = useState<Tab>('select');
  const [adding, setAdding] = useState(false);
  const [seenChat, setSeenChat] = useState(chat.length);
  const unread = tab === 'chat' ? 0 : Math.max(0, chat.length - seenChat);
  const markSeen = useCallback(() => setSeenChat(chat.length), [chat.length]);

  const select = (s: Selection | null) => {
    setSel(s);
    if (s) setTab('select');
  };

  return (
    <div className="status-view">
      <div className="buildings">
        {data.buildings.map((b, i) => (
          <BuildingCard
            key={i}
            idx={i}
            building={b}
            selection={sel?.b === i ? sel : null}
            onSelect={select}
            canAdd={i === data.buildings.length - 1 && data.buildings.length < 3}
            onAdd={() => setAdding(true)}
          />
        ))}
      </div>

      <aside className="side">
        <div className="side-tabs" role="tablist">
          <button className={tab === 'select' ? 'on' : ''} onClick={() => setTab('select')}>
            선택·상태
          </button>
          <button className={tab === 'teams' ? 'on' : ''} onClick={() => setTab('teams')}>
            진입대 <b className="cnt">{data.teams.filter((t) => t.status !== 'waiting').length}</b>
          </button>
          <button
            className={tab === 'chat' ? 'on' : ''}
            onClick={() => {
              setTab('chat');
              setSeenChat(chat.length);
            }}
          >
            채팅 {unread > 0 && <b className="badge">{unread}</b>}
          </button>
        </div>
        <div className="side-body">
          {tab === 'select' && <ActionPanel sel={sel} onClear={() => setSel(null)} onSelect={select} />}
          {tab === 'teams' && <TeamsPanel />}
          {tab === 'chat' && <ChatPanel onSeen={markSeen} />}
        </div>
      </aside>

      {adding && (
        <Modal title="건물 추가" onClose={() => setAdding(false)}>
          <BuildingForm
            submitLabel="건물 추가"
            onSubmit={(b) => {
              setAdding(false);
              act(
                (d) => {
                  if (d.buildings.length >= 3) return;
                  d.buildings.push(b);
                  d.states.push(createBuildingState(b));
                  d.personnelStats.push({ selfEvac: 0, rescued: 0, notFound: 0 });
                },
                '건물',
                b.isHorizontal && b.endFloor < 0
                  ? `건물 추가: ${b.name} (지하주차장 B1~B${-b.startFloor}, ${b.defaultUnits}구역)`
                  : `건물 추가: ${b.name} (${b.startFloor}~${b.endFloor}${b.isHorizontal ? '구역' : '층'}, ${b.defaultUnits}칸)`,
              );
            }}
          />
        </Modal>
      )}
    </div>
  );
}
