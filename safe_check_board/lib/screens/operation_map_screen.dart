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
  entrance,     // 출입구
  road,         // 도로
  fireHydrant,  // 소화전

  // ── 소방진압 차량 ──
  pumpTruck,          // 펌프차
  tankTruck,          // 물탱크차
  highFoamTruck,      // 고발포차
  foamTruck,          // 화학차(포말차)
  dryPowderTruck,     // 분말차
  aerialLadder,       // 고가사다리차
  articulatedLadder,  // 굴절사다리차
  highCapacityTruck,  // 대용량방수차

  // ── 구조·구급 차량 ──
  rescueVehicle,      // 구조공작차
  ambulance1,         // 구급차(1급)
  ambulance2,         // 구급차(2급)
  chemRescue,         // 화학구조차
  commsVehicle,       // 이동통신차

  // ── 지휘·지원 차량 ──
  commandCar,         // 지휘차
  adminVehicle,       // 소방행정차
  lightingTruck,      // 조명차
  exhaustFan,         // 배연차(송풍차)
  supportVehicle,     // 현장지원차
  droneVehicle,       // 드론운용차

  // ── 유관기관 차량 ──
  doctorCar,          // 닥터카
  alliedAmbulance,    // 구급차(유관)
  policeCar,          // 순찰차
  policeBus,          // 경찰버스
  electricSafetyCar,  // 전기안전차
  gasCar,             // 가스긴급차
  waterSupplyCar,     // 급수지원차
  militaryTruck,      // 군 지원트럭
  adminCommandCar,    // 행정지휘차
  broadcastVehicle,   // 중계차·취재차
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
      case MapItemType.pumpTruck:
      case MapItemType.tankTruck:
      case MapItemType.highFoamTruck:
      case MapItemType.foamTruck:
      case MapItemType.dryPowderTruck:
      case MapItemType.aerialLadder:
      case MapItemType.articulatedLadder:
      case MapItemType.highCapacityTruck:
        return MapItemCategory.fireVehicle;
      case MapItemType.rescueVehicle:
      case MapItemType.ambulance1:
      case MapItemType.ambulance2:
      case MapItemType.chemRescue:
      case MapItemType.commsVehicle:
        return MapItemCategory.rescue;
      case MapItemType.commandCar:
      case MapItemType.adminVehicle:
      case MapItemType.lightingTruck:
      case MapItemType.exhaustFan:
      case MapItemType.supportVehicle:
      case MapItemType.droneVehicle:
        return MapItemCategory.command;
      case MapItemType.doctorCar:
      case MapItemType.alliedAmbulance:
      case MapItemType.policeCar:
      case MapItemType.policeBus:
      case MapItemType.electricSafetyCar:
      case MapItemType.gasCar:
      case MapItemType.waterSupplyCar:
      case MapItemType.militaryTruck:
      case MapItemType.adminCommandCar:
      case MapItemType.broadcastVehicle:
        return MapItemCategory.allied;
    }
  }

  // ── 전체 이름 ──
  String get label {
    switch (this) {
      case MapItemType.building:          return '건물/시설';
      case MapItemType.entrance:          return '출입구';
      case MapItemType.road:              return '도로';
      case MapItemType.fireHydrant:       return '소화전';
      case MapItemType.pumpTruck:         return '펌프차';
      case MapItemType.tankTruck:         return '물탱크차';
      case MapItemType.highFoamTruck:     return '고발포차';
      case MapItemType.foamTruck:         return '화학차(포말차)';
      case MapItemType.dryPowderTruck:    return '분말차';
      case MapItemType.aerialLadder:      return '고가사다리차';
      case MapItemType.articulatedLadder: return '굴절사다리차';
      case MapItemType.highCapacityTruck: return '대용량방수차';
      case MapItemType.rescueVehicle:     return '구조공작차';
      case MapItemType.ambulance1:        return '구급차(1급)';
      case MapItemType.ambulance2:        return '구급차(2급)';
      case MapItemType.chemRescue:        return '화학구조차';
      case MapItemType.commsVehicle:      return '이동통신차';
      case MapItemType.commandCar:        return '지휘차';
      case MapItemType.adminVehicle:      return '소방행정차';
      case MapItemType.lightingTruck:     return '조명차';
      case MapItemType.exhaustFan:        return '배연차(송풍차)';
      case MapItemType.supportVehicle:    return '현장지원차';
      case MapItemType.droneVehicle:      return '드론운용차';
      case MapItemType.doctorCar:         return '닥터카';
      case MapItemType.alliedAmbulance:   return '구급차(유관)';
      case MapItemType.policeCar:         return '순찰차';
      case MapItemType.policeBus:         return '경찰버스';
      case MapItemType.electricSafetyCar: return '전기안전차';
      case MapItemType.gasCar:            return '가스긴급차';
      case MapItemType.waterSupplyCar:    return '급수지원차';
      case MapItemType.militaryTruck:     return '군 지원트럭';
      case MapItemType.adminCommandCar:   return '행정지휘차';
      case MapItemType.broadcastVehicle:  return '중계차·취재차';
    }
  }

  // ── 팔레트 짧은 이름 ──
  String get shortLabel {
    switch (this) {
      case MapItemType.building:          return '건물\n시설';
      case MapItemType.entrance:          return '출입구';
      case MapItemType.road:              return '도로';
      case MapItemType.fireHydrant:       return '소화전';
      case MapItemType.pumpTruck:         return '펌프차';
      case MapItemType.tankTruck:         return '물탱크차';
      case MapItemType.highFoamTruck:     return '고발포차';
      case MapItemType.foamTruck:         return '화학차\n포말';
      case MapItemType.dryPowderTruck:    return '분말차';
      case MapItemType.aerialLadder:      return '고가\n사다리';
      case MapItemType.articulatedLadder: return '굴절\n사다리';
      case MapItemType.highCapacityTruck: return '대용량\n방수차';
      case MapItemType.rescueVehicle:     return '구조\n공작차';
      case MapItemType.ambulance1:        return '구급차\n1급';
      case MapItemType.ambulance2:        return '구급차\n2급';
      case MapItemType.chemRescue:        return '화학\n구조차';
      case MapItemType.commsVehicle:      return '이동\n통신차';
      case MapItemType.commandCar:        return '지휘차';
      case MapItemType.adminVehicle:      return '소방\n행정차';
      case MapItemType.lightingTruck:     return '조명차';
      case MapItemType.exhaustFan:        return '배연차\n송풍차';
      case MapItemType.supportVehicle:    return '현장\n지원차';
      case MapItemType.droneVehicle:      return '드론\n운용차';
      case MapItemType.doctorCar:         return '닥터카';
      case MapItemType.alliedAmbulance:   return '구급차\n유관';
      case MapItemType.policeCar:         return '순찰차';
      case MapItemType.policeBus:         return '경찰버스';
      case MapItemType.electricSafetyCar: return '전기\n안전차';
      case MapItemType.gasCar:            return '가스\n긴급차';
      case MapItemType.waterSupplyCar:    return '급수\n지원차';
      case MapItemType.militaryTruck:     return '군\n지원트럭';
      case MapItemType.adminCommandCar:   return '행정\n지휘차';
      case MapItemType.broadcastVehicle:  return '중계차\n취재차';
    }
  }

  // ── 아이콘 ──
  IconData get icon {
    switch (this) {
      case MapItemType.building:          return Icons.apartment;
      case MapItemType.entrance:          return Icons.sensor_door;
      case MapItemType.road:              return Icons.add_road;
      case MapItemType.fireHydrant:       return Icons.fire_hydrant;
      case MapItemType.pumpTruck:         return Icons.local_fire_department;
      case MapItemType.tankTruck:         return Icons.water_drop;
      case MapItemType.highFoamTruck:     return Icons.bubble_chart;
      case MapItemType.foamTruck:         return Icons.science;
      case MapItemType.dryPowderTruck:    return Icons.grain;
      case MapItemType.aerialLadder:      return Icons.safety_check;
      case MapItemType.articulatedLadder: return Icons.fire_truck;
      case MapItemType.highCapacityTruck: return Icons.water;
      case MapItemType.rescueVehicle:     return Icons.construction;
      case MapItemType.ambulance1:        return Icons.medical_services;
      case MapItemType.ambulance2:        return Icons.medical_services;
      case MapItemType.chemRescue:        return Icons.masks;
      case MapItemType.commsVehicle:      return Icons.cell_tower;
      case MapItemType.commandCar:        return Icons.flag;
      case MapItemType.adminVehicle:      return Icons.admin_panel_settings;
      case MapItemType.lightingTruck:     return Icons.wb_sunny;
      case MapItemType.exhaustFan:        return Icons.air;
      case MapItemType.supportVehicle:    return Icons.inventory_2;
      case MapItemType.droneVehicle:      return Icons.flight_takeoff;
      case MapItemType.doctorCar:         return Icons.local_hospital;
      case MapItemType.alliedAmbulance:   return Icons.emergency;
      case MapItemType.policeCar:         return Icons.local_police;
      case MapItemType.policeBus:         return Icons.directions_bus;
      case MapItemType.electricSafetyCar: return Icons.electrical_services;
      case MapItemType.gasCar:            return Icons.local_gas_station;
      case MapItemType.waterSupplyCar:    return Icons.water_drop;
      case MapItemType.militaryTruck:     return Icons.security;
      case MapItemType.adminCommandCar:   return Icons.account_balance;
      case MapItemType.broadcastVehicle:  return Icons.broadcast_on_personal;
    }
  }

  // ── 색상 ──
  Color get color {
    switch (this) {
      case MapItemType.building:
        return const Color(0xFF546E7A);
      case MapItemType.entrance:
        return const Color(0xFF00695C);
      case MapItemType.road:
        return const Color(0xFF455A64);
      case MapItemType.fireHydrant:
        return const Color(0xFFD32F2F);
      // 소방진압
      case MapItemType.pumpTruck:         return const Color(0xFFC62828);
      case MapItemType.tankTruck:         return const Color(0xFF1565C0);
      case MapItemType.highFoamTruck:     return const Color(0xFF558B2F);
      case MapItemType.foamTruck:         return const Color(0xFF6A1B9A);
      case MapItemType.dryPowderTruck:    return const Color(0xFF795548);
      case MapItemType.aerialLadder:      return const Color(0xFFE65100);
      case MapItemType.articulatedLadder: return const Color(0xFFB71C1C);
      case MapItemType.highCapacityTruck: return const Color(0xFF006064);
      // 구조·구급
      case MapItemType.rescueVehicle:     return const Color(0xFF1B5E20);
      case MapItemType.ambulance1:        return const Color(0xFF2E7D32);
      case MapItemType.ambulance2:        return const Color(0xFF388E3C);
      case MapItemType.chemRescue:        return const Color(0xFF4A148C);
      case MapItemType.commsVehicle:      return const Color(0xFF37474F);
      // 지휘·지원
      case MapItemType.commandCar:        return const Color(0xFF1565C0);
      case MapItemType.adminVehicle:      return const Color(0xFF0D47A1);
      case MapItemType.lightingTruck:     return const Color(0xFFF57F17);
      case MapItemType.exhaustFan:        return const Color(0xFF546E7A);
      case MapItemType.supportVehicle:    return const Color(0xFF4E342E);
      case MapItemType.droneVehicle:      return const Color(0xFF00695C);
      // 유관기관
      case MapItemType.doctorCar:         return const Color(0xFF00838F);
      case MapItemType.alliedAmbulance:   return const Color(0xFF2E7D32);
      case MapItemType.policeCar:         return const Color(0xFF283593);
      case MapItemType.policeBus:         return const Color(0xFF1A237E);
      case MapItemType.electricSafetyCar: return const Color(0xFFF9A825);
      case MapItemType.gasCar:            return const Color(0xFFE65100);
      case MapItemType.waterSupplyCar:    return const Color(0xFF0277BD);
      case MapItemType.militaryTruck:     return const Color(0xFF33691E);
      case MapItemType.adminCommandCar:   return const Color(0xFF37474F);
      case MapItemType.broadcastVehicle:  return const Color(0xFF6A1B9A);
    }
  }

  // ── 기본 셀 크기: 건물=2×3, 차량류=1×1 ──
  int get cellW {
    switch (this) {
      case MapItemType.building: return 5;
      case MapItemType.road:     return 3;
      default:                   return 1;
    }
  }
  int get cellH {
    switch (this) {
      case MapItemType.building: return 5;
      case MapItemType.road:     return 1;
      default:                   return 1;
    }
  }
}

class MapItem {
  final String id;
  MapItemType type;
  double col;
  double row;
  String? customLabel;
  int? customW;
  int? customH;

  MapItem({
    required this.id,
    required this.type,
    required this.col,
    required this.row,
    this.customLabel,
    this.customW,
    this.customH,
  });

  int get w => customW ?? type.cellW;
  int get h => customH ?? type.cellH;
  String get displayLabel => customLabel ?? type.label;
}

// ── Screen ─────────────────────────────────────────────────

class OperationMapScreen extends StatefulWidget {
  const OperationMapScreen({super.key});

  @override
  State<OperationMapScreen> createState() => _OperationMapScreenState();
}

class _OperationMapScreenState extends State<OperationMapScreen> {
  static const double _cell = 64.0;
  int _cols = 48;
  int _rows = 36;

  final List<MapItem> _items = [];
  MapItemCategory? _paletteCategory; // 1단계: 대분류 열림 상태
  MapItemType? _paletteType;         // 2단계: 배치할 유형 선택
  String? _selectedId;
  String? _movingId;
  int _nextId = 0;

  // 아이템 드래그 state (Listener 기반)
  String? _draggingId;
  Offset _pointerStart = Offset.zero;
  double _dragStartCol = 0;
  double _dragStartRow = 0;
  bool _didMove = false; // tap vs drag 구분

  // 배치 미리보기 (hover 셀)
  int? _hoverCol;
  int? _hoverRow;

  // InteractiveViewer 컨트롤러 (pan 비활성화용)
  final TransformationController _transformCtrl = TransformationController();

  // 캔버스 SizedBox GlobalKey (배치 tap 좌표용 — 이미 사용)
  final GlobalKey _canvasKey = GlobalKey();
  // Viewport (InteractiveViewer 감싸는 Expanded 내 MouseRegion) GlobalKey
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void dispose() {
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
          IconButton(
            icon: const Icon(Icons.layers_clear_outlined),
            tooltip: '전체 초기화',
            onPressed: _confirmClear,
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
              Text(
                _movingId != null
                    ? '이동할 위치를 탭하세요 · 취소는 하단 취소 버튼'
                    : _paletteType != null
                        ? '빈 곳 탭하면 배치 · 드래그로 이동'
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
      panEnabled: _draggingId == null,
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onBgTap,
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
                Icon(type.icon, color: Colors.green.shade300, size: 22),
                const SizedBox(height: 2),
                Text(
                  type.label,
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 8,
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

  List<Widget> _buildItemWidgets() {
    return _items.map((item) {
      final isSel = _selectedId == item.id;
      final isDrag = _draggingId == item.id;
      return Positioned(
        left: item.col * _cell,
        top: item.row * _cell,
        width: item.w * _cell,
        height: item.h * _cell,
        child: MouseRegion(
          cursor: isDrag
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
                          _paletteType =
                              _paletteType == type ? null : type;
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
    if (_items.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 초기화'),
        content: const Text('모든 배치 항목을 삭제하시겠습니까?'),
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
              });
              Navigator.pop(ctx);
            },
            child: const Text('초기화'),
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

  const _ItemCard({
    required this.item,
    required this.isSelected,
    required this.isDragging,
    required this.cell,
  });

  @override
  Widget build(BuildContext context) {
    final totalCells = item.w * item.h;
    final isBig = totalCells >= 4;
    final iconSize = isBig ? 30.0 : (totalCells >= 2 ? 26.0 : 22.0);
    final fontSize = isBig ? 10.0 : (totalCells >= 2 ? 9.0 : 8.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: EdgeInsets.all(isBig ? 5 : 4),
      decoration: BoxDecoration(
        color: item.type.color.withOpacity(isDragging ? 0.65 : 0.88),
        borderRadius: BorderRadius.circular(isBig ? 10 : 8),
        border: isSelected
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
            Icon(icon, color: isSelected ? color : Colors.white60, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 8,
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
