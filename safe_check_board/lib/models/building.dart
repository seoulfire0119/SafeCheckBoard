import 'unit.dart';

class Building {
  final String name;
  final int startFloor;
  final int endFloor;
  final int startUnit;
  final int endUnit;
  final List<Unit> units;

  Building({
    required this.name,
    required this.startFloor,
    required this.endFloor,
    required this.startUnit,
    required this.endUnit,
    required this.units,
  });

  factory Building.create({
    required String name,
    required int startFloor,
    required int endFloor,
    required int startUnit,
    required int endUnit,
  }) {
    final units = <Unit>[];
    final floors = _generateFloors(startFloor, endFloor);

    for (final floor in floors) {
      for (int unit = startUnit; unit <= endUnit; unit++) {
        units.add(Unit(floor: floor, number: unit));
      }
    }

    return Building(
      name: name,
      startFloor: startFloor,
      endFloor: endFloor,
      startUnit: startUnit,
      endUnit: endUnit,
      units: units,
    );
  }

  /// 층 목록 생성 (0층 제외, 지하층 지원)
  static List<int> _generateFloors(int start, int end) {
    final floors = <int>[];
    for (int i = start; i <= end; i++) {
      if (i == 0) continue; // 0층은 존재하지 않음
      floors.add(i);
    }
    return floors;
  }

  /// 정렬된 층 목록 (위→아래 표시를 위해 내림차순)
  List<int> get floorsDescending {
    final floors = _generateFloors(startFloor, endFloor);
    floors.sort((a, b) => b.compareTo(a));
    return floors;
  }

  /// 호실 번호 목록 (오름차순)
  List<int> get unitNumbers {
    return List.generate(
      endUnit - startUnit + 1,
      (i) => startUnit + i,
    );
  }

  /// 특정 층의 유닛들
  List<Unit> unitsOnFloor(int floor) {
    return units.where((u) => u.floor == floor).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  /// 특정 유닛 찾기
  Unit? findUnit(int floor, int number) {
    try {
      return units.firstWhere(
        (u) => u.floor == floor && u.number == number,
      );
    } catch (_) {
      return null;
    }
  }
}
