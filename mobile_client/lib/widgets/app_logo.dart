import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBadge;

  const AppLogo({
    super.key,
    this.size = 32,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(
              color: AppColors.borderMedium,
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.terminal_rounded,
              color: AppColors.brandPrimary,
              size: size * 0.54,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Briefing',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          '.ai',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
            letterSpacing: -0.4,
          ),
        ),
        if (showBadge) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.borderHairline,
                width: 1,
              ),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
