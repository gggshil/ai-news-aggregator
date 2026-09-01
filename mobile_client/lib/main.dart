import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const AiNewsApp());
}

class AiNewsApp extends StatelessWidget {
  const AiNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI News Aggregator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}
