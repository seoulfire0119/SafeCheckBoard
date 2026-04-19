import 'package:flutter/material.dart';

enum UnitStatus {
  unknown,       // 미확인
  empty,         // 공실
  confirmed,     // 확인완료
  danger,        // 화재층
  fireFalseAlarm, // 연소확대층
  resourceBase,  // 자원대기소
}

extension UnitStatusExtension on UnitStatus {
  String get label {
    switch (this) {
      case UnitStatus.unknown:
        return '미확인';
      case UnitStatus.empty:
        return '공실';
      case UnitStatus.confirmed:
        return '확인완료';
      case UnitStatus.danger:
        return '화재층';
      case UnitStatus.fireFalseAlarm:
        return '연소확대층';
      case UnitStatus.resourceBase:
        return '자원대기소';
    }
  }

  Color get color {
    switch (this) {
      case UnitStatus.unknown:
        return const Color(0xFF9E9E9E); // grey
      case UnitStatus.empty:
        return const Color(0xFF90CAF9); // blue-200
      case UnitStatus.confirmed:
        return const Color(0xFF66BB6A); // green-400
      case UnitStatus.danger:
        return const Color(0xFFEF5350); // red-400
      case UnitStatus.fireFalseAlarm:
        return const Color(0xFFFFA726); // orange-400
      case UnitStatus.resourceBase:
        return const Color(0xFFAB47BC); // purple-400
    }
  }

  Color get textColor {
    switch (this) {
      case UnitStatus.unknown:
      case UnitStatus.empty:
        return Colors.black87;
      case UnitStatus.confirmed:
      case UnitStatus.danger:
      case UnitStatus.fireFalseAlarm:
      case UnitStatus.resourceBase:
        return Colors.white;
    }
  }

  IconData get icon {
    switch (this) {
      case UnitStatus.unknown:
        return Icons.help_outline;
      case UnitStatus.empty:
        return Icons.person_off_outlined;
      case UnitStatus.confirmed:
        return Icons.check_circle_outline;
      case UnitStatus.danger:
        return Icons.local_fire_department;
      case UnitStatus.fireFalseAlarm:
        return Icons.fireplace_outlined;
      case UnitStatus.resourceBase:
        return Icons.groups_outlined;
    }
  }
}
