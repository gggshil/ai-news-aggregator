import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBadge;
  final bool useFullLogoWithBg;

  const AppLogo({
    super.key,
    this.size = 46,
    this.showBadge = true,
    this.useFullLogoWithBg = false,
  });


  @override
  Widget build(BuildContext context) {
    final assetPath = useFullLogoWithBg
        ? 'assets/images/app_logo.png'
        : 'assets/images/navbar_logo.png';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Prominent, crisp transparent logo image
        Image.asset(
          assetPath,
          height: size,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/logo with no bg.png',
              height: size,
              width: size,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) {
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(size * 0.25),
                    border: Border.all(color: AppColors.borderMedium),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.brandPrimary,
                      size: size * 0.55,
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 12),
        Text(
          'AI News Aggregator',
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        if (showBadge) ...[
          const SizedBox(width: 9),
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
