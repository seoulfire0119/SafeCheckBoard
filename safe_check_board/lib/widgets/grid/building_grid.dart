import 'package:flutter/material.dart';
import '../../models/building.dart';
import '../../models/building_state.dart';
import '../../models/unit.dart';
import 'floor_row.dart';

class _Segment {
  final bool isHidden;
  final List<int> floors;
  _Segment({required this.isHidden, required this.floors});
}

class BuildingGrid extends StatelessWidget {
  final int buildingIdx;
  final Building building;
  final BuildingState state;
  final Unit? selectedUnit;
  final Set<int> selectedFloors;
  final Map<String, List<Color>> floorTeamColors;
  final ValueChanged<Unit> onUnitTap;
  final ValueChanged<int> onFloorAllTap;       // floor
  final void Function(int floor, int unitIndex) onEmptyCellTap;
  final void Function(int floor, String label) onFloorLabelChanged;
  final void Function(List<int> floors) onShowHiddenFloors;

  const BuildingGrid({
    super.key,
    required this.buildingIdx,
    required this.building,
    required this.state,
    required this.selectedUnit,
    required this.selectedFloors,
    this.floorTeamColors = const <String, List<Color>>{},
    required this.onUnitTap,
    required this.onFloorAllTap,
    required this.onEmptyCellTap,
    required this.onFloorLabelChanged,
    required this.onShowHiddenFloors,
  });

  List<_Segment> _buildSegments(List<int> floors) {
    final segments = <_Segment>[];
    List<int> currentHidden = [];

    for (final floor in floors) {
      if (state.hiddenFloors.contains(floor)) {
        currentHidden.add(floor);
      } else {
        if (currentHidden.isNotEmpty) {
          segments.add(_Segment(isHidden: true, floors: List.from(currentHidden)));
          currentHidden.clear();
        }
        segments.add(_Segment(isHidden: false, floors: [floor]));
      }
    }
    if (currentHidden.isNotEmpty) {
      segments.add(_Segment(isHidden: true, floors: List.from(currentHidden)));
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final floors = building.floorsDescending;
    final segments = _buildSegments(floors);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(height: 4, thickness: 1),
              ...segments.map((seg) {
                if (seg.isHidden) {
                  return HiddenFloorsRow(
                    floors: seg.floors,
                    isHorizontal: building.isHorizontal,
                    onShow: () => onShowHiddenFloors(seg.floors),
                  );
                }
                final floor = seg.floors.first;
                return FloorRow(
                  floor: floor,
                  units: state.unitsOnFloor(floor),
                  totalUnitSlots: building.defaultUnits,
                  selectedUnit: selectedUnit,
                  selectedFloors: selectedFloors,
                  isRooftop: floor == building.rooftopFloor,
                  customLabel: state.floorLabels[floor],
                  isHorizontal: building.isHorizontal,
                  teamColors: floorTeamColors['${buildingIdx}_$floor'] ?? const [],
                  onUnitTap: onUnitTap,
                  onAllTap: () => onFloorAllTap(floor),
                  onEmptyCellTap: onEmptyCellTap,
                  onLabelChanged: onFloorLabelChanged,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 48), // 층 라벨 자리
        const SizedBox(width: 3),
        const SizedBox(width: 36), // ALL 자리
        const SizedBox(width: 3),
        ...List.generate(building.defaultUnits, (i) {
          return SizedBox(
            width: 56,
            child: Center(
              child: Text(
                building.isHorizontal ? '${i + 1}번' : '${i + 1}호',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
