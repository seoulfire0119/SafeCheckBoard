import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../../models/building.dart';
import '../../models/team_entry.dart';

class EntryTimerPanel extends StatefulWidget {
  final List<Building> buildings;
  final void Function(Map<String, List<Color>>)? onFloorChanged;

  const EntryTimerPanel({
    super.key,
    this.buildings = const [],
    this.onFloorChanged,
  });

  @override
  State<EntryTimerPanel> createState() => _EntryTimerPanelState();
}

class _EntryTimerPanelState extends State<EntryTimerPanel> {
  int _warningMinutes = 15;
  int _dangerMinutes = 20;
  bool _soundEnabled = true;

  final List<TeamEntry> _teams = [
    TeamEntry(id: '1', name: '1착대', teamColor: TeamEntry.teamColors[0]),
    TeamEntry(id: '2', name: '2착대', teamColor: TeamEntry.teamColors[1]),
    TeamEntry(id: '3', name: '3착대', teamColor: TeamEntry.teamColors[2]),
  ];

  Timer? _clock;
  int _nextId = 4;
  int _nextUnitNum = 4; // 다음 착대 번호

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_tick);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  // ── 1초 틱 ────────────────────────────────────────────────
  void _tick() {
    bool changed = false;
    for (final team in _teams) {
      if (team.status == TeamStatus.waiting ||
          team.status == TeamStatus.paused) continue;

      final secs = team.elapsed.inSeconds;
      final mins = secs ~/ 60;
      final oldStatus = team.status;

      if (mins >= _dangerMinutes) {
        team.status = TeamStatus.danger;
      } else if (mins >= _warningMinutes) {
        team.status = TeamStatus.warning;
      } else {
        team.status = TeamStatus.active;
      }

      if (oldStatus != team.status) {
        changed = true;
        if (_soundEnabled) _playSound(team.status == TeamStatus.danger);
      }
      if ((team.status == TeamStatus.warning ||
              team.status == TeamStatus.danger) &&
          secs > 0 &&
          secs % 30 == 0 &&
          _soundEnabled) {
        _playSound(team.status == TeamStatus.danger);
      }
    }
    if (changed) _notifyFloorChanged();
  }

  void _playSound(bool isDanger) {
    try {
      final freq = isDanger ? 1000 : 800;
      js.context.callMethod('eval', [
        '(()=>{try{var c=new AudioContext(),o=c.createOscillator(),'
            'g=c.createGain();o.connect(g);g.connect(c.destination);'
            'o.frequency.value=$freq;o.type="square";g.gain.value=0.15;'
            'g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.5);'
            'o.start();o.stop(c.currentTime+0.5)}catch(e){}})()'
      ]);
    } catch (_) {}
  }

  // ── 플로어→색상 맵 알림 ────────────────────────────────────
  void _notifyFloorChanged() {
    if (widget.onFloorChanged == null) return;
    final map = <String, List<Color>>{};
    for (final team in _teams) {
      if (team.assignedFloorKey != null &&
          team.assignedFloorKey!.isNotEmpty &&
          team.status != TeamStatus.waiting) {
        map.putIfAbsent(team.assignedFloorKey!, () => []).add(team.teamColor);
      }
    }
    widget.onFloorChanged!(map);
  }

  // ── 층 레이블 파생 ─────────────────────────────────────────
  String _getFloorLabel(String key) {
    final parts = key.split('_');
    if (parts.length != 2) return key;
    final bi = int.tryParse(parts[0]);
    final fl = int.tryParse(parts[1]);
    if (bi == null || fl == null || bi >= widget.buildings.length) return key;
    final building = widget.buildings[bi];
    final flLabel = building.isHorizontal
        ? '${fl}구역'
        : fl < 0
            ? 'B${fl.abs()}F'
            : '${fl}F';
    return widget.buildings.length > 1 ? '${building.name} > $flLabel' : flLabel;
  }

  List<DropdownMenuItem<String>> _buildFloorItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('선택 안함')),
    ];
    for (var bi = 0; bi < widget.buildings.length; bi++) {
      final building = widget.buildings[bi];
      for (final floor in building.floorsDescending) {
        final key = '${bi}_$floor';
        final flLabel = building.isHorizontal
            ? '${floor}구역'
            : floor < 0
                ? 'B${floor.abs()}F'
                : '${floor}F';
        final displayLabel = widget.buildings.length > 1
            ? '${building.name} > $flLabel'
            : flLabel;
        items.add(DropdownMenuItem(value: key, child: Text(displayLabel)));
      }
    }
    return items;
  }

  // ── 팀 조작 ───────────────────────────────────────────────
  void _start(TeamEntry t) {
    setState(() {
      t.status = TeamStatus.active;
      t.entryTime = DateTime.now();
      t.pausedElapsed = null;
      t.pausedFromStatus = null;
    });
    _notifyFloorChanged();
  }

  void _pause(TeamEntry t) {
    setState(() {
      t.pausedElapsed = t.elapsed;
      t.pausedFromStatus = t.status;
      t.status = TeamStatus.paused;
    });
    _notifyFloorChanged();
  }

  void _resume(TeamEntry t) {
    setState(() {
      final elapsed = t.pausedElapsed ?? Duration.zero;
      t.entryTime = DateTime.now().subtract(elapsed);
      final mins = elapsed.inMinutes;
      t.status = mins >= _dangerMinutes
          ? TeamStatus.danger
          : mins >= _warningMinutes
              ? TeamStatus.warning
              : TeamStatus.active;
      t.pausedFromStatus = null;
    });
    _notifyFloorChanged();
  }

  void _reset(TeamEntry t) {
    setState(() {
      t.status = TeamStatus.waiting;
      t.entryTime = null;
      t.pausedElapsed = null;
      t.pausedFromStatus = null;
    });
    _notifyFloorChanged();
  }

  // ── 다이얼로그 ────────────────────────────────────────────
  void _confirmReset(TeamEntry t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${t.name}" 초기화'),
        content: const Text('타이머를 초기화하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              _reset(t);
              Navigator.pop(ctx);
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(TeamEntry t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${t.name}" 삭제'),
        content: const Text('이 팀을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _teams.remove(t));
              _notifyFloorChanged();
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditDialog([TeamEntry? editing]) {
    final unitCtrl = TextEditingController(text: editing?.unit ?? '');
    String selectedFloorKey = editing?.assignedFloorKey ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: editing == null
              ? Text('대 추가 (${_nextUnitNum}착대)')
              : Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: editing.teamColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${editing.name} 편집'),
                  ],
                ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: unitCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '단대명',
                  hintText: '예) 신수대, 성산119',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              widget.buildings.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: selectedFloorKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '활동구역',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _buildFloorItems(),
                      onChanged: (v) =>
                          setSt(() => selectedFloorKey = v ?? ''),
                    )
                  : TextField(
                      decoration: const InputDecoration(
                        labelText: '활동구역/비고 (선택)',
                        hintText: '예) 4층, B1~3층',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => selectedFloorKey = v,
                    ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            FilledButton(
              onPressed: () {
                final unit = unitCtrl.text.trim().isEmpty
                    ? null
                    : unitCtrl.text.trim();
                final floorKey = selectedFloorKey.isEmpty
                    ? null
                    : selectedFloorKey;
                final floorLabel =
                    floorKey != null ? _getFloorLabel(floorKey) : null;

                if (editing != null) {
                  setState(() {
                    editing.unit = unit;
                    editing.assignedFloorKey = floorKey;
                    editing.note = floorLabel;
                  });
                } else {
                  final color = TeamEntry
                      .teamColors[_teams.length % TeamEntry.teamColors.length];
                  setState(() => _teams.add(TeamEntry(
                        id: '${_nextId++}',
                        name: '${_nextUnitNum++}착대',
                        teamColor: color,
                        unit: unit,
                        assignedFloorKey: floorKey,
                        note: floorLabel,
                      )));
                }
                _notifyFloorChanged();
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final warnCtrl = TextEditingController(text: _warningMinutes.toString());
    final dangerCtrl = TextEditingController(text: _dangerMinutes.toString());
    bool sound = _soundEnabled;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('타이머 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: warnCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '경고 시간(분)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: dangerCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '위험 시간(분)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('소리 알림'),
                value: sound,
                onChanged: (v) => setSt(() => sound = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _warningMinutes =
                      int.tryParse(warnCtrl.text) ?? _warningMinutes;
                  _dangerMinutes =
                      int.tryParse(dangerCtrl.text) ?? _dangerMinutes;
                  _soundEnabled = sound;
                });
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    int waiting = 0, active = 0, warning = 0, danger = 0;
    for (final t in _teams) {
      switch (t.status) {
        case TeamStatus.waiting:
          waiting++;
          break;
        case TeamStatus.active:
        case TeamStatus.paused:
          active++;
          break;
        case TeamStatus.warning:
          warning++;
          break;
        case TeamStatus.danger:
          danger++;
          break;
      }
    }

    // ── 헤더: 타이틀+버튼 / 상태칩 2줄 구조
    final header = Container(
      color: const Color(0xFF1A237E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1줄: 타이틀 + 설정 버튼
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Text(
                  '진입 타이머',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const Spacer(),
                // 설정 버튼 — 더 큰 터치 영역
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _showSettingsDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.settings,
                              color: Colors.white70, size: 16),
                          SizedBox(width: 4),
                          Text('설정',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 2줄: 상태 칩
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                _chip('대기', waiting, Colors.grey.shade400),
                _chip('진입', active, Colors.green.shade400),
                _chip('경고', warning, Colors.orange.shade500),
                _chip('위험', danger, Colors.red.shade500),
              ],
            ),
          ),
        ],
      ),
    );

    // ── 팀 추가 카드
    final addCard = Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _showAddOrEditDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.indigo.shade200, width: 1.5,
                  style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline,
                    size: 18, color: Colors.indigo.shade400),
                const SizedBox(width: 6),
                Text(
                  '${_nextUnitNum}착대 추가',
                  style: TextStyle(
                      color: Colors.indigo.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (_teams.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('등록된 대가 없습니다',
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showAddOrEditDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('첫 번째 대 추가'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            sliver: SliverList.separated(
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _teams.length,
              itemBuilder: (_, i) {
                final team = _teams[i];
                final isFirst = team.id == '1';
                final displayStatus = team.status == TeamStatus.paused
                    ? (team.pausedFromStatus ?? TeamStatus.active)
                    : team.status;
                return _TeamTimerCard(
                  team: team,
                  displayStatus: displayStatus,
                  warningMinutes: _warningMinutes,
                  dangerMinutes: _dangerMinutes,
                  canDelete: !isFirst,
                  onStart: () => _start(team),
                  onPause: () => _pause(team),
                  onResume: () => _resume(team),
                  onReset: () => _confirmReset(team),
                  onEdit: () => _showAddOrEditDialog(team),
                  onDelete: () => _confirmDelete(team),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: addCard),
        ],
      ],
    );
  }

  Widget _chip(String label, int count, Color color) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$label $count',
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
        ),
      );
}

// ── 팀 카드 ─────────────────────────────────────────────────

class _TeamTimerCard extends StatelessWidget {
  final TeamEntry team;
  final TeamStatus displayStatus;
  final int warningMinutes;
  final int dangerMinutes;
  final bool canDelete;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TeamTimerCard({
    required this.team,
    required this.displayStatus,
    required this.warningMinutes,
    required this.dangerMinutes,
    required this.canDelete,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = dangerMinutes > 0
        ? (team.elapsed.inSeconds / (dangerMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: displayStatus.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                // 팀 색상 원
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: team.teamColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: team.teamColor.withAlpha(120),
                          blurRadius: 3)
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // 상태 점
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: displayStatus.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(team.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (team.unit != null) ...[
                  const SizedBox(width: 6),
                  Text(team.unit!,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade600)),
                ],
                if (team.note != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: team.teamColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: team.teamColor.withAlpha(100), width: 1),
                    ),
                    child: Text(
                      team.note!,
                      style: TextStyle(
                          fontSize: 10,
                          color: team.teamColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: Colors.grey.shade500),
                  ),
                ),
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 14, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 바디: 원형 링 + 상태
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CustomPaint(
                    painter: _CircularTimerPainter(
                      progress: progress.toDouble(),
                      color: displayStatus.color,
                      ringColor: team.teamColor,
                    ),
                    child: Center(
                      child: Text(
                        team.elapsedDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: displayStatus.color,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: displayStatus.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          team.status == TeamStatus.paused
                              ? '일시정지'
                              : displayStatus.label,
                          style: TextStyle(
                            color: displayStatus.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '경고 ${warningMinutes}분 / 위험 ${dangerMinutes}분',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 버튼
            Row(
              children: [
                if (team.status == TeamStatus.waiting)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: const Text('진입 시작',
                          style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  )
                else if (team.status == TeamStatus.paused)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: const Text('이어서',
                          style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPause,
                      icon: const Icon(Icons.pause, size: 14),
                      label: const Text('일시정지',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side:
                            BorderSide(color: Colors.orange.shade400),
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                  child: const Icon(Icons.refresh, size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 원형 타이머 CustomPainter ───────────────────────────────

class _CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color ringColor;

  _CircularTimerPainter({
    required this.progress,
    required this.color,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.0;
    const startAngle = -pi / 2;

    // 팀 색상 배경 트랙
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 진행 아크 (상태 색상)
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularTimerPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.ringColor != ringColor;
}
