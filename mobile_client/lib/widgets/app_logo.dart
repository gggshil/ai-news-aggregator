import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBadge;
  final bool useFullLogoWithBg;
  final double? fontSize;

  const AppLogo({
    super.key,
    this.size = 44,
    this.showBadge = true,
    this.useFullLogoWithBg = false,
    this.fontSize,
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
        // High-clarity transparent logo image
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
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'AI News Aggregator',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize ?? (size >= 40 ? 16 : 14),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
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
