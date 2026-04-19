# SafeCheckBoard (SCB) — 바이브코딩 레퍼런스

화재현장 인명·구역 확인 보드 시스템. 소방관이 실시간으로 건물 세대 현황을 파악하고 팀 진입 시간을 관리하는 Flutter Web 앱.

---

## 빌드 & 실행

```bat
cd safe_check_board
C:\Users\user\.puro\flutter_direct.bat build web --release
cd build\web
C:\Users\user\AppData\Local\Pub\Cache\bin\dhttpd.bat --host localhost --port 8080
```

> `flutter run -d chrome` 은 **사용 불가** (Puro 버그). 반드시 `build web` 사용.
> 브라우저: http://localhost:8080

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| 프레임워크 | Flutter (Web) |
| 언어 | Dart |
| 백엔드 | Firebase Firestore (Seoul, 프로젝트명: `safecheckboard`) |
| 상태관리 | StatefulWidget + setState (별도 상태관리 라이브러리 없음, 단순 구조 유지) |
| 패키지 | `firebase_core ^3.10.0`, `cloud_firestore ^5.6.0` |

---

## 디렉토리 구조

```
safe_check_board/lib/
├── main.dart                        # Firebase 초기화, MaterialApp
├── firebase_options.dart            # Firebase 설정
├── constants/
│   └── status.dart                  # UnitStatus enum + extension
├── models/
│   ├── unit.dart                    # 세대(호실) 모델
│   ├── building.dart                # 건물 구조 모델
│   ├── building_state.dart          # 건물 런타임 상태
│   ├── personnel_stats.dart         # 인명현황 카운터
│   ├── log_entry.dart               # 상태 변경 로그
│   └── team_entry.dart              # 진입 타이머 팀 항목
├── services/
│   └── firebase_service.dart        # Firestore CRUD + 스트림
├── screens/
│   ├── session_screen.dart          # 홈 화면 (새 세션 / 세션 참여)
│   ├── building_setup_screen.dart   # 건물 설정 화면
│   └── dashboard_screen.dart        # 메인 대시보드
└── widgets/
    ├── grid/
    │   ├── building_grid.dart       # 건물 그리드 전체
    │   ├── floor_row.dart           # 층별 행 + 숨긴 층 배지
    │   └── unit_cell.dart           # 세대 셀 + 빈 셀(점선)
    ├── panel/
    │   ├── action_panel.dart        # 우측 액션 패널 (상태 변경, 메모 등)
    │   ├── status_buttons.dart      # 상태 버튼 3열 그리드
    │   └── activity_log.dart        # 활동 로그 리스트
    └── timer/
        └── entry_timer_panel.dart   # 진입 타이머 탭
```

---

## 데이터 모델

### UnitStatus (lib/constants/status.dart)

6가지 상태. **enum 값 추가/삭제 시 Firestore 직렬화(`status.name`)도 함께 고려.**

| enum 값 | 한국어 | 배경색 | 글자색 |
|---------|--------|--------|--------|
| `unknown` | 미확인 | 회색 `#9E9E9E` | 검정 |
| `empty` | 공실 | 하늘색 `#90CAF9` | 검정 |
| `confirmed` | 확인완료 | 초록 `#66BB6A` | 흰색 |
| `danger` | 화재층 | 빨강 `#EF5350` | 흰색 |
| `fireFalseAlarm` | 연소확대층 | 주황 `#FFA726` | 흰색 |
| `resourceBase` | 자원대기소 | 보라 `#AB47BC` | 흰색 |

익스텐션 제공 속성: `.label`(한글 이름), `.color`(배경색), `.textColor`(글자색), `.icon`(아이콘)

### Unit (lib/models/unit.dart)

```dart
Unit {
  String id;        // "${floor}-${unitIndex}" (예: "3-2")
  int floor;        // 양수=지상, 음수=지하 (0층 없음)
  int unitIndex;    // 1-based, 층 내 순서
  int number;       // 표시 번호 (지상: floor*100+unitIndex, 지하: -(abs*100+unitIndex))
  UnitStatus status;
  String memo;
  bool memoPinned;
  bool vulnerable;  // 요구조자/노약자 표시
  int spanCount;    // 병합 칸 수 (기본 1)
}
```

- `displayNumber`: "301호", "B101호" 형식
- `fullName`: "3층 301호" 형식
- `Unit.makeId(floor, unitIndex)` → id 생성

### Building (lib/models/building.dart)

```dart
Building {
  String name;
  int startFloor;      // 시작 층 (지하면 음수, 예: -2)
  int endFloor;        // 최상층
  int defaultUnits;    // 층당 세대/구획 수
  bool isHorizontal;   // 가로형(시장·의료) vs 세로형(아파트·빌딩)
}
```

- `floors`: 유효 층 목록 (0층 제외, 세로형은 옥상층(endFloor+1) 포함)
- `floorsDescending`: 위→아래 정렬 (그리드 표시 순서)
- `rooftopFloor`: 세로형만, `endFloor + 1`

### BuildingState (lib/models/building_state.dart)

```dart
BuildingState {
  List<Unit> units;
  Set<int> hiddenFloors;
  Map<int, String> floorLabels;  // floor → 커스텀 레이블
}
```

- `BuildingState.create(building)`: 건물 구조로 초기 유닛 생성, 옥상층 레이블 자동 설정
- `findUnit(floor, unitIndex)`: id로 유닛 검색
- `unitsOnFloor(floor)`: 특정 층의 유닛 목록 (unitIndex 정렬)

### PersonnelStats (lib/models/personnel_stats.dart)

```dart
PersonnelStats {
  int selfEvac;   // 자력대피
  int rescued;    // 구조완료
  int notFound;   // 미발견
}
```

### LogEntry (lib/models/log_entry.dart)

```dart
LogEntry {
  int id;
  String unitName;   // unit.fullName
  UnitStatus from;
  UnitStatus to;
  DateTime time;
}
```

### TeamEntry (lib/models/team_entry.dart)

```dart
TeamEntry {
  String id;
  String name;          // 예: "1착대"
  String? unit;         // 단대명 (예: "신수대")
  String? note;         // 활동구역/비고
  TeamStatus status;    // waiting/active/warning/danger/paused
  DateTime? entryTime;
  Duration? pausedElapsed;
}
```

팀 상태값: `waiting`(대기), `active`(진입중), `warning`(경고), `danger`(위험), `paused`(일시정지)

---

## 화면 흐름

```
SessionScreen (홈)
  ├─ 새 세션 시작 → Firebase 세션 생성(6자리 코드) → BuildingSetupScreen → DashboardScreen
  └─ 세션 참여 → 코드 입력 → (건물 있음) DashboardScreen
                            → (건물 없음) _WaitingScreen → DashboardScreen
```

- `DashboardScreen`의 뒤로가기 → `SessionScreen` (BuildingSetupScreen 아님)
- 로컬 모드: `sessionCode == null`일 때 Firebase 저장 없이 동작

---

## 핵심 패턴

### Firebase 세션 동기화

```dart
// 실시간 스트림 (hasPendingWrites 필터로 서버 확정 데이터만 수신)
FirebaseService.instance.sessionStream(code).listen(_applyRemoteData);

// 디바운스 저장 (상태 변경 후 1.5초)
_saveDebounce = Timer(const Duration(milliseconds: 1500), () {
  FirebaseService.instance.saveSession(...);
});
```

### 반응형 레이아웃

```dart
final isWide = MediaQuery.of(context).size.width > 800;
// Wide: 우측 300px 고정 패널
// Narrow: 탭 시 모달 바텀시트
```

### 빈 셀 활성화 (pendingEmpty 패턴)

빈 위치 탭 → `_pendingEmpty` 설정 → 확인 다이얼로그 → `_activateUnit()` 호출

### 유닛 병합/분리

- 병합: 오른쪽 빈 슬롯을 흡수, `spanCount += 1`
- 분리: `spanCount -= 1`, 해방된 index에 새 Unit 추가

### 세션 코드 생성

```dart
const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// 0/O/1/I 혼동 문자 제외, 6자리
```

---

## DashboardScreen 상태

| 변수 | 설명 |
|------|------|
| `_buildings` | 건물 목록 (최대 3개) |
| `_buildingStates` | 건물별 유닛 상태 |
| `_personnelStats` | 건물별 인명현황 |
| `_activeBuildingIdx` | 현재 선택된 건물 인덱스 |
| `_selectedId` | 선택된 유닛 id |
| `_selectedFloors` | 선택된 층 집합 |
| `_log` | 상태 변경 로그 (최대 200개 Firestore 저장) |
| `_currentTab` | 0=건물현황, 1=진입타이머 |

---

## Firebase 데이터 구조 (Firestore)

```
sessions/{code}
  createdAt: Timestamp
  updatedAt: Timestamp
  buildings: [ { name, startFloor, endFloor, defaultUnits, isHorizontal } ]
  states: [
    {
      units: [ { id, floor, unitIndex, number, status(name), memo, memoPinned, vulnerable, spanCount } ],
      hiddenFloors: [int, ...],
      floorLabels: { "floor": "label", ... }
    }
  ]
  personnelStats: [ { selfEvac, rescued, notFound } ]
  log: [ { id, unitName, from(name), to(name), time(ms) } ]
```

---

## 진입 타이머 (EntryTimerPanel)

- 기본 팀: 1착대, 2착대, 3착대 (최대 7팀)
- 경고 기준: 기본 15분 / 위험: 기본 20분 (설정 변경 가능)
- 위험 상태 변경 시 + 경고/위험 상태 30초마다 AudioContext 소리 알림 (Web only)
- `dart:js` 사용으로 Web 전용 (`// ignore: avoid_web_libraries_in_flutter`)

---

## 주요 UI 색상

| 용도 | 색상 |
|------|------|
| 앱바 / 강조색 | `Color(0xFFBF360C)` 딥오렌지 어두운 계열 |
| 전체 배경 | `Color(0xFFFFF3E0)` 연한 주황 |
| 인명현황 보드 배경 | `Color(0xFF0D0D0D)` 거의 검정 |
| 인명현황 테두리 | `Colors.yellow.shade700` 노랑 |
| 진입타이머 상단바 | `Color(0xFF1A237E)` 남색 계열 |

---

## 주의사항 & 제약

1. **건물 최대 3개** — `_buildings.length < 3` 체크
2. **로그 최대 200개** — `saveSession`에서 `take(200)` 처리
3. **옥상층** — 세로형 건물만 자동 생성, `endFloor + 1`
4. **0층 없음** — `Building.floors`에서 `i != 0` 필터
5. **지하층 번호** — `floor=-1, unitIndex=1` → `number=-101`, display `B101호`
6. **spanCount** — 병합 시 오른쪽 Unit 삭제 (unitIndex+spanCount 위치)
7. **Web 전용 API** — `entry_timer_panel.dart`의 `dart:js` AudioContext는 Web에서만 동작
8. **Puro 환경** — `flutter_direct.bat` 사용 필수
