# 현장안전보드 SafeCheckBoard — 웹앱 (v2)

Flutter 버전(`../safe_check_board`)을 React + Vite 웹앱으로 새로 만든 것.
태블릿(가로·세로)을 기준으로, 휴대폰·PC 브라우저에서도 그대로 쓴다.
Firebase 프로젝트 `safecheckboard`(Firestore + Hosting)를 그대로 쓴다.

## 화면

| 화면 | 내용 |
| --- | --- |
| 처음 | 새 세션 시작 / 코드로 참여. 들어가기 전에 **기록자 정보(기관·소속·담당)** 를 고른다 (버튼 선택 또는 직접 입력, 기기에 기억) |
| 현황판 | 건물 그리드(호실 상태·메모·피난약자·화점), 인명현황 전광판, 오른쪽 패널(선택·상태 / 진입대 / 채팅) |
| 진압작전도 | 도면·지도 캡처를 배경으로 올리고 표시물 배치. **✨ 자동 배치**: 현황판의 건물·화점·진입대 위치대로 놓음. 진입경로·수관 그리기, 확대/이동, 인쇄 |
| 인명피해 | 중증도 분류(지연·긴급·응급·비응급) 표, 성명 가림, 복사·인쇄·CSV |
| 보고서 | 재난발생현황 / 시간대별 조치 / 유관기관 활동 / 브리핑(초동·중간·공식, 자동 채우기, 게시판 저장) |
| 📋 기록 | 모든 활동 기록 + 채팅을 시간순으로. 분류·기관·검색 필터, **엑셀(CSV)·인쇄·복사** |

## 데이터 (Firestore)

- `sessions/{코드}` — Flutter 버전과 같은 키(buildings, states, personnelStats, incident, disasterResponse, casualty) +
  새 키 `title`, `teams`(진입대), `timerSettings`, `fireOrigin`(화점)
- `sessions/{코드}/logs` — 활동 기록 (누가·언제·무엇을). 쌓기만 하고 수정·삭제 불가
- `sessions/{코드}/chat` — 채팅 (보낸이 = "기관 소속 담당")
- `sessions/{코드}/secondary/map` — 진압작전도 (배경 이미지는 줄여서 문서 안에 저장)
- `sessions/{코드}/briefings` — 브리핑 게시판
- 여러 사람이 동시에 고쳐도 덮어쓰지 않도록 현황판 변경은 트랜잭션으로 저장한다 (`src/lib/session.ts` `mutateSession`)

## 개발

다른 PC에서 이어서 개발할 때는 저장소의 **main 브랜치**를 받으세요. `github-old-backup`은 2026년 4월의 옛 Flutter 백업입니다. 최신 앱의 원본은 이 폴더의 `src/`이며, `dist/`는 빌드할 때 생성됩니다. 기존 복제본은 미저장 작업을 보관한 뒤 `git fetch origin`, `git switch main`, `git pull --ff-only origin main`으로 갱신합니다.

새 PC에서는 이 폴더에서 `npm ci`, `npm run dev`를 실행합니다. GitHub Actions 빌드 파일도 추가되어 있으며, main에 올린 뒤 성공한 **Actions → SafeCheckBoard web build → Artifacts**에서 웹 빌드 ZIP을 받을 수 있습니다. 이 ZIP은 HTTP 서버 또는 Firebase Hosting에서 제공해야 하며 index.html을 파일로 더블클릭하는 방식은 지원하지 않습니다.

새 현장(세션)은 **Google 계정으로 로그인한 관리자만** 만들 수 있습니다 (앱 화면과 Firestore 규칙 모두에서 막음). 참여자는 로그인 없이 코드로 들어오며 열람자로 시작하고, 개설자가 편집 권한을 부여합니다. 같은 Google 계정으로 로그인하면 다른 PC에서도 같은 관리 권한을 씁니다.

작전도 표시물·선은 `sessions/{코드}/mapObjects/{id}`에 하나씩 저장하며, 놓은 사람(by)과 관리자만 고치고 지울 수 있습니다. 도면 사진은 `secondary/mapBg`에 따로 저장합니다. 예전 현장의 작전도는 관리자가 열 때 자동으로 옮겨집니다. 기존 현장은 Google 계정 `119gpt1@gmail.com`으로 로그인하면 관리할 수 있습니다. [운영 권한 이전 안내](docs/운영-권한-이전.md)에 이전 방법과 주의사항이 있습니다.

```bash
npm ci                            # Firebase 웹 설정은 .env 에 들어 있음
npm run dev                       # http://localhost:5173
```

실제 현장 데이터를 건드리지 않고 시험하려면 로컬 인증·Firestore 에뮬레이터를 쓴다 (Java 21 필요):

```bash
echo VITE_USE_EMULATOR=1 > .env.development.local
npm run emulators                 # demo-safecheckboard, 운영 데이터와 분리
npm run dev                       # 화면 왼쪽 아래에 "개발용 · 로컬 에뮬레이터" 표시
```

`npm run build` 결과물(`dist/`)은 항상 실제 Firebase 에 연결된다 (에뮬레이터 설정은 개발 모드에서만 읽힘).

## 배포

**이번 버전은 배포 전에 [인증 활성화·기존 세션 이전](docs/운영-권한-이전.md)이 필수입니다.** 이전 완료 후 Windows 명령 프롬프트에서 `set SCB_ACCESS_MIGRATED=1`을 지정해야 deploy.bat을 실행할 수 있습니다. 단순 미리보기 배포도 같은 운영 Firestore에 연결되므로 개발 검증에는 에뮬레이터를 사용하세요.

`deploy.bat` — 빌드 → 인증 설정 → Firestore 규칙·Hosting을 올린다.
**주의:** Flutter 버전(`../safe_check_board/deploy.bat`)과 같은 사이트(safecheckboard.web.app)를 쓴다.
나중에 올린 쪽이 화면에 나온다.

미리보기 주소로만 올려 보려면:

```bash
npm run build
firebase hosting:channel:deploy beta --expires 7d
```
