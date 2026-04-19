import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../../models/team_entry.dart';

class EntryTimerPanel extends StatefulWidget {
  const EntryTimerPanel({super.key});

  @override
  State<EntryTimerPanel> createState() => _EntryTimerPanelState();
}

class _EntryTimerPanelState extends State<EntryTimerPanel> {
  int _warningMinutes = 15;
  int _dangerMinutes = 20;
  bool _soundEnabled = true;

  final List<TeamEntry> _teams = [
    TeamEntry(id: '1', name: '1착대'),
    TeamEntry(id: '2', name: '2착대'),
    TeamEntry(id: '3', name: '3착대'),
  ];

  Timer? _clock;
  int _nextId = 4;

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

      // 상태 변경 시 즉시 알림
      if (oldStatus != team.status && _soundEnabled) {
        _playSound(team.status == TeamStatus.danger);
      }
      // 경고/위험 상태 30초마다 반복 알림
      if ((team.status == TeamStatus.warning ||
              team.status == TeamStatus.danger) &&
          secs > 0 &&
          secs % 30 == 0 &&
          _soundEnabled) {
        _playSound(team.status == TeamStatus.danger);
      }
    }
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

  // ── 팀 조작 ───────────────────────────────────────────────
  void _start(TeamEntry t) => setState(() {
        t.status = TeamStatus.active;
        t.entryTime = DateTime.now();
        t.pausedElapsed = null;
        t.pausedFromStatus = null;
      });

  void _pause(TeamEntry t) => setState(() {
        t.pausedElapsed = t.elapsed;
        t.pausedFromStatus = t.status;
        t.status = TeamStatus.paused;
      });

  void _resume(TeamEntry t) => setState(() {
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

  void _reset(TeamEntry t) => setState(() {
        t.status = TeamStatus.waiting;
        t.entryTime = null;
        t.pausedElapsed = null;
        t.pausedFromStatus = null;
      });

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
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditDialog([TeamEntry? editing]) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final unitCtrl = TextEditingController(text: editing?.unit ?? '');
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? '대 추가' : '대 편집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '대명',
                hintText: '예) 1착대, 2착대',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: '단대명 (선택)',
                hintText: '예) 신수대, 성산119',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: '활동구역/비고 (선택)',
                hintText: '예) 4층, B1~3층, 계단실',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final unit =
                  unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim();
              final note =
                  noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
              if (editing != null) {
                setState(() {
                  editing.name = name;
                  editing.unit = unit;
                  editing.note = note;
                });
              } else {
                setState(() => _teams.add(TeamEntry(
                      id: '${_nextId++}',
                      name: name,
                      unit: unit,
                      note: note,
                    )));
              }
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final warnCtrl =
        TextEditingController(text: _warningMinutes.toString());
    final dangerCtrl =
        TextEditingController(text: _dangerMinutes.toString());
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

    // ── 상황 요약바 ────────────────────────────────────────
    final statusBar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1A237E),
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
          const SizedBox(width: 10),
          _chip('대기', waiting, Colors.grey.shade400),
          _chip('진입', active, Colors.green.shade400),
          _chip('경고', warning, Colors.orange.shade500),
          _chip('위험', danger, Colors.red.shade500),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70, size: 18),
            onPressed: _showSettingsDialog,
            tooltip: '설정',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          if (_teams.length < 7)
            IconButton(
              icon: const Icon(Icons.group_add, color: Colors.white, size: 18),
              onPressed: () => _showAddOrEditDialog(),
              tooltip: '대 추가',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );

    // ── CustomScrollView로 Expanded 없이 구성 (높이 제약 문제 해결) ──
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: statusBar),
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
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _showAddOrEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('첫 번째 대 추가'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList.separated(
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _teams.length,
              itemBuilder: (_, i) {
                final team = _teams[i];
                final displayStatus = team.status == TeamStatus.paused
                    ? (team.pausedFromStatus ?? TeamStatus.active)
                    : team.status;
                return _TeamTimerCard(
                  team: team,
                  displayStatus: displayStatus,
                  warningMinutes: _warningMinutes,
                  dangerMinutes: _dangerMinutes,
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
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: displayStatus.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
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
                  Text('// ${team.note}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
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

  _CircularTimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.0;
    const startAngle = -pi / 2;

    // 배경 트랙
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 진행 아크
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
      old.progress != progress || old.color != color;
}
