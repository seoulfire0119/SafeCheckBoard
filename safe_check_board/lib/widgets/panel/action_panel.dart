import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';
import '../../models/log_entry.dart';
import 'activity_log.dart';
import 'status_buttons.dart';

class ActionPanel extends StatelessWidget {
  final Unit? selectedUnit;
  final List<Unit>? selectedFloorUnits; // 층 전체 선택 시
  final int? selectedFloor;
  final int? activeBuildingIdx;
  final List<LogEntry> logEntries;
  final ValueChanged<UnitStatus> onStatusChanged;
  final ValueChanged<String> onMemoChanged;
  final VoidCallback? onMemoPinToggle;
  final VoidCallback? onVulnerableToggle;
  final VoidCallback? onDeactivateUnit;   // 공백으로 만들기
  final VoidCallback? onHideFloor;        // 층 숨기기/보이기
  final bool isFloorHidden;
  final VoidCallback? onMergeRight;       // 우측 셀과 병합
  final VoidCallback? onSplitUnit;        // 병합 분리

  const ActionPanel({
    super.key,
    required this.selectedUnit,
    this.selectedFloorUnits,
    this.selectedFloor,
    this.activeBuildingIdx,
    required this.logEntries,
    required this.onStatusChanged,
    required this.onMemoChanged,
    this.onMemoPinToggle,
    this.onVulnerableToggle,
    this.onDeactivateUnit,
    this.onHideFloor,
    this.isFloorHidden = false,
    this.onMergeRight,
    this.onSplitUnit,
  });

  bool get _hasSelection => selectedUnit != null || selectedFloorUnits != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        border: Border(
          left: BorderSide(color: Colors.orange.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          // 상태 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: StatusButtons(
              currentStatus: selectedUnit?.status,
              isVulnerable: selectedUnit?.vulnerable,
              onStatusChanged: onStatusChanged,
              onVulnerableToggle:
                  selectedUnit != null ? onVulnerableToggle : null,
              enabled: _hasSelection,
            ),
          ),
          // 단일 유닛 선택 시 추가 액션
          if (selectedUnit != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 병합/분리 버튼
                  if (onMergeRight != null || onSplitUnit != null)
                    Row(
                      children: [
                        if (onMergeRight != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onMergeRight,
                              icon: const Icon(Icons.table_chart_outlined, size: 14),
                              label: const Text('우측 병합', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.deepOrange.shade700,
                                side: BorderSide(color: Colors.deepOrange.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        if (onMergeRight != null && onSplitUnit != null)
                          const SizedBox(width: 6),
                        if (onSplitUnit != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onSplitUnit,
                              icon: const Icon(Icons.vertical_split_outlined, size: 14),
                              label: const Text('세대 분리', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                side: BorderSide(color: Colors.blue.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (onMergeRight != null || onSplitUnit != null)
                    const SizedBox(height: 6),
                  // 공백으로 만들기
                  OutlinedButton.icon(
                    onPressed: onDeactivateUnit,
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('공백으로 만들기', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 층 선택 시 숨기기 버튼
          if (selectedFloor != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                onPressed: onHideFloor,
                icon: Icon(
                  isFloorHidden ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                ),
                label: Text(
                  isFloorHidden ? '층 표시' : '층 숨기기',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 1),
          // 메모 영역
          if (selectedUnit != null) ...[
            _buildMemoSection(context),
            const Divider(height: 1),
          ],
          // 활동 로그
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '활동 로그',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                const Spacer(),
                Text(
                  '${logEntries.length}건',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(child: ActivityLog(entries: logEntries)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final String title;
    final String subtitle;
    Color? bgColor;

    if (selectedFloor != null && selectedFloorUnits != null) {
      title = '${selectedFloor}층 전체';
      subtitle = '${selectedFloorUnits!.length}개 호실';
      bgColor = Colors.orange.shade50;
    } else if (selectedUnit != null) {
      title = selectedUnit!.fullName;
      subtitle = selectedUnit!.status.label;
      bgColor = selectedUnit!.status.color.withAlpha(30);
    } else {
      title = '호실을 선택하세요';
      subtitle = '그리드에서 호실 또는 층을 탭하세요';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '메모',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.grey.shade700),
              ),
              const Spacer(),
              if (onMemoPinToggle != null)
                GestureDetector(
                  onTap: onMemoPinToggle,
                  child: Icon(
                    selectedUnit!.memoPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    size: 16,
                    color: selectedUnit!.memoPinned
                        ? Colors.orange.shade700
                        : Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(selectedUnit!.id),
            initialValue: selectedUnit!.memo,
            decoration: InputDecoration(
              hintText: '메모를 입력하세요...',
              hintStyle:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: 3,
            onChanged: onMemoChanged,
          ),
        ],
      ),
    );
  }
}
