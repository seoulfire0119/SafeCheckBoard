import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/status.dart';
import '../models/building.dart';
import '../models/building_state.dart';
import '../models/unit.dart';
import '../models/personnel_stats.dart';
import '../models/log_entry.dart';
import '../services/firebase_service.dart';
import '../widgets/grid/building_grid.dart';
import '../widgets/panel/action_panel.dart';
import '../widgets/timer/entry_timer_panel.dart';
import 'building_setup_screen.dart';
import 'session_screen.dart';
import 'operation_map_screen.dart';
import 'disaster_briefing_screen.dart';
import 'briefing_board_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? sessionCode;       // Firebase 세션 코드 (없으면 로컬 모드)
  final Building? initialBuilding; // 새 세션 시작 시
  final BuildingState? initialState;
  final SessionData? sessionData;  // 기존 세션 참여 시

  const DashboardScreen({
    super.key,
    this.sessionCode,
    this.initialBuilding,
    this.initialState,
    this.sessionData,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final List<Building> _buildings;
  late final List<BuildingState> _buildingStates;
  late final List<PersonnelStats> _personnelStats;

  int? _activeBuildingIdx;
  String? _selectedId;
  Set<int> _selectedFloors = {};

  List<LogEntry> _log = [];
  int _logIdCounter = 0;

  Map<String, int>? _pendingEmpty;

  // 탭 (0=건물현황, 1=진입타이머)
  int _currentTab = 0;

  // Firebase
  StreamSubscription<SessionData?>? _firestoreSub;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.sessionData != null) {
      final d = widget.sessionData!;
      _buildings = List.from(d.buildings);
      _buildingStates = List.from(d.states);
      _personnelStats = List.from(d.personnelStats);
      _log = List.from(d.log);
      if (_log.isNotEmpty) {
        _logIdCounter = _log.map((e) => e.id).reduce(max);
      }
    } else {
      _buildings = widget.initialBuilding != null ? [widget.initialBuilding!] : [];
      _buildingStates = widget.initialState != null ? [widget.initialState!] : [];
      _personnelStats = _buildings.map((_) => PersonnelStats()).toList();
    }

    if (widget.sessionCode != null) {
      _firestoreSub = FirebaseService.instance
          .sessionStream(widget.sessionCode!)
          .listen(_applyRemoteData);
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── Firebase 원격 업데이트 수신 ────────────────────────────────
  void _applyRemoteData(SessionData? data) {
    if (data == null || !mounted) return;
    setState(() {
      // 건물 목록 교체
      _buildings
        ..clear()
        ..addAll(data.buildings);
      _buildingStates
        ..clear()
        ..addAll(data.states);
      _personnelStats
        ..clear()
        ..addAll(data.personnelStats);
      _log = List.from(data.log);
      if (_log.isNotEmpty) {
        _logIdCounter = _log.map((e) => e.id).reduce(max);
      }
      // 선택 해제 (unit이 삭제됐을 수 있음)
      if (_selectedUnit == null) _selectedId = null;
    });
  }

  // ── 변경 후 Firebase 저장 (1.5초 디바운스) ────────────────────
  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      FirebaseService.instance.saveSession(
        code: widget.sessionCode!,
        buildings: _buildings,
        states: _buildingStates,
        personnelStats: _personnelStats,
        log: _log,
      );
    });
  }

  // ──────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────

  int get _totalUnits =>
      _buildingStates.fold(0, (sum, s) => sum + s.units.length);

  Unit? get _selectedUnit {
    if (_activeBuildingIdx == null || _selectedId == null) return null;
    final state = _buildingStates[_activeBuildingIdx!];
    try {
      return state.units.firstWhere((u) => u.id == _selectedId);
    } catch (_) {
      return null;
    }
  }

  List<Unit>? get _selectedFloorUnits {
    if (_activeBuildingIdx == null || _selectedFloors.isEmpty) return null;
    if (_selectedFloors.length != 1) return null;
    final floor = _selectedFloors.first;
    return _buildingStates[_activeBuildingIdx!].unitsOnFloor(floor);
  }

  int? get _selectedFloor =>
      _selectedFloors.length == 1 ? _selectedFloors.first : null;

  bool get _isSelectedFloorHidden {
    if (_activeBuildingIdx == null || _selectedFloor == null) return false;
    return _buildingStates[_activeBuildingIdx!]
        .hiddenFloors
        .contains(_selectedFloor);
  }

  // ──────────────────────────────────────────────
  // Selection handlers
  // ──────────────────────────────────────────────

  void _onUnitTap(int buildingIdx, Unit unit) {
    setState(() {
      _activeBuildingIdx = buildingIdx;
      _selectedId = unit.id;
      _selectedFloors = {};
    });
    if (MediaQuery.of(context).size.width <= 800) {
      _showBottomPanel();
    }
  }

  void _onFloorAllTap(int buildingIdx, int floor) {
    setState(() {
      _activeBuildingIdx = buildingIdx;
      _selectedId = null;
      if (_selectedFloors.contains(floor) &&
          _activeBuildingIdx == buildingIdx) {
        _selectedFloors.remove(floor);
      } else {
        _selectedFloors = {floor};
      }
    });
    if (MediaQuery.of(context).size.width <= 800 &&
        _selectedFloors.isNotEmpty) {
      _showBottomPanel();
    }
  }

  void _onEmptyCellTap(int buildingIdx, int floor, int unitIndex) {
    setState(() {
      _activeBuildingIdx = buildingIdx;
      _pendingEmpty = {
        'buildingIdx': buildingIdx,
        'floor': floor,
        'unitIndex': unitIndex,
      };
    });
    _showActivateDialog(buildingIdx, floor, unitIndex);
  }

  // ──────────────────────────────────────────────
  // State mutation
  // ──────────────────────────────────────────────

  void _onStatusChanged(UnitStatus newStatus) {
    if (_activeBuildingIdx == null) return;
    final state = _buildingStates[_activeBuildingIdx!];

    setState(() {
      if (_selectedFloors.isNotEmpty && _selectedId == null) {
        for (final floor in _selectedFloors) {
          for (final unit in state.unitsOnFloor(floor)) {
            if (unit.status != newStatus) {
              _addLog(unit, unit.status, newStatus);
              unit.status = newStatus;
            }
          }
        }
      } else if (_selectedId != null) {
        final unit = _selectedUnit;
        if (unit != null && unit.status != newStatus) {
          _addLog(unit, unit.status, newStatus);
          unit.status = newStatus;
        }
      }
    });
    _scheduleSave();
  }

  void _onMemoChanged(String memo) {
    _selectedUnit?.memo = memo;
    _scheduleSave();
  }

  void _onMemoPinToggle() {
    if (_selectedUnit == null) return;
    setState(() => _selectedUnit!.memoPinned = !_selectedUnit!.memoPinned);
    _scheduleSave();
  }

  void _onVulnerableToggle() {
    if (_selectedUnit == null) return;
    setState(() => _selectedUnit!.vulnerable = !_selectedUnit!.vulnerable);
    _scheduleSave();
  }

  void _onDeactivateUnit() {
    if (_activeBuildingIdx == null || _selectedId == null) return;
    final state = _buildingStates[_activeBuildingIdx!];
    setState(() {
      state.units.removeWhere((u) => u.id == _selectedId);
      _selectedId = null;
    });
    _scheduleSave();
  }

  // ── 병합/분리 ──────────────────────────────────

  bool get _canMergeRight {
    final unit = _selectedUnit;
    if (unit == null || _activeBuildingIdx == null) return false;
    final building = _buildings[_activeBuildingIdx!];
    return unit.unitIndex + unit.spanCount <= building.defaultUnits;
  }

  bool get _canSplit {
    return (_selectedUnit?.spanCount ?? 1) > 1;
  }

  void _onMergeRight() {
    final unit = _selectedUnit;
    if (unit == null || _activeBuildingIdx == null) return;
    final state = _buildingStates[_activeBuildingIdx!];
    final nextIndex = unit.unitIndex + unit.spanCount;
    setState(() {
      state.units.removeWhere(
          (u) => u.floor == unit.floor && u.unitIndex == nextIndex);
      unit.spanCount += 1;
    });
    _scheduleSave();
  }

  void _onSplitUnit() {
    final unit = _selectedUnit;
    if (unit == null || _activeBuildingIdx == null) return;
    final state = _buildingStates[_activeBuildingIdx!];
    setState(() {
      final freedIndex = unit.unitIndex + unit.spanCount - 1;
      unit.spanCount -= 1;
      final id = Unit.makeId(unit.floor, freedIndex);
      final int number = unit.floor > 0
          ? unit.floor * 100 + freedIndex
          : -(unit.floor.abs() * 100 + freedIndex);
      state.units.add(Unit(
          id: id, floor: unit.floor, unitIndex: freedIndex, number: number));
    });
    _scheduleSave();
  }

  void _onHideFloor() {
    if (_activeBuildingIdx == null || _selectedFloor == null) return;
    final state = _buildingStates[_activeBuildingIdx!];
    setState(() {
      final floor = _selectedFloor!;
      if (state.hiddenFloors.contains(floor)) {
        state.hiddenFloors.remove(floor);
      } else {
        state.hiddenFloors.add(floor);
        _selectedFloors.remove(floor);
      }
    });
    _scheduleSave();
  }

  void _onShowHiddenFloors(int buildingIdx, List<int> floors) {
    setState(() {
      for (final f in floors) {
        _buildingStates[buildingIdx].hiddenFloors.remove(f);
      }
    });
    _scheduleSave();
  }

  void _onFloorLabelChanged(int buildingIdx, int floor, String label) {
    setState(() {
      if (label.isEmpty) {
        _buildingStates[buildingIdx].floorLabels.remove(floor);
      } else {
        _buildingStates[buildingIdx].floorLabels[floor] = label;
      }
    });
    _scheduleSave();
  }

  void _addBuilding(Building building, BuildingState state) {
    setState(() {
      _buildings.add(building);
      _buildingStates.add(state);
      _personnelStats.add(PersonnelStats());
    });
    Navigator.of(context).pop();
    _scheduleSave();
  }

  void _removeBuilding(int idx) {
    if (_buildings.length <= 1) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('건물 제거'),
        content: Text('${_buildings[idx].name}을 제거하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              setState(() {
                _buildings.removeAt(idx);
                _buildingStates.removeAt(idx);
                _personnelStats.removeAt(idx);
                if (_activeBuildingIdx == idx) {
                  _activeBuildingIdx = null;
                  _selectedId = null;
                  _selectedFloors = {};
                } else if (_activeBuildingIdx != null &&
                    _activeBuildingIdx! > idx) {
                  _activeBuildingIdx = _activeBuildingIdx! - 1;
                }
              });
              Navigator.pop(ctx);
              _scheduleSave();
            },
            child: const Text('제거'),
          ),
        ],
      ),
    );
  }

  void _showActivateDialog(int buildingIdx, int floor, int unitIndex) {
    final floorLabel = floor < 0 ? 'B${floor.abs()}층' : '$floor층';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('호실 활성화'),
        content: Text('$floorLabel $unitIndex번째 위치를 활성화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _pendingEmpty = null);
              Navigator.pop(ctx);
            },
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              _activateUnit(buildingIdx, floor, unitIndex);
              setState(() => _pendingEmpty = null);
              Navigator.pop(ctx);
            },
            child: const Text('활성화'),
          ),
        ],
      ),
    );
  }

  void _activateUnit(int buildingIdx, int floor, int unitIndex) {
    final state = _buildingStates[buildingIdx];
    if (state.findUnit(floor, unitIndex) != null) return;

    final id = Unit.makeId(floor, unitIndex);
    final int number = floor > 0
        ? floor * 100 + unitIndex
        : -(floor.abs() * 100 + unitIndex);

    final unit = Unit(
      id: id,
      floor: floor,
      unitIndex: unitIndex,
      number: number,
    );
    setState(() {
      state.units.add(unit);
      _selectedId = id;
      _activeBuildingIdx = buildingIdx;
      _selectedFloors = {};
    });
    _scheduleSave();
  }

  void _showSessionCodeDialog() {
    final code = widget.sessionCode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_outlined, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('세션 참여 코드'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code == null) ...[
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                '로컬 모드로 실행 중입니다.\nFirebase 세션 없이 시작하면 코드가 없습니다.\n\n처음 화면에서 "새 세션 시작"으로 다시 시작해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else ...[
              const Text(
                '아래 코드를 팀원에게 공유하세요.\n팀원은 앱 첫 화면에서 코드를 입력합니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('코드 $code 복사됨'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.deepOrange.shade700,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('클립보드에 복사'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showAddBuildingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 560,
          child: BuildingSetupScreen(
            onSetupComplete: (b, s) => _addBuilding(b, s),
          ),
        ),
      ),
    );
  }

  void _addLog(Unit unit, UnitStatus from, UnitStatus to) {
    _log.add(LogEntry(
      id: ++_logIdCounter,
      unitName: unit.fullName,
      from: from,
      to: to,
      time: DateTime.now(),
    ));
  }

  // ──────────────────────────────────────────────
  // PersonnelStats 편집
  // ──────────────────────────────────────────────

  void _editPersonnelStat(int buildingIdx, String field) {
    final stats = _personnelStats[buildingIdx];
    final current = field == 'selfEvac'
        ? stats.selfEvac
        : field == 'rescued'
            ? stats.rescued
            : stats.notFound;
    final controller = TextEditingController(text: current.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_personnelLabel(field)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim()) ?? current;
              setState(() {
                if (field == 'selfEvac') stats.selfEvac = v;
                if (field == 'rescued') stats.rescued = v;
                if (field == 'notFound') stats.notFound = v;
              });
              _scheduleSave();
              Navigator.pop(ctx);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _personnelLabel(String field) {
    switch (field) {
      case 'selfEvac':
        return '자력대피';
      case 'rescued':
        return '구조완료';
      case 'notFound':
        return '미발견';
      default:
        return field;
    }
  }

  // ──────────────────────────────────────────────
  // Bottom sheet (narrow)
  // ──────────────────────────────────────────────

  void _showBottomPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scroll) {
              return SingleChildScrollView(
                controller: scroll,
                child: SizedBox(
                  height: 560,
                  child: _buildActionPanel(
                    onStatusChanged: (s) {
                      _onStatusChanged(s);
                      setModal(() {});
                    },
                    onMemoPinToggle: () {
                      _onMemoPinToggle();
                      setModal(() {});
                    },
                    onVulnerableToggle: () {
                      _onVulnerableToggle();
                      setModal(() {});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Build helpers
  // ──────────────────────────────────────────────

  Widget _buildActionPanel({
    ValueChanged<UnitStatus>? onStatusChanged,
    VoidCallback? onMemoPinToggle,
    VoidCallback? onVulnerableToggle,
  }) {
    return ActionPanel(
      selectedUnit: _selectedUnit,
      selectedFloorUnits: _selectedFloorUnits,
      selectedFloor: _selectedFloor,
      activeBuildingIdx: _activeBuildingIdx,
      logEntries: _log,
      onStatusChanged: onStatusChanged ?? _onStatusChanged,
      onMemoChanged: _onMemoChanged,
      onMemoPinToggle: onMemoPinToggle ?? _onMemoPinToggle,
      onVulnerableToggle: onVulnerableToggle ?? _onVulnerableToggle,
      onDeactivateUnit: _selectedId != null ? _onDeactivateUnit : null,
      onHideFloor: _selectedFloor != null ? _onHideFloor : null,
      isFloorHidden: _isSelectedFloorHidden,
      onMergeRight: _canMergeRight ? _onMergeRight : null,
      onSplitUnit: _canSplit ? _onSplitUnit : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: _buildAppBar(),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '설정으로 돌아가기',
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('설정으로 돌아가기'),
              content: const Text('현재 진행 중인 모든 데이터가 초기화됩니다.\n계속하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SessionScreen(),
                      ),
                    );
                  },
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          );
        },
      ),
      title: Row(
        children: [
          const Text('SCB', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(
            '총 $_totalUnits실',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
          ),
          const Spacer(),
          ..._buildStatusChips(),
          InkWell(
            onTap: _showSessionCodeDialog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_outlined, size: 16),
                  SizedBox(width: 4),
                  Text('코드', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      backgroundColor: const Color(0xFFBF360C),
      foregroundColor: Colors.white,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Colors.white, size: 22),
          tooltip: '메뉴',
          color: const Color(0xFF1E2A4A),
          onSelected: (value) {
            switch (value) {
              case 'timer':
                setState(() => _currentTab = _currentTab == 1 ? 0 : 1);
                break;
              case 'map':
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OperationMapScreen()));
                break;
              case 'briefing':
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DisasterBriefingScreen()));
                break;
              case 'board':
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BriefingBoardScreen()));
                break;
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'timer',
              child: Row(children: [
                Icon(
                  _currentTab == 1 ? Icons.apartment_outlined : Icons.timer_outlined,
                  size: 16,
                  color: _currentTab == 1 ? Colors.yellow : Colors.white70,
                ),
                const SizedBox(width: 10),
                Text(
                  _currentTab == 1 ? '건물현황' : '현장타이머',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ]),
            ),
            const PopupMenuItem(
              value: 'map',
              child: Row(children: [
                Icon(Icons.map_outlined, size: 16, color: Colors.white70),
                SizedBox(width: 10),
                Text('진압작전도', style: TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
            const PopupMenuItem(
              value: 'briefing',
              child: Row(children: [
                Icon(Icons.article_outlined, size: 16, color: Colors.white70),
                SizedBox(width: 10),
                Text('재난대응 브리핑 자료',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
            const PopupMenuItem(
              value: 'board',
              child: Row(children: [
                Icon(Icons.dashboard_outlined, size: 16, color: Colors.white70),
                SizedBox(width: 10),
                Text('브리핑 게시판',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStatusChips() {
    // 전체 건물 통합 상태 카운트
    final counts = <UnitStatus, int>{};
    for (final status in UnitStatus.values) {
      counts[status] = _buildingStates
          .expand((s) => s.units)
          .where((u) => u.status == status)
          .length;
    }

    return UnitStatus.values
        .where((s) => (counts[s] ?? 0) > 0)
        .map((status) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status.color.withAlpha(200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${status.label} ${counts[status]}',
                  style: TextStyle(
                    fontSize: 11,
                    color: status.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ))
        .toList();
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 건물 컬럼들 (스크롤 가능)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(_buildings.length, (i) => _buildBuildingColumn(i)),
                if (_buildings.length < 3) _buildAddButton(),
              ],
            ),
          ),
        ),
        // 우측 패널 (300px 고정) — 탭에 따라 액션패널 또는 진입타이머
        SizedBox(
          width: 300,
          child: _currentTab == 1 ? const EntryTimerPanel() : _buildActionPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    if (_currentTab == 1) return const EntryTimerPanel();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_buildings.length, (i) => _buildBuildingColumn(i)),
          if (_buildings.length < 3) _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildBuildingColumn(int idx) {
    final building = _buildings[idx];
    final state = _buildingStates[idx];
    final stats = _personnelStats[idx];
    final isActive = _activeBuildingIdx == idx;

    return Container(
      width: 200.0 + building.defaultUnits * 58,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.deepOrange : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 인명현황 전광판
          _buildPersonnelBoard(idx, stats),
          // 건물 헤더
          _buildBuildingHeader(idx, building),
          // 그리드
          Flexible(
            child: BuildingGrid(
              building: building,
              state: state,
              selectedUnit: isActive ? _selectedUnit : null,
              selectedFloors: isActive ? _selectedFloors : {},
              onUnitTap: (unit) => _onUnitTap(idx, unit),
              onFloorAllTap: (floor) => _onFloorAllTap(idx, floor),
              onEmptyCellTap: (floor, unitIndex) =>
                  _onEmptyCellTap(idx, floor, unitIndex),
              onFloorLabelChanged: (floor, label) =>
                  _onFloorLabelChanged(idx, floor, label),
              onShowHiddenFloors: (floors) => _onShowHiddenFloors(idx, floors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelBoard(int idx, PersonnelStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        border: Border.all(color: Colors.yellow.shade700, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPersonnelStat(idx, '자력대피', stats.selfEvac, 'selfEvac',
              const Color(0xFF00FF88)),
          Container(width: 1, height: 30, color: Colors.grey.shade700),
          _buildPersonnelStat(idx, '구조완료', stats.rescued, 'rescued',
              const Color(0xFF00BFFF)),
          Container(width: 1, height: 30, color: Colors.grey.shade700),
          _buildPersonnelStat(idx, '미발견', stats.notFound, 'notFound',
              const Color(0xFFFF4444)),
        ],
      ),
    );
  }

  Widget _buildPersonnelStat(
      int idx, String label, int value, String field, Color color) {
    return GestureDetector(
      onTap: () => _editPersonnelStat(idx, field),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withAlpha(200),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingHeader(int idx, Building building) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.apartment, size: 16, color: Colors.deepOrange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              building.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 층 수 정보
          Text(
            '${building.floors.length}층',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          // X 버튼 (건물 제거)
          if (_buildings.length > 1)
            GestureDetector(
              onTap: () => _removeBuilding(idx),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddBuildingDialog,
      child: Container(
        width: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '건물 추가',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
