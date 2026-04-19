import '../constants/status.dart';

class Unit {
  final String id;       // "${floor}-${unitIndex}"
  final int floor;
  final int unitIndex;   // 1-based position within floor
  final int number;      // display number (floor*100+unitIndex for positive floors)
  UnitStatus status;
  String memo;
  bool memoPinned;
  bool vulnerable;       // 요구조자/노약자
  int spanCount;         // 병합 슬롯 수 (기본 1)

  Unit({
    required this.id,
    required this.floor,
    required this.unitIndex,
    required this.number,
    this.status = UnitStatus.unknown,
    this.memo = '',
    this.memoPinned = false,
    this.vulnerable = false,
    this.spanCount = 1,
  });

  static String makeId(int floor, int unitIndex) => '$floor-$unitIndex';

  String get displayNumber {
    if (floor < 0) {
      return 'B${floor.abs()}${unitIndex.toString().padLeft(2, '0')}호';
    }
    return '${number}호';
  }

  String get floorLabel {
    if (floor < 0) return 'B${floor.abs()}F';
    return '${floor}F';
  }

  String get fullName => '${floor < 0 ? "B${floor.abs()}층" : "${floor}층"} $displayNumber';

  Unit copyWith({
    UnitStatus? status,
    String? memo,
    bool? memoPinned,
    bool? vulnerable,
    int? spanCount,
  }) {
    return Unit(
      id: id,
      floor: floor,
      unitIndex: unitIndex,
      number: number,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      memoPinned: memoPinned ?? this.memoPinned,
      vulnerable: vulnerable ?? this.vulnerable,
      spanCount: spanCount ?? this.spanCount,
    );
  }
}
