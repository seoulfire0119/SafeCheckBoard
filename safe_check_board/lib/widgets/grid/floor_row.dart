import 'package:flutter/material.dart';
import '../../models/unit.dart';
import 'unit_cell.dart';

class FloorRow extends StatefulWidget {
  final int floor;
  final List<Unit> units;
  final int totalUnitSlots;
  final Unit? selectedUnit;
  final Set<int> selectedFloors;
  final bool isRooftop;
  final String? customLabel;
  final bool isHorizontal;
  final List<Color> teamColors; // 진입 팀 색상 목록 (여러 대 동시 가능)
  final ValueChanged<Unit> onUnitTap;
  final VoidCallback onAllTap;
  final void Function(int floor, int unitIndex) onEmptyCellTap;
  final void Function(int floor, String label) onLabelChanged;

  const FloorRow({
    super.key,
    required this.floor,
    required this.units,
    required this.totalUnitSlots,
    required this.selectedUnit,
    required this.selectedFloors,
    this.isRooftop = false,
    this.customLabel,
    this.isHorizontal = false,
    this.teamColors = const [],
    required this.onUnitTap,
    required this.onAllTap,
    required this.onEmptyCellTap,
    required this.onLabelChanged,
  });

  @override
  State<FloorRow> createState() => _FloorRowState();
}

class _FloorRowState extends State<FloorRow>
    with SingleTickerProviderStateMixin {
  bool _editingLabel = false;
  late TextEditingController _labelController;

  AnimationController? _pulseCtrl;
  Animation<double>? _pulseScale;
  Animation<double>? _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _labelController =
        TextEditingController(text: widget.customLabel ?? _defaultLabel);
    if (widget.teamColors.isNotEmpty) _startAnimation();
  }

  @override
  void didUpdateWidget(FloorRow old) {
    super.didUpdateWidget(old);
    if (!_editingLabel) {
      _labelController.text = widget.customLabel ?? _defaultLabel;
    }
    if (widget.teamColors.isNotEmpty && _pulseCtrl == null) {
      _startAnimation();
    } else if (widget.teamColors.isEmpty && _pulseCtrl != null) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
  }

  void _stopAnimation() {
    _pulseCtrl?.dispose();
    _pulseCtrl = null;
    _pulseScale = null;
    _pulseOpacity = null;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  String get _defaultLabel {
    if (widget.isHorizontal) return '${widget.floor}구역';
    if (widget.floor < 0) return 'B${widget.floor.abs()}F';
    return '${widget.floor}F';
  }

  bool get _isFloorSelected => widget.selectedFloors.contains(widget.floor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFloorLabel(),
          const SizedBox(width: 3),
          _buildAllButton(),
          const SizedBox(width: 3),
          ..._buildUnitCells(),
          // 소방관 아이콘 (진입 팀 있을 때만)
          if (widget.teamColors.isNotEmpty &&
              _pulseScale != null &&
              _pulseOpacity != null) ...[
            const SizedBox(width: 6),
            AnimatedBuilder(
              animation: _pulseCtrl!,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.teamColors.asMap().entries.map((e) {
                  final idx = e.key;
                  final color = e.value;
                  // 각 아이콘마다 위상 약간 다르게 (0.0 ~ 0.5 오프셋)
                  final phase = (idx * 0.25).clamp(0.0, 0.75);
                  final t = (((_pulseCtrl!.value + phase) % 1.0));
                  final scale = 0.88 + (0.24 * (t < 0.5 ? t * 2 : (1 - t) * 2));
                  final opacity = 0.75 + (0.25 * (t < 0.5 ? t * 2 : (1 - t) * 2));
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: _FirefighterIcon(color: color),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildUnitCells() {
    final cells = <Widget>[];
    int slotIdx = 1;
    while (slotIdx <= widget.totalUnitSlots) {
      final unit = widget.units.firstWhere(
        (u) => u.unitIndex == slotIdx,
        orElse: () =>
            Unit(id: '', floor: widget.floor, unitIndex: slotIdx, number: 0),
      );

      if (unit.id.isNotEmpty) {
        final span =
            unit.spanCount.clamp(1, widget.totalUnitSlots - slotIdx + 1);
        cells.add(SizedBox(
          width: span * 56.0,
          height: 42,
          child: UnitCell(
            unit: unit,
            isSelected: widget.selectedUnit?.id == unit.id,
            isHorizontal: widget.isHorizontal,
            isRooftop: widget.isRooftop,
            onTap: () => widget.onUnitTap(unit),
          ),
        ));
        slotIdx += span;
      } else {
        final capturedSlot = slotIdx;
        cells.add(SizedBox(
          width: 56,
          height: 42,
          child: EmptyUnitCell(
            onTap: () => widget.onEmptyCellTap(widget.floor, capturedSlot),
          ),
        ));
        slotIdx++;
      }
    }
    return cells;
  }

  Widget _buildFloorLabel() {
    if (_editingLabel) {
      return SizedBox(
        width: 48,
        height: 42,
        child: TextField(
          controller: _labelController,
          autofocus: true,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            widget.onLabelChanged(widget.floor, v.trim());
            setState(() => _editingLabel = false);
          },
          onEditingComplete: () {
            widget.onLabelChanged(
                widget.floor, _labelController.text.trim());
            setState(() => _editingLabel = false);
          },
        ),
      );
    }

    final vulnerableCount =
        widget.units.where((u) => u.vulnerable).length;

    return GestureDetector(
      onDoubleTap: () => setState(() => _editingLabel = true),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isRooftop
                  ? Colors.blueGrey.shade200
                  : (_isFloorSelected
                      ? Colors.orange.shade100
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(4),
              border: _isFloorSelected
                  ? Border.all(color: Colors.deepOrange, width: 1.5)
                  : widget.isRooftop
                      ? Border.all(
                          color: Colors.blueGrey.shade400, width: 1.5)
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.customLabel ?? _defaultLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isRooftop
                        ? Colors.blueGrey.shade900
                        : Colors.black87,
                  ),
                ),
                if (widget.isRooftop)
                  Text(
                    '옥상',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          if (vulnerableCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: VulnerableFloorBadge(count: vulnerableCount),
            ),
        ],
      ),
    );
  }

  Widget _buildAllButton() {
    return SizedBox(
      width: 36,
      height: 42,
      child: Material(
        color: _isFloorSelected
            ? Colors.orange.shade100
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: widget.onAllTap,
          child: Center(
            child: Text(
              'ALL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _isFloorSelected
                    ? Colors.deepOrange.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 소방관 아이콘 ───────────────────────────────────────────

class _FirefighterIcon extends StatelessWidget {
  final Color color;

  const _FirefighterIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(80),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🧑‍🚒',
            style: TextStyle(
              fontSize: 16,
              shadows: [
                Shadow(
                  color: color.withAlpha(200),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 숨겨진 층 그룹 요약 행
class HiddenFloorsRow extends StatelessWidget {
  final List<int> floors;
  final bool isHorizontal;
  final VoidCallback onShow;

  const HiddenFloorsRow({
    super.key,
    required this.floors,
    this.isHorizontal = false,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: onShow,
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Icon(Icons.expand_more, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                isHorizontal
                    ? '숨겨진 구역 ${floors.length}개 (클릭하여 표시)'
                    : '숨겨진 층 ${floors.length}개 (클릭하여 표시)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
