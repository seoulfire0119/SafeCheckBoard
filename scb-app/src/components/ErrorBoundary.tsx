import { Component, type ReactNode } from 'react';

/**
 * 한 화면(탭)에서 오류가 나도 앱 전체가 하얗게 멈추지 않게 그 화면만 막는다.
 * 다른 탭과 위쪽 띠(저장 상태·경보)는 계속 동작한다.
 */
export class ErrorBoundary extends Component<{ name: string; children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error) {
    console.error(`[${this.props.name}] 화면 오류`, error);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="center-msg error-box">
        <p className="error">「{this.props.name}」 화면에 오류가 났습니다.</p>
        <p className="hint">현장 데이터는 서버에 그대로 있습니다. 다시 불러와도 안 되면 새로고침(F5) 해 주세요.</p>
        <p className="hint">오류 내용: {this.state.error.message}</p>
        <div className="row-btns">
          <button className="btn primary" onClick={() => this.setState({ error: null })}>
            다시 불러오기
          </button>
          <button className="btn" onClick={() => location.reload()}>
            새로고침
          </button>
        </div>
      </div>
    );
  }
}
