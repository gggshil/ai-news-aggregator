import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GoogleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF161822) : const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered ? const Color(0xFF282B38) : const Color(0xFF1C1F2B),
            width: 1,
          ),
        ),
        child: OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandCyan,
                      fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
