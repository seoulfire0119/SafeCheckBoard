import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/log_entry.dart';

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
            style: TextStyle(color: Colors.grey, fontSize: 12),
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
        final t = entry.time;
        final time =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.to.color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${entry.unitName}: ${entry.from.label} → ${entry.to.label}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
