import '../constants/status.dart';

class Unit {
  final int floor;
  final int number;
  UnitStatus status;
  String memo;
  bool memoPinned;

  Unit({
    required this.floor,
    required this.number,
    this.status = UnitStatus.unknown,
    this.memo = '',
    this.memoPinned = false,
  });

  String get displayName => '$number호';

  String get fullName => '$floor층 $number호';

  Unit copyWith({
    UnitStatus? status,
    String? memo,
    bool? memoPinned,
  }) {
    return Unit(
      floor: floor,
      number: number,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      memoPinned: memoPinned ?? this.memoPinned,
    );
  }
}
