import 'package:flutter/material.dart';
import '../../constants/status.dart';

class StatusButtons extends StatelessWidget {
  final UnitStatus? currentStatus;
  final ValueChanged<UnitStatus> onStatusChanged;
  final bool enabled;

  const StatusButtons({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UnitStatus.values.map((status) {
        final isActive = currentStatus == status;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: enabled ? () => onStatusChanged(status) : null,
            icon: Icon(status.icon, size: 18),
            label: Text(status.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? status.color : Colors.grey.shade100,
              foregroundColor: isActive ? status.textColor : Colors.black87,
              elevation: isActive ? 3 : 0,
              side: BorderSide(
                color: isActive ? status.color : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      }).toList(),
    );
  }
}
