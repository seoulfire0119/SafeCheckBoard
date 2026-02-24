import 'package:flutter/material.dart';
import '../constants/status.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../widgets/grid/building_grid.dart';
import '../widgets/panel/action_panel.dart';
import '../widgets/panel/activity_log.dart';

class DashboardScreen extends StatefulWidget {
  final Building building;

  const DashboardScreen({super.key, required this.building});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Unit? _selectedUnit;
  List<Unit>? _selectedFloorUnits;
  int? _selectedFloor;
  final List<LogEntry> _logEntries = [];

  void _onUnitTap(Unit unit) {
    setState(() {
      _selectedUnit = unit;
      _selectedFloorUnits = null;
      _selectedFloor = null;
    });
  }

  void _onFloorAllTap(int floor) {
    setState(() {
      _selectedUnit = null;
      _selectedFloorUnits = widget.building.unitsOnFloor(floor);
      _selectedFloor = floor;
    });
  }

  void _onStatusChanged(UnitStatus newStatus) {
    setState(() {
      if (_selectedFloorUnits != null) {
        // 층 전체 변경
        for (final unit in _selectedFloorUnits!) {
          final oldStatus = unit.status;
          if (oldStatus != newStatus) {
            unit.status = newStatus;
            _logEntries.add(LogEntry(
              timestamp: DateTime.now(),
              unitName: unit.fullName,
              fromStatus: oldStatus,
              toStatus: newStatus,
            ));
          }
        }
      } else if (_selectedUnit != null) {
        final oldStatus = _selectedUnit!.status;
        if (oldStatus != newStatus) {
          _selectedUnit!.status = newStatus;
          _logEntries.add(LogEntry(
            timestamp: DateTime.now(),
            unitName: _selectedUnit!.fullName,
            fromStatus: oldStatus,
            toStatus: newStatus,
          ));
        }
      }
    });
  }

  void _onMemoChanged(String memo) {
    if (_selectedUnit != null) {
      _selectedUnit!.memo = memo;
    }
  }

  void _onMemoPinToggle() {
    if (_selectedUnit != null) {
      setState(() {
        _selectedUnit!.memoPinned = !_selectedUnit!.memoPinned;
      });
    }
  }

  /// 상태별 통계
  Map<UnitStatus, int> _statusCounts() {
    final counts = <UnitStatus, int>{};
    for (final status in UnitStatus.values) {
      counts[status] =
          widget.building.units.where((u) => u.status == status).length;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final counts = _statusCounts();
    final total = widget.building.units.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('SCB - ${widget.building.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // 상태 요약 칩들
          ...UnitStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: status.color,
                  radius: 8,
                ),
                label: Text(
                  '${counts[status]}',
                  style: const TextStyle(fontSize: 12),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '총 $total실',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // 좌측 그리드 (70%)
        Expanded(
          flex: 7,
          child: BuildingGrid(
            building: widget.building,
            selectedUnit: _selectedUnit,
            onUnitTap: _onUnitTap,
            onFloorAllTap: _onFloorAllTap,
          ),
        ),
        // 우측 패널 (30%)
        SizedBox(
          width: 320,
          child: ActionPanel(
            selectedUnit: _selectedUnit,
            selectedFloorUnits: _selectedFloorUnits,
            selectedFloor: _selectedFloor,
            logEntries: _logEntries,
            onStatusChanged: _onStatusChanged,
            onMemoChanged: _onMemoChanged,
            onMemoPinToggle: _onMemoPinToggle,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          child: BuildingGrid(
            building: widget.building,
            selectedUnit: _selectedUnit,
            onUnitTap: (unit) {
              _onUnitTap(unit);
              _showBottomSheet();
            },
            onFloorAllTap: (floor) {
              _onFloorAllTap(floor);
              _showBottomSheet();
            },
          ),
        ),
      ],
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: SizedBox(
                    height: 500,
                    child: ActionPanel(
                      selectedUnit: _selectedUnit,
                      selectedFloorUnits: _selectedFloorUnits,
                      selectedFloor: _selectedFloor,
                      logEntries: _logEntries,
                      onStatusChanged: (status) {
                        _onStatusChanged(status);
                        setModalState(() {});
                      },
                      onMemoChanged: _onMemoChanged,
                      onMemoPinToggle: () {
                        _onMemoPinToggle();
                        setModalState(() {});
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
