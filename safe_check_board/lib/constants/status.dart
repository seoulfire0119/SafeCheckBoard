import 'package:flutter/material.dart';

enum UnitStatus {
  unknown,        // 미확인
  confirmed,      // 확인완료
  danger,         // 화재층
  fireFalseAlarm, // 연소확대층
  resourceBase,   // 자원대기소
}

extension UnitStatusExtension on UnitStatus {
  String get label {
    switch (this) {
      case UnitStatus.unknown:        return '미확인';
      case UnitStatus.confirmed:      return '확인완료';
      case UnitStatus.danger:         return '화재층';
      case UnitStatus.fireFalseAlarm: return '연소확대층';
      case UnitStatus.resourceBase:   return '자원대기소';
    }
  }

  Color get color {
    switch (this) {
      case UnitStatus.unknown:        return const Color(0xFF757575);
      case UnitStatus.confirmed:      return const Color(0xFF43A047);
      case UnitStatus.danger:         return const Color(0xFFE53935);
      case UnitStatus.fireFalseAlarm: return const Color(0xFFFB8C00);
      case UnitStatus.resourceBase:   return const Color(0xFF8E24AA);
    }
  }

  Color get textColor {
    return Colors.white;
  }

  IconData get icon {
    switch (this) {
      case UnitStatus.unknown:        return Icons.help_outline;
      case UnitStatus.confirmed:      return Icons.check_circle_outline;
      case UnitStatus.danger:         return Icons.local_fire_department;
      case UnitStatus.fireFalseAlarm: return Icons.warning_amber;
      case UnitStatus.resourceBase:   return Icons.groups_outlined;
    }
  }
}
