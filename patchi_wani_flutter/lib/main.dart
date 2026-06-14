// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to landscape (recommended for tablet play)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PatchiWaniApp());
}

class PatchiWaniApp extends StatelessWidget {
  const PatchiWaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'パッチワニを捕まえろ！',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF3B30),
          secondary: Color(0xFFFFCC00),
        ),
      ),
      home: const GameScreen(),
    );
  }
}
