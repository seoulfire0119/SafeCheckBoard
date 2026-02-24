import 'package:flutter/material.dart';
import '../models/building.dart';
import 'dashboard_screen.dart';

class BuildingSetupScreen extends StatefulWidget {
  const BuildingSetupScreen({super.key});

  @override
  State<BuildingSetupScreen> createState() => _BuildingSetupScreenState();
}

class _BuildingSetupScreenState extends State<BuildingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: '테스트 빌딩');
  final _startFloorController = TextEditingController(text: '1');
  final _endFloorController = TextEditingController(text: '5');
  final _startUnitController = TextEditingController(text: '101');
  final _endUnitController = TextEditingController(text: '110');

  @override
  void dispose() {
    _nameController.dispose();
    _startFloorController.dispose();
    _endFloorController.dispose();
    _startUnitController.dispose();
    _endUnitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final building = Building.create(
      name: _nameController.text.trim(),
      startFloor: int.parse(_startFloorController.text.trim()),
      endFloor: int.parse(_endFloorController.text.trim()),
      startUnit: int.parse(_startUnitController.text.trim()),
      endUnit: int.parse(_endUnitController.text.trim()),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(building: building),
      ),
    );
  }

  String? _validateNotEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return '필수 입력';
    return null;
  }

  String? _validateInt(String? value) {
    if (value == null || value.trim().isEmpty) return '필수 입력';
    if (int.tryParse(value.trim()) == null) return '정수를 입력하세요';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCB - 건물 설정'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '건물 정보 입력',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '건물명',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.apartment),
                        ),
                        validator: _validateNotEmpty,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startFloorController,
                              decoration: const InputDecoration(
                                labelText: '시작 층',
                                border: OutlineInputBorder(),
                                hintText: '예: -2, 1',
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('~', style: TextStyle(fontSize: 20)),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _endFloorController,
                              decoration: const InputDecoration(
                                labelText: '끝 층',
                                border: OutlineInputBorder(),
                                hintText: '예: 5, 63',
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startUnitController,
                              decoration: const InputDecoration(
                                labelText: '시작 호',
                                border: OutlineInputBorder(),
                                hintText: '예: 101',
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('~', style: TextStyle(fontSize: 20)),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _endUnitController,
                              decoration: const InputDecoration(
                                labelText: '끝 호',
                                border: OutlineInputBorder(),
                                hintText: '예: 110',
                              ),
                              keyboardType: TextInputType.number,
                              validator: _validateInt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '* 지하층은 음수로 입력 (예: -2층 = -2)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text(
                          '대시보드 시작',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
