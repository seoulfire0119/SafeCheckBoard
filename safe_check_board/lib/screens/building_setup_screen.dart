import 'dart:math';
import 'package:flutter/material.dart';
import '../models/building.dart';
import '../models/building_state.dart';
import '../models/personnel_stats.dart';
import '../services/firebase_service.dart';
import 'dashboard_screen.dart';

typedef BuildingSetupCallback = void Function(Building, BuildingState);

class BuildingSetupScreen extends StatefulWidget {
  final String? sessionCode;
  final BuildingSetupCallback? onSetupComplete;

  const BuildingSetupScreen({super.key, this.sessionCode, this.onSetupComplete});

  @override
  State<BuildingSetupScreen> createState() => _BuildingSetupScreenState();
}

class _BuildingSetupScreenState extends State<BuildingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _startFloorController = TextEditingController();
  final _endFloorController = TextEditingController();
  final _unitsController = TextEditingController();
  bool _isHorizontal = false;

  @override
  void initState() {
    super.initState();
    _startFloorController.addListener(() => setState(() {}));
    _endFloorController.addListener(() => setState(() {}));
    _unitsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startFloorController.dispose();
    _endFloorController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  void _onOrientationChanged(bool horizontal) {
    setState(() {
      _isHorizontal = horizontal;
      _nameController.clear();
      _startFloorController.clear();
      _endFloorController.clear();
      _unitsController.clear();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final startFloor = int.parse(_startFloorController.text.trim());
    final endFloor = int.parse(_endFloorController.text.trim());
    final defaultUnits = int.parse(_unitsController.text.trim());

    if (startFloor > endFloor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isHorizontal
              ? '시작 구역은 끝 구역보다 작거나 같아야 합니다'
              : '시작층은 끝층보다 작거나 같아야 합니다'),
        ),
      );
      return;
    }

    final building = Building(
      name: _nameController.text.trim(),
      startFloor: startFloor,
      endFloor: endFloor,
      defaultUnits: defaultUnits,
      isHorizontal: _isHorizontal,
    );
    final state = BuildingState.create(building);

    if (widget.onSetupComplete != null) {
      widget.onSetupComplete!(building, state);
    } else if (widget.sessionCode != null) {
      _saveAndGo(building, state, widget.sessionCode!);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            initialBuilding: building,
            initialState: state,
          ),
        ),
      );
    }
  }

  Future<void> _saveAndGo(
      Building building, BuildingState state, String code) async {
    try {
      await FirebaseService.instance.saveSession(
        code: code,
        buildings: [building],
        states: [state],
        personnelStats: [PersonnelStats()],
        log: [],
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            sessionCode: code,
            initialBuilding: building,
            initialState: state,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String? _validateNotEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 입력' : null;

  String? _validateInt(String? v) {
    if (v == null || v.trim().isEmpty) return '필수 입력';
    if (int.tryParse(v.trim()) == null) return '정수를 입력하세요';
    return null;
  }

  String? _validatePositiveInt(String? v) {
    final err = _validateInt(v);
    if (err != null) return err;
    if (int.parse(v!.trim()) < 1) return '1 이상 입력';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onSetupComplete != null
          ? AppBar(
              title: const Text('건물 추가'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apartment,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            widget.onSetupComplete != null
                                ? '건물 추가'
                                : 'SafeCheckBoard',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── 건물 방향 선택 ──────────────────────────
                      _buildOrientationToggle(),
                      const SizedBox(height: 16),

                      // 건물명 / 시설명
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _isHorizontal ? '시설명' : '건물명 / 동 이름',
                          hintText: _isHorizontal
                              ? '예) 문기시장 / 소방요양원'
                              : '예) 101동 / 슈퍼파워타워',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.label_outline),
                          isDense: true,
                        ),
                        validator: _validateNotEmpty,
                      ),
                      const SizedBox(height: 14),

                      // 시작~끝 층/구역
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startFloorController,
                              decoration: InputDecoration(
                                labelText: _isHorizontal ? '시작 구역' : '시작 층',
                                border: const OutlineInputBorder(),
                                hintText: _isHorizontal ? '예) 1' : '예) 1  (지하: -2)',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('~', style: TextStyle(fontSize: 18)),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _endFloorController,
                              decoration: InputDecoration(
                                labelText: _isHorizontal ? '끝 구역' : '끝 층',
                                border: const OutlineInputBorder(),
                                hintText: _isHorizontal ? '예) 5' : '예) 15',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                        ],
                      ),
                      if (!_isHorizontal) ...[
                        const SizedBox(height: 6),
                        Text(
                          '* 지하층은 음수로 입력 (예: -2)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 층(구역)당 세대(구획)수
                      TextFormField(
                        controller: _unitsController,
                        decoration: InputDecoration(
                          labelText: _isHorizontal ? '구역당 구획수' : '층당 세대수',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.grid_view_outlined),
                          hintText: _isHorizontal ? '예) 10' : '예) 4',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validatePositiveInt,
                      ),
                      const SizedBox(height: 14),

                      // ── 미리보기 ─────────────────────────────────
                      _buildPreview(),

                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check),
                        label: Text(
                          widget.onSetupComplete != null ? '건물 추가' : '대시보드 시작',
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrientationToggle() {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: _OrientationCard(
            selected: !_isHorizontal,
            title: '세로형',
            subtitle: '아파트·빌딩 등',
            color: color,
            child: const _VerticalBuildingIllust(),
            onTap: () => _onOrientationChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OrientationCard(
            selected: _isHorizontal,
            title: '가로형',
            subtitle: '시장·의료시설 등',
            color: color,
            child: const _HorizontalBuildingIllust(),
            onTap: () => _onOrientationChanged(true),
          ),
        ),
      ],
    );
  }

  // ── 입력값 기반 실시간 미리보기 (단계별 표시) ──────────────────
  Widget _buildPreview() {
    final start = int.tryParse(_startFloorController.text.trim());
    if (start == null) return const SizedBox.shrink();

    final end = int.tryParse(_endFloorController.text.trim());
    final units = int.tryParse(_unitsController.text.trim());

    // 끝층 미입력 시 시작층만 단독 표시
    final effectiveEnd = (end != null && end >= start) ? end : start;
    final hasEnd = end != null && end >= start;
    final hasUnits = units != null && units >= 1;

    // 층(구역) 목록 생성
    final allFloors = <int>[];
    if (_isHorizontal) {
      for (int f = start; f <= effectiveEnd; f++) allFloors.add(f);
    } else {
      for (int f = effectiveEnd; f >= start; f--) {
        if (f != 0) allFloors.add(f);
      }
      allFloors.insert(0, effectiveEnd + 1); // 옥상층
    }

    final totalFloors = allFloors.length;
    final effectiveUnits = hasUnits ? units! : 0;
    final totalCount = totalFloors * effectiveUnits;

    const maxShowFloors = 10;
    const maxShowUnits = 7;
    final showFloors = min(totalFloors, maxShowFloors);
    final showUnits = hasUnits ? min(effectiveUnits, maxShowUnits) : 3;
    final moreFloors = totalFloors > maxShowFloors;
    final moreUnits = hasUnits && effectiveUnits > maxShowUnits;

    const cellW = 28.0;
    const cellH = 19.0;
    const labelW = 36.0;
    const gap = 1.5;

    final floorUnit = _isHorizontal ? '구역' : '층';
    final unitUnit = _isHorizontal ? '구획' : '세대';

    Color floorBgColor(int floor) {
      if (!_isHorizontal && floor == effectiveEnd + 1) return Colors.blueGrey.shade200;
      return Colors.grey.shade200;
    }
    Color floorBdColor(int floor) {
      if (!_isHorizontal && floor == effectiveEnd + 1) return Colors.blueGrey.shade400;
      return Colors.grey.shade400;
    }
    String floorLabelText(int floor) {
      if (!_isHorizontal && floor == effectiveEnd + 1) return '옥상';
      if (_isHorizontal) return '$floor$floorUnit';
      if (floor < 0) return 'B${floor.abs()}';
      return '${floor}F';
    }

    Widget labelCell(int floor) => Container(
          width: labelW,
          height: cellH,
          margin: const EdgeInsets.all(gap / 2),
          decoration: BoxDecoration(
            color: floorBgColor(floor),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: floorBdColor(floor), width: 0.8),
          ),
          child: Center(
            child: Text(floorLabelText(floor),
                style:
                    const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        );

    Widget unitCell(int floor, int unitIdx) => Container(
          width: cellW,
          height: cellH,
          margin: const EdgeInsets.all(gap / 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Center(
            child: Text(
              _isHorizontal
                  ? '$unitIdx'
                  : (floor < 0
                      ? 'B${floor.abs() * 100 + unitIdx}'
                      : floor == effectiveEnd + 1
                          ? '옥$unitIdx'
                          : '${floor * 100 + unitIdx}'),
              style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

    // 세대수 미입력 시 점선 플레이스홀더 셀
    Widget placeholderCell() => Container(
          width: cellW,
          height: cellH,
          margin: const EdgeInsets.all(gap / 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Center(
            child: Text('?',
                style: TextStyle(fontSize: 7, color: Colors.grey.shade400)),
          ),
        );

    Widget moreCell({bool isFloor = false}) => Container(
          width: isFloor ? labelW : cellW,
          height: cellH,
          margin: const EdgeInsets.all(gap / 2),
          child: Center(
            child: Text('···',
                style:
                    TextStyle(fontSize: 8, color: Colors.grey.shade400)),
          ),
        );

    // 상태 요약 텍스트
    String summaryText() {
      if (!hasEnd && !hasUnits) {
        return '${floorLabelText(start)} 입력됨';
      } else if (!hasUnits) {
        return '총 $totalFloors$floorUnit | ${unitUnit}수 미입력';
      } else {
        return '총 $totalCount$unitUnit ($totalFloors$floorUnit × $effectiveUnits$unitUnit)';
      }
    }

    Color summaryColor() {
      if (!hasEnd || !hasUnits) return Colors.grey.shade500;
      return Colors.deepOrange.shade700;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(children: [
              Icon(Icons.grid_view_outlined,
                  size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('미리보기',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                summaryText(),
                style: TextStyle(
                    fontSize: 11,
                    color: summaryColor(),
                    fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 8),
            // 그리드
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 가로형: 상단 구획 번호 헤더 행
                  if (_isHorizontal)
                    Row(children: [
                      SizedBox(width: labelW + gap),
                      for (int ui = 1; ui <= showUnits; ui++)
                        SizedBox(
                          width: cellW + gap,
                          height: 14,
                          child: Center(
                            child: Text(
                              hasUnits ? '$ui호' : '?',
                              style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      if (moreUnits)
                        SizedBox(
                          width: cellW + gap,
                          height: 14,
                          child: Center(
                            child: Text('···',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey.shade400)),
                          ),
                        ),
                    ]),
                  // 각 층/구역 행
                  for (int fi = 0; fi < showFloors; fi++)
                    Row(children: [
                      labelCell(allFloors[fi]),
                      for (int ui = 1; ui <= showUnits; ui++)
                        hasUnits
                            ? unitCell(allFloors[fi], ui)
                            : placeholderCell(),
                      if (moreUnits) moreCell(),
                    ]),
                  // 더 많은 층/구역 표시
                  if (moreFloors)
                    Row(children: [
                      moreCell(isFloor: true),
                      Text(
                        '  … +${totalFloors - showFloors}개 $floorUnit 더',
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey.shade400),
                      ),
                    ]),
                ],
              ),
            ),
            // 범례 (세로형: 옥상층)
            if (!_isHorizontal) ...[
              const SizedBox(height: 6),
              _legend(
                  Colors.blueGrey.shade200, Colors.blueGrey.shade400, '옥상층'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend(Color bg, Color border, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: border, width: 0.8),
            ),
          ),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      );

}

// ── 방향 선택 카드 ──────────────────────────────────────────────
class _OrientationCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;
  final VoidCallback onTap;

  const _OrientationCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // 이미지 영역
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: child,
              ),
            ),
            // 텍스트 영역
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: selected ? color : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 세로형 빌딩 일러스트 (커스텀 그리기) ────────────────────────
class _VerticalBuildingIllust extends StatelessWidget {
  const _VerticalBuildingIllust();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BuildingPainter(),
    );
  }
}

class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE3F2FD);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final wall = Paint()..color = const Color(0xFF90A4AE);
    final window = Paint()..color = const Color(0xFF81D4FA);
    final dark = Paint()..color = const Color(0xFF546E7A);

    // 왼쪽 빌딩 (낮은 것)
    final b1x = size.width * 0.08;
    final b1w = size.width * 0.25;
    final b1h = size.height * 0.65;
    final b1y = size.height - b1h;
    canvas.drawRect(Rect.fromLTWH(b1x, b1y, b1w, b1h), wall);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 2; c++) {
        canvas.drawRect(
          Rect.fromLTWH(b1x + 6 + c * 13, b1y + 8 + r * 14, 8, 9),
          window,
        );
      }
    }

    // 중앙 빌딩 (높은 것)
    final b2x = size.width * 0.38;
    final b2w = size.width * 0.28;
    final b2h = size.height * 0.92;
    final b2y = size.height - b2h;
    canvas.drawRect(Rect.fromLTWH(b2x, b2y, b2w, b2h), dark);
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 2; c++) {
        canvas.drawRect(
          Rect.fromLTWH(b2x + 6 + c * 13, b2y + 6 + r * 12, 8, 8),
          window,
        );
      }
    }

    // 오른쪽 빌딩 (중간)
    final b3x = size.width * 0.7;
    final b3w = size.width * 0.22;
    final b3h = size.height * 0.75;
    final b3y = size.height - b3h;
    canvas.drawRect(Rect.fromLTWH(b3x, b3y, b3w, b3h), wall);
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 2; c++) {
        canvas.drawRect(
          Rect.fromLTWH(b3x + 5 + c * 11, b3y + 8 + r * 13, 7, 8),
          window,
        );
      }
    }

    // 지면
    final ground = Paint()..color = const Color(0xFF78909C);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 4, size.width, 4),
      ground,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 가로형 일러스트 ─────────────────────────────────────────────
class _HorizontalBuildingIllust extends StatelessWidget {
  const _HorizontalBuildingIllust();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MarketPainter());
  }
}

class _MarketPainter extends CustomPainter {
  static const _awningColors = [
    Color(0xFFE53935), // 빨강
    Color(0xFF1E88E5), // 파랑
    Color(0xFF43A047), // 초록
    Color(0xFFFB8C00), // 주황
    Color(0xFF8E24AA), // 보라
    Color(0xFF00ACC1), // 청록
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 (하늘)
    final sky = Paint()..color = const Color(0xFFFFF8E1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);

    final w = size.width;
    final h = size.height;

    const stalls = 6;
    final stallW = w / stalls;
    final buildingTop = h * 0.18;
    final buildingH = h * 0.62;
    final awningH = h * 0.18;

    final wall = Paint()..color = const Color(0xFFF5F5F5);
    final wallDark = Paint()..color = const Color(0xFFE0E0E0);
    final doorPaint = Paint()..color = const Color(0xFF6D4C41);
    final windowPaint = Paint()..color = const Color(0xFFB3E5FC);
    final groundPaint = Paint()..color = const Color(0xFF8D6E63);
    final roofPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;

    // 지붕 (전체 가로로 이어진 지붕)
    final roofPath = Path()
      ..moveTo(0, buildingTop)
      ..lineTo(w, buildingTop)
      ..lineTo(w, buildingTop + h * 0.06)
      ..lineTo(0, buildingTop + h * 0.06)
      ..close();
    canvas.drawPath(roofPath, roofPaint);

    // 벽 전체
    canvas.drawRect(
      Rect.fromLTWH(0, buildingTop + h * 0.06, w, buildingH),
      wall,
    );

    for (int i = 0; i < stalls; i++) {
      final sx = i * stallW;
      final awningColor = _awningColors[i % _awningColors.length];

      // 점포 구분선
      if (i > 0) {
        canvas.drawLine(
          Offset(sx, buildingTop),
          Offset(sx, buildingTop + buildingH + h * 0.06),
          dividerPaint,
        );
      }

      // 점포 벽 (약간 어두운 패널)
      canvas.drawRect(
        Rect.fromLTWH(
          sx + stallW * 0.08,
          buildingTop + h * 0.06 + buildingH * 0.04,
          stallW * 0.84,
          buildingH * 0.92,
        ),
        wallDark,
      );

      // 차양 (어닝)
      final awningPaint = Paint()..color = awningColor;
      final awningPath = Path()
        ..moveTo(sx + 2, buildingTop + h * 0.06)
        ..lineTo(sx + stallW - 2, buildingTop + h * 0.06)
        ..lineTo(sx + stallW + 2, buildingTop + h * 0.06 + awningH)
        ..lineTo(sx - 2, buildingTop + h * 0.06 + awningH)
        ..close();
      canvas.drawPath(awningPath, awningPaint);

      // 차양 줄무늬
      final stripePaint = Paint()
        ..color = awningColor.withAlpha(120)
        ..strokeWidth = 2;
      for (int s = 1; s < 4; s++) {
        final rx = sx + stallW * s / 4;
        canvas.drawLine(
          Offset(rx, buildingTop + h * 0.06),
          Offset(rx + 2, buildingTop + h * 0.06 + awningH),
          stripePaint,
        );
      }

      // 창문 (위)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            sx + stallW * 0.18,
            buildingTop + h * 0.06 + awningH + buildingH * 0.08,
            stallW * 0.62,
            buildingH * 0.28,
          ),
          const Radius.circular(2),
        ),
        windowPaint,
      );

      // 창문 십자 구분선
      final crossPaint = Paint()
        ..color = const Color(0xFF90CAF9)
        ..strokeWidth = 1;
      final winX = sx + stallW * 0.18;
      final winY = buildingTop + h * 0.06 + awningH + buildingH * 0.08;
      final winW = stallW * 0.62;
      final winH = buildingH * 0.28;
      canvas.drawLine(
        Offset(winX + winW / 2, winY),
        Offset(winX + winW / 2, winY + winH),
        crossPaint,
      );
      canvas.drawLine(
        Offset(winX, winY + winH / 2),
        Offset(winX + winW, winY + winH / 2),
        crossPaint,
      );

      // 출입문
      final doorW = stallW * 0.38;
      final doorH = buildingH * 0.35;
      final doorX = sx + (stallW - doorW) / 2;
      final doorY = buildingTop + h * 0.06 + buildingH - doorH;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(doorX, doorY, doorW, doorH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        doorPaint,
      );
      // 문 손잡이
      canvas.drawCircle(
        Offset(doorX + doorW * 0.72, doorY + doorH * 0.55),
        2,
        Paint()..color = const Color(0xFFFFD54F),
      );
    }

    // 지면
    canvas.drawRect(
      Rect.fromLTWH(0, buildingTop + h * 0.06 + buildingH, w, h * 0.14),
      groundPaint,
    );
    // 보도 라인
    final pavePaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 1;
    for (int i = 1; i < stalls; i++) {
      canvas.drawLine(
        Offset(i * stallW, buildingTop + h * 0.06 + buildingH),
        Offset(i * stallW, h),
        pavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
