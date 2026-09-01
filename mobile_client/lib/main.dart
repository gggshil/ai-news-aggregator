import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.darkTheme,
      home: const AuthScreen(),
    );
  }
}

