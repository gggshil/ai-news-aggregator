import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color bgDark = Color(0xFF070A12);
  static const Color bgSecondary = Color(0xFF090D17);
  
  // Surfaces
  static const Color surface = Color(0xFF0D1320);
  static const Color surfaceCard = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF151D2E);
  static const Color surfaceInput = Color(0xFF0B101D);

  // Borders
  static const Color borderSubtle = Color(0x1FFFFFFF); // 12% white
  static const Color borderGlow = Color(0x336366F1); // indigo glow
  static const Color borderFocused = Color(0xFF6366F1);

  // Brand & Gradients
  static const Color primaryIndigo = Color(0xFF6366F1);
  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentBlue = Color(0xFF2563EB);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient heroRadialGlow = RadialGradient(
    center: Alignment(0.0, -0.2),
    radius: 0.8,
    colors: [
      Color(0x1F6366F1), // Soft subtle indigo glow
      Color(0x0A38BDF8),
      Colors.transparent,
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1F10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0x1FEF4444);
  static const Color errorBorder = Color(0x4DEF4444);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8); // Cool gray
  static const Color textMuted = Color(0xFF64748B); // Muted gray-blue
  static const Color textPlaceholder = Color(0xFF475569);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryIndigo,
        secondary: AppColors.accentCyan,
        surface: AppColors.surface,
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
    );

  }
}
