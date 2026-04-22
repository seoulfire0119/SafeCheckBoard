import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/firebase_service.dart';
import 'casualty_status_screen.dart' show savedCasualtyRows;
import 'disaster_response_screen.dart' show savedAgencyRows;

// ── 세션 내 저장 상태 ────────────────────────────────────────
Map<String, String> savedIncident = {};

// ── 재난발생현황 화면 ──────────────────────────────────────────

class IncidentStatusScreen extends StatefulWidget {
  final String? sessionCode;
  const IncidentStatusScreen({super.key, this.sessionCode});
  @override
  State<IncidentStatusScreen> createState() => _IncidentStatusScreenState();
}

class _IncidentStatusScreenState extends State<IncidentStatusScreen> {

  // ── 발생개요 ──
  final _date      = TextEditingController();
  final _location  = TextEditingController();
  final _target    = TextEditingController();
  final _floors    = TextEditingController();
  final _area      = TextEditingController();
  final _cause     = TextEditingController();

  // ── 피해상황 (사망/부상은 인명피해상황에서 자동계산) ──
  final _propReal  = TextEditingController(text: '0'); // 부동산
  final _propMove  = TextEditingController(text: '0'); // 동산

  // 사망/부상 자동계산
  int get _deadCount => savedCasualtyRows.where((r) => r['status'] == '지연환자').length;
  int get _injuredCount => savedCasualtyRows.where((r) => r['status'] != '지연환자' && (r['status'] ?? '').isNotEmpty).length;

  // 인원 자동계산 (유관기관 활동사항에서)
  int get _autoPersonTotal => savedAgencyRows.fold(0, (sum, r) => sum + (int.tryParse(r['person'] ?? '') ?? 0));

  // ── 동원상황 — 장비 ──
  final _eFire     = TextEditingController(text: '0');
  final _eDistrict = TextEditingController(text: '0');
  final _ePolice   = TextEditingController(text: '0');
  final _eElec     = TextEditingController(text: '0');
  final _eGas      = TextEditingController(text: '0');
  final _eOther    = TextEditingController(text: '0');

  // ── 주요활동사항 ──
  final _activities = TextEditingController();

  // 합계 (자동계산)
  int get _propTotal => _parseInt(_propReal) + _parseInt(_propMove);
  int get _equipTotal =>
      _parseInt(_eFire) + _parseInt(_eDistrict) + _parseInt(_ePolice) +
      _parseInt(_eElec) + _parseInt(_eGas) + _parseInt(_eOther);

  int _parseInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  Timer? _saveDebounce;

  void _scheduleSave() {
    if (widget.sessionCode == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1500), () {
      FirebaseService.instance.saveIncident(widget.sessionCode!, _collectData());
    });
  }

  Map<String, String> _collectData() => {
    'date': _date.text, 'location': _location.text,
    'target': _target.text, 'floors': _floors.text,
    'area': _area.text, 'cause': _cause.text,
    'dead': '$_deadCount', 'injured': '$_injuredCount',
    'propReal': _propReal.text, 'propMove': _propMove.text,
    'personTotal': '$_autoPersonTotal',
    'eFire': _eFire.text, 'eDistrict': _eDistrict.text,
    'ePolice': _ePolice.text, 'eElec': _eElec.text,
    'eGas': _eGas.text, 'eOther': _eOther.text,
    'activities': _activities.text,
  };

  void _applyData(Map<String, String> s) {
    _date.text       = s['date']       ?? '';
    _location.text   = s['location']   ?? '';
    _target.text     = s['target']     ?? '';
    _floors.text     = s['floors']     ?? '';
    _area.text       = s['area']       ?? '';
    _cause.text      = s['cause']      ?? '';
    _propReal.text   = s['propReal']   ?? '0';
    _propMove.text   = s['propMove']   ?? '0';
    _eFire.text      = s['eFire']      ?? '0';
    _eDistrict.text  = s['eDistrict']  ?? '0';
    _ePolice.text    = s['ePolice']    ?? '0';
    _eElec.text      = s['eElec']      ?? '0';
    _eGas.text       = s['eGas']       ?? '0';
    _eOther.text     = s['eOther']     ?? '0';
    _activities.text = s['activities'] ?? '';
  }

  @override
  void initState() {
    super.initState();
    // 로컬 캐시로 즉시 복원
    if (savedIncident.isNotEmpty) _applyData(savedIncident);
    // Firebase에서 최신 데이터 로드
    if (widget.sessionCode != null) {
      FirebaseService.instance.loadSecondaryData(widget.sessionCode!).then((data) {
        if (!mounted || data == null) return;
        final raw = data['incident'];
        if (raw == null) return;
        final s = Map<String, String>.from((raw as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
        setState(() => _applyData(s));
      });
    }
    // 합계 자동 갱신 + Firebase 저장 트리거
    for (final c in [
      _propReal, _propMove,
      _eFire, _eDistrict, _ePolice, _eElec, _eGas, _eOther,
    ]) {
      c.addListener(() { setState(() {}); _scheduleSave(); });
    }
    for (final c in [_date, _location, _target, _floors, _area, _cause, _activities]) {
      c.addListener(_scheduleSave);
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    savedIncident = _collectData();
    for (final c in [
      _date, _location, _target, _floors, _area, _cause,
      _propReal, _propMove,
      _eFire, _eDistrict, _ePolice, _eElec, _eGas, _eOther,
      _activities,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── 복사 텍스트 ──
  String _buildCopyText() {
    final b = StringBuffer();
    b.writeln('【재난발생현황】');
    b.writeln();
    b.writeln('[발생개요]');
    b.writeln('일시: ${_date.text}');
    b.writeln('장소: ${_location.text}');
    b.writeln('대상: ${_target.text}');
    b.writeln('건물구조: ${_floors.text}층 / ${_area.text}㎡');
    b.writeln('원인: ${_cause.text}');
    b.writeln();
    b.writeln('[피해상황]');
    b.writeln('인명피해: 사망 ${_deadCount}명 / 부상 ${_injuredCount}명');
    b.writeln('재산피해: ${_commaNum(_propTotal)}천원');
    b.writeln('  부동산: ${_commaNum(_parseInt(_propReal))}천원');
    b.writeln('  동산:   ${_commaNum(_parseInt(_propMove))}천원');
    b.writeln();
    b.writeln('[동원상황]');
    b.writeln('인원 총 ${_autoPersonTotal}명');
    for (final r in savedAgencyRows) {
      final agency = r['agency'] ?? '';
      final person = r['person'] ?? '0';
      if (agency.isNotEmpty) b.writeln('  $agency: $person명');
    }
    b.writeln('장비 총 ${_equipTotal}대');
    b.writeln('  소방 ${_eFire.text}대 / 구청 ${_eDistrict.text}대 / 경찰 ${_ePolice.text}대');
    b.writeln('  한전 ${_eElec.text}대 / 가스 ${_eGas.text}대 / 기타 ${_eOther.text}대');
    b.writeln();
    b.writeln('[주요활동사항]');
    b.writeln(_activities.text);
    return b.toString();
  }

  String _commaNum(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _buildCopyText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('재난발생현황 복사됨'),
      backgroundColor: Color(0xFF1565C0),
      duration: Duration(seconds: 2),
    ));
  }

  void _print() {
    final buf = StringBuffer();
    buf.write('''<html><head><meta charset="utf-8">
<style>
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
body { font-family: "Malgun Gothic", sans-serif; font-size: 13px; margin: 24px; color: #1a1a1a; }
h1 { font-size: 17px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 16px; text-align:center; }
h2 { font-size: 13px; background: #333; color: #fff; padding: 4px 10px; margin: 16px 0 6px; }
table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
th { width: 130px; background: #f0f0f0; padding: 5px 8px; text-align: left;
     border: 1px solid #ccc; font-weight: bold; vertical-align: top; }
td { padding: 5px 8px; border: 1px solid #ccc; vertical-align: top; }
.total { font-weight: bold; background: #e8f0fe; }
@media print { body { padding: 1cm; } }
</style>
<script>window.onload=function(){window.print();}</script>
</head><body>
<h1>재난발생현황</h1>
<h2>발생개요</h2>
<table>
  <tr><th>일시</th><td>${_esc(_date.text)}</td></tr>
  <tr><th>장소</th><td>${_esc(_location.text)}</td></tr>
  <tr><th>대상</th><td>${_esc(_target.text)}</td></tr>
  <tr><th>건물구조</th><td>${_esc(_floors.text)}층 / ${_esc(_area.text)}㎡</td></tr>
  <tr><th>원인</th><td>${_esc(_cause.text)}</td></tr>
</table>
<h2>피해상황</h2>
<table>
  <tr><th>인명피해</th><td>사망 ${_deadCount}명 &nbsp; 부상 ${_injuredCount}명</td></tr>
  <tr><th>재산피해</th><td class="total">${_commaNum(_propTotal)}천원</td></tr>
  <tr><th>&nbsp;&nbsp;부동산</th><td>${_commaNum(_parseInt(_propReal))}천원</td></tr>
  <tr><th>&nbsp;&nbsp;동산</th><td>${_commaNum(_parseInt(_propMove))}천원</td></tr>
</table>
<h2>동원상황</h2>
<table>
  <tr><th>인원 합계</th><td class="total">${_autoPersonTotal}명</td></tr>
  ${savedAgencyRows.where((r) => (r['agency'] ?? '').isNotEmpty).map((r) => '<tr><th>&nbsp;&nbsp;${_esc(r['agency']!)}</th><td>${_esc(r['person'] ?? '0')}명</td></tr>').join()}
  <tr><th>장비 합계</th><td class="total">${_equipTotal}대</td></tr>
  <tr><th>&nbsp;&nbsp;소방 / 구청 / 경찰</th><td>${_esc(_eFire.text)}대 &nbsp; ${_esc(_eDistrict.text)}대 &nbsp; ${_esc(_ePolice.text)}대</td></tr>
  <tr><th>&nbsp;&nbsp;한전 / 가스 / 기타</th><td>${_esc(_eElec.text)}대 &nbsp; ${_esc(_eGas.text)}대 &nbsp; ${_esc(_eOther.text)}대</td></tr>
</table>
<h2>주요활동사항</h2>
<table><tr><td style="min-height:60px">${_esc(_activities.text)}</td></tr></table>
</body></html>''');
    final blob = html.Blob([buf.toString()], 'text/html');
    html.window.open(html.Url.createObjectUrl(blob), '_blank');
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('\n', '<br>');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('재난발생현황'),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              // ── 발생개요 ──────────────────────────────────
              _section(
                color: const Color(0xFF1565C0),
                icon: Icons.info_outline,
                title: '발생개요',
                child: Column(children: [
                  Row(children: [
                    Expanded(flex: 2, child: _cf('일시', _date, hint: '2026-04-19 14:32')),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _cf('장소', _location, hint: '서울 마포구 ○○동 123')),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(flex: 3, child: _cf('대상', _target, hint: '주상복합 (지하2·지상25층)')),
                    const SizedBox(width: 8),
                    Expanded(child: _cf('층수', _floors, hint: '25', suffix: '층')),
                    const SizedBox(width: 8),
                    Expanded(child: _cf('면적', _area, hint: '4500', suffix: '㎡')),
                  ]),
                  const SizedBox(height: 6),
                  _cf('원인', _cause, hint: '주방 조리 중 실화 (추정)'),
                ]),
              ),
              const SizedBox(height: 8),
              // ── 피해상황 ──────────────────────────────────
              _section(
                color: const Color(0xFF6A1B9A),
                icon: Icons.warning_amber,
                title: '피해상황',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 인명피해 (자동)
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _subLabel('인명피해', autoNote: '인명피해상황 자동'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: _inlineNum('사망', _deadCount, Colors.red.shade700, '명')),
                          const SizedBox(width: 8),
                          Expanded(child: _inlineNum('부상', _injuredCount, Colors.orange.shade700, '명')),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 60, color: const Color(0xFFDDD8F0)),
                    const SizedBox(width: 16),
                    // 재산피해 (수동)
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _subLabel('재산피해', trailing: '합계 ${_commaNum(_propTotal)}천원'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: _compactNumField('부동산', _propReal, '천원')),
                          const SizedBox(width: 8),
                          Expanded(child: _compactNumField('동산', _propMove, '천원')),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── 동원상황 ──────────────────────────────────
              _section(
                color: const Color(0xFF2E7D32),
                icon: Icons.groups,
                title: '동원상황',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 인원 (자동)
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _subLabel('인원', autoNote: '유관기관 자동', trailing: '총 $_autoPersonTotal명'),
                        const SizedBox(height: 6),
                        ...() {
                          final agencies = savedAgencyRows
                              .where((r) => (r['agency'] ?? '').isNotEmpty).toList();
                          if (agencies.isEmpty) {
                            return [Text('유관기관 활동사항 입력 후 자동 반영',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400))];
                          }
                          return agencies.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(children: [
                              Expanded(child: Text(r['agency']!,
                                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                              Text('${r['person'] ?? '0'}명',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                            ]),
                          )).toList();
                        }(),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Container(width: 1, color: const Color(0xFFCCE5CC)),
                    const SizedBox(width: 16),
                    // 장비 (수동)
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _subLabel('장비', trailing: '총 $_equipTotal대'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: _compactNumField('소방', _eFire, '대')),
                          const SizedBox(width: 4),
                          Expanded(child: _compactNumField('구청', _eDistrict, '대')),
                          const SizedBox(width: 4),
                          Expanded(child: _compactNumField('경찰', _ePolice, '대')),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: _compactNumField('한전', _eElec, '대')),
                          const SizedBox(width: 4),
                          Expanded(child: _compactNumField('가스', _eGas, '대')),
                          const SizedBox(width: 4),
                          Expanded(child: _compactNumField('기타', _eOther, '대')),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── 주요활동사항 ──────────────────────────────
              _section(
                color: const Color(0xFF37474F),
                icon: Icons.edit_note,
                title: '주요활동사항',
                child: TextField(
                  controller: _activities,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '예) 14:32 최초 신고접수 / 14:41 펌프차 1번 도착 / 15:10 연소저지선 확보...',
                    hintStyle: TextStyle(fontSize: 11, color: Colors.black38),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(8),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static const _inputDeco = InputDecoration(
    border: OutlineInputBorder(),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  );

  Widget _section({required Color color, required IconData icon, required String title, required Widget child}) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(8), child: child),
      ]),
    );
  }

  // 컴팩트 텍스트 필드 (라벨 포함)
  Widget _cf(String label, TextEditingController ctrl, {String? hint, String? suffix}) {
    return TextField(
      controller: ctrl,
      decoration: _inputDeco.copyWith(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        hintStyle: const TextStyle(fontSize: 11, color: Colors.black26),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  // 소제목 행 (자동집계 주석 + 합계 트레일링)
  Widget _subLabel(String text, {String? autoNote, String? trailing}) {
    return Row(children: [
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
      if (autoNote != null) ...[
        const SizedBox(width: 4),
        Icon(Icons.lock_outline, size: 10, color: Colors.grey.shade400),
        const SizedBox(width: 2),
        Text(autoNote, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ],
      if (trailing != null) ...[
        const Spacer(),
        Text(trailing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
      ],
    ]);
  }

  // 자동계산 인명피해 표시 (작은 박스)
  Widget _inlineNum(String label, int value, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$label  ', style: TextStyle(fontSize: 11, color: color)),
        Text('$value$unit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // 컴팩트 숫자 입력 (장비/재산피해)
  Widget _compactNumField(String label, TextEditingController ctrl, String unit) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: _inputDeco.copyWith(
        labelText: label,
        suffixText: unit,
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

}
