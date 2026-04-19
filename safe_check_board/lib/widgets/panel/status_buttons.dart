import 'package:flutter/material.dart';
import '../../constants/status.dart';

class StatusButtons extends StatelessWidget {
  final UnitStatus? currentStatus;
  final bool? isVulnerable;
  final ValueChanged<UnitStatus> onStatusChanged;
  final VoidCallback? onVulnerableToggle;
  final bool enabled;

  const StatusButtons({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.isVulnerable,
    this.onVulnerableToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = UnitStatus.values;

    return _buildStatusGrid(
      statuses,
      currentStatus,
      enabled,
      onStatusChanged,
      isVulnerable: isVulnerable,
      onVulnerableToggle: onVulnerableToggle != null && enabled
          ? onVulnerableToggle
          : null,
    );
  }
}

Widget _buildStatusGrid(
  List<UnitStatus> statuses,
  UnitStatus? current,
  bool enabled,
  ValueChanged<UnitStatus> onChanged, {
  bool? isVulnerable,
  VoidCallback? onVulnerableToggle,
}) {
  // 상태버튼 + 요구조자 버튼을 하나의 리스트로 합쳐 2열 배치
  final rows = <Widget>[];

  // 상태 버튼 위젯 목록
  final cells = <Widget>[
    for (final s in statuses)
      _StatusBtn(
        status: s,
        isActive: current == s,
        enabled: enabled,
        onTap: enabled ? () => onChanged(s) : null,
      ),
    // 요구조자 버튼 (상태버튼과 동일 스타일)
    if (onVulnerableToggle != null)
      _VulnerableBtn(
        isActive: isVulnerable ?? false,
        onTap: onVulnerableToggle,
      ),
  ];

  for (var i = 0; i < cells.length; i += 2) {
    final left = cells[i];
    final right = i + 1 < cells.length ? cells[i + 1] : null;
    rows.add(
      IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right ?? const SizedBox()),
          ],
        ),
      ),
    );
    if (i + 2 < cells.length) rows.add(const SizedBox(height: 8));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

class _VulnerableBtn extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _VulnerableBtn({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFFE65100); // 진한 주황
    final bg = isActive ? baseColor : baseColor.withAlpha(45);
    final fg = isActive ? Colors.white : baseColor;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? baseColor : baseColor.withAlpha(100),
              width: isActive ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.elderly, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '요구조자',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final UnitStatus status;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  const _StatusBtn({
    required this.status,
    required this.isActive,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = status.color;
    final bg = isActive ? baseColor : baseColor.withAlpha(45);
    final fg = isActive ? Colors.white : baseColor;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? baseColor : baseColor.withAlpha(100),
              width: isActive ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(status.icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
