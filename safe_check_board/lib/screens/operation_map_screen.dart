import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;

// ── 데이터 모델 ─────────────────────────────────────────────

// 팔레트 1단계: 대분류
enum MapItemCategory {
  building,    // 건물/시설
  fireVehicle, // 소방진압
  rescue,      // 구조·구급
  command,     // 지휘·지원
  allied,      // 유관기관
}

extension MapItemCategoryX on MapItemCategory {
  String get label {
    switch (this) {
      case MapItemCategory.building:    return '건물/시설';
      case MapItemCategory.fireVehicle: return '소방진압';
      case MapItemCategory.rescue:      return '구조·구급';
      case MapItemCategory.command:     return '지휘·지원';
      case MapItemCategory.allied:      return '유관기관';
    }
  }
  IconData get icon {
    switch (this) {
      case MapItemCategory.building:    return Icons.apartment;
      case MapItemCategory.fireVehicle: return Icons.local_fire_department;
      case MapItemCategory.rescue:      return Icons.medical_services;
      case MapItemCategory.command:     return Icons.flag;
      case MapItemCategory.allied:      return Icons.groups;
    }
  }
  Color get color {
    switch (this) {
      case MapItemCategory.building:    return const Color(0xFF546E7A);
      case MapItemCategory.fireVehicle: return const Color(0xFFC62828);
      case MapItemCategory.rescue:      return const Color(0xFF2E7D32);
      case MapItemCategory.command:     return const Color(0xFF1565C0);
      case MapItemCategory.allied:      return const Color(0xFF6A1B9A);
    }
  }
}

// 팔레트 2단계: 세부 유형
enum MapItemType {
  // ── 건물/시설 ──
  building,
  entrance,        // 출입구
  road,            // 도로
  fireHydrant,     // 소화전

  // ── 유관기관 (인원/거점 마커) ──
  police,          // 경찰
  cityHall,        // 시청
  districtOffice,  // 구청
  gasAgency,       // 가스
  electricAgency,  // 전기
  healthCenter,    // 보건소

  // ── 소방진압 ──
  pumpTruck,       // 펌프차
  tankTruck,       // 탱크차
  foamTruck,       // 화학차
  aerialLadder,    // 고가차
  articulatedLadder, // 굴절차
  supportTender,   // 조연차

  // ── 구조·구급 ──
  rescueVehicle,   // 구조공작차
  rescueBus,       // 구조버스
  ambulance,       // 구급차
  ambulanceNP,     // 구급차(음압)

  // ── 지휘·지원 ──
  commandCar,      // 지휘차
  headquartersCar, // 본부차
  recoveryVehicle, // 회복차
}

extension MapItemTypeX on MapItemType {
  // ── 카테고리 분류 ──
  MapItemCategory get category {
    switch (this) {
      case MapItemType.building:
      case MapItemType.entrance:
      case MapItemType.road:
      case MapItemType.fireHydrant:
        return MapItemCategory.building;
      case MapItemType.police:
      case MapItemType.cityHall:
      case MapItemType.districtOffice:
      case MapItemType.gasAgency:
      case MapItemType.electricAgency:
      case MapItemType.healthCenter:
        return MapItemCategory.allied;
      case MapItemType.pumpTruck:
      case MapItemType.tankTruck:
      case MapItemType.foamTruck:
      case MapItemType.aerialLadder:
      case MapItemType.articulatedLadder:
      case MapItemType.supportTender:
        return MapItemCategory.fireVehicle;
      case MapItemType.rescueVehicle:
      case MapItemType.rescueBus:
      case MapItemType.ambulance:
      case MapItemType.ambulanceNP:
        return MapItemCategory.rescue;
      case MapItemType.commandCar:
      case MapItemType.headquartersCar:
      case MapItemType.recoveryVehicle:
        return MapItemCategory.command;
    }
  }

  // ── 전체 이름 ──
  String get label {
    switch (this) {
      case MapItemType.building:          return '건물/시설';
      case MapItemType.entrance:          return '출입구';
      case MapItemType.road:              return '도로';
      case MapItemType.fireHydrant:       return '소화전';
      case MapItemType.police:            return '경찰';
      case MapItemType.cityHall:          return '시청';
      case MapItemType.districtOffice:    return '구청';
      case MapItemType.gasAgency:         return '가스';
      case MapItemType.electricAgency:    return '전기';
      case MapItemType.healthCenter:      return '보건소';
      case MapItemType.pumpTruck:         return '펌프차';
      case MapItemType.tankTruck:         return '탱크차';
      case MapItemType.foamTruck:         return '화학차';
      case MapItemType.aerialLadder:      return '고가차';
      case MapItemType.articulatedLadder: return '굴절차';
      case MapItemType.supportTender:     return '조연차';
      case MapItemType.rescueVehicle:     return '구조공작차';
      case MapItemType.rescueBus:         return '구조버스';
      case MapItemType.ambulance:         return '구급차';
      case MapItemType.ambulanceNP:       return '구급차(음압)';
      case MapItemType.commandCar:        return '지휘차';
      case MapItemType.headquartersCar:   return '본부차';
      case MapItemType.recoveryVehicle:   return '회복차';
    }
  }

  // ── 팔레트 짧은 이름 ──
  String get shortLabel {
    switch (this) {
      case MapItemType.building:          return '건물\n시설';
      case MapItemType.entrance:          return '출입구';
      case MapItemType.road:              return '도로';
      case MapItemType.fireHydrant:       return '소화전';
      case MapItemType.police:            return '경찰';
      case MapItemType.cityHall:          return '시청';
      case MapItemType.districtOffice:    return '구청';
      case MapItemType.gasAgency:         return '가스';
      case MapItemType.electricAgency:    return '전기';
      case MapItemType.healthCenter:      return '보건소';
      case MapItemType.pumpTruck:         return '펌프차';
      case MapItemType.tankTruck:         return '탱크차';
      case MapItemType.foamTruck:         return '화학차';
      case MapItemType.aerialLadder:      return '고가차';
      case MapItemType.articulatedLadder: return '굴절차';
      case MapItemType.supportTender:     return '조연차';
      case MapItemType.rescueVehicle:     return '구조\n공작차';
      case MapItemType.rescueBus:         return '구조버스';
      case MapItemType.ambulance:         return '구급차';
      case MapItemType.ambulanceNP:       return '구급차\n음압';
      case MapItemType.commandCar:        return '지휘차';
      case MapItemType.headquartersCar:   return '본부차';
      case MapItemType.recoveryVehicle:   return '회복차';
    }
  }

  // ── 아이콘 ──
  IconData get icon {
    switch (this) {
      case MapItemType.building:          return Icons.apartment;
      case MapItemType.entrance:          return Icons.sensor_door;
      case MapItemType.road:              return Icons.add_road;
      case MapItemType.fireHydrant:       return Icons.fire_hydrant;
      case MapItemType.police:            return Icons.local_police;
      case MapItemType.cityHall:          return Icons.account_balance;
      case MapItemType.districtOffice:    return Icons.location_city;
      case MapItemType.gasAgency:         return Icons.local_gas_station;
      case MapItemType.electricAgency:    return Icons.electrical_services;
      case MapItemType.healthCenter:      return Icons.local_hospital;
      case MapItemType.pumpTruck:         return Icons.local_fire_department;
      case MapItemType.tankTruck:         return Icons.water_drop;
      case MapItemType.foamTruck:         return Icons.science;
      case MapItemType.aerialLadder:      return Icons.safety_check;
      case MapItemType.articulatedLadder: return Icons.fire_truck;
      case MapItemType.supportTender:     return Icons.support;
      case MapItemType.rescueVehicle:     return Icons.construction;
      case MapItemType.rescueBus:         return Icons.directions_bus;
      case MapItemType.ambulance:         return Icons.medical_services;
      case MapItemType.ambulanceNP:       return Icons.air;
      case MapItemType.commandCar:        return Icons.flag;
      case MapItemType.headquartersCar:   return Icons.account_balance;
      case MapItemType.recoveryVehicle:   return Icons.health_and_safety;
    }
  }

  // ── 색상 ──
  Color get color {
    switch (this) {
      case MapItemType.building:          return const Color(0xFF546E7A);
      case MapItemType.entrance:          return const Color(0xFF00695C);
      case MapItemType.road:              return const Color(0xFF455A64);
      case MapItemType.fireHydrant:       return const Color(0xFFD32F2F);
      case MapItemType.police:            return const Color(0xFF1A237E);
      case MapItemType.cityHall:          return const Color(0xFF37474F);
      case MapItemType.districtOffice:    return const Color(0xFF455A64);
      case MapItemType.gasAgency:         return const Color(0xFFE65100);
      case MapItemType.electricAgency:    return const Color(0xFFF9A825);
      case MapItemType.healthCenter:      return const Color(0xFF00838F);
      case MapItemType.pumpTruck:         return const Color(0xFFC62828);
      case MapItemType.tankTruck:         return const Color(0xFF1565C0);
      case MapItemType.foamTruck:         return const Color(0xFF6A1B9A);
      case MapItemType.aerialLadder:      return const Color(0xFFE65100);
      case MapItemType.articulatedLadder: return const Color(0xFFB71C1C);
      case MapItemType.supportTender:     return const Color(0xFF795548);
      case MapItemType.rescueVehicle:     return const Color(0xFF1B5E20);
      case MapItemType.rescueBus:         return const Color(0xFF33691E);
      case MapItemType.ambulance:         return const Color(0xFF2E7D32);
      case MapItemType.ambulanceNP:       return const Color(0xFF00695C);
      case MapItemType.commandCar:        return const Color(0xFF1565C0);
      case MapItemType.headquartersCar:   return const Color(0xFF0D47A1);
      case MapItemType.recoveryVehicle:   return const Color(0xFF4E342E);
    }
  }

  // ── 기본 셀 크기 ──
  int get cellW => this == MapItemType.building ? 5 : 1;
  int get cellH => this == MapItemType.building ? 5 : 1;
}

class MapItem {
  final String id;
  MapItemType type;
  double col;
  double row;
  String? customLabel;
  int? customW;
  int? customH;
  Color? customColor;

  MapItem({
    required this.id,
    required this.type,
    required this.col,
    required this.row,
    this.customLabel,
    this.customW,
    this.customH,
    this.customColor,
  });

  int get w => customW ?? type.cellW;
  int get h => customH ?? type.cellH;
  String get displayLabel => customLabel ?? type.label;
  Color get displayColor => customColor ?? type.color;
}

// 색상 프리셋 10가지
const List<Color> kTileColors = [
  Color(0xFFC62828), // 빨강
  Color(0xFFE65100), // 주황
  Color(0xFFF9A825), // 노랑
  Color(0xFF2E7D32), // 초록
  Color(0xFF00695C), // 청록
  Color(0xFF1565C0), // 파랑
  Color(0xFF4A148C), // 보라
  Color(0xFF880E4F), // 자주
  Color(0xFF4E342E), // 갈색
  Color(0xFF546E7A), // 회청
];

// ── Screen ─────────────────────────────────────────────────

// ── 진압작전도 영속 데이터 (화면 이탈 후 복원용) ──────────────
List<MapItem> _savedMapItems = [];
int _savedMapNextId = 0;
int _savedMapCols = 48;
int _savedMapRows = 36;

class OperationMapScreen extends StatefulWidget {
  const OperationMapScreen({super.key});

  @override
  State<OperationMapScreen> createState() => _OperationMapScreenState();
}

class _OperationMapScreenState extends State<OperationMapScreen> {
  static const double _cell = 64.0;
  late int _cols;
  late int _rows;

  late List<MapItem> _items;
  MapItemCategory? _paletteCategory;
  MapItemType? _paletteType;
  String? _selectedId;
  String? _movingId;
  late int _nextId;

  // 아이템 드래그 state (Listener 기반)
  String? _draggingId;
  Offset _pointerStart = Offset.zero;
  double _dragStartCol = 0;
  double _dragStartRow = 0;
  bool _didMove = false; // tap vs drag 구분

  // 배치 미리보기 (hover 셀)
  int? _hoverCol;
  int? _hoverRow;

  // 페인트 드래그 (팔레트 유형 선택 후 드래그 배치)
  Set<String> _paintedCells = {}; // 현재 드래그 중 배치된 셀 (중복 방지)
  bool _isPainting = false;

  // 지우개 모드
  bool _eraserMode = false;
  bool _isErasing = false;

  // 그룹 선택/병합 모드
  bool _groupMode = false;
  Set<String> _groupSelectedIds = {};
  Offset? _groupDragStart;
  Offset? _groupDragEnd;

  // InteractiveViewer 컨트롤러 (pan 비활성화용)
  final TransformationController _transformCtrl = TransformationController();

  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cols = _savedMapCols;
    _rows = _savedMapRows;
    _nextId = _savedMapNextId;
    _items = List.from(_savedMapItems);
  }

  @override
  void dispose() {
    _savedMapItems = List.from(_items);
    _savedMapNextId = _nextId;
    _savedMapCols = _cols;
    _savedMapRows = _rows;
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('진압작전도'),
        backgroundColor: const Color(0xFFBF360C),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '선택 삭제',
              onPressed: _deleteSelected,
            ),
          IconButton(
            icon: const Icon(Icons.open_in_full),
            tooltip: '캔버스 크기',
            onPressed: _showCanvasSizeDialog,
          ),
          TextButton(
            onPressed: _confirmClear,
            child: const Text('새로하기', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 안내 힌트 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: const Color(0xFF263238),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              if (_groupMode && _groupSelectedIds.length >= 2) ...[
                Expanded(
                  child: Text(
                    '${_groupSelectedIds.length}개 선택됨',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ),
                InkWell(
                  onTap: _mergeGroupSelected,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('병합하기', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
              Text(
                _groupMode
                    ? '드래그로 합칠 아이템을 선택하세요'
                    : _eraserMode
                        ? '탭 또는 드래그로 아이템 삭제'
                        : _movingId != null
                        ? '이동할 위치를 탭하세요 · 취소는 하단 취소 버튼'
                        : _paletteType != null
                            ? '탭 또는 드래그로 연속 배치'
                            : _paletteCategory != null
                                ? '세부 유형을 선택하세요'
                                : '아이콘 탭 → 편집 · 드래그 → 이동',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ]),
          ),
          Expanded(
            child: MouseRegion(
              key: _viewportKey,
              onHover: _onCanvasHover,
              onExit: (_) => setState(() { _hoverCol = null; _hoverRow = null; }),
              child: _buildCanvas(),
            ),
          ),
          _buildPalette(),
        ],
      ),
    );
  }

  // ── Canvas ────────────────────────────────────────────────

  Widget _buildCanvas() {
    final w = _cell * _cols;
    final h = _cell * _rows;
    return InteractiveViewer(
      transformationController: _transformCtrl,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 4.0,
      panEnabled: _draggingId == null && _paletteType == null && _movingId == null && !_eraserMode && !_groupMode,
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _eraserMode ? _onEraserTap : (_groupMode ? null : _onBgTap),
          onPanStart: _eraserMode ? _onEraserStart : (_groupMode ? _onGroupStart : (_paletteType != null ? _onPaintStart : null)),
          onPanUpdate: _eraserMode ? _onEraserUpdate : (_groupMode ? _onGroupUpdate : (_paletteType != null ? _onPaintUpdate : null)),
          onPanEnd: _eraserMode ? _onEraserEnd : (_groupMode ? _onGroupEnd : (_paletteType != null ? _onPaintEnd : null)),
          child: SizedBox(
            key: _canvasKey,
            width: w,
            height: h,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(w, h),
                  painter: _GridPainter(cell: _cell),
                ),
                // 페인트 드래그 — 이번 드래그에서 배치된 셀 하이라이트
                if (_isPainting)
                  ..._paintedCells.map((key) {
                    final p = key.split(',');
                    final c = int.parse(p[0]);
                    final r = int.parse(p[1]);
                    return Positioned(
                      left: c * _cell, top: r * _cell,
                      width: _cell, height: _cell,
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade400, width: 1.5),
                          ),
                        ),
                      ),
                    );
                  }),
                // 그룹 모드 — 드래그 선택 사각형
                if (_groupMode && _groupDragStart != null && _groupDragEnd != null)
                  Positioned(
                    left: _groupDragStart!.dx < _groupDragEnd!.dx ? _groupDragStart!.dx : _groupDragEnd!.dx,
                    top: _groupDragStart!.dy < _groupDragEnd!.dy ? _groupDragStart!.dy : _groupDragEnd!.dy,
                    width: (_groupDragEnd!.dx - _groupDragStart!.dx).abs(),
                    height: (_groupDragEnd!.dy - _groupDragStart!.dy).abs(),
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          border: Border.all(color: Colors.amber.shade400, width: 2),
                        ),
                      ),
                    ),
                  ),
                // 배치 미리보기 (팔레트 선택 시)
                if (_paletteType != null &&
                    _hoverCol != null &&
                    _hoverRow != null)
                  _buildPreview(_paletteType!, _hoverCol!, _hoverRow!),
                // 이동 모드 미리보기
                if (_movingId != null &&
                    _hoverCol != null &&
                    _hoverRow != null)
                  for (final item in _items.where((i) => i.id == _movingId))
                    _buildMovePreview(item, _hoverCol!, _hoverRow!),
                ..._buildItemWidgets(),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildPreview(MapItemType type, int col, int row) {
    return Positioned(
      left: col * _cell,
      top: row * _cell,
      width: type.cellW * _cell,
      height: type.cellH * _cell,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: 0.75,
          duration: const Duration(milliseconds: 80),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade400, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, color: Colors.green.shade300, size: 26),
                const SizedBox(height: 2),
                Text(
                  type.label,
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovePreview(MapItem item, int col, int row) {
    return Positioned(
      left: col * _cell,
      top: row * _cell,
      width: item.w * _cell,
      height: item.h * _cell,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: 0.75,
          duration: const Duration(milliseconds: 80),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade400, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.type.icon, color: Colors.blue.shade300, size: 24),
                const SizedBox(height: 2),
                Text(
                  item.displayLabel,
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isBackgroundType(MapItemType t) =>
      t == MapItemType.road || t == MapItemType.entrance ||
      t == MapItemType.fireHydrant || t == MapItemType.building;

  List<Widget> _buildItemWidgets() {
    // 배경 아이템(도로·출입구·소화전)을 먼저 렌더링 → 차량이 위에 올라옴
    final sorted = [..._items]..sort((a, b) {
        final ab = _isBackgroundType(a.type) ? 0 : 1;
        final bb = _isBackgroundType(b.type) ? 0 : 1;
        return ab.compareTo(bb);
      });
    return sorted.map((item) {
      final isSel = _selectedId == item.id;
      final isDrag = _draggingId == item.id;
      final isGroupSel = _groupSelectedIds.contains(item.id);
      return Positioned(
        left: item.col * _cell,
        top: item.row * _cell,
        width: item.w * _cell,
        height: item.h * _cell,
        child: IgnorePointer(
          ignoring: _eraserMode || _groupMode,
          child: MouseRegion(
          cursor: _eraserMode
              ? SystemMouseCursors.none
              : isDrag
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              setState(() {
                _draggingId = item.id;
                _selectedId = item.id;
                _pointerStart = e.position;
                _dragStartCol = item.col;
                _dragStartRow = item.row;
                _didMove = false;
              });
            },
            onPointerMove: (e) {
              if (_draggingId != item.id) return;
              final scale = _transformCtrl.value.getMaxScaleOnAxis();
              final delta = e.position - _pointerStart;
              if (delta.distance > 4) _didMove = true;
              setState(() {
                item.col = (_dragStartCol + delta.dx / (_cell * scale))
                    .clamp(0, _cols - item.w.toDouble());
                item.row = (_dragStartRow + delta.dy / (_cell * scale))
                    .clamp(0, _rows - item.h.toDouble());
              });
            },
            onPointerUp: (e) {
              if (_draggingId != item.id) return;
              final wasTap = !_didMove;
              setState(() {
                if (_didMove) {
                  // 그리드에 스냅
                  item.col = item.col.roundToDouble();
                  item.row = item.row.roundToDouble();
                } else {
                  _selectedId = item.id;
                }
                _draggingId = null;
              });
              if (wasTap) _showItemOptions(item);
            },
            onPointerCancel: (_) {
              if (_draggingId == item.id) {
                setState(() {
                  item.col = _dragStartCol;
                  item.row = _dragStartRow;
                  _draggingId = null;
                });
              }
            },
            child: _ItemCard(
              item: item,
              isSelected: isSel,
              isDragging: isDrag,
              cell: _cell,
              erasing: _eraserMode,
              groupSelected: isGroupSel,
            ),
          ),
        ),
        ),
      );
    }).toList();
  }

  void _onBgTap(TapDownDetails d) {
    // 이동 모드: 탭한 위치로 아이템 이동
    if (_movingId != null) {
      final movingItem = _items.firstWhere(
        (i) => i.id == _movingId,
        orElse: () => _items.first,
      );
      if (_items.any((i) => i.id == _movingId)) {
        final col = (d.localPosition.dx / _cell)
            .floor()
            .clamp(0, _cols - movingItem.w)
            .toDouble();
        final row = (d.localPosition.dy / _cell)
            .floor()
            .clamp(0, _rows - movingItem.h)
            .toDouble();
        setState(() {
          movingItem.col = col;
          movingItem.row = row;
          _movingId = null;
        });
      }
      return;
    }
    if (_paletteType == null) {
      setState(() => _selectedId = null);
      return;
    }
    // InteractiveViewer 자식의 localPosition은 이미 캔버스 좌표계
    final tapX = d.localPosition.dx / _cell;
    final tapY = d.localPosition.dy / _cell;
    // 기존 아이템 위를 탭했으면 배치하지 않음 (아이템 탭 핸들러가 처리)
    if (_items.any((item) =>
        tapX >= item.col && tapX < item.col + item.w &&
        tapY >= item.row && tapY < item.row + item.h)) {
      return;
    }
    final type = _paletteType!;
    final col = (d.localPosition.dx / _cell)
        .floor()
        .clamp(0, _cols - type.cellW)
        .toDouble();
    final row = (d.localPosition.dy / _cell)
        .floor()
        .clamp(0, _rows - type.cellH)
        .toDouble();
    setState(() {
      _items.add(MapItem(
        id: '${_nextId++}',
        type: type,
        col: col,
        row: row,
      ));
    });
  }

  // ── 그룹 선택/병합 ──────────────────────────────────────────

  void _onGroupStart(DragStartDetails d) {
    setState(() {
      _groupDragStart = d.localPosition;
      _groupDragEnd = d.localPosition;
      _groupSelectedIds.clear();
    });
  }

  void _onGroupUpdate(DragUpdateDetails d) {
    final dragRect = Rect.fromPoints(_groupDragStart!, d.localPosition);
    final newSel = <String>{};
    for (final item in _items) {
      final itemRect = Rect.fromLTWH(
        item.col * _cell, item.row * _cell,
        item.w * _cell, item.h * _cell,
      );
      if (dragRect.overlaps(itemRect)) newSel.add(item.id);
    }
    setState(() {
      _groupDragEnd = d.localPosition;
      _groupSelectedIds = newSel;
    });
  }

  void _onGroupEnd(DragEndDetails _) {
    setState(() { _groupDragStart = null; _groupDragEnd = null; });
  }

  void _mergeGroupSelected() {
    final selected = _items.where((i) => _groupSelectedIds.contains(i.id)).toList();
    if (selected.length < 2) return;
    final minCol = selected.map((i) => i.col).reduce((a, b) => a < b ? a : b);
    final minRow = selected.map((i) => i.row).reduce((a, b) => a < b ? a : b);
    final maxColEnd = selected.map((i) => i.col + i.w).reduce((a, b) => a > b ? a : b);
    final maxRowEnd = selected.map((i) => i.row + i.h).reduce((a, b) => a > b ? a : b);
    final newW = (maxColEnd - minCol).round();
    final newH = (maxRowEnd - minRow).round();
    final type = selected.first.type;
    setState(() {
      _items.removeWhere((i) => _groupSelectedIds.contains(i.id));
      _items.add(MapItem(
        id: '${_nextId++}',
        type: type,
        col: minCol,
        row: minRow,
        customW: newW,
        customH: newH,
      ));
      _groupSelectedIds.clear();
      _groupMode = false;
    });
  }

  // ── 지우개 드래그 ───────────────────────────────────────────

  void _onEraserTap(TapDownDetails d) => _eraseAt(d.localPosition);

  void _onEraserStart(DragStartDetails d) {
    setState(() => _isErasing = true);
    _eraseAt(d.localPosition);
  }

  void _onEraserUpdate(DragUpdateDetails d) => _eraseAt(d.localPosition);

  void _onEraserEnd(DragEndDetails _) => setState(() => _isErasing = false);

  void _eraseAt(Offset localPos) {
    final px = localPos.dx / _cell;
    final py = localPos.dy / _cell;
    final toRemove = _items.where((item) =>
        px >= item.col && px < item.col + item.w &&
        py >= item.row && py < item.row + item.h).toList();
    if (toRemove.isEmpty) return;
    setState(() {
      for (final item in toRemove) {
        _items.remove(item);
        if (_selectedId == item.id) _selectedId = null;
      }
    });
  }

  // ── 페인트 드래그 (팔레트 유형 선택 후 드래그 연속 배치) ────────

  void _onPaintStart(DragStartDetails d) {
    if (_paletteType == null) return;
    setState(() {
      _isPainting = true;
      _paintedCells.clear();
    });
    _paintCell(d.localPosition);
  }

  void _onPaintUpdate(DragUpdateDetails d) {
    if (!_isPainting || _paletteType == null) return;
    _paintCell(d.localPosition);
  }

  void _onPaintEnd(DragEndDetails _) {
    setState(() {
      _isPainting = false;
      _paintedCells.clear();
    });
  }

  void _paintCell(Offset localPos) {
    if (_paletteType == null) return;
    final type = _paletteType!;
    final c = (localPos.dx / _cell).floor().clamp(0, _cols - type.cellW);
    final r = (localPos.dy / _cell).floor().clamp(0, _rows - type.cellH);
    final key = '$c,$r';
    if (_paintedCells.contains(key)) return; // 이번 드래그에서 이미 배치
    // 해당 셀 범위에 기존 아이템이 있으면 스킵
    final occupied = _items.any((item) =>
        c < item.col + item.w && c + type.cellW > item.col &&
        r < item.row + item.h && r + type.cellH > item.row);
    if (occupied) return;
    setState(() {
      _paintedCells.add(key);
      _items.add(MapItem(
        id: '${_nextId++}',
        type: type,
        col: c.toDouble(),
        row: r.toDouble(),
        customW: type.cellW == 1 ? null : 1,
        customH: type.cellH == 1 ? null : 1,
      ));
    });
  }

  // ── Palette ───────────────────────────────────────────────

  Widget _buildPalette() {
    final bool anyActive =
        _paletteCategory != null || _paletteType != null || _movingId != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1단계: 대분류 카테고리 버튼 ──
        Container(
          height: 56,
          color: const Color(0xFF0D0D1A),
          child: Row(
            children: [
              // 취소 버튼
              if (anyActive)
                InkWell(
                  onTap: () => setState(() {
                    _paletteCategory = null;
                    _paletteType = null;
                    _movingId = null;
                  }),
                  child: Container(
                    width: 52,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, color: Colors.white60, size: 20),
                        SizedBox(height: 2),
                        Text('취소',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              if (anyActive)
                Container(
                    width: 1,
                    margin:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    color: Colors.white24),
              // 지우개 버튼
              InkWell(
                onTap: () => setState(() {
                  _eraserMode = !_eraserMode;
                  if (_eraserMode) {
                    _paletteType = null;
                    _movingId = null;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 52,
                  color: _eraserMode ? Colors.red.withOpacity(0.25) : Colors.transparent,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_fix_normal,
                          color: _eraserMode ? Colors.red.shade300 : Colors.white38,
                          size: 20),
                      const SizedBox(height: 2),
                      Text(
                        '지우개',
                        style: TextStyle(
                          color: _eraserMode ? Colors.red.shade300 : Colors.white38,
                          fontSize: 9,
                          fontWeight: _eraserMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 그룹 버튼
              InkWell(
                onTap: () => setState(() {
                  _groupMode = !_groupMode;
                  if (_groupMode) {
                    _eraserMode = false;
                    _paletteType = null;
                    _movingId = null;
                  } else {
                    _groupSelectedIds.clear();
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 52,
                  color: _groupMode ? Colors.amber.withOpacity(0.25) : Colors.transparent,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.select_all,
                          color: _groupMode ? Colors.amber.shade300 : Colors.white38,
                          size: 20),
                      const SizedBox(height: 2),
                      Text(
                        '그룹',
                        style: TextStyle(
                          color: _groupMode ? Colors.amber.shade300 : Colors.white38,
                          fontSize: 9,
                          fontWeight: _groupMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                color: Colors.white24,
              ),
              // 카테고리 버튼들
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: MapItemCategory.values.map((cat) {
                    final isOpen = _paletteCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _paletteCategory = isOpen ? null : cat;
                        if (!isOpen) _paletteType = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 80,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? cat.color.withOpacity(0.35)
                              : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOpen ? cat.color : Colors.white24,
                            width: isOpen ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.icon,
                                color: isOpen ? cat.color : Colors.white54,
                                size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  color:
                                      isOpen ? Colors.white : Colors.white54,
                                  fontSize: 9,
                                  fontWeight: isOpen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // ── 2단계: 세부 유형 버튼 (카테고리 선택 시) ──
        if (_paletteCategory != null)
          Container(
            height: 82,
            color: const Color(0xFF1A1A2E),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: MapItemType.values
                  .where((t) => t.category == _paletteCategory)
                  .map((type) => _PaletteButton(
                        icon: type.icon,
                        label: type.shortLabel,
                        color: type.color,
                        isSelected: _paletteType == type,
                        onTap: () => setState(() {
                          _paletteType = _paletteType == type ? null : type;
                          _selectedId = null;
                        }),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────

  // ── Hover 좌표 계산 (viewport 외부 MouseRegion → 캔버스 좌표) ──
  void _onCanvasHover(PointerHoverEvent e) {
    if (_paletteType == null && _movingId == null) return;
    // viewport의 render box 가져오기
    final vpBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (vpBox == null) return;
    // global → viewport 로컬 변환
    final vpLocal = vpBox.globalToLocal(e.position);
    // InteractiveViewer 변환행렬 역행렬 적용: viewport → 캔버스 좌표
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    final tx = _transformCtrl.value.entry(0, 3);
    final ty = _transformCtrl.value.entry(1, 3);
    final canvasX = (vpLocal.dx - tx) / scale;
    final canvasY = (vpLocal.dy - ty) / scale;

    final int w;
    final int h;
    if (_paletteType != null) {
      w = _paletteType!.cellW;
      h = _paletteType!.cellH;
    } else {
      final mi = _items.where((i) => i.id == _movingId).firstOrNull;
      w = mi?.w ?? 1;
      h = mi?.h ?? 1;
    }
    final col = (canvasX / _cell).floor().clamp(0, _cols - w);
    final row = (canvasY / _cell).floor().clamp(0, _rows - h);
    if (col != _hoverCol || row != _hoverRow) {
      setState(() { _hoverCol = col; _hoverRow = row; });
    }
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    setState(() {
      _items.removeWhere((i) => i.id == _selectedId);
      _selectedId = null;
    });
  }

  void _showItemOptions(MapItem item) {
    final labelCtrl = TextEditingController(
        text: item.customLabel ?? item.type.label);
    final wCtrl = TextEditingController(text: '${item.w}');
    final hCtrl = TextEditingController(text: '${item.h}');
    Color? pickedColor = item.customColor; // null = 기본값
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
        title: Text('${item.type.label} 편집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '표시 이름',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '가로 (칸)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('×', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '세로 (칸)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('색상', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 기본값 버튼
                GestureDetector(
                  onTap: () => setDlgState(() => pickedColor = null),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: item.type.color,
                      shape: BoxShape.circle,
                      border: pickedColor == null
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey.shade300, width: 1.5),
                    ),
                    child: pickedColor == null
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                // 프리셋 10가지
                for (final c in kTileColors)
                  GestureDetector(
                    onTap: () => setDlgState(() => pickedColor = c),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: pickedColor == c
                            ? Border.all(color: Colors.black, width: 3)
                            : Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: pickedColor == c
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _items.remove(item);
                if (_selectedId == item.id) _selectedId = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () {
              setState(() => _movingId = item.id);
              Navigator.pop(ctx);
            },
            child: const Text('이동'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final newW = int.tryParse(wCtrl.text.trim());
              final newH = int.tryParse(hCtrl.text.trim());
              setState(() {
                item.customLabel =
                    label.isEmpty || label == item.type.label ? null : label;
                if (newW != null && newW >= 1)
                  item.customW = newW == item.type.cellW ? null : newW;
                if (newH != null && newH >= 1)
                  item.customH = newH == item.type.cellH ? null : newH;
                item.customColor = pickedColor;
                // 캔버스 범위 보정
                item.col = item.col.clamp(0, _cols - item.w.toDouble());
                item.row = item.row.clamp(0, _rows - item.h.toDouble());
              });
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
      ),
    );
  }

  void _showCanvasSizeDialog() {
    final colsCtrl = TextEditingController(text: '$_cols');
    final rowsCtrl = TextEditingController(text: '$_rows');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캔버스 크기 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 크기보다 줄이면 캔버스 밖 아이템이 잘릴 수 있습니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: colsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '가로 (열)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×', style: TextStyle(fontSize: 18)),
                ),
                Expanded(
                  child: TextField(
                    controller: rowsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '세로 (행)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final newCols = int.tryParse(colsCtrl.text.trim());
              final newRows = int.tryParse(rowsCtrl.text.trim());
              if (newCols != null && newCols >= 10 &&
                  newRows != null && newRows >= 6) {
                setState(() {
                  _cols = newCols;
                  _rows = newRows;
                  // 캔버스 밖으로 나간 아이템 위치 보정
                  for (final item in _items) {
                    item.col = item.col.clamp(0, _cols - item.w.toDouble());
                    item.row = item.row.clamp(0, _rows - item.h.toDouble());
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새로하기'),
        content: const Text('모든 배치 항목을 삭제하고 새로 시작하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _items.clear();
                _selectedId = null;
                _nextId = 0;
                _cols = 48;
                _rows = 36;
              });
              // 영속 데이터도 초기화
              _savedMapItems = [];
              _savedMapNextId = 0;
              _savedMapCols = 48;
              _savedMapRows = 36;
              Navigator.pop(ctx);
            },
            child: const Text('새로하기'),
          ),
        ],
      ),
    );
  }
}

// ── Item Card Widget ────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final MapItem item;
  final bool isSelected;
  final bool isDragging;
  final double cell;
  final bool erasing;
  final bool groupSelected;

  const _ItemCard({
    required this.item,
    required this.isSelected,
    required this.isDragging,
    required this.cell,
    this.erasing = false,
    this.groupSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalCells = item.w * item.h;
    final isBig = totalCells >= 4;
    final iconSize = isBig ? 38.0 : (totalCells >= 2 ? 32.0 : 26.0);
    final fontSize = isBig ? 14.0 : (totalCells >= 2 ? 13.0 : 12.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: EdgeInsets.all(isBig ? 5 : 4),
      decoration: BoxDecoration(
        color: erasing
            ? Colors.red.shade400.withOpacity(0.6)
            : item.displayColor.withOpacity(isDragging ? 0.65 : 0.88),
        borderRadius: BorderRadius.circular(isBig ? 10 : 8),
        border: erasing
            ? Border.all(color: Colors.red.shade300, width: 2)
            : groupSelected
                ? Border.all(color: Colors.amber.shade300, width: 2.5)
                : isSelected
                    ? Border.all(color: Colors.white, width: 2.5)
                    : Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDragging ? 0.5 : 0.25),
            blurRadius: isDragging ? 14 : 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.type.icon, color: Colors.white, size: iconSize),
          const SizedBox(height: 2),
          Text(
            item.displayLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: item.h + 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Palette Button ──────────────────────────────────────────

class _PaletteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 62,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.white60, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Painter ────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double cell;
  const _GridPainter({required this.cell});

  @override
  void paint(Canvas canvas, Size size) {
    // white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final minor = Paint()
      ..color = Colors.blueGrey.withOpacity(0.12)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = Colors.blueGrey.withOpacity(0.28)
      ..strokeWidth = 1.0;

    final colCount = (size.width / cell).ceil();
    final rowCount = (size.height / cell).ceil();

    for (int c = 0; c <= colCount; c++) {
      final x = c * cell;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), c % 5 == 0 ? major : minor);
    }
    for (int r = 0; r <= rowCount; r++) {
      final y = r * cell;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), r % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
