import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/firebase_service.dart';

// ── 상태 옵션 ─────────────────────────────────────────────────

const List<String> kCasualtyStatuses = ['지연환자', '긴급환자', '응급환자', '비응급환자'];

const Map<String, Color> kCasualtyColors = {
  '지연환자': Color(0xFF212121),  // 검은색
  '긴급환자': Color(0xFFE53935),  // 빨간색
  '응급환자': Color(0xFFF9A825),  // 노란색
  '비응급환자': Color(0xFF66BB6A),  // 초록색
};

// ── 데이터 모델 ──────────────────────────────────────────────

class _CasualtyRow {
  int no;
  String status = '';
  final nameCtrl     = TextEditingController();
  final genderCtrl   = TextEditingController();
  final ageCtrl      = TextEditingController();
  final foundCtrl    = TextEditingController();
  final ambulCtrl    = TextEditingController();
  final hospitalCtrl = TextEditingController();
  final injuryCtrl   = TextEditingController();
  final etcCtrl      = TextEditingController();
  _CasualtyRow(this.no);
  void dispose() {
    for (final c in [nameCtrl, genderCtrl, ageCtrl, foundCtrl, ambulCtrl, hospitalCtrl, injuryCtrl, etcCtrl]) c.dispose();
  }
}

// ── 세션 내 저장 상태 ────────────────────────────────────────
List<Map<String, String>> savedCasualtyRows = [];
int _savedCasualtyPage = 0;

// ── 인명피해상황 화면 ─────────────────────────────────────────

class CasualtyStatusScreen extends StatefulWidget {
  final String? sessionCode;
  const CasualtyStatusScreen({super.key, this.sessionCode});
  @override
  State<CasualtyStatusScreen> createState() => _CasualtyStatusScreenState();
}

class _CasualtyStatusScreenState extends State<CasualtyStatusScreen> {

  static const int _pageSize = 10;
  int _currentPage = 0;

  final List<_CasualtyRow> _casualtyRows = [];
  Timer? _saveDebounce;

  int get _totalPages => ((_casualtyRows.length - 1) ~/ _pageSize) + 1;
  List<_CasualtyRow> get _pageRows {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _casualtyRows.length);
    return _casualtyRows.sublist(start, end);
  }

  // 환자현황 자동 집계
  int _count(String status) => _casualtyRows.where((r) => r.status == status).length;
  int get _delayedCount    => _count('지연환자');
  int get _urgentCount     => _count('긴급환자');
  int get _emergencyCount  => _count('응급환자');
  int get _nonEmergencyCount => _count('비응급환자');
  int get _totalCount      => _delayedCount + _urgentCount + _emergencyCount + _nonEmergencyCount;

  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      FirebaseService.instance.saveCasualty(widget.sessionCode!, _collectRows());
    });
  }

  List<Map<String, String>> _collectRows() => _casualtyRows.map((r) => {
    'status': r.status, 'name': r.nameCtrl.text,
    'gender': r.genderCtrl.text, 'age': r.ageCtrl.text,
    'found': r.foundCtrl.text, 'ambul': r.ambulCtrl.text,
    'hospital': r.hospitalCtrl.text, 'injury': r.injuryCtrl.text,
    'etc': r.etcCtrl.text,
  }).toList();

  void _addRowListeners(_CasualtyRow r) {
    for (final c in [r.nameCtrl, r.genderCtrl, r.ageCtrl, r.foundCtrl, r.ambulCtrl, r.hospitalCtrl, r.injuryCtrl, r.etcCtrl]) {
      c.addListener(_scheduleSave);
    }
  }

  void _applyRows(List<Map<String, String>> list) {
    for (final r in _casualtyRows) r.dispose();
    _casualtyRows.clear();
    if (list.isEmpty) {
      for (int i = 0; i < 10; i++) { final r = _CasualtyRow(i + 1); _addRowListeners(r); _casualtyRows.add(r); }
      return;
    }
    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      final r = _CasualtyRow(i + 1);
      r.status            = m['status']   ?? '';
      r.nameCtrl.text     = m['name']     ?? '';
      r.genderCtrl.text   = m['gender']   ?? '';
      r.ageCtrl.text      = m['age']      ?? '';
      r.foundCtrl.text    = m['found']    ?? '';
      r.ambulCtrl.text    = m['ambul']    ?? '';
      r.hospitalCtrl.text = m['hospital'] ?? '';
      r.injuryCtrl.text   = m['injury']   ?? '';
      r.etcCtrl.text      = m['etc']      ?? '';
      _addRowListeners(r);
      _casualtyRows.add(r);
    }
  }

  @override
  void initState() {
    super.initState();
    // 로컬 캐시로 즉시 복원
    _applyRows(savedCasualtyRows);
    if (savedCasualtyRows.isNotEmpty) {
      _currentPage = _savedCasualtyPage.clamp(0, _totalPages - 1);
    }
    // Firebase에서 최신 데이터 로드
    if (widget.sessionCode != null) {
      FirebaseService.instance.loadSecondaryData(widget.sessionCode!).then((data) {
        if (!mounted || data == null) return;
        final raw = data['casualty'];
        if (raw == null) return;
        final rows = ((raw['rows'] as List?) ?? [])
            .map((m) => Map<String, String>.from((m as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
        setState(() { _applyRows(rows); _currentPage = 0; });
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    savedCasualtyRows = _collectRows();
    _savedCasualtyPage = _currentPage;
    for (final r in _casualtyRows) r.dispose();
    super.dispose();
  }

  // ── 복사 텍스트 ──
  String _buildCopyText() {
    final b = StringBuffer();
    b.writeln('[인명피해 목록]');
    for (final r in _casualtyRows) {
      if (r.nameCtrl.text.isNotEmpty || r.status.isNotEmpty) {
        final statusStr = r.status.isNotEmpty ? '[${r.status}] ' : '';
        b.writeln('  ${r.no}. $statusStr${r.nameCtrl.text} / ${r.genderCtrl.text} / ${r.ageCtrl.text}세 / 발견: ${r.foundCtrl.text} / 구급대: ${r.ambulCtrl.text} / 병원: ${r.hospitalCtrl.text} / 부상: ${r.injuryCtrl.text} / ${r.etcCtrl.text}');
      }
    }
    b.writeln();
    b.writeln('[환자현황]');
    b.writeln('  총계: ${_totalCount}명  지연(사망): ${_delayedCount}명  긴급: ${_urgentCount}명  응급: ${_emergencyCount}명  비응급: ${_nonEmergencyCount}명');
    return b.toString();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _buildCopyText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('인명피해상황 복사됨'),
      backgroundColor: Color(0xFFB71C1C),
      duration: Duration(seconds: 2),
    ));
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('\n', '<br>');

  String _statusBadge(String status) {
    if (status.isEmpty) return '';
    const colors = {
      '지연환자': '#212121',
      '긴급환자': '#E53935',
      '응급환자': '#F9A825',
      '비응급환자': '#66BB6A',
    };
    final c = colors[status] ?? '#333';
    return '<span style="background:$c;color:#fff;padding:1px 6px;border-radius:3px;font-size:10px;">$status</span>';
  }

  void _print() {
    final buf = StringBuffer();
    buf.write('''<html><head><meta charset="utf-8">
<style>
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
body { font-family: "Malgun Gothic", sans-serif; font-size: 12px; margin: 24px; color: #1a1a1a; }
h1 { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; text-align:center; }
h2 { font-size: 13px; background: #B71C1C; color: #fff; padding: 4px 10px; margin: 16px 0 6px; }
table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
th { background: #f0f0f0; padding: 5px 6px; text-align: left; border: 1px solid #ccc; font-weight: bold; vertical-align: top; font-size: 11px; }
td { padding: 5px 6px; border: 1px solid #ccc; vertical-align: middle; }
.summary-table td { font-size: 15px; font-weight: bold; text-align: center; padding: 10px 8px; }
.delayed  { color: #212121; } .urgent  { color: #E53935; }
.emergency { color: #2E7D32; } .non     { color: #66BB6A; }
.total    { color: #1a1a1a; background: #f5f5f5; }
@media print { body { padding: 1cm; } }
</style>
<script>window.onload=function(){window.print();}</script>
</head><body>
<h1>인명피해상황</h1>
<h2>환자현황</h2>
<table class="summary-table">
  <tr>
    <th style="width:20%">총계</th>
    <th style="width:20%">지연환자</th>
    <th style="width:20%">긴급환자</th>
    <th style="width:20%">응급환자</th>
    <th style="width:20%">비응급환자</th>
  </tr>
  <tr>
    <td class="total">${_totalCount}명</td>
    <td class="delayed">${_delayedCount}명</td>
    <td class="urgent">${_urgentCount}명</td>
    <td class="emergency">${_emergencyCount}명</td>
    <td class="non">${_nonEmergencyCount}명</td>
  </tr>
</table>
<h2>인명피해 목록</h2>
<table>
<tr>
  <th style="width:28px">연번</th>
  <th style="width:76px">구분</th>
  <th style="width:90px">성명(국적)</th>
  <th style="width:40px">성별</th>
  <th style="width:36px">연령</th>
  <th style="width:80px">발견장소</th>
  <th style="width:80px">구급대</th>
  <th style="width:100px">이송병원/현장처치</th>
  <th style="width:110px">부상정도(부위)</th>
  <th>기타</th>
</tr>
${_casualtyRows.map((r) => '<tr><td style="text-align:center">${r.no}</td><td>${_statusBadge(r.status)}</td><td>${_esc(r.nameCtrl.text)}</td><td>${_esc(r.genderCtrl.text)}</td><td>${_esc(r.ageCtrl.text)}</td><td>${_esc(r.foundCtrl.text)}</td><td>${_esc(r.ambulCtrl.text)}</td><td>${_esc(r.hospitalCtrl.text)}</td><td>${_esc(r.injuryCtrl.text)}</td><td>${_esc(r.etcCtrl.text)}</td></tr>').join()}
</table>
</body></html>''');
    final blob = html.Blob([buf.toString()], 'text/html');
    html.window.open(html.Url.createObjectUrl(blob), '_blank');
  }

  static final _colHeader = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600);

  // 성명 마스킹: 성(첫 글자)만 표시, 나머지는 ● 처리
  static String _maskName(String s) {
    final name = s.trim();
    if (name.isEmpty) return '';
    final runes = name.runes.toList();
    if (runes.length <= 1) return name;
    return String.fromCharCode(runes[0]) + '●' * (runes.length - 1);
  }

  Widget _cell(TextEditingController ctrl, String hint, {double? width}) {
    Widget field = TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 10, color: Colors.black38),
        border: const OutlineInputBorder(), isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      style: const TextStyle(fontSize: 12),
    );
    return width != null ? SizedBox(width: width, child: field) : field;
  }

  Widget _statusDropdown(_CasualtyRow row) {
    return SizedBox(
      width: 110,
      child: DropdownButtonFormField<String>(
        value: row.status.isEmpty ? null : row.status,
        hint: const Text('구분', style: TextStyle(fontSize: 11, color: Colors.black38)),
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(), isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          const DropdownMenuItem(value: '', child: Text('—', style: TextStyle(color: Colors.black38, fontSize: 12))),
          ...kCasualtyStatuses.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kCasualtyColors[s] ?? Colors.black87,
              ),
            ),
          )),
        ],
        onChanged: (v) { setState(() => row.status = v ?? ''); _scheduleSave(); },
      ),
    );
  }

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

  Widget _summaryTile(String label, int count, Color color, {bool isTotal = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isTotal ? const Color(0xFF1a1a1a) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isTotal ? Colors.black45 : color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white70 : color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$count명',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white : color,
              fontFamily: 'monospace',
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('인명피해상황'),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_outlined), tooltip: '인쇄', onPressed: _print),
          IconButton(icon: const Icon(Icons.copy_outlined), tooltip: '복사', onPressed: _copyToClipboard),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // ── 환자현황 ──
              _section(
                color: const Color(0xFF880E4F),
                icon: Icons.local_hospital_outlined,
                title: '환자현황',
                child: Column(children: [
                  Row(children: [
                    _summaryTile('총계', _totalCount, Colors.black87, isTotal: true),
                    const SizedBox(width: 8),
                    _summaryTile('지연환자', _delayedCount, const Color(0xFF212121)),
                    const SizedBox(width: 8),
                    _summaryTile('긴급환자', _urgentCount, const Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    _summaryTile('응급환자', _emergencyCount, const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _summaryTile('비응급환자', _nonEmergencyCount, const Color(0xFF66BB6A)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '* 아래 인명피해 목록의 구분 드롭박스 선택에 따라 자동 집계됩니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // ── 인명피해 목록 ──
              _section(
                color: const Color(0xFFB71C1C),
                icon: Icons.personal_injury,
                title: '인명피해 목록  (총 ${_casualtyRows.length}명)',
                child: Column(children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          SizedBox(width: 32,  child: Text('연번', style: _colHeader, textAlign: TextAlign.center)),
                          const SizedBox(width: 6),
                          SizedBox(width: 110, child: Text('구분', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 100, child: Text('성명(국적)', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 52,  child: Text('성별', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 48,  child: Text('연령', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 90,  child: Text('발견장소', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 90,  child: Text('구급대', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 110, child: Text('이송병원/현장처치', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 120, child: Text('부상정도(부위)', style: _colHeader)),
                          const SizedBox(width: 6),
                          SizedBox(width: 90,  child: Text('기타', style: _colHeader)),
                        ]),
                      ),
                      ..._pageRows.map((r) {
                        final globalIdx = _casualtyRows.indexOf(r);
                        r.no = globalIdx + 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            SizedBox(width: 32, child: Center(child: Text('${r.no}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                            const SizedBox(width: 6),
                            _statusDropdown(r),
                            const SizedBox(width: 6),
                            _MaskedNameField(ctrl: r.nameCtrl, width: 100),
                            const SizedBox(width: 6),
                            _cell(r.genderCtrl, '남/여', width: 52),
                            const SizedBox(width: 6),
                            _cell(r.ageCtrl, '30', width: 48),
                            const SizedBox(width: 6),
                            _cell(r.foundCtrl, '2층 복도', width: 90),
                            const SizedBox(width: 6),
                            _cell(r.ambulCtrl, '○○구급대', width: 90),
                            const SizedBox(width: 6),
                            _cell(r.hospitalCtrl, '○○병원', width: 110),
                            const SizedBox(width: 6),
                            _cell(r.injuryCtrl, '2도 화상/손·팔', width: 120),
                            const SizedBox(width: 6),
                            _cell(r.etcCtrl, '비고', width: 90),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                              onPressed: () { setState(() {
                                _casualtyRows[globalIdx].dispose();
                                _casualtyRows.removeAt(globalIdx);
                                if (_currentPage >= _totalPages) {
                                  _currentPage = (_totalPages - 1).clamp(0, 999);
                                }
                              }); _scheduleSave(); },
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(minWidth: 32),
                            ),
                          ]),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // ── 페이지 네비게이터 + 행 추가 ──
                  Row(children: [
                    TextButton.icon(
                      onPressed: () { final r = _CasualtyRow(_casualtyRows.length + 1); _addRowListeners(r); setState(() { _casualtyRows.add(r); _currentPage = _totalPages - 1; }); _scheduleSave(); },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('행 추가'),
                    ),
                    const Spacer(),
                    if (_totalPages > 1) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                        tooltip: '이전 페이지',
                      ),
                      Text(
                        '${_currentPage + 1} / $_totalPages',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < _totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                        tooltip: '다음 페이지',
                      ),
                    ],
                  ]),
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

// ── 성명 마스킹 필드 (포커스 시 원본, 비포커스 시 성●● 표시) ──────────
class _MaskedNameField extends StatefulWidget {
  final TextEditingController ctrl;
  final double width;
  const _MaskedNameField({required this.ctrl, required this.width});
  @override
  State<_MaskedNameField> createState() => _MaskedNameFieldState();
}

class _MaskedNameFieldState extends State<_MaskedNameField> {
  late final FocusNode _focus;
  bool _isFocused = false;

  static String _mask(String s) {
    final name = s.trim();
    if (name.isEmpty) return '';
    final runes = name.runes.toList();
    if (runes.length <= 1) return name;
    return String.fromCharCode(runes[0]) + '●' * (runes.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() => setState(() => _isFocused = _focus.hasFocus));
    widget.ctrl.addListener(() { if (!_isFocused) setState(() {}); });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masked = _mask(widget.ctrl.text);
    final showMask = !_isFocused && widget.ctrl.text.isNotEmpty;

    return SizedBox(
      width: widget.width,
      child: Stack(
        children: [
          // TextField가 높이를 결정 (항상 존재)
          TextField(
            controller: widget.ctrl,
            focusNode: _focus,
            decoration: const InputDecoration(
              hintText: '성명(국적)',
              hintStyle: TextStyle(fontSize: 10, color: Colors.black26),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 12,
              color: showMask ? Colors.transparent : Colors.black87,
            ),
          ),
          // 마스킹 오버레이: TextField와 동일 영역을 Positioned.fill로 덮음
          if (showMask)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    Expanded(
                      child: Text(masked,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade400),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
