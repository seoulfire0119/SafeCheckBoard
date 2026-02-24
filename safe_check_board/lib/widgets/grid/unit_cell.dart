import 'package:flutter/material.dart';
import '../../constants/status.dart';
import '../../models/unit.dart';

class UnitCell extends StatelessWidget {
  final Unit unit;
  final bool isSelected;
  final VoidCallback onTap;

  const UnitCell({
    super.key,
    required this.unit,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = unit.status;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: status.color,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: Colors.black, width: 2.5)
              : Border.all(color: Colors.black12, width: 0.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    unit.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.textColor,
                    ),
                  ),
                  if (unit.memoPinned)
                    Icon(
                      Icons.push_pin,
                      size: 10,
                      color: status.textColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
