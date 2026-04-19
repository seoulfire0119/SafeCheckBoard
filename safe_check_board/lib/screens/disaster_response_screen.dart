import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/firebase_service.dart';

// ── 데이터 모델 ──────────────────────────────────────────────

class _ActionRow {
  final timeCtrl    = TextEditingController();
  final contentCtrl = TextEditingController();
  void dispose() { timeCtrl.dispose(); contentCtrl.dispose(); }
}

class _AgencyRow {
  int no;
  final agencyCtrl  = TextEditingController();
  final personCtrl  = TextEditingController();
  final arriveCtrl  = TextEditingController();
  final actionCtrl  = TextEditingController();
  _AgencyRow(this.no);
  void dispose() { agencyCtrl.dispose(); personCtrl.dispose(); arriveCtrl.dispose(); actionCtrl.dispose(); }
}

// ── 세션 내 저장 상태 ────────────────────────────────────────
List<Map<String, String>> _savedActionRows = [];
List<Map<String, String>> _savedAgencyRows = [];

// ── 재난대응활동 + 유관기관 활동사항 화면 ──────────────────────

class DisasterResponseScreen extends StatefulWidget {
  final String? sessionCode;
  const DisasterResponseScreen({super.key, this.sessionCode});
  @override
  State<DisasterResponseScreen> createState() => _DisasterResponseScreenState();
}

class _DisasterResponseScreenState extends State<DisasterResponseScreen> {

  final List<_ActionRow> _actionRows = [];
  final List<_AgencyRow> _agencyRows = [];
  Timer? _saveDebounce;

  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      FirebaseService.instance.saveDisasterResponse(
        widget.sessionCode!,
        _actionRows.map((r) => {'time': r.timeCtrl.text, 'content': r.contentCtrl.text}).toList(),
        _agencyRows.map((r) => {'agency': r.agencyCtrl.text, 'person': r.personCtrl.text, 'arrive': r.arriveCtrl.text, 'action': r.actionCtrl.text}).toList(),
      );
    });
  }

  void _addListeners(_ActionRow r) {
    r.timeCtrl.addListener(_scheduleSave);
    r.contentCtrl.addListener(_scheduleSave);
  }

  void _addAgencyListeners(_AgencyRow r) {
    r.agencyCtrl.addListener(_scheduleSave);
    r.personCtrl.addListener(_scheduleSave);
    r.arriveCtrl.addListener(_scheduleSave);
    r.actionCtrl.addListener(_scheduleSave);
  }

  void _applyActionRows(List<Map<String, String>> list) {
    for (final r in _actionRows) r.dispose();
    _actionRows.clear();
    if (list.isEmpty) {
      for (int i = 0; i < 10; i++) { final r = _ActionRow(); _addListeners(r); _actionRows.add(r); }
      return;
    }
    for (final m in list) {
      final r = _ActionRow();
      r.timeCtrl.text    = m['time']    ?? '';
      r.contentCtrl.text = m['content'] ?? '';
      _addListeners(r);
      _actionRows.add(r);
    }
  }

  void _applyAgencyRows(List<Map<String, String>> list) {
    for (final r in _agencyRows) r.dispose();
    _agencyRows.clear();
    if (list.isEmpty) {
      for (int i = 0; i < 10; i++) { final r = _AgencyRow(i + 1); _addAgencyListeners(r); _agencyRows.add(r); }
      return;
    }
    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      final r = _AgencyRow(i + 1);
      r.agencyCtrl.text  = m['agency']  ?? '';
      r.personCtrl.text  = m['person']  ?? '';
      r.arriveCtrl.text  = m['arrive']  ?? '';
      r.actionCtrl.text  = m['action']  ?? '';
      _addAgencyListeners(r);
      _agencyRows.add(r);
    }
  }

  @override
  void initState() {
    super.initState();
    // 로컬 캐시로 즉시 복원
    _applyActionRows(_savedActionRows);
    _applyAgencyRows(_savedAgencyRows);
    // Firebase에서 최신 데이터 로드
    if (widget.sessionCode != null) {
      FirebaseService.instance.loadSecondaryData(widget.sessionCode!).then((data) {
        if (!mounted || data == null) return;
        final raw = data['disasterResponse'];
        if (raw == null) return;
        final actionList = ((raw['actionRows'] as List?) ?? [])
            .map((m) => Map<String, String>.from((m as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
        final agencyList = ((raw['agencyRows'] as List?) ?? [])
            .map((m) => Map<String, String>.from((m as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
        setState(() {
          _applyActionRows(actionList);
          _applyAgencyRows(agencyList);
        });
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _savedActionRows = _actionRows.map((r) => {'time': r.timeCtrl.text, 'content': r.contentCtrl.text}).toList();
    _savedAgencyRows = _agencyRows.map((r) => {'agency': r.agencyCtrl.text, 'person': r.personCtrl.text, 'arrive': r.arriveCtrl.text, 'action': r.actionCtrl.text}).toList();
    for (final r in _actionRows) r.dispose();
    for (final r in _agencyRows) r.dispose();
    super.dispose();
  }

  // ── 복사 텍스트 ──
  String _buildCopyText() {
    final b = StringBuffer();
    b.writeln('[재난대응활동]');
    for (final r in _actionRows) {
      if (r.timeCtrl.text.isNotEmpty || r.contentCtrl.text.isNotEmpty) {
        b.writeln('  ${r.timeCtrl.text.padRight(6)} ${r.contentCtrl.text}');
      }
    }
    b.writeln();
    b.writeln('[유관기관 활동사항]');
    for (final r in _agencyRows) {
      if (r.agencyCtrl.text.isNotEmpty) {
        b.writeln('  ${r.no}. ${r.agencyCtrl.text} / ${r.personCtrl.text} / 도착: ${r.arriveCtrl.text} / ${r.actionCtrl.text}');
      }
    }
    return b.toString();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _buildCopyText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('복사됨'),
      backgroundColor: Color(0xFF1565C0),
      duration: Duration(seconds: 2),
    ));
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('\n', '<br>');

  void _print() {
    final buf = StringBuffer();
    buf.write('''<html><head><meta charset="utf-8">
<style>
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
body { font-family: "Malgun Gothic", sans-serif; font-size: 13px; margin: 24px; color: #1a1a1a; }
h1 { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; text-align:center; }
h2 { font-size: 13px; background: #333; color: #fff; padding: 4px 10px; margin: 16px 0 6px; }
table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
th { background: #f0f0f0; padding: 5px 8px; text-align: left; border: 1px solid #ccc; font-weight: bold; vertical-align: top; }
td { padding: 5px 8px; border: 1px solid #ccc; vertical-align: top; }
@media print { body { padding: 1cm; } }
</style>
<script>window.onload=function(){window.print();}</script>
</head><body>
<h1>재난대응활동 / 유관기관 활동사항</h1>
<h2>재난대응활동</h2>
<table>
<tr><th style="width:80px">시간</th><th>조치사항</th></tr>
${_actionRows.map((r) => '<tr><td>${_esc(r.timeCtrl.text)}</td><td>${_esc(r.contentCtrl.text)}</td></tr>').join()}
</table>
<h2>유관기관 활동사항</h2>
<table>
<tr><th style="width:36px">연번</th><th style="width:90px">기관명</th><th style="width:80px">참석자</th><th style="width:80px">도착시간</th><th>조치내용</th></tr>
${_agencyRows.map((r) => '<tr><td style="text-align:center">${r.no}</td><td>${_esc(r.agencyCtrl.text)}</td><td>${_esc(r.personCtrl.text)}</td><td>${_esc(r.arriveCtrl.text)}</td><td>${_esc(r.actionCtrl.text)}</td></tr>').join()}
</table>
</body></html>''');
    final blob = html.Blob([buf.toString()], 'text/html');
    html.window.open(html.Url.createObjectUrl(blob), '_blank');
  }

  static final _colHeader = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600);

  Widget _agencyCell(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 10, color: Colors.black38),
      border: const OutlineInputBorder(), isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    style: const TextStyle(fontSize: 12),
  );

  Widget _section({required Color color, required IconData icon, required String title, required Widget child}) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('재난대응 · 유관기관'),
        backgroundColor: const Color(0xFFBF360C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_outlined), tooltip: '인쇄', onPressed: _print),
          IconButton(icon: const Icon(Icons.copy_outlined), tooltip: '복사', onPressed: _copyToClipboard),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // ── 재난대응활동 ──
              _section(
                color: const Color(0xFF0D47A1),
                icon: Icons.access_time_filled,
                title: '재난대응활동',
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text('시간', style: _colHeader)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('조치사항', style: _colHeader)),
                    ]),
                  ),
                  ..._actionRows.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: e.value.timeCtrl,
                          decoration: const InputDecoration(
                            hintText: '14:32',
                            border: OutlineInputBorder(), isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: e.value.contentCtrl,
                          decoration: const InputDecoration(
                            hintText: '조치사항 입력',
                            border: OutlineInputBorder(), isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_actionRows.length > 10)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                          onPressed: () { setState(() { _actionRows[e.key].dispose(); _actionRows.removeAt(e.key); }); _scheduleSave(); },
                          padding: const EdgeInsets.only(left: 4),
                          constraints: const BoxConstraints(minWidth: 32),
                        ),
                    ]),
                  )),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () { final r = _ActionRow(); _addListeners(r); setState(() => _actionRows.add(r)); _scheduleSave(); },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('행 추가'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // ── 유관기관 활동사항 ──
              _section(
                color: const Color(0xFF4A148C),
                icon: Icons.groups,
                title: '유관기관 활동사항',
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text('연번', style: _colHeader, textAlign: TextAlign.center)),
                      const SizedBox(width: 6),
                      SizedBox(width: 80, child: Text('기관명', style: _colHeader)),
                      const SizedBox(width: 6),
                      SizedBox(width: 70, child: Text('참석자', style: _colHeader)),
                      const SizedBox(width: 6),
                      SizedBox(width: 70, child: Text('도착시간', style: _colHeader)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('조치내용', style: _colHeader)),
                    ]),
                  ),
                  ..._agencyRows.asMap().entries.map((e) {
                    final r = e.value;
                    r.no = e.key + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(
                          width: 34,
                          child: Center(child: Text('${r.no}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(width: 80, child: _agencyCell(r.agencyCtrl, '기관명')),
                        const SizedBox(width: 6),
                        SizedBox(width: 70, child: _agencyCell(r.personCtrl, '참석자')),
                        const SizedBox(width: 6),
                        SizedBox(width: 70, child: _agencyCell(r.arriveCtrl, '14:30')),
                        const SizedBox(width: 6),
                        Expanded(child: _agencyCell(r.actionCtrl, '조치내용')),
                        if (_agencyRows.length > 10)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                            onPressed: () { setState(() { _agencyRows[e.key].dispose(); _agencyRows.removeAt(e.key); }); _scheduleSave(); },
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(minWidth: 32),
                          ),
                      ]),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () { final r = _AgencyRow(_agencyRows.length + 1); _addAgencyListeners(r); setState(() => _agencyRows.add(r)); _scheduleSave(); },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('행 추가'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
