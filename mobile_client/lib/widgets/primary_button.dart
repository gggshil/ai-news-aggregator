import 'package:flutter/material.dart';

class PrimaryButton extends StatefulWidget {

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showArrow;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.showArrow = true,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5E6AD2), Color(0xFF4F59C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: _isHovered ? 0.22 : 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5E6AD2).withValues(alpha: _isHovered ? 0.25 : 0.12),
                  blurRadius: _isHovered ? 14 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.text,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.showArrow) ...[
                          const SizedBox(width: 7),
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 180),
                            offset: _isHovered ? const Offset(0.2, 0) : Offset.zero,
                            child: const Text(
                              '→',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
