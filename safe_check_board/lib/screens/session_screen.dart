import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../models/personnel_stats.dart';
import 'building_setup_screen.dart';
import 'dashboard_screen.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _joinController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _createNewSession() async {
    try {
      final code = FirebaseService.generateSessionCode();
      await FirebaseService.instance.createSession(code);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BuildingSetupScreen(
            sessionCode: code,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _joinSession() async {
    final code = _joinController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = '세션 코드는 6자리입니다');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final exists = await FirebaseService.instance.sessionExists(code);
      if (!exists) {
        setState(() {
          _error = '세션을 찾을 수 없습니다: $code';
          _joining = false;
        });
        return;
      }

      final data = await FirebaseService.instance.loadSession(code);
      if (!mounted) return;

      if (data == null || data.buildings.isEmpty) {
        // 세션은 있지만 아직 건물 설정 전 (같이 대기)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _WaitingScreen(sessionCode: code),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              sessionCode: code,
              sessionData: data,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '연결 오류: $e';
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고
                Icon(Icons.local_fire_department,
                    size: 72, color: Colors.deepOrange.shade600),
                const SizedBox(height: 8),
                Text(
                  'SafeCheckBoard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade800,
                      ),
                ),
                Text(
                  '화재현장 확인 시스템',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ── 새 세션 ──────────────────────────────────
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: Colors.deepOrange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '새 세션 시작',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '새 현장 세션을 생성합니다.\n고유 6자리 코드가 자동 발급됩니다.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _createNewSession,
                          icon: const Icon(Icons.rocket_launch_outlined),
                          label: const Text('새 세션 시작'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 세션 참여 ─────────────────────────────────
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login,
                                color: Colors.deepOrange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '세션 참여',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '진행 중인 현장 세션에 접속합니다.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _joinController,
                          decoration: InputDecoration(
                            hintText: '세션 코드 6자리 (예: AB3K7Z)',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            errorText: _error,
                            suffixIcon: const Icon(Icons.vpn_key_outlined),
                          ),
                          textCapitalization:
                              TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              letterSpacing: 4),
                          textAlign: TextAlign.center,
                          onSubmitted: (_) => _joinSession(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _joining ? null : _joinSession,
                          icon: _joining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(_joining ? '연결 중...' : '참여'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 세션 생성됐지만 아직 건물 설정 전 대기 화면 ─────────────────────────
class _WaitingScreen extends StatelessWidget {
  final String sessionCode;
  const _WaitingScreen({required this.sessionCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: Text('세션 $sessionCode'),
        backgroundColor: const Color(0xFFBF360C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<SessionData?>(
        stream: FirebaseService.instance.sessionStream(sessionCode),
        builder: (context, snap) {
          final data = snap.data;
          if (data != null && data.buildings.isNotEmpty) {
            // 건물 설정 완료 → 대시보드로
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DashboardScreen(
                    sessionCode: sessionCode,
                    sessionData: data,
                  ),
                ),
              );
            });
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text('세션 호스트가 건물을 설정 중입니다...'),
                const SizedBox(height: 8),
                Text(
                  '세션 코드: $sessionCode',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
