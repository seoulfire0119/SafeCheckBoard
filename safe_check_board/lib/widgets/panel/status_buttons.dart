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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3열 그리드 - 8가지 상태 버튼
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: UnitStatus.values.length,
          itemBuilder: (context, index) {
            final status = UnitStatus.values[index];
            final isActive = currentStatus == status;
            return _StatusBtn(
              status: status,
              isActive: isActive,
              enabled: enabled,
              onTap: enabled ? () => onStatusChanged(status) : null,
            );
          },
        ),
        if (onVulnerableToggle != null) ...[
          const SizedBox(height: 6),
          // 노약자 토글 버튼
          OutlinedButton.icon(
            onPressed: enabled ? onVulnerableToggle : null,
            icon: Icon(
              Icons.elderly_outlined,
              size: 16,
              color: (isVulnerable ?? false) ? Colors.orange.shade700 : null,
            ),
            label: Text(
              '요구조자(노약자)',
              style: TextStyle(
                color: (isVulnerable ?? false) ? Colors.orange.shade700 : null,
                fontWeight: (isVulnerable ?? false)
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: (isVulnerable ?? false)
                    ? Colors.orange.shade400
                    : Colors.grey.shade400,
                width: (isVulnerable ?? false) ? 2 : 1,
              ),
              backgroundColor: (isVulnerable ?? false)
                  ? Colors.orange.shade50
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ],
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
    return Material(
      color: isActive ? status.color : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.black : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                status.icon,
                size: 14,
                color: isActive ? status.textColor : Colors.grey.shade600,
              ),
              const SizedBox(height: 2),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? status.textColor : Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
