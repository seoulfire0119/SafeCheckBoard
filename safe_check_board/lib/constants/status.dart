import 'package:flutter/material.dart';

enum UnitStatus {
  unknown,    // 미확인
  checking,   // 확인 중
  empty,      // 부재 (빈 호실)
  confirmed,  // 확인 완료 (안전)
  danger,     // 위험/구조 필요
}

extension UnitStatusExtension on UnitStatus {
  String get label {
    switch (this) {
      case UnitStatus.unknown:
        return '미확인';
      case UnitStatus.checking:
        return '확인 중';
      case UnitStatus.empty:
        return '부재';
      case UnitStatus.confirmed:
        return '확인 완료';
      case UnitStatus.danger:
        return '위험';
    }
  }

  Color get color {
    switch (this) {
      case UnitStatus.unknown:
        return Colors.grey.shade400;
      case UnitStatus.checking:
        return Colors.amber.shade400;
      case UnitStatus.empty:
        return Colors.blue.shade300;
      case UnitStatus.confirmed:
        return Colors.green.shade400;
      case UnitStatus.danger:
        return Colors.red.shade500;
    }
  }

  Color get textColor {
    switch (this) {
      case UnitStatus.unknown:
      case UnitStatus.checking:
      case UnitStatus.empty:
        return Colors.black87;
      case UnitStatus.confirmed:
      case UnitStatus.danger:
        return Colors.white;
    }
  }

  IconData get icon {
    switch (this) {
      case UnitStatus.unknown:
        return Icons.help_outline;
      case UnitStatus.checking:
        return Icons.search;
      case UnitStatus.empty:
        return Icons.person_off;
      case UnitStatus.confirmed:
        return Icons.check_circle;
      case UnitStatus.danger:
        return Icons.warning;
    }
  }
}
