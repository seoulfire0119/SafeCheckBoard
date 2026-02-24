import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';
import '../panel/activity_log.dart';
import '../panel/status_buttons.dart';

class ActionPanel extends StatelessWidget {
  final Unit? selectedUnit;
  final List<Unit>? selectedFloorUnits;
  final int? selectedFloor;
  final List<LogEntry> logEntries;
  final ValueChanged<UnitStatus> onStatusChanged;
  final ValueChanged<String> onMemoChanged;
  final VoidCallback onMemoPinToggle;

  const ActionPanel({
    super.key,
    required this.selectedUnit,
    this.selectedFloorUnits,
    this.selectedFloor,
    required this.logEntries,
    required this.onStatusChanged,
    required this.onMemoChanged,
    required this.onMemoPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 선택된 호실 정보
          _buildSelectionHeader(context),
          const Divider(height: 1),
          // 상태 변경 버튼
          Padding(
            padding: const EdgeInsets.all(12),
            child: StatusButtons(
              currentStatus: selectedUnit?.status,
              onStatusChanged: onStatusChanged,
              enabled: selectedUnit != null || selectedFloorUnits != null,
            ),
          ),
          const Divider(height: 1),
          // 메모 영역
          if (selectedUnit != null) _buildMemoSection(context),
          if (selectedUnit != null) const Divider(height: 1),
          // 활동 로그
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 4),
                Text(
                  '활동 로그',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${logEntries.length}건',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ActivityLog(entries: logEntries),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final String title;
    final String subtitle;

    if (selectedFloorUnits != null && selectedFloor != null) {
      title = '${selectedFloor}층 전체';
      final count = selectedFloorUnits!.length;
      subtitle = '$count개 호실 선택됨';
    } else if (selectedUnit != null) {
      title = selectedUnit!.fullName;
      subtitle = '상태: ${selectedUnit!.status.label}';
    } else {
      title = '호실을 선택하세요';
      subtitle = '그리드에서 호실을 탭하세요';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: selectedUnit != null
          ? selectedUnit!.status.color.withAlpha(30)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildMemoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note, size: 16),
              const SizedBox(width: 4),
              Text('메모', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                icon: Icon(
                  selectedUnit!.memoPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  size: 18,
                ),
                onPressed: onMemoPinToggle,
                tooltip: '메모 고정',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(
                '${selectedUnit!.floor}-${selectedUnit!.number}'),
            initialValue: selectedUnit!.memo,
            decoration: const InputDecoration(
              hintText: '메모를 입력하세요...',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            maxLines: 3,
            onChanged: onMemoChanged,
          ),
        ],
      ),
    );
  }
}
