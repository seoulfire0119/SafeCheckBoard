import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';
import 'unit_cell.dart';

class FloorRow extends StatelessWidget {
  final int floor;
  final List<Unit> units;
  final Unit? selectedUnit;
  final ValueChanged<Unit> onUnitTap;
  final VoidCallback onAllTap;

  const FloorRow({
    super.key,
    required this.floor,
    required this.units,
    required this.selectedUnit,
    required this.onUnitTap,
    required this.onAllTap,
  });

  /// 층의 대표 상태 색상 (가장 심각한 상태 기준)
  Color _floorIndicatorColor() {
    if (units.any((u) => u.status == UnitStatus.danger)) {
      return UnitStatus.danger.color;
    }
    if (units.any((u) => u.status == UnitStatus.checking)) {
      return UnitStatus.checking.color;
    }
    if (units.any((u) => u.status == UnitStatus.unknown)) {
      return UnitStatus.unknown.color;
    }
    if (units.every((u) => u.status == UnitStatus.confirmed)) {
      return UnitStatus.confirmed.color;
    }
    return Colors.grey.shade300;
  }

  String _floorLabel(int floor) {
    if (floor < 0) return 'B${floor.abs()}';
    return '${floor}F';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // 층 번호 라벨
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _floorIndicatorColor().withAlpha(60),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _floorLabel(floor),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // ALL 버튼
          SizedBox(
            width: 40,
            height: 44,
            child: Material(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onAllTap,
                child: const Center(
                  child: Text(
                    'ALL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 호실 셀들
          ...units.map(
            (unit) => SizedBox(
              width: 56,
              height: 44,
              child: UnitCell(
                unit: unit,
                isSelected: selectedUnit?.floor == unit.floor &&
                    selectedUnit?.number == unit.number,
                onTap: () => onUnitTap(unit),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
