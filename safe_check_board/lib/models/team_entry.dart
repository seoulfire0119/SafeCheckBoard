import 'package:flutter/material.dart';

enum TeamStatus { waiting, active, warning, danger, paused }

extension TeamStatusX on TeamStatus {
  String get label {
    switch (this) {
      case TeamStatus.waiting: return '대기';
      case TeamStatus.active:  return '진입중';
      case TeamStatus.warning: return '경고';
      case TeamStatus.danger:  return '위험';
      case TeamStatus.paused:  return '일시정지';
    }
  }

  Color get color {
    switch (this) {
      case TeamStatus.waiting: return Colors.grey.shade400;
      case TeamStatus.active:  return Colors.green.shade500;
      case TeamStatus.warning: return Colors.orange.shade600;
      case TeamStatus.danger:  return Colors.red.shade600;
      case TeamStatus.paused:  return Colors.blueGrey.shade300;
    }
  }

  Color get textColor =>
      (this == TeamStatus.waiting || this == TeamStatus.paused)
          ? Colors.black87
          : Colors.white;
}

class TeamEntry {
  final String id;
  String name;
  String? unit;  // 단대명 (예: 신수대)
  String? note;  // 활동구역/비고 (예: 4층, B1~3층)
  TeamStatus status;
  DateTime? entryTime;
  Duration? pausedElapsed;
  TeamStatus? pausedFromStatus;

  TeamEntry({
    required this.id,
    required this.name,
    this.unit,
    this.note,
    this.status = TeamStatus.waiting,
    this.entryTime,
    this.pausedElapsed,
    this.pausedFromStatus,
  });

  Duration get elapsed {
    if (status == TeamStatus.paused) return pausedElapsed ?? Duration.zero;
    if (entryTime == null) return Duration.zero;
    return DateTime.now().difference(entryTime!);
  }

  String get elapsedDisplay {
    final d = elapsed;
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
