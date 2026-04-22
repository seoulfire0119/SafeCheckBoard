import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';
import '../../models/log_entry.dart';
import 'activity_log.dart';
import 'status_buttons.dart';
import 'chat_panel.dart';

class ActionPanel extends StatelessWidget {
  final Unit? selectedUnit;
  final List<Unit>? selectedFloorUnits;
  final int? selectedFloor;
  final int? activeBuildingIdx;
  final List<LogEntry> logEntries;
  final ValueChanged<UnitStatus> onStatusChanged;
  final ValueChanged<String> onMemoChanged;
  final VoidCallback? onMemoPinToggle;
  final VoidCallback? onVulnerableToggle;
  final VoidCallback? onDeactivateUnit;
  final VoidCallback? onHideFloor;
  final bool isFloorHidden;
  final VoidCallback? onMergeRight;
  final VoidCallback? onSplitUnit;
  final String? sessionCode;

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
    this.sessionCode,
  });

  bool get _hasSelection => selectedUnit != null || selectedFloorUnits != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        border: Border(left: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(selectedUnit: selectedUnit, selectedFloor: selectedFloor, selectedFloorUnits: selectedFloorUnits),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 상태 변경
                  _SectionLabel(label: '상태 변경'),
                  const SizedBox(height: 8),
                  StatusButtons(
                    currentStatus: selectedUnit?.status,
                    isVulnerable: selectedUnit?.vulnerable,
                    onStatusChanged: onStatusChanged,
                    onVulnerableToggle: selectedUnit != null ? onVulnerableToggle : null,
                    enabled: _hasSelection,
                  ),

                  // 메모 (단일 유닛 선택 시)
                  if (selectedUnit != null) ...[
                    const SizedBox(height: 14),
                    _MemoSection(
                      unit: selectedUnit!,
                      onMemoChanged: onMemoChanged,
                      onMemoPinToggle: onMemoPinToggle,
                    ),
                  ],

                  // 층 숨기기 (층 선택 시)
                  if (selectedFloor != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onHideFloor,
                      icon: Icon(
                        isFloorHidden ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                      ),
                      label: Text(isFloorHidden ? '층 표시' : '층 숨기기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],

                  // 편집 (병합/분리/비활성화) — 접힘
                  if (selectedUnit != null) ...[
                    const SizedBox(height: 12),
                    _EditSection(
                      onMergeRight: onMergeRight,
                      onSplitUnit: onSplitUnit,
                      onDeactivateUnit: onDeactivateUnit,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 활동 로그
                  _SectionLabel(label: '활동 로그 (${logEntries.length}건)'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 180,
                    child: ActivityLog(entries: logEntries),
                  ),
                ],
              ),
            ),
          ),

          // 채팅창
          if (sessionCode != null) ...[
            const Divider(height: 1),
            SizedBox(
              height: 260,
              child: ChatPanel(sessionCode: sessionCode!),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 헤더 ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Unit? selectedUnit;
  final int? selectedFloor;
  final List<Unit>? selectedFloorUnits;

  const _Header({this.selectedUnit, this.selectedFloor, this.selectedFloorUnits});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    Color bgColor = Colors.transparent;

    if (selectedFloor != null && selectedFloorUnits != null) {
      title = '$selectedFloor층 전체';
      subtitle = '${selectedFloorUnits!.length}개 호실';
      bgColor = Colors.orange.shade50;
    } else if (selectedUnit != null) {
      title = selectedUnit!.fullName;
      subtitle = selectedUnit!.status.label;
      bgColor = selectedUnit!.status.color.withAlpha(25);
    } else {
      title = '호실을 선택하세요';
      subtitle = '그리드에서 호실 또는 층을 탭하세요';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: bgColor,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (selectedUnit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selectedUnit!.status.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selectedUnit!.status.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 섹션 레이블 ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── 메모 섹션 ────────────────────────────────────────────────

class _MemoSection extends StatelessWidget {
  final Unit unit;
  final ValueChanged<String> onMemoChanged;
  final VoidCallback? onMemoPinToggle;

  const _MemoSection({
    required this.unit,
    required this.onMemoChanged,
    this.onMemoPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(label: '메모'),
            const Spacer(),
            if (onMemoPinToggle != null)
              GestureDetector(
                onTap: onMemoPinToggle,
                child: Row(
                  children: [
                    Icon(
                      unit.memoPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 15,
                      color: unit.memoPinned ? Colors.orange.shade700 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '고정',
                      style: TextStyle(
                        fontSize: 11,
                        color: unit.memoPinned ? Colors.orange.shade700 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey(unit.id),
          initialValue: unit.memo,
          decoration: InputDecoration(
            hintText: '특이사항을 입력하세요...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
          maxLines: 3,
          onChanged: onMemoChanged,
        ),
      ],
    );
  }
}

// ── 편집 섹션 (접힘) ─────────────────────────────────────────

class _EditSection extends StatelessWidget {
  final VoidCallback? onMergeRight;
  final VoidCallback? onSplitUnit;
  final VoidCallback? onDeactivateUnit;

  const _EditSection({this.onMergeRight, this.onSplitUnit, this.onDeactivateUnit});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          '셀 편집',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        iconColor: Colors.grey.shade400,
        collapsedIconColor: Colors.grey.shade400,
        children: [
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (onMergeRight != null || onSplitUnit != null)
                  const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeactivateUnit,
                    icon: const Icon(Icons.remove_circle_outline, size: 14),
                    label: const Text('공백', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
