import { useEffect, useRef, useState } from 'react';
import { MessageSquare, Send } from 'lucide-react';
import { useSession } from '../session-context';
import { chatSender } from '../lib/identity';
import { sendChat } from '../lib/session';
import { hhmm } from '../lib/format';

export function ChatPanel({ onSeen }: { onSeen: () => void }) {
  const { code, me, chat, toast } = useSession();
  const [text, setText] = useState('');
  const endRef = useRef<HTMLDivElement>(null);
  const mine = chatSender(me);

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: 'end' });
    onSeen();
  }, [chat.length, onSeen]);

  const send = async () => {
    const t = text.trim();
    if (!t) return;
    setText('');
    try {
      await sendChat(code, me, t);
    } catch (e) {
      toast(`전송 실패: ${(e as Error).message}`, 'error');
      setText(t);
    }
  };

  return (
    <div className="chat">
      <div className="chat-list">
        {chat.length === 0 && (
          <div className="empty-state">
            <MessageSquare size={26} />
            <p className="hint">메시지가 없습니다</p>
          </div>
        )}
        {chat.map((m) => (
          <div key={m.id} className={`bubble ${m.sender === mine ? 'me' : ''}`}>
            <div className="bmeta">
              <b>{m.sender}</b> <time>{hhmm(m.at)}</time>
            </div>
            <div className="btext">{m.text}</div>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      <form
        className="chat-input"
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
      >
        <input value={text} maxLength={500} placeholder="메시지 입력…" onChange={(e) => setText(e.target.value)} />
        <button className="btn primary icon-only" disabled={!text.trim()} aria-label="전송">
          <Send size={18} />
        </button>
      </form>
    </div>
  );
}
