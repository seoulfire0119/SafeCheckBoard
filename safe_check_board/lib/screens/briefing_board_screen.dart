import 'package:flutter/material.dart';
import '../models/briefing_record.dart';
import '../services/briefing_service.dart';
import 'disaster_briefing_screen.dart';

class BriefingBoardScreen extends StatelessWidget {
  final String? sessionCode;
  final VoidCallback? onClose;
  const BriefingBoardScreen({super.key, this.sessionCode, this.onClose});

  static const _tabNames = ['초동 브리핑', '중간 브리핑', '공식 보고서'];
  static const _tabColors = [
    Color(0xFFBF360C),
    Color(0xFF1565C0),
    Color(0xFF0D1B2A),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('브리핑 게시판'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBriefing(context, null),
        icon: const Icon(Icons.add),
        label: const Text('새 브리핑'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<BriefingRecord>>(
        stream: BriefingService.stream(sessionCode ?? '__local__'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('저장된 브리핑이 없습니다',
                      style: TextStyle(color: Colors.black45, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _BriefingTile(
              record: list[i],
              tabNames: _tabNames,
              tabColors: _tabColors,
              onTap: () => _openBriefing(context, list[i]),
              onEditTitle: () => _editTitle(context, list[i]),
              onDelete: () => _confirmDelete(context, list[i]),
            ),
          );
        },
      ),
    );
  }

  void _openBriefing(BuildContext context, BriefingRecord? record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DisasterBriefingScreen(
          initialRecord: record,
          sessionCode: sessionCode,
        ),
      ),
    );
  }

  Future<void> _editTitle(BuildContext context, BriefingRecord record) async {
    final ctrl = TextEditingController(text: record.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제목 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '제목',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await BriefingService.updateTitle(record.id, result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, BriefingRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('「${record.title}」을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await BriefingService.delete(record.id);
    }
  }
}

// ── 목록 타일 ──────────────────────────────────────────────────

class _BriefingTile extends StatelessWidget {
  final BriefingRecord record;
  final List<String> tabNames;
  final List<Color> tabColors;
  final VoidCallback onTap;
  final VoidCallback onEditTitle;
  final VoidCallback onDelete;

  const _BriefingTile({
    required this.record,
    required this.tabNames,
    required this.tabColors,
    required this.onTap,
    required this.onEditTitle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tabIdx = record.tabType.clamp(0, 2);
    final color = tabColors[tabIdx];
    final dateStr = _formatDate(record.updatedAt);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // 탭 타입 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tabNames[tabIdx],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              // 제목 + 날짜
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title.isEmpty ? '(제목 없음)' : record.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              // 수정 버튼
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Colors.black45),
                tooltip: '제목 수정',
                onPressed: onEditTitle,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              // 삭제 버튼
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red.shade400),
                tooltip: '삭제',
                onPressed: onDelete,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
