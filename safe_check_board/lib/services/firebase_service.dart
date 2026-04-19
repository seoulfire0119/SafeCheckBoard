import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/status.dart';
import '../models/building.dart';
import '../models/building_state.dart';
import '../models/unit.dart';
import '../models/personnel_stats.dart';
import '../models/log_entry.dart';

class SessionData {
  final List<Building> buildings;
  final List<BuildingState> states;
  final List<PersonnelStats> personnelStats;
  final List<LogEntry> log;

  SessionData({
    required this.buildings,
    required this.states,
    required this.personnelStats,
    required this.log,
  });
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  // ── 세션 코드 생성 (6자리 영숫자, 혼동 문자 제외) ──────────────────
  static String generateSessionCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ── 세션 생성 ─────────────────────────────────────────────────────
  Future<void> createSession(String code) async {
    await _sessions.doc(code).set({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'buildings': [],
      'states': [],
      'personnelStats': [],
      'log': [],
    });
  }

  // ── 세션 존재 확인 ───────────────────────────────────────────────
  Future<bool> sessionExists(String code) async {
    final doc = await _sessions.doc(code).get();
    return doc.exists;
  }

  // ── 전체 세션 저장 ───────────────────────────────────────────────
  Future<void> saveSession({
    required String code,
    required List<Building> buildings,
    required List<BuildingState> states,
    required List<PersonnelStats> personnelStats,
    required List<LogEntry> log,
  }) async {
    await _sessions.doc(code).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'buildings': buildings.map(_buildingToMap).toList(),
      'states': states.map(_stateToMap).toList(),
      'personnelStats': personnelStats.map(_statsToMap).toList(),
      'log': log.reversed.take(200).toList().reversed
          .map(_logToMap)
          .toList(),
    });
  }

  // ── 세션 1회 로드 ────────────────────────────────────────────────
  Future<SessionData?> loadSession(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists || doc.data() == null) return null;
    return _parseSession(doc.data()!);
  }

  // ── 실시간 스트림 (서버 확정 데이터만) ──────────────────────────
  Stream<SessionData?> sessionStream(String code) {
    return _sessions
        .doc(code)
        .snapshots()
        .where((snap) => !snap.metadata.hasPendingWrites && snap.exists)
        .map((snap) =>
            snap.data() != null ? _parseSession(snap.data()!) : null);
  }

  // ── 직렬화 ───────────────────────────────────────────────────────
  Map<String, dynamic> _buildingToMap(Building b) => {
        'name': b.name,
        'startFloor': b.startFloor,
        'endFloor': b.endFloor,
        'defaultUnits': b.defaultUnits,
        'isHorizontal': b.isHorizontal,
      };

  Map<String, dynamic> _stateToMap(BuildingState s) => {
        'units': s.units.map(_unitToMap).toList(),
        'hiddenFloors': s.hiddenFloors.toList(),
        'floorLabels':
            s.floorLabels.map((k, v) => MapEntry(k.toString(), v)),
      };

  Map<String, dynamic> _unitToMap(Unit u) => {
        'id': u.id,
        'floor': u.floor,
        'unitIndex': u.unitIndex,
        'number': u.number,
        'status': u.status.name,
        'memo': u.memo,
        'memoPinned': u.memoPinned,
        'vulnerable': u.vulnerable,
        'spanCount': u.spanCount,
      };

  Map<String, dynamic> _statsToMap(PersonnelStats s) => {
        'selfEvac': s.selfEvac,
        'rescued': s.rescued,
        'notFound': s.notFound,
      };

  Map<String, dynamic> _logToMap(LogEntry e) => {
        'id': e.id,
        'unitName': e.unitName,
        'from': e.from.name,
        'to': e.to.name,
        'time': e.time.millisecondsSinceEpoch,
      };

  // ── 역직렬화 ─────────────────────────────────────────────────────
  SessionData _parseSession(Map<String, dynamic> data) {
    final buildings = (data['buildings'] as List? ?? [])
        .map((b) => _buildingFromMap(b as Map<String, dynamic>))
        .toList();
    final states = (data['states'] as List? ?? [])
        .map((s) => _stateFromMap(s as Map<String, dynamic>))
        .toList();
    final stats = (data['personnelStats'] as List? ?? [])
        .map((s) => _statsFromMap(s as Map<String, dynamic>))
        .toList();
    final log = (data['log'] as List? ?? [])
        .map((e) => _logFromMap(e as Map<String, dynamic>))
        .toList();

    // 건물 수와 states/stats 수 맞추기
    while (states.length < buildings.length) {
      states.add(BuildingState(units: []));
    }
    while (stats.length < buildings.length) {
      stats.add(PersonnelStats());
    }

    return SessionData(
      buildings: buildings,
      states: states,
      personnelStats: stats,
      log: log,
    );
  }

  Building _buildingFromMap(Map<String, dynamic> m) => Building(
        name: m['name'] as String,
        startFloor: m['startFloor'] as int,
        endFloor: m['endFloor'] as int,
        defaultUnits: m['defaultUnits'] as int,
        isHorizontal: m['isHorizontal'] as bool? ?? false,
      );

  BuildingState _stateFromMap(Map<String, dynamic> m) {
    final units = (m['units'] as List? ?? [])
        .map((u) => _unitFromMap(u as Map<String, dynamic>))
        .toList();
    final hidden =
        (m['hiddenFloors'] as List? ?? []).cast<int>().toSet();
    final labels =
        (m['floorLabels'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(int.parse(k), v as String));
    return BuildingState(
        units: units, hiddenFloors: hidden, floorLabels: labels);
  }

  Unit _unitFromMap(Map<String, dynamic> m) => Unit(
        id: m['id'] as String,
        floor: m['floor'] as int,
        unitIndex: m['unitIndex'] as int,
        number: m['number'] as int,
        status: UnitStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => UnitStatus.unknown,
        ),
        memo: m['memo'] as String? ?? '',
        memoPinned: m['memoPinned'] as bool? ?? false,
        vulnerable: m['vulnerable'] as bool? ?? false,
        spanCount: m['spanCount'] as int? ?? 1,
      );

  PersonnelStats _statsFromMap(Map<String, dynamic> m) => PersonnelStats(
        selfEvac: m['selfEvac'] as int? ?? 0,
        rescued: m['rescued'] as int? ?? 0,
        notFound: m['notFound'] as int? ?? 0,
      );

  LogEntry _logFromMap(Map<String, dynamic> m) => LogEntry(
        id: m['id'] as int,
        unitName: m['unitName'] as String,
        from: UnitStatus.values.firstWhere(
          (s) => s.name == m['from'],
          orElse: () => UnitStatus.unknown,
        ),
        to: UnitStatus.values.firstWhere(
          (s) => s.name == m['to'],
          orElse: () => UnitStatus.unknown,
        ),
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
      );

  // ── 보조 화면 저장 ────────────────────────────────────────────

  Future<void> saveIncident(String code, Map<String, String> data) async {
    await _sessions.doc(code).update({
      'incident': data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveDisasterResponse(
      String code,
      List<Map<String, String>> actionRows,
      List<Map<String, String>> agencyRows) async {
    await _sessions.doc(code).update({
      'disasterResponse': {'actionRows': actionRows, 'agencyRows': agencyRows},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveCasualty(
      String code, List<Map<String, String>> rows) async {
    await _sessions.doc(code).update({
      'casualty': {'rows': rows},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 보조 화면 로드 ────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadSecondaryData(String code) async {
    final doc = await _sessions.doc(code).get();
    if (!doc.exists || doc.data() == null) return null;
    final d = doc.data()!;
    return {
      'incident':        d['incident'],
      'disasterResponse': d['disasterResponse'],
      'casualty':        d['casualty'],
    };
  }
}
