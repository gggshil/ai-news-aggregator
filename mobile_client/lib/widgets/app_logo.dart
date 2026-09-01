import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBadge;
  final bool useFullLogoWithBg;

  const AppLogo({
    super.key,
    this.size = 30,
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
        // Transparent BG-less custom logo image
        Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Secondary attempt with original filename
            return Image.asset(
              'assets/images/logo with no bg.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) {
                // Subtle vector fallback if assets aren't yet loaded by flutter engine
                return Icon(
                  Icons.auto_awesome,
                  color: AppColors.brandPrimary,
                  size: size * 0.8,
                );
              },
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          'AI News Aggregator',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        if (showBadge) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.borderHairline,
                width: 1,
              ),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
