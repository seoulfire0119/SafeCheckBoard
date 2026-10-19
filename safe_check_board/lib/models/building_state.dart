import 'unit.dart';
import 'building.dart';

class BuildingState {
  List<Unit> units;
  Set<int> hiddenFloors;
  Map<int, String> floorLabels; // floor -> custom label

  BuildingState({
    required this.units,
    Set<int>? hiddenFloors,
    Map<int, String>? floorLabels,
  })  : hiddenFloors = hiddenFloors ?? {},
        floorLabels = floorLabels ?? {};

  Unit? findUnit(int floor, int unitIndex) {
    final id = Unit.makeId(floor, unitIndex);
    try {
      return units.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Unit> unitsOnFloor(int floor) {
    return units.where((u) => u.floor == floor).toList()
      ..sort((a, b) => a.unitIndex.compareTo(b.unitIndex));
  }

  /// 건물 구조로부터 초기 유닛 생성
  static BuildingState create(Building building) {
    final units = <Unit>[];
    final floorLabels = <int, String>{};

    for (final floor in building.floors) {
      for (int i = 1; i <= building.defaultUnits; i++) {
        final id = Unit.makeId(floor, i);
        final int number;
        if (floor > 0) {
          number = floor * 100 + i;
        } else {
          // 지하층: B1의 1호 → 표시는 B101호
          number = -(floor.abs() * 100 + i);
        }
        units.add(Unit(
          id: id,
          floor: floor,
          unitIndex: i,
          number: number,
        ));
      }
    }

    // 세로형: 옥상층 레이블 자동 설정
    if (building.rooftopFloor != null) {
      floorLabels[building.rooftopFloor!] = '옥상층';
    }

    return BuildingState(units: units, floorLabels: floorLabels);
  }
}
