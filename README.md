# 현장안전보드 SafeCheckBoard

현재 개발하는 앱은 **main 브랜치의 [scb-app](scb-app/README.md)** 입니다. 건물·호실 상태, 진입대 체류 시간, 진압작전도, 인명피해, 보고서와 활동 기록을 관리하는 React + Vite 웹앱입니다.

| 위치 | 용도 |
|---|---|
| `scb-app/` | 현재 React 앱의 원본 소스·설정·실행 안내 |
| `safe_check_board/` | 이전 Flutter 앱. 현재 웹앱을 수정할 때 사용하는 폴더가 아닙니다. |
| `scb-web/` | 초기 React 실험 버전 |
| `github-old-backup` 브랜치 | 2026년 4월까지의 옛 백업. 최신 코드는 main에 있습니다. |

## 다른 PC에서 개발

```powershell
git clone https://github.com/seoulfire0119/SafeCheckBoard.git
cd SafeCheckBoard/scb-app
npm ci
npm run dev
```

이미 받은 복제본은 먼저 `git status`로 미저장 변경을 확인하고 보관한 다음 업데이트합니다.

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
cd scb-app
npm ci
npm run dev
```

작업을 마친 PC에서는 변경을 커밋한 후 main에 push해야 다른 PC에서 받을 수 있습니다. 비밀번호·서버 비밀키는 커밋하지 않습니다.

## 실행 결과물

`scb-app/dist/`는 `npm run build`로 생성되며 Git에서는 제외합니다. HTML 파일 한 개를 더블클릭하는 방식이 아닌, HTTP 서버 또는 Firebase Hosting으로 실행하는 웹앱입니다. 개발 소스가 없는 것은 아닙니다.

자동 빌드 workflow를 main에 올린 뒤에는 GitHub **Actions → SafeCheckBoard web build → 성공한 실행 → Artifacts**에서 빌드 ZIP을 받을 수 있습니다. 산출물 보관 기간은 30일입니다. 별도 GitHub Release에 자동 게시하거나 운영 사이트에 자동 배포하지는 않습니다.

## 권한 기능 적용

새 권한 기능은 개설자·입력자·열람자를 구분합니다. 운영 적용 전 **[인증 활성화와 기존 세션 이전](scb-app/docs/운영-권한-이전.md)** 이 필수입니다. 서버 설정을 준비하지 않은 상태에서 구버전의 운영 규칙을 교체하면 기존 현장에 접근할 수 없습니다.

로컬 검증, 빌드, 배포의 자세한 방법은 [scb-app 안내](scb-app/README.md)를 참고하세요.
