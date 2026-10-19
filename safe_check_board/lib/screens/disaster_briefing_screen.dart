import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/briefing_record.dart';
import '../services/briefing_service.dart';
import 'incident_status_screen.dart';
import 'disaster_response_screen.dart';
import 'casualty_status_screen.dart';

// ── 세션 내 저장 상태 ────────────────────────────────────────
Map<String, dynamic> _savedBriefingDraft = {};

// ── 시간대별 상황일지 항목 ──────────────────────────────────

class _LogEntry {
  String time;
  String content;
  _LogEntry({this.time = '', this.content = ''});
}

// ── Screen ─────────────────────────────────────────────────

class DisasterBriefingScreen extends StatefulWidget {
  final BriefingRecord? initialRecord;
  final String? sessionCode;
  final VoidCallback? onClose;
  const DisasterBriefingScreen({super.key, this.initialRecord, this.sessionCode, this.onClose});

  @override
  State<DisasterBriefingScreen> createState() =>
      _DisasterBriefingScreenState();
}

class _DisasterBriefingScreenState extends State<DisasterBriefingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // 저장 상태
  String? _recordId;
  String _recordTitle = '';

  // ── ① 초동 브리핑 ──────────────────────────────────────────
  final _f1Date = TextEditingController();
  final _f1Location = TextEditingController();
  final _f1ResponseLevel = TextEditingController();
  final _f1Personnel = TextEditingController();
  final _f1Equipment = TextEditingController();
  final _f1Dead = TextEditingController(text: '0');
  final _f1Injured = TextEditingController(text: '0');
  final _f1Missing = TextEditingController(text: '0');
  final _f1ExtRate = TextEditingController(text: '0');
  final _f1Hazard = TextEditingController();
  final _f1Memo = TextEditingController();

  // ── ② 중간 브리핑 ──────────────────────────────────────────
  final _f2Summary = TextEditingController();
  final _f2Tactic = TextEditingController();
  final _f2Rescue = TextEditingController();
  final _f2Teams = TextEditingController();
  final _f2Area = TextEditingController();
  final _f2Commander = TextEditingController();
  final _f2Hazard = TextEditingController();
  final List<_LogEntry> _f2Log = [_LogEntry()];

  // ── ③ 공식 결과 보고서 ──────────────────────────────────────
  final _f3Overview = TextEditingController();
  final _f3Resources = TextEditingController();
  final _f3Dead = TextEditingController(text: '0');
  final _f3Injured = TextEditingController(text: '0');
  final _f3Missing = TextEditingController(text: '0');
  final _f3Cause = TextEditingController();
  final _f3Issues = TextEditingController();
  final _f3JointInvest = TextEditingController();
  final List<_LogEntry> _f3Timeline = [_LogEntry()];

  @override
  void initState() {
    super.initState();
    final rec = widget.initialRecord;
    _tab = TabController(
        length: 3, vsync: this, initialIndex: rec?.tabType ?? 0);
    if (rec != null) {
      _loadRecord(rec);
    } else if (_savedBriefingDraft.isNotEmpty) {
      // 미저장 초안 복원 (새 브리핑으로 열 때만)
      final f = _savedBriefingDraft;
      _f1Date.text          = f['f1Date'] ?? '';
      _f1Location.text      = f['f1Location'] ?? '';
      _f1ResponseLevel.text = f['f1ResponseLevel'] ?? '';
      _f1Personnel.text     = f['f1Personnel'] ?? '';
      _f1Equipment.text     = f['f1Equipment'] ?? '';
      _f1Dead.text          = f['f1Dead'] ?? '0';
      _f1Injured.text       = f['f1Injured'] ?? '0';
      _f1Missing.text       = f['f1Missing'] ?? '0';
      _f1ExtRate.text       = f['f1ExtRate'] ?? '0';
      _f1Hazard.text        = f['f1Hazard'] ?? '';
      _f1Memo.text          = f['f1Memo'] ?? '';
      _f2Summary.text       = f['f2Summary'] ?? '';
      _f2Tactic.text        = f['f2Tactic'] ?? '';
      _f2Rescue.text        = f['f2Rescue'] ?? '';
      _f2Teams.text         = f['f2Teams'] ?? '';
      _f2Area.text          = f['f2Area'] ?? '';
      _f2Commander.text     = f['f2Commander'] ?? '';
      _f2Hazard.text        = f['f2Hazard'] ?? '';
      if (f['f2Log'] is List) {
        _f2Log..clear()..addAll((f['f2Log'] as List).map((e) =>
            _LogEntry(time: e['time'] ?? '', content: e['content'] ?? '')));
        if (_f2Log.isEmpty) _f2Log.add(_LogEntry());
      }
      _f3Overview.text      = f['f3Overview'] ?? '';
      _f3Resources.text     = f['f3Resources'] ?? '';
      _f3Dead.text          = f['f3Dead'] ?? '0';
      _f3Injured.text       = f['f3Injured'] ?? '0';
      _f3Missing.text       = f['f3Missing'] ?? '0';
      _f3Cause.text         = f['f3Cause'] ?? '';
      _f3Issues.text        = f['f3Issues'] ?? '';
      _f3JointInvest.text   = f['f3JointInvest'] ?? '';
      if (f['f3Timeline'] is List) {
        _f3Timeline..clear()..addAll((f['f3Timeline'] as List).map((e) =>
            _LogEntry(time: e['time'] ?? '', content: e['content'] ?? '')));
        if (_f3Timeline.isEmpty) _f3Timeline.add(_LogEntry());
      }
    }
  }

  void _loadRecord(BriefingRecord rec) {
    _recordId = rec.id;
    _recordTitle = rec.title;
    final f = rec.fields;
    _f1Date.text = f['f1Date'] ?? '';
    _f1Location.text = f['f1Location'] ?? '';
    _f1ResponseLevel.text = f['f1ResponseLevel'] ?? '';
    _f1Personnel.text = f['f1Personnel'] ?? '';
    _f1Equipment.text = f['f1Equipment'] ?? '';
    _f1Dead.text = f['f1Dead'] ?? '0';
    _f1Injured.text = f['f1Injured'] ?? '0';
    _f1Missing.text = f['f1Missing'] ?? '0';
    _f1ExtRate.text = f['f1ExtRate'] ?? '0';
    _f1Hazard.text = f['f1Hazard'] ?? '';
    _f1Memo.text = f['f1Memo'] ?? '';

    _f2Summary.text = f['f2Summary'] ?? '';
    _f2Tactic.text = f['f2Tactic'] ?? '';
    _f2Rescue.text = f['f2Rescue'] ?? '';
    _f2Teams.text = f['f2Teams'] ?? '';
    _f2Area.text = f['f2Area'] ?? '';
    _f2Commander.text = f['f2Commander'] ?? '';
    _f2Hazard.text = f['f2Hazard'] ?? '';
    if (f['f2Log'] is List) {
      _f2Log
        ..clear()
        ..addAll((f['f2Log'] as List).map((e) =>
            _LogEntry(time: e['time'] ?? '', content: e['content'] ?? '')));
      if (_f2Log.isEmpty) _f2Log.add(_LogEntry());
    }

    _f3Overview.text = f['f3Overview'] ?? '';
    _f3Resources.text = f['f3Resources'] ?? '';
    _f3Dead.text = f['f3Dead'] ?? '0';
    _f3Injured.text = f['f3Injured'] ?? '0';
    _f3Missing.text = f['f3Missing'] ?? '0';
    _f3Cause.text = f['f3Cause'] ?? '';
    _f3Issues.text = f['f3Issues'] ?? '';
    _f3JointInvest.text = f['f3JointInvest'] ?? '';
    if (f['f3Timeline'] is List) {
      _f3Timeline
        ..clear()
        ..addAll((f['f3Timeline'] as List).map((e) =>
            _LogEntry(time: e['time'] ?? '', content: e['content'] ?? '')));
      if (_f3Timeline.isEmpty) _f3Timeline.add(_LogEntry());
    }
  }

  Map<String, dynamic> _collectFields() => {
        'f1Date': _f1Date.text,
        'f1Location': _f1Location.text,
        'f1ResponseLevel': _f1ResponseLevel.text,
        'f1Personnel': _f1Personnel.text,
        'f1Equipment': _f1Equipment.text,
        'f1Dead': _f1Dead.text,
        'f1Injured': _f1Injured.text,
        'f1Missing': _f1Missing.text,
        'f1ExtRate': _f1ExtRate.text,
        'f1Hazard': _f1Hazard.text,
        'f1Memo': _f1Memo.text,
        'f2Summary': _f2Summary.text,
        'f2Tactic': _f2Tactic.text,
        'f2Rescue': _f2Rescue.text,
        'f2Teams': _f2Teams.text,
        'f2Area': _f2Area.text,
        'f2Commander': _f2Commander.text,
        'f2Hazard': _f2Hazard.text,
        'f2Log': _f2Log
            .map((e) => {'time': e.time, 'content': e.content})
            .toList(),
        'f3Overview': _f3Overview.text,
        'f3Resources': _f3Resources.text,
        'f3Dead': _f3Dead.text,
        'f3Injured': _f3Injured.text,
        'f3Missing': _f3Missing.text,
        'f3Cause': _f3Cause.text,
        'f3Issues': _f3Issues.text,
        'f3JointInvest': _f3JointInvest.text,
        'f3Timeline': _f3Timeline
            .map((e) => {'time': e.time, 'content': e.content})
            .toList(),
      };

  Future<void> _saveRecord() async {
    // 새 저장: 제목 입력 다이얼로그
    if (_recordId == null) {
      final ctrl = TextEditingController(text: _recordTitle);
      final title = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('브리핑 저장'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '제목',
              hintText: '예) 2025-03-26 강남 물류창고 화재',
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
      if (title == null || title.isEmpty) return;
      _recordTitle = title;
      final now = DateTime.now();
      final rec = BriefingRecord(
        id: '',
        sessionCode: widget.sessionCode ?? widget.initialRecord?.sessionCode ?? '__local__',
        title: title,
        tabType: _tab.index,
        createdAt: now,
        updatedAt: now,
        fields: _collectFields(),
      );
      final newId = await BriefingService.create(rec);
      setState(() => _recordId = newId);
    } else {
      // 덮어쓰기
      final now = DateTime.now();
      final rec = BriefingRecord(
        id: _recordId!,
        sessionCode: widget.sessionCode ?? widget.initialRecord?.sessionCode ?? '__local__',
        title: _recordTitle,
        tabType: _tab.index,
        createdAt: now,
        updatedAt: now,
        fields: _collectFields(),
      );
      await BriefingService.update(rec);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장되었습니다'),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // 초안 저장 (새 브리핑이거나 Firebase 저장 전이면 draft에 보존)
    if (widget.initialRecord == null) {
      _savedBriefingDraft = _collectFields();
    }
    _tab.dispose();
    for (final c in [
      _f1Date, _f1Location, _f1ResponseLevel, _f1Personnel, _f1Equipment,
      _f1Dead, _f1Injured, _f1Missing, _f1ExtRate, _f1Hazard, _f1Memo,
      _f2Summary, _f2Tactic, _f2Rescue, _f2Teams, _f2Area,
      _f2Commander, _f2Hazard,
      _f3Overview, _f3Resources, _f3Dead, _f3Injured, _f3Missing,
      _f3Cause, _f3Issues, _f3JointInvest,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 자동채우기 ─────────────────────────────────────────────

  void _showAutoFillDialog() {
    // 사용 가능한 소스 확인
    final hasIncident = savedIncident.isNotEmpty;
    final hasCasualty = savedCasualtyRows.any((r) => (r['status'] ?? '').isNotEmpty);
    final hasTimeline = savedActionRows.any(
        (r) => (r['time'] ?? '').isNotEmpty || (r['content'] ?? '').isNotEmpty);
    final hasAgency = savedAgencyRows.any((r) => (r['agency'] ?? '').isNotEmpty);

    if (!hasIncident && !hasCasualty && !hasTimeline && !hasAgency) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('자동으로 채울 수 있는 데이터가 없습니다.\n재난발생현황, 인명피해상황, 조치현황을 먼저 입력하세요.'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_fix_high, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Text('자동채우기'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('다른 화면에서 입력한 데이터로 브리핑 항목을 채웁니다.\n기존 입력값은 덮어쓰기됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              if (hasIncident) ...[
                _autoFillChip(Icons.assignment_outlined, '재난발생현황',
                    '발생일시, 장소, 원인 → 초동·보고서'),
                const SizedBox(height: 6),
              ],
              if (hasCasualty) ...[
                _autoFillChip(Icons.personal_injury_outlined, '인명피해상황',
                    '사망·부상 집계 → 초동·보고서 인명피해'),
                const SizedBox(height: 6),
              ],
              if (hasTimeline) ...[
                _autoFillChip(Icons.access_time_filled, '시간대별 조치현황',
                    '시간·조치사항 → 중간 상황일지·보고서 경과'),
                const SizedBox(height: 6),
              ],
              if (hasAgency) ...[
                _autoFillChip(Icons.groups_outlined, '유관기관 활동사항',
                    '기관명·조치내용 → 중간 편성현황'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('채우기'),
            onPressed: () {
              Navigator.pop(ctx);
              _applyAutoFill();
            },
          ),
        ],
      ),
    );
  }

  Widget _autoFillChip(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ]),
        ),
      ]),
    );
  }

  void _applyAutoFill() {
    int filled = 0;

    // ── 재난발생현황 → 초동 + 보고서 ──
    final inc = savedIncident;
    if ((inc['date'] ?? '').isNotEmpty) { _f1Date.text = inc['date']!; filled++; }
    if ((inc['location'] ?? '').isNotEmpty) { _f1Location.text = inc['location']!; filled++; }
    if ((inc['cause'] ?? '').isNotEmpty) { _f3Cause.text = inc['cause']!; filled++; }

    // 보고서 화재개요 조합
    final overviewParts = <String>[];
    if ((inc['date'] ?? '').isNotEmpty) overviewParts.add('발생일시: ${inc['date']}');
    if ((inc['location'] ?? '').isNotEmpty) overviewParts.add('발생장소: ${inc['location']}');
    if ((inc['target'] ?? '').isNotEmpty) overviewParts.add('대상물: ${inc['target']}');
    if ((inc['floors'] ?? '').isNotEmpty || (inc['area'] ?? '').isNotEmpty) {
      final struct = [
        if ((inc['floors'] ?? '').isNotEmpty) '${inc['floors']}층',
        if ((inc['area'] ?? '').isNotEmpty) '${inc['area']}㎡',
      ].join(' / ');
      overviewParts.add('건물구조: $struct');
    }
    if (overviewParts.isNotEmpty) {
      _f3Overview.text = overviewParts.join('\n');
      filled++;
    }

    // ── 인명피해상황 → 사망·부상 숫자 ──
    final delayed = savedCasualtyRows
        .where((r) => r['status'] == '지연환자').length;
    final injured = savedCasualtyRows
        .where((r) => ['긴급환자', '응급환자', '비응급환자'].contains(r['status'])).length;
    if (delayed > 0 || injured > 0) {
      _f1Dead.text = '$delayed'; _f3Dead.text = '$delayed';
      _f1Injured.text = '$injured'; _f3Injured.text = '$injured';
      filled++;
    }

    // ── 시간대별 조치현황 → 중간 상황일지 + 보고서 경과 ──
    final actionEntries = savedActionRows
        .where((r) => (r['time'] ?? '').isNotEmpty || (r['content'] ?? '').isNotEmpty)
        .toList();
    if (actionEntries.isNotEmpty) {
      setState(() {
        _f2Log
          ..clear()
          ..addAll(actionEntries.map(
              (r) => _LogEntry(time: r['time'] ?? '', content: r['content'] ?? '')));
        _f3Timeline
          ..clear()
          ..addAll(actionEntries.map(
              (r) => _LogEntry(time: r['time'] ?? '', content: r['content'] ?? '')));
      });
      filled++;
    }

    // ── 유관기관 활동사항 → 중간 편성현황 ──
    final agencyEntries =
        savedAgencyRows.where((r) => (r['agency'] ?? '').isNotEmpty).toList();
    if (agencyEntries.isNotEmpty) {
      _f2Teams.text = agencyEntries.asMap().entries.map((e) {
        final r = e.value;
        final parts = ['${e.key + 1}. ${r['agency']}'];
        if ((r['person'] ?? '').isNotEmpty) parts.add(r['person']!);
        if ((r['arrive'] ?? '').isNotEmpty) parts.add('도착 ${r['arrive']}');
        if ((r['action'] ?? '').isNotEmpty) parts.add(r['action']!);
        return parts.join(' / ');
      }).join('\n');
      filled++;
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$filled개 항목이 자동으로 채워졌습니다.'),
      backgroundColor: const Color(0xFF1565C0),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── 복사 텍스트 생성 ────────────────────────────────────────

  String _buildCopyText() {
    final buf = StringBuffer();
    final tab = _tab.index;

    if (tab == 0) {
      buf.writeln('【초동 현장 브리핑】');
      buf.writeln('일시: ${_f1Date.text}');
      buf.writeln('장소: ${_f1Location.text}');
      buf.writeln('대응단계: ${_f1ResponseLevel.text}');
      buf.writeln('투입 인력: ${_f1Personnel.text}명 / 장비: ${_f1Equipment.text}대');
      buf.writeln(
          '인명피해 — 사망: ${_f1Dead.text} / 부상: ${_f1Injured.text} / 대피: ${_f1Missing.text}');
      buf.writeln('진화율: ${_f1ExtRate.text}%');
      buf.writeln('위험 요소: ${_f1Hazard.text}');
      if (_f1Memo.text.isNotEmpty) buf.writeln('비고: ${_f1Memo.text}');
    } else if (tab == 1) {
      buf.writeln('【중간 브리핑】');
      buf.writeln('현황 요약: ${_f2Summary.text}');
      buf.writeln('수색 전술: ${_f2Tactic.text}');
      buf.writeln('구조 현황: ${_f2Rescue.text}');
      buf.writeln('편성: ${_f2Teams.text}');
      buf.writeln('수색 구역: ${_f2Area.text}');
      buf.writeln('현장 지휘관: ${_f2Commander.text}');
      buf.writeln('위험 요소: ${_f2Hazard.text}');
      if (_f2Log.any((e) => e.time.isNotEmpty || e.content.isNotEmpty)) {
        buf.writeln('\n[시간대별 상황일지]');
        for (final e in _f2Log) {
          if (e.time.isNotEmpty || e.content.isNotEmpty) {
            buf.writeln('  ${e.time.padRight(6)} ${e.content}');
          }
        }
      }
    } else {
      buf.writeln('【공식 결과 보고서】');
      buf.writeln('[화재 개요]\n${_f3Overview.text}');
      buf.writeln('\n[인명피해] 사망: ${_f3Dead.text} / 부상: ${_f3Injured.text} / 실종: ${_f3Missing.text}');
      buf.writeln('\n[투입 자원]\n${_f3Resources.text}');
      if (_f3Timeline.any((e) => e.time.isNotEmpty || e.content.isNotEmpty)) {
        buf.writeln('\n[대응 경과]');
        for (final e in _f3Timeline) {
          if (e.time.isNotEmpty || e.content.isNotEmpty) {
            buf.writeln('  ${e.time.padRight(6)} ${e.content}');
          }
        }
      }
      buf.writeln('\n[원인 추정]\n${_f3Cause.text}');
      buf.writeln('\n[문제점 및 개선사항]\n${_f3Issues.text}');
      buf.writeln('\n[합동 감식 현황]\n${_f3JointInvest.text}');
    }
    return buf.toString();
  }

  void _copyToClipboard() {
    final text = _buildCopyText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            ['초동 브리핑', '중간 브리핑', '공식 보고서'][_tab.index] + ' 복사됨'),
        backgroundColor: const Color(0xFF1565C0),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── 인쇄 ───────────────────────────────────────────────────

  void _printTab(int tabIndex) {
    final content = _buildPrintHtml(tabIndex);
    final blob = html.Blob([content], 'text/html');
    final url = html.Url.createObjectUrl(blob);
    html.window.open(url, '_blank');
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', '<br>');

  String _row(String label, String value) =>
      '<tr><th>$label</th><td>${_esc(value)}</td></tr>';

  String _buildPrintHtml(int tab) {
    final style = '''
<style>
  * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
  body { font-family: "Malgun Gothic", sans-serif; font-size: 13px; margin: 24px; color: #1a1a1a; }
  h1 { font-size: 18px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; }
  h2 { font-size: 14px; background: #333; color: #fff; padding: 4px 10px; margin: 16px 0 6px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
  th { width: 130px; background: #f0f0f0; padding: 5px 8px; text-align: left;
       border: 1px solid #ccc; font-weight: bold; vertical-align: top; }
  td { padding: 5px 8px; border: 1px solid #ccc; vertical-align: top; }
  @page { margin: 0; }
  @media print { body { padding: 1.5cm; } }
</style>
<script>window.onload = function() { window.print(); }</script>
''';

    final buf = StringBuffer();
    buf.write('<html><head><meta charset="utf-8">$style</head><body>');

    if (tab == 0) {
      buf.write('<h1>초동 현장 브리핑</h1>');
      buf.write('<h2>기본 사항</h2><table>');
      buf.write(_row('발생 일시', _f1Date.text));
      buf.write(_row('발생 장소', _f1Location.text));
      buf.write(_row('대응단계', _f1ResponseLevel.text));
      buf.write('</table>');
      buf.write('<h2>투입 자원</h2><table>');
      buf.write(_row('투입 인력', '${_f1Personnel.text} 명'));
      buf.write(_row('투입 장비', '${_f1Equipment.text} 대'));
      buf.write('</table>');
      buf.write('<h2>인명피해 현황</h2><table>');
      buf.write(_row('사망', '${_f1Dead.text} 명'));
      buf.write(_row('부상', '${_f1Injured.text} 명'));
      buf.write(_row('대피', '${_f1Missing.text} 명'));
      buf.write('</table>');
      buf.write('<h2>진화 현황</h2><table>');
      buf.write(_row('진화율', '${_f1ExtRate.text} %'));
      buf.write(_row('위험 요소', _f1Hazard.text));
      buf.write('</table>');
      if (_f1Memo.text.isNotEmpty) {
        buf.write('<h2>비고</h2><table>');
        buf.write(_row('기타 사항', _f1Memo.text));
        buf.write('</table>');
      }
    } else if (tab == 1) {
      buf.write('<h1>중간 브리핑</h1>');
      buf.write('<h2>현황 요약</h2><table>');
      buf.write(_row('현황 요약', _f2Summary.text));
      buf.write('</table>');
      buf.write('<h2>수색·구조 현황</h2><table>');
      buf.write(_row('수색 전술', _f2Tactic.text));
      buf.write(_row('편성 현황', _f2Teams.text));
      buf.write(_row('수색 구역', _f2Area.text));
      buf.write(_row('구조 현황', _f2Rescue.text));
      buf.write('</table>');
      buf.write('<h2>위험 요소 및 지휘</h2><table>');
      buf.write(_row('위험 요소', _f2Hazard.text));
      buf.write(_row('현장 지휘관', _f2Commander.text));
      buf.write('</table>');
      final hasLog = _f2Log.any((e) => e.time.isNotEmpty || e.content.isNotEmpty);
      if (hasLog) {
        buf.write('<h2>시간대별 상황일지</h2><table>');
        buf.write('<tr><th style="width:70px">시각</th><th>상황</th></tr>');
        for (final e in _f2Log) {
          if (e.time.isNotEmpty || e.content.isNotEmpty) {
            buf.write('<tr><td>${_esc(e.time)}</td><td>${_esc(e.content)}</td></tr>');
          }
        }
        buf.write('</table>');
      }
    } else {
      buf.write('<h1>공식 결과 보고서</h1>');
      buf.write('<h2>화재 개요</h2><table>');
      buf.write(_row('화재 개요', _f3Overview.text));
      buf.write('</table>');
      buf.write('<h2>인명피해 최종</h2><table>');
      buf.write(_row('사망', '${_f3Dead.text} 명'));
      buf.write(_row('부상', '${_f3Injured.text} 명'));
      buf.write(_row('실종', '${_f3Missing.text} 명'));
      buf.write('</table>');
      buf.write('<h2>투입 자원</h2><table>');
      buf.write(_row('투입 자원 현황', _f3Resources.text));
      buf.write('</table>');
      final hasTimeline = _f3Timeline.any((e) => e.time.isNotEmpty || e.content.isNotEmpty);
      if (hasTimeline) {
        buf.write('<h2>대응 경과 (타임라인)</h2><table>');
        buf.write('<tr><th style="width:70px">시각</th><th>상황</th></tr>');
        for (final e in _f3Timeline) {
          if (e.time.isNotEmpty || e.content.isNotEmpty) {
            buf.write('<tr><td>${_esc(e.time)}</td><td>${_esc(e.content)}</td></tr>');
          }
        }
        buf.write('</table>');
      }
      buf.write('<h2>원인 추정</h2><table>');
      buf.write(_row('화재 원인 추정', _f3Cause.text));
      buf.write('</table>');
      buf.write('<h2>문제점 및 개선사항</h2><table>');
      buf.write(_row('문제점 및 개선사항', _f3Issues.text));
      buf.write('</table>');
      buf.write('<h2>합동 감식 현황</h2><table>');
      buf.write(_row('참여 기관 및 현황', _f3JointInvest.text));
      buf.write('</table>');
    }

    buf.write('</body></html>');
    return buf.toString();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('재난대응 브리핑 자료'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: '자동채우기',
            onPressed: _showAutoFillDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: _recordId == null ? '저장' : '덮어쓰기',
            onPressed: _saveRecord,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: '현재 탭 인쇄',
            onPressed: () => _printTab(_tab.index),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '현재 탭 복사',
            onPressed: _copyToClipboard,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.lightBlueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.flash_on, size: 16),
              text: '초동 브리핑',
            ),
            Tab(
              icon: Icon(Icons.search, size: 16),
              text: '중간 브리핑',
            ),
            Tab(
              icon: Icon(Icons.assignment, size: 16),
              text: '공식 보고서',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildInitialBriefing(),
          _buildInterimBriefing(),
          _buildOfficialReport(),
        ],
      ),
    );
  }

  // ── ① 초동 현장 브리핑 ─────────────────────────────────────

  Widget _buildInitialBriefing() {
    return _FormPage(
      sections: [
        _SectionCard(
          color: const Color(0xFFBF360C),
          icon: Icons.access_time,
          title: '기본 사항',
          children: [
            _Field(label: '발생 일시', ctrl: _f1Date,
                hint: '예) 2025-03-26 14:32'),
            _Field(label: '발생 장소', ctrl: _f1Location,
                hint: '예) 서울 강남구 ○○ 물류창고'),
            _Field(label: '대응단계 발령', ctrl: _f1ResponseLevel,
                hint: '예) 대응 3단계 / 국가소방동원령'),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF1565C0),
          icon: Icons.groups,
          title: '투입 자원',
          children: [
            _NumberRow(
              fields: [
                _NumberField(label: '투입 인력', unit: '명', ctrl: _f1Personnel),
                _NumberField(label: '투입 장비', unit: '대', ctrl: _f1Equipment),
              ],
            ),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF6A1B9A),
          icon: Icons.person_off,
          title: '인명피해 현황',
          children: [
            _NumberRow(
              fields: [
                _NumberField(
                    label: '사망', unit: '명', ctrl: _f1Dead,
                    color: Colors.red.shade700),
                _NumberField(
                    label: '부상', unit: '명', ctrl: _f1Injured,
                    color: Colors.orange.shade700),
                _NumberField(
                    label: '대피', unit: '명', ctrl: _f1Missing,
                    color: Colors.grey.shade700),
              ],
            ),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF2E7D32),
          icon: Icons.local_fire_department,
          title: '진화 현황',
          children: [
            _NumberRow(
              fields: [
                _NumberField(
                    label: '진화율', unit: '%', ctrl: _f1ExtRate),
              ],
            ),
            _Field(
                label: '위험 요소', ctrl: _f1Hazard,
                hint: '예) 나트륨, LPG, 유해화학물질'),
          ],
        ),
        _SectionCard(
          color: Colors.blueGrey.shade700,
          icon: Icons.notes,
          title: '비고',
          children: [
            _Field(
                label: '기타 사항', ctrl: _f1Memo,
                hint: '구두 보고 특이사항 입력', maxLines: 3),
          ],
        ),
      ],
    );
  }

  // ── ② 중간 브리핑 ──────────────────────────────────────────

  Widget _buildInterimBriefing() {
    return _FormPage(
      sections: [
        _SectionCard(
          color: const Color(0xFF1565C0),
          icon: Icons.info_outline,
          title: '현황 요약',
          children: [
            _Field(
                label: '현황 요약', ctrl: _f2Summary,
                hint: '현재 상황을 간결하게 기술', maxLines: 3),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF6A1B9A),
          icon: Icons.search,
          title: '수색·구조 현황',
          children: [
            _Field(
                label: '수색 전술', ctrl: _f2Tactic,
                hint: '예) 4인 1개조, 총 2개조 편성 — 2·3층 정밀 수색'),
            _Field(label: '편성 현황', ctrl: _f2Teams,
                hint: '예) 1조: ○○대 / 2조: ○○대'),
            _Field(label: '수색 구역', ctrl: _f2Area,
                hint: '예) 2층 동쪽 / 3층 계단실'),
            _Field(
                label: '구조 현황', ctrl: _f2Rescue,
                hint: '구조 인원, 특이사항 등', maxLines: 2),
          ],
        ),
        _SectionCard(
          color: const Color(0xFFBF360C),
          icon: Icons.warning_amber,
          title: '위험 요소 및 지휘',
          children: [
            _Field(
                label: '위험 요소', ctrl: _f2Hazard,
                hint: '예) 철골 열변형·붕괴 우려, 나트륨 화재'),
            _Field(label: '현장 지휘관', ctrl: _f2Commander,
                hint: '예) 중앙긴급구조통제단장 ○○○'),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF37474F),
          icon: Icons.access_time_filled,
          title: '시간대별 상황일지',
          footer: TextButton.icon(
            onPressed: () =>
                setState(() => _f2Log.add(_LogEntry())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('항목 추가'),
          ),
          children: [
            ..._f2Log.asMap().entries.map((e) =>
                _LogRow(
                  entry: e.value,
                  onDelete: _f2Log.length > 1
                      ? () => setState(() => _f2Log.removeAt(e.key))
                      : null,
                )),
          ],
        ),
      ],
    );
  }

  // ── ③ 공식 결과 보고서 ──────────────────────────────────────

  Widget _buildOfficialReport() {
    return _FormPage(
      sections: [
        _SectionCard(
          color: const Color(0xFF0D1B2A),
          icon: Icons.article,
          title: '화재 개요',
          children: [
            _Field(
                label: '화재 개요', ctrl: _f3Overview,
                hint: '발생 장소, 구조물 특성, 기상 조건 등', maxLines: 4),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF6A1B9A),
          icon: Icons.person_off,
          title: '인명피해 최종',
          children: [
            _NumberRow(
              fields: [
                _NumberField(
                    label: '사망', unit: '명', ctrl: _f3Dead,
                    color: Colors.red.shade700),
                _NumberField(
                    label: '부상', unit: '명', ctrl: _f3Injured,
                    color: Colors.orange.shade700),
                _NumberField(
                    label: '실종', unit: '명', ctrl: _f3Missing,
                    color: Colors.grey.shade700),
              ],
            ),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF1565C0),
          icon: Icons.inventory_2_outlined,
          title: '투입 자원',
          children: [
            _Field(
                label: '투입 자원 현황', ctrl: _f3Resources,
                hint: '인력 합계, 소방차 종류·대수, 헬기 등', maxLines: 3),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF37474F),
          icon: Icons.timeline,
          title: '대응 경과 (타임라인)',
          footer: TextButton.icon(
            onPressed: () =>
                setState(() => _f3Timeline.add(_LogEntry())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('항목 추가'),
          ),
          children: [
            ..._f3Timeline.asMap().entries.map((e) =>
                _LogRow(
                  entry: e.value,
                  onDelete: _f3Timeline.length > 1
                      ? () =>
                          setState(() => _f3Timeline.removeAt(e.key))
                      : null,
                )),
          ],
        ),
        _SectionCard(
          color: const Color(0xFFBF360C),
          icon: Icons.find_in_page_outlined,
          title: '원인 추정',
          children: [
            _Field(
                label: '화재 원인 추정', ctrl: _f3Cause,
                hint: '수사·감식 결과 반영 전까지 추정 기재', maxLines: 3),
          ],
        ),
        _SectionCard(
          color: const Color(0xFF2E7D32),
          icon: Icons.rule,
          title: '문제점 및 개선사항',
          children: [
            _Field(
                label: '문제점 및 개선사항', ctrl: _f3Issues,
                hint: '대응 과정에서 드러난 문제점, 제도·장비 개선 의견',
                maxLines: 4),
          ],
        ),
        _SectionCard(
          color: Colors.blueGrey.shade700,
          icon: Icons.groups_2_outlined,
          title: '합동 감식 현황',
          children: [
            _Field(
                label: '참여 기관 및 현황', ctrl: _f3JointInvest,
                hint: '예) 소방청·경찰·노동부·국과수 등 9개 기관 65명 합동감식 진행 중',
                maxLines: 3),
          ],
        ),
      ],
    );
  }
}

// ── 공통 위젯들 ──────────────────────────────────────────────

class _FormPage extends StatelessWidget {
  final List<Widget> sections;
  const _FormPage({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: sections
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: s,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? footer;

  const _SectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // 바디
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
          if (footer != null)
            Padding(
              padding:
                  const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final int maxLines;

  const _Field({
    required this.label,
    required this.ctrl,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Colors.black38),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _NumberField {
  final String label;
  final String unit;
  final TextEditingController ctrl;
  final Color? color;
  _NumberField(
      {required this.label,
      required this.unit,
      required this.ctrl,
      this.color});
}

class _NumberRow extends StatelessWidget {
  final List<_NumberField> fields;
  const _NumberRow({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: fields.map((f) {
          final isLast = f == fields.last;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: TextField(
                controller: f.ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: f.label,
                  suffixText: f.unit,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  labelStyle: TextStyle(
                      color: f.color, fontWeight: FontWeight.bold),
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: f.color ?? Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final _LogEntry entry;
  final VoidCallback? onDelete;
  const _LogRow({required this.entry, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: TextField(
              onChanged: (v) => entry.time = v,
              controller: TextEditingController(text: entry.time)
                ..selection = TextSelection.collapsed(
                    offset: entry.time.length),
              decoration: const InputDecoration(
                labelText: '시각',
                hintText: '14:32',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style:
                  const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => entry.content = v,
              controller: TextEditingController(text: entry.content)
                ..selection = TextSelection.collapsed(
                    offset: entry.content.length),
              decoration: const InputDecoration(
                labelText: '상황',
                hintText: '상황 내용 입력',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: Colors.red),
              onPressed: onDelete,
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(minWidth: 32),
            ),
        ],
      ),
    );
  }
}
