import 'package:flutter/material.dart';
import '../../models/building.dart';
import '../../models/unit.dart';
import 'floor_row.dart';

class BuildingGrid extends StatelessWidget {
  final Building building;
  final Unit? selectedUnit;
  final ValueChanged<Unit> onUnitTap;
  final void Function(int floor) onFloorAllTap;

  const BuildingGrid({
    super.key,
    required this.building,
    required this.selectedUnit,
    required this.onUnitTap,
    required this.onFloorAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final floors = building.floorsDescending;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(40),
      minScale: 0.3,
      maxScale: 3.0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 호실 번호
            _buildHeader(),
            const Divider(height: 4),
            // 각 층
            ...floors.map(
              (floor) => FloorRow(
                floor: floor,
                units: building.unitsOnFloor(floor),
                selectedUnit: selectedUnit,
                onUnitTap: onUnitTap,
                onAllTap: () => onFloorAllTap(floor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final unitNumbers = building.unitNumbers;
    return Row(
      children: [
        const SizedBox(width: 44), // 층 라벨 자리
        const SizedBox(width: 4),
        const SizedBox(width: 40), // ALL 버튼 자리
        const SizedBox(width: 4),
        ...unitNumbers.map(
          (num) => SizedBox(
            width: 56,
            child: Center(
              child: Text(
                '$num호',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
