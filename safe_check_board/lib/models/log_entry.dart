import '../constants/status.dart';

class LogEntry {
  final int id;
  final String unitName;
  final UnitStatus from;
  final UnitStatus to;
  final DateTime time;

  LogEntry({
    required this.id,
    required this.unitName,
    required this.from,
    required this.to,
    required this.time,
  });
}
