class Building {
  final String name;
  final int startFloor;
  final int endFloor;
  final int defaultUnits;  // 층(구역)당 세대(구획)수
  final bool isHorizontal; // 가로형(시장·의료) vs 세로형(아파트·빌딩)

  Building({
    required this.name,
    required this.startFloor,
    required this.endFloor,
    required this.defaultUnits,
    List<int>? pinanFloors, // 하위호환용 (무시)
    this.isHorizontal = false,
  });

  /// 옥상층 번호 (세로형만, endFloor + 1)
  int? get rooftopFloor => isHorizontal ? null : endFloor + 1;

  /// 유효 층 목록 (0층 제외, 세로형은 옥상층 포함)
  List<int> get floors {
    final result = <int>[];
    for (int i = startFloor; i <= endFloor; i++) {
      if (i != 0) result.add(i);
    }
    if (!isHorizontal) result.add(endFloor + 1); // 옥상층
    return result;
  }

  /// 위→아래 순서 (내림차순)
  List<int> get floorsDescending {
    final result = floors;
    result.sort((a, b) => b.compareTo(a));
    return result;
  }

}
