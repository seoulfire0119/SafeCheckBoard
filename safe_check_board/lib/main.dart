import 'package:flutter/material.dart';
import 'screens/building_setup_screen.dart';

void main() {
  runApp(const SafeCheckBoardApp());
}

class SafeCheckBoardApp extends StatelessWidget {
  const SafeCheckBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCB - SafeCheckBoard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const BuildingSetupScreen(),
    );
  }
}
