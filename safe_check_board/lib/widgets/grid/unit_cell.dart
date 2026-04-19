import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';

/// 층 라벨에 붙는 자기 애니메이션 요구조자 뱃지
class VulnerableFloorBadge extends StatefulWidget {
  final int count;
  const VulnerableFloorBadge({super.key, required this.count});

  @override
  State<VulnerableFloorBadge> createState() => _VulnerableFloorBadgeState();
}

class _VulnerableFloorBadgeState extends State<VulnerableFloorBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final glow = _anim.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Color.lerp(Colors.red.shade700, Colors.orange.shade400, glow),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withAlpha((180 * glow).round()),
                blurRadius: 6 + 4 * glow,
                spreadRadius: glow * 2,
              ),
            ],
          ),
          child: Text(
            '⚠ ${widget.count}',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────

/// 실제 유닛이 있는 셀
class UnitCell extends StatefulWidget {
  final Unit unit;
  final bool isSelected;
  final bool isHorizontal;
  final bool isRooftop;
  final VoidCallback onTap;

  const UnitCell({
    super.key,
    required this.unit,
    required this.isSelected,
    this.isHorizontal = false,
    this.isRooftop = false,
    required this.onTap,
  });

  @override
  State<UnitCell> createState() => _UnitCellState();
}

class _UnitCellState extends State<UnitCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _anim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    if (widget.unit.vulnerable) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(UnitCell old) {
    super.didUpdateWidget(old);
    if (widget.unit.vulnerable && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.unit.vulnerable && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.unit.status;
    final hasMemo = widget.unit.memo.isNotEmpty;
    final vulnerable = widget.unit.vulnerable;

    if (!vulnerable) {
      return _buildCell(context, status, hasMemo, null);
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => _buildCell(context, status, hasMemo, _anim.value),
    );
  }

  Widget _buildCell(
      BuildContext context, UnitStatus status, bool hasMemo, double? t) {
    // 옥상층: unknown 상태일 때 slate-blue 색상으로 덮어씀
    final cellColor = (widget.isRooftop && status == UnitStatus.unknown)
        ? Colors.blueGrey.shade300
        : status.color;
    final cellTextColor = (widget.isRooftop && status == UnitStatus.unknown)
        ? Colors.white
        : status.textColor;

    final borderColor = t != null
        ? Color.lerp(Colors.red.shade600, Colors.yellow.shade300, t)!
        : (widget.isRooftop ? Colors.blueGrey.shade400 : Colors.black12);
    final borderWidth = t != null ? 2.5 + 1.5 * t : (widget.isRooftop ? 1.0 : 0.5);

    final List<BoxShadow> shadows = [];
    if (widget.isSelected) {
      shadows.add(BoxShadow(
        color: Colors.black.withAlpha(80),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ));
    }
    if (t != null) {
      shadows.add(BoxShadow(
        color: Colors.red.withAlpha((160 * t).round()),
        blurRadius: 6 + 6 * t,
        spreadRadius: t * 2.5,
      ));
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(5),
          border: widget.isSelected
              ? Border.all(color: Colors.black, width: 2.5)
              : Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows.isEmpty ? null : shadows,
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isRooftop
                          ? '옥상${widget.unit.unitIndex}'
                          : widget.isHorizontal
                              ? '${widget.unit.unitIndex}번'
                              : widget.unit.displayNumber,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cellTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.unit.memoPinned)
                      Icon(Icons.push_pin, size: 9, color: cellTextColor),
                  ],
                ),
              ),
            ),
            // 노약자 좌하단 아이콘
            if (t != null)
              Positioned(
                bottom: 1,
                left: 2,
                child: Icon(
                  Icons.elderly,
                  size: 10,
                  color: Color.lerp(Colors.red.shade300, Colors.yellow.shade200, t),
                ),
              ),
            // 메모 인디케이터 (우상단)
            if (hasMemo)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.unit.memoPinned
                        ? Colors.red.shade600
                        : Colors.orange.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────

/// 빈 셀 (유닛 없는 슬롯)
class EmptyUnitCell extends StatelessWidget {
  final VoidCallback onTap;

  const EmptyUnitCell({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Center(
          child: Icon(Icons.add, size: 12, color: Colors.grey.shade400),
        ),
      ),
    );
  }
}
