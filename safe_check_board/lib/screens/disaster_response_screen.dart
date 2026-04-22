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
  Color? highlightColor;
  void dispose() { timeCtrl.dispose(); contentCtrl.dispose(); }
}

class _AgencyRow {
  int no;
  final agencyCtrl  = TextEditingController();
  final personCtrl  = TextEditingController();
  final arriveCtrl  = TextEditingController();
  final actionCtrl  = TextEditingController();
  _AgencyRow(this.no);
  void dispose() {
    agencyCtrl.dispose(); personCtrl.dispose();
    arriveCtrl.dispose(); actionCtrl.dispose();
  }
}

// ── 세션 내 저장 상태 (두 화면이 공유) ──────────────────────────
List<Map<String, String>> savedActionRows = [];
List<Map<String, String>> savedAgencyRows = [];

// ── 시간 자동 포맷 (0814 → 08:14) ────────────────────────────
class _TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return oldValue;
    String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else {
      formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── 행 강조 색 팔레트 ──────────────────────────────────────────
const _highlightPalette = <Color?>[
  null,
  Color(0xFFFFF9C4),  // 연노랑
  Color(0xFFFFE0B2),  // 연주황
  Color(0xFFFFCDD2),  // 연빨강
  Color(0xFFC8E6C9),  // 연초록
  Color(0xFFBBDEFB),  // 연파랑
  Color(0xFFE1BEE7),  // 연보라
];

String? _colorToHex(Color? c) =>
    c == null ? null : c.value.toRadixString(16).padLeft(8, '0');

Color? _hexToColor(String? s) {
  if (s == null || s.isEmpty) return null;
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

// ── 컬럼 드래그 분리자 ────────────────────────────────────────
// 헤더 셀 안에 리사이즈 핸들이 내장된 위젯
// width는 데이터 셀과 동일한 너비를 사용
Widget _resizableHeader(
    String label, double width, void Function(double)? onResize,
    {TextStyle? style}) {
  return SizedBox(
    width: width,
    child: Row(children: [
      Expanded(
          child: Text(label,
              style: style ??
                  TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600))),
      if (onResize != null)
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: Listener(
            onPointerMove: (e) => onResize(e.delta.dx),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
    ]),
  );
}

// ── 공통 스타일 ──────────────────────────────────────────────
final _colHeader = TextStyle(
    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600);

Widget _sectionCard({
  required Color color,
  required IconData icon,
  required String title,
  required Widget child,
}) {
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
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(12), child: child),
    ]),
  );
}

// ════════════════════════════════════════════════════════════
// 시간대별 조치현황 화면
// ════════════════════════════════════════════════════════════

class TimelineActionScreen extends StatefulWidget {
  final String? sessionCode;
  const TimelineActionScreen({super.key, this.sessionCode});
  @override
  State<TimelineActionScreen> createState() => _TimelineActionScreenState();
}

class _TimelineActionScreenState extends State<TimelineActionScreen> {
  final List<_ActionRow> _rows = [];
  Timer? _saveDebounce;

  // ── 리스너 & 저장 ──
  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      savedActionRows = _rows.map((r) => {
        'time': r.timeCtrl.text,
        'content': r.contentCtrl.text,
        if (r.highlightColor != null) 'highlight': _colorToHex(r.highlightColor)!,
      }).toList();
      FirebaseService.instance.saveDisasterResponse(
        widget.sessionCode!,
        savedActionRows,
        savedAgencyRows,
      );
    });
  }

  void _addListeners(_ActionRow r) {
    r.timeCtrl.addListener(_scheduleSave);
    r.contentCtrl.addListener(_scheduleSave);
  }

  void _applyRows(List<Map<String, String>> list) {
    for (final r in _rows) r.dispose();
    _rows.clear();
    final src = list.isEmpty
        ? List.generate(10, (_) => <String, String>{})
        : list;
    for (final m in src) {
      final r = _ActionRow();
      r.timeCtrl.text    = m['time']    ?? '';
      r.contentCtrl.text = m['content'] ?? '';
      r.highlightColor   = _hexToColor(m['highlight']);
      _addListeners(r);
      _rows.add(r);
    }
  }

  @override
  void initState() {
    super.initState();
    _applyRows(savedActionRows);
    if (widget.sessionCode != null) {
      FirebaseService.instance.loadSecondaryData(widget.sessionCode!).then((data) {
        if (!mounted || data == null) return;
        final raw = data['disasterResponse'];
        if (raw == null) return;
        final list = ((raw['actionRows'] as List?) ?? [])
            .map((m) => Map<String, String>.from(
                (m as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
        if (list.isNotEmpty) setState(() => _applyRows(list));
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    savedActionRows = _rows.map((r) => {
      'time': r.timeCtrl.text,
      'content': r.contentCtrl.text,
      if (r.highlightColor != null) 'highlight': _colorToHex(r.highlightColor)!,
    }).toList();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _cycleHighlight(int idx) {
    final r = _rows[idx];
    final cur = _highlightPalette.indexOf(r.highlightColor);
    final next = (cur + 1) % _highlightPalette.length;
    setState(() => r.highlightColor = _highlightPalette[next]);
    _scheduleSave();
  }

  // ── 복사 / 인쇄 ──
  String _buildCopyText() {
    final b = StringBuffer('[시간대별 조치현황]\n');
    for (final r in _rows) {
      if (r.timeCtrl.text.isNotEmpty || r.contentCtrl.text.isNotEmpty) {
        b.writeln('  ${r.timeCtrl.text.padRight(6)} ${r.contentCtrl.text}');
      }
    }
    return b.toString();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _buildCopyText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('복사됨'),
      backgroundColor: Color(0xFF0D47A1),
      duration: Duration(seconds: 2),
    ));
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', '<br>');

  String _highlightToHtml(Color? c) {
    if (c == null) return '';
    final hex = '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}';
    return ' style="background:$hex"';
  }

  void _print() {
    final buf = StringBuffer();
    buf.write('''<html><head><meta charset="utf-8">
<style>
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
body { font-family: "Malgun Gothic", sans-serif; font-size: 13px; margin: 24px; color: #1a1a1a; }
h1 { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; text-align:center; }
table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
th { background: #f0f0f0; padding: 5px 8px; text-align: left; border: 1px solid #ccc; font-weight: bold; }
td { padding: 5px 8px; border: 1px solid #ccc; vertical-align: top; }
@media print { body { padding: 1cm; } }
</style>
<script>window.onload=function(){window.print();}</script>
</head><body>
<h1>시간대별 조치현황</h1>
<table>
<tr><th style="width:90px">시간</th><th>조치사항</th></tr>
${_rows.map((r) => '<tr${_highlightToHtml(r.highlightColor)}><td>${_esc(r.timeCtrl.text)}</td><td>${_esc(r.contentCtrl.text)}</td></tr>').join()}
</table>
</body></html>''');
    final blob = html.Blob([buf.toString()], 'text/html');
    html.window.open(html.Url.createObjectUrl(blob), '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('시간대별 조치현황'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: '인쇄',
              onPressed: _print),
          IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: '복사',
              onPressed: _copyToClipboard),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              _sectionCard(
                color: const Color(0xFF0D47A1),
                icon: Icons.access_time_filled,
                title: '시간대별 조치현황',
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const SizedBox(width: 28), // 강조 버튼 자리
                      const SizedBox(width: 6),
                      SizedBox(width: 90, child: Text('시간', style: _colHeader)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('조치사항', style: _colHeader)),
                    ]),
                  ),
                  ..._rows.asMap().entries.map((e) {
                    final idx = e.key;
                    final row = e.value;
                    final bg = row.highlightColor;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg ?? Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: bg != null
                              ? Border.all(
                                  color: bg.withOpacity(0.6),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        padding: bg != null
                            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 3)
                            : EdgeInsets.zero,
                        child: Row(children: [
                          // 강조 색 버튼
                          GestureDetector(
                            onTap: () => _cycleHighlight(idx),
                            child: Tooltip(
                              message: '강조 색 변경',
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: bg ?? Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: bg != null
                                        ? bg.withOpacity(0.8)
                                        : Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                child: bg == null
                                    ? Icon(Icons.circle_outlined,
                                        size: 12, color: Colors.grey.shade400)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: row.timeCtrl,
                              decoration: const InputDecoration(
                                hintText: '14:32',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                              inputFormatters: [_TimeFormatter()],
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.contentCtrl,
                              decoration: const InputDecoration(
                                hintText: '조치사항 입력',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_rows.length > 10)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _rows[idx].dispose();
                                  _rows.removeAt(idx);
                                });
                                _scheduleSave();
                              },
                              padding: const EdgeInsets.only(left: 4),
                              constraints:
                                  const BoxConstraints(minWidth: 32),
                            ),
                        ]),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final r = _ActionRow();
                        _addListeners(r);
                        setState(() => _rows.add(r));
                        _scheduleSave();
                      },
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

// ════════════════════════════════════════════════════════════
// 유관기관 활동사항 화면
// ════════════════════════════════════════════════════════════

class DisasterResponseScreen extends StatefulWidget {
  final String? sessionCode;
  const DisasterResponseScreen({super.key, this.sessionCode});
  @override
  State<DisasterResponseScreen> createState() => _DisasterResponseScreenState();
}

class _DisasterResponseScreenState extends State<DisasterResponseScreen> {
  final List<_AgencyRow> _rows = [];
  Timer? _saveDebounce;

  // 컬럼 너비 (드래그 조절 가능)
  double _agencyW = 100;
  double _personW = 80;
  double _arriveW = 80;

  static const double _colMin = 40;
  static const double _colMax = 300;

  // ── 리스너 & 저장 ──
  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      savedAgencyRows = _rows
          .map((r) => {
                'agency': r.agencyCtrl.text,
                'person': r.personCtrl.text,
                'arrive': r.arriveCtrl.text,
                'action': r.actionCtrl.text,
              })
          .toList();
      FirebaseService.instance.saveDisasterResponse(
        widget.sessionCode!,
        savedActionRows,
        savedAgencyRows,
      );
    });
  }

  void _addListeners(_AgencyRow r) {
    r.agencyCtrl.addListener(_scheduleSave);
    r.personCtrl.addListener(_scheduleSave);
    r.arriveCtrl.addListener(_scheduleSave);
    r.actionCtrl.addListener(_scheduleSave);
  }

  void _applyRows(List<Map<String, String>> list) {
    for (final r in _rows) r.dispose();
    _rows.clear();
    final src = list.isEmpty
        ? List.generate(10, (i) => <String, String>{})
        : list;
    for (int i = 0; i < src.length; i++) {
      final m = src[i];
      final r = _AgencyRow(i + 1);
      r.agencyCtrl.text = m['agency'] ?? '';
      r.personCtrl.text = m['person'] ?? '';
      r.arriveCtrl.text = m['arrive'] ?? '';
      r.actionCtrl.text = m['action'] ?? '';
      _addListeners(r);
      _rows.add(r);
    }
  }

  @override
  void initState() {
    super.initState();
    _applyRows(savedAgencyRows);
    if (widget.sessionCode != null) {
      FirebaseService.instance.loadSecondaryData(widget.sessionCode!).then((data) {
        if (!mounted || data == null) return;
        final raw = data['disasterResponse'];
        if (raw == null) return;
        final list = ((raw['agencyRows'] as List?) ?? [])
            .map((m) => Map<String, String>.from(
                (m as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
        if (list.isNotEmpty) setState(() => _applyRows(list));
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    savedAgencyRows = _rows
        .map((r) => {
              'agency': r.agencyCtrl.text,
              'person': r.personCtrl.text,
              'arrive': r.arriveCtrl.text,
              'action': r.actionCtrl.text,
            })
        .toList();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(_colMin, _colMax);

  // ── 복사 / 인쇄 ──
  String _buildCopyText() {
    final b = StringBuffer('[유관기관 활동사항]\n');
    for (final r in _rows) {
      if (r.agencyCtrl.text.isNotEmpty) {
        b.writeln(
            '  ${r.no}. ${r.agencyCtrl.text} / ${r.personCtrl.text} / 도착: ${r.arriveCtrl.text} / ${r.actionCtrl.text}');
      }
    }
    return b.toString();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _buildCopyText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('복사됨'),
      backgroundColor: Color(0xFF4A148C),
      duration: Duration(seconds: 2),
    ));
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', '<br>');

  void _print() {
    final buf = StringBuffer();
    buf.write('''<html><head><meta charset="utf-8">
<style>
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
body { font-family: "Malgun Gothic", sans-serif; font-size: 13px; margin: 24px; color: #1a1a1a; }
h1 { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; text-align:center; }
table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
th { background: #f0f0f0; padding: 5px 8px; text-align: left; border: 1px solid #ccc; font-weight: bold; }
td { padding: 5px 8px; border: 1px solid #ccc; vertical-align: top; }
@media print { body { padding: 1cm; } }
</style>
<script>window.onload=function(){window.print();}</script>
</head><body>
<h1>유관기관 활동사항</h1>
<table>
<tr><th style="width:36px">연번</th><th style="width:90px">기관명</th><th style="width:80px">참석자</th><th style="width:80px">도착시간</th><th>조치내용</th></tr>
${_rows.map((r) => '<tr><td style="text-align:center">${r.no}</td><td>${_esc(r.agencyCtrl.text)}</td><td>${_esc(r.personCtrl.text)}</td><td>${_esc(r.arriveCtrl.text)}</td><td>${_esc(r.actionCtrl.text)}</td></tr>').join()}
</table>
</body></html>''');
    final blob = html.Blob([buf.toString()], 'text/html');
    html.window.open(html.Url.createObjectUrl(blob), '_blank');
  }

  Widget _cell(TextEditingController ctrl, String hint, {bool multiline = false}) => TextField(
        controller: ctrl,
        maxLines: multiline ? null : 1,
        minLines: 1,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Colors.black38),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        style: const TextStyle(fontSize: 12),
      );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('유관기관 활동사항'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: '인쇄',
              onPressed: _print),
          IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: '복사',
              onPressed: _copyToClipboard),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              _sectionCard(
                color: const Color(0xFF4A148C),
                icon: Icons.groups,
                title: '유관기관 활동사항',
                child: Column(children: [
                  // ── 헤더 행 (드래그 핸들 포함) ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(
                          width: 34,
                          child: Text('연번', style: _colHeader,
                              textAlign: TextAlign.center)),
                      const SizedBox(width: 8),
                      _resizableHeader('기관명', _agencyW,
                          (dx) => setState(() => _agencyW = _clamp(_agencyW + dx))),
                      const SizedBox(width: 8),
                      _resizableHeader('참석자', _personW,
                          (dx) => setState(() => _personW = _clamp(_personW + dx))),
                      const SizedBox(width: 8),
                      _resizableHeader('도착시간', _arriveW, null),
                      const SizedBox(width: 8),
                      Expanded(child: Text('조치내용', style: _colHeader)),
                    ]),
                  ),
                  // ── 데이터 행 ──
                  ..._rows.asMap().entries.map((e) {
                    final r = e.value;
                    r.no = e.key + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 34,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${r.no}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: _agencyW, child: _cell(r.agencyCtrl, '기관명')),
                        const SizedBox(width: 8),
                        SizedBox(width: _personW, child: _cell(r.personCtrl, '참석자')),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: _arriveW,
                          child: TextField(
                            controller: r.arriveCtrl,
                            decoration: const InputDecoration(
                              hintText: '14:30',
                              hintStyle: TextStyle(fontSize: 10, color: Colors.black38),
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            inputFormatters: [_TimeFormatter()],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _cell(r.actionCtrl, '조치내용', multiline: true)),
                        if (_rows.length > 10)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _rows[e.key].dispose();
                                _rows.removeAt(e.key);
                              });
                              _scheduleSave();
                            },
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(minWidth: 32),
                          ),
                      ]),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final r = _AgencyRow(_rows.length + 1);
                        _addListeners(r);
                        setState(() => _rows.add(r));
                        _scheduleSave();
                      },
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
