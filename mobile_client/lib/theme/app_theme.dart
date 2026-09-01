import 'package:flutter/material.dart';

class AppColors {
  // Ultra-deep neutral surfaces (Linear / Raycast style)
  static const Color bgDark = Color(0xFF08090C);
  static const Color bgCanvas = Color(0xFF0C0D12);
  
  // Surfaces & Panels
  static const Color surface = Color(0xFF111218);
  static const Color surfaceCard = Color(0xFF111218);
  static const Color surfaceElevated = Color(0xFF161821);
  static const Color surfaceInput = Color(0xFF0F1015);
  static const Color surfaceHighlight = Color(0xFF1E202B);

  // Hairline Borders (Crisp & Restrained)
  static const Color borderHairline = Color(0x14FFFFFF); // 8% white
  static const Color borderSubtle = Color(0x1FFFFFFF);   // 12% white
  static const Color borderMedium = Color(0x2EFFFFFF);   // 18% white
  static const Color borderFocused = Color(0xFF5E6AD2);

  // Brand Accent (Restrained Linear Indigo)
  static const Color brandPrimary = Color(0xFF5E6AD2);
  static const Color primaryIndigo = Color(0xFF5E6AD2);
  static const Color brandHover = Color(0xFF4F59C7);
  static const Color brandAccent = Color(0xFF6875E8);
  static const Color brandCyan = Color(0xFF38BDF8);
  static const Color accentCyan = Color(0xFF38BDF8);

  // Linear-style subtle atmospheric mesh gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF5E6AD2), Color(0xFF4F59C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF141620), Color(0xFF0E0F15)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Status Colors
  static const Color statusLive = Color(0xFF10B981);
  static const Color statusLiveBg = Color(0x1A10B981);
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1A10B981);
  static const Color error = Color(0xFFF87171);
  static const Color errorBg = Color(0x1AF87171);
  static const Color errorBorder = Color(0x33F87171);

  // High-Grade Typography (Geist / Inter / Apple Neutral)
  static const Color textPrimary = Color(0xFFF7F8F8);   // Pure crisp white
  static const Color textSecondary = Color(0xFF8A8F98); // Muted neutral
  static const Color textMuted = Color(0xFF62666D);     // Slate gray
  static const Color textTertiary = Color(0xFF4B4F56);  // Subtle label
  static const Color textPlaceholder = Color(0xFF4B4F56);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandCyan,
        surface: AppColors.surface,
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
    );
  }
}
