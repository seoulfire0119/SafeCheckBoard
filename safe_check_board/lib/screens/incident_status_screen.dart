import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ── 세션 내 저장 상태 ────────────────────────────────────────
Map<String, String> _savedIncident = {};

// ── 재난발생현황 화면 ──────────────────────────────────────────

class IncidentStatusScreen extends StatefulWidget {
  const IncidentStatusScreen({super.key});
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

  // ── 피해상황 ──
  final _dead      = TextEditingController(text: '0');
  final _injured   = TextEditingController(text: '0');
  final _propReal  = TextEditingController(text: '0'); // 부동산
  final _propMove  = TextEditingController(text: '0'); // 동산

  // ── 동원상황 — 인원 ──
  final _pFire     = TextEditingController(text: '0');
  final _pDistrict = TextEditingController(text: '0');
  final _pPolice   = TextEditingController(text: '0');
  final _pElec     = TextEditingController(text: '0');
  final _pGas      = TextEditingController(text: '0');
  final _pOther    = TextEditingController(text: '0');

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
  int get _personTotal =>
      _parseInt(_pFire) + _parseInt(_pDistrict) + _parseInt(_pPolice) +
      _parseInt(_pElec) + _parseInt(_pGas) + _parseInt(_pOther);
  int get _equipTotal =>
      _parseInt(_eFire) + _parseInt(_eDistrict) + _parseInt(_ePolice) +
      _parseInt(_eElec) + _parseInt(_eGas) + _parseInt(_eOther);

  int _parseInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  @override
  void initState() {
    super.initState();
    // 저장된 상태 복원
    final s = _savedIncident;
    if (s.isNotEmpty) {
      _date.text      = s['date']      ?? '';
      _location.text  = s['location']  ?? '';
      _target.text    = s['target']    ?? '';
      _floors.text    = s['floors']    ?? '';
      _area.text      = s['area']      ?? '';
      _cause.text     = s['cause']     ?? '';
      _dead.text      = s['dead']      ?? '0';
      _injured.text   = s['injured']   ?? '0';
      _propReal.text  = s['propReal']  ?? '0';
      _propMove.text  = s['propMove']  ?? '0';
      _pFire.text     = s['pFire']     ?? '0';
      _pDistrict.text = s['pDistrict'] ?? '0';
      _pPolice.text   = s['pPolice']   ?? '0';
      _pElec.text     = s['pElec']     ?? '0';
      _pGas.text      = s['pGas']      ?? '0';
      _pOther.text    = s['pOther']    ?? '0';
      _eFire.text     = s['eFire']     ?? '0';
      _eDistrict.text = s['eDistrict'] ?? '0';
      _ePolice.text   = s['ePolice']   ?? '0';
      _eElec.text     = s['eElec']     ?? '0';
      _eGas.text      = s['eGas']      ?? '0';
      _eOther.text    = s['eOther']    ?? '0';
      _activities.text = s['activities'] ?? '';
    }
    // 합계 자동 갱신
    for (final c in [
      _propReal, _propMove,
      _pFire, _pDistrict, _pPolice, _pElec, _pGas, _pOther,
      _eFire, _eDistrict, _ePolice, _eElec, _eGas, _eOther,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    // 상태 저장
    _savedIncident = {
      'date': _date.text, 'location': _location.text,
      'target': _target.text, 'floors': _floors.text,
      'area': _area.text, 'cause': _cause.text,
      'dead': _dead.text, 'injured': _injured.text,
      'propReal': _propReal.text, 'propMove': _propMove.text,
      'pFire': _pFire.text, 'pDistrict': _pDistrict.text,
      'pPolice': _pPolice.text, 'pElec': _pElec.text,
      'pGas': _pGas.text, 'pOther': _pOther.text,
      'eFire': _eFire.text, 'eDistrict': _eDistrict.text,
      'ePolice': _ePolice.text, 'eElec': _eElec.text,
      'eGas': _eGas.text, 'eOther': _eOther.text,
      'activities': _activities.text,
    };
    for (final c in [
      _date, _location, _target, _floors, _area, _cause,
      _dead, _injured, _propReal, _propMove,
      _pFire, _pDistrict, _pPolice, _pElec, _pGas, _pOther,
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
    b.writeln('인명피해: 사망 ${_dead.text}명 / 부상 ${_injured.text}명');
    b.writeln('재산피해: ${_commaNum(_propTotal)}천원');
    b.writeln('  부동산: ${_commaNum(_parseInt(_propReal))}천원');
    b.writeln('  동산:   ${_commaNum(_parseInt(_propMove))}천원');
    b.writeln();
    b.writeln('[동원상황]');
    b.writeln('인원 총 ${_personTotal}명');
    b.writeln('  소방 ${_pFire.text}명 / 구청 ${_pDistrict.text}명 / 경찰 ${_pPolice.text}명');
    b.writeln('  한전 ${_pElec.text}명 / 가스 ${_pGas.text}명 / 기타 ${_pOther.text}명');
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
  <tr><th>인명피해</th><td>사망 ${_esc(_dead.text)}명 &nbsp; 부상 ${_esc(_injured.text)}명</td></tr>
  <tr><th>재산피해</th><td class="total">${_commaNum(_propTotal)}천원</td></tr>
  <tr><th>&nbsp;&nbsp;부동산</th><td>${_commaNum(_parseInt(_propReal))}천원</td></tr>
  <tr><th>&nbsp;&nbsp;동산</th><td>${_commaNum(_parseInt(_propMove))}천원</td></tr>
</table>
<h2>동원상황</h2>
<table>
  <tr><th>인원 합계</th><td class="total">${_personTotal}명</td></tr>
  <tr><th>&nbsp;&nbsp;소방 / 구청 / 경찰</th><td>${_esc(_pFire.text)}명 &nbsp; ${_esc(_pDistrict.text)}명 &nbsp; ${_esc(_pPolice.text)}명</td></tr>
  <tr><th>&nbsp;&nbsp;한전 / 가스 / 기타</th><td>${_esc(_pElec.text)}명 &nbsp; ${_esc(_pGas.text)}명 &nbsp; ${_esc(_pOther.text)}명</td></tr>
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              _section(
                color: const Color(0xFF1565C0),
                icon: Icons.info_outline,
                title: '발생개요',
                child: Column(children: [
                  _field('일시', _date, hint: '예) 2026-04-19 14:32'),
                  _field('장소', _location, hint: '예) 서울 마포구 ○○동 123'),
                  _field('대상', _target, hint: '예) 주상복합 (지하2층~지상25층)'),
                  Row(children: [
                    Expanded(child: _field('층수', _floors, hint: '예) 25', suffix: '층')),
                    const SizedBox(width: 10),
                    Expanded(child: _field('면적', _area, hint: '예) 4500', suffix: '㎡')),
                  ]),
                  _field('원인', _cause, hint: '예) 주방 조리 중 실화 (추정)'),
                ]),
              ),
              const SizedBox(height: 12),
              _section(
                color: const Color(0xFF6A1B9A),
                icon: Icons.warning_amber,
                title: '피해상황',
                child: Column(children: [
                  // 인명피해
                  _label('인명피해'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _numField('사망', _dead, Colors.red.shade700, '명')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField('부상', _injured, Colors.orange.shade700, '명')),
                  ]),
                  const SizedBox(height: 12),
                  // 재산피해
                  _label('재산피해'),
                  const SizedBox(height: 6),
                  _totalBox('합계 ${_commaNum(_propTotal)}천원'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _numField('부동산', _propReal, Colors.brown.shade700, '천원')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField('동산', _propMove, Colors.brown.shade400, '천원')),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              _section(
                color: const Color(0xFF2E7D32),
                icon: Icons.groups,
                title: '동원상황',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('인원'),
                  const SizedBox(height: 6),
                  _totalBox('총 $_personTotal명'),
                  const SizedBox(height: 6),
                  _mobilRow(['소방', '구청', '경찰'], [_pFire, _pDistrict, _pPolice], '명'),
                  const SizedBox(height: 6),
                  _mobilRow(['한전', '가스', '기타'], [_pElec, _pGas, _pOther], '명'),
                  const SizedBox(height: 14),
                  _label('장비'),
                  const SizedBox(height: 6),
                  _totalBox('총 $_equipTotal대'),
                  const SizedBox(height: 6),
                  _mobilRow(['소방', '구청', '경찰'], [_eFire, _eDistrict, _ePolice], '대'),
                  const SizedBox(height: 6),
                  _mobilRow(['한전', '가스', '기타'], [_eElec, _eGas, _eOther], '대'),
                ]),
              ),
              const SizedBox(height: 12),
              _section(
                color: const Color(0xFF37474F),
                icon: Icons.edit_note,
                title: '주요활동사항',
                child: TextField(
                  controller: _activities,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '주요 활동 내용을 자유롭게 서술하세요\n예) 14:32 최초 신고접수 / 14:41 펌프차 1번 도착 / 15:10 연소저지선 확보...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.black38),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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

  Widget _field(String label, TextEditingController ctrl, {String? hint, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          hintStyle: const TextStyle(fontSize: 11, color: Colors.black38),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, Color color, String unit) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _mobilRow(List<String> labels, List<TextEditingController> ctrls, String unit) {
    return Row(
      children: List.generate(labels.length, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
          child: TextField(
            controller: ctrls[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: labels[i],
              suffixText: unit,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      )),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600));

  Widget _totalBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F0FE),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
    ),
    child: Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
  );
}
