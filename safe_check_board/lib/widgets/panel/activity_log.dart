import 'package:flutter/material.dart';
import '../../constants/status.dart';

class LogEntry {
  final DateTime timestamp;
  final String unitName;
  final UnitStatus fromStatus;
  final UnitStatus toStatus;
  final String? memo;

  LogEntry({
    required this.timestamp,
    required this.unitName,
    required this.fromStatus,
    required this.toStatus,
    this.memo,
  });
}

class ActivityLog extends StatelessWidget {
  final List<LogEntry> entries;

  const ActivityLog({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '활동 기록이 없습니다',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      reverse: true,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final time =
            '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.toStatus.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.unitName}: ${entry.fromStatus.label} → ${entry.toStatus.label}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
