import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InputField extends StatefulWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final IconData prefixIcon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;

  const InputField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    required this.prefixIcon,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onFieldSubmitted,
    this.onChanged,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 7),
        Focus(
          onFocusChange: (focus) {
            setState(() {
              _isFocused = focus;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF090A0E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isFocused
                    ? AppColors.brandPrimary
                    : const Color(0xFF1C1E26),
                width: _isFocused ? 1.2 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.12),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.isPassword ? _obscureText : false,
              keyboardType: widget.keyboardType,
              onFieldSubmitted: widget.onFieldSubmitted,
              onChanged: widget.onChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: const TextStyle(
                  color: Color(0xFF424652),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: Icon(
                  widget.prefixIcon,
                  color: _isFocused ? AppColors.brandPrimary : const Color(0xFF5A5E6B),
                  size: 17,
                ),
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF5A5E6B),
                          size: 17,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              validator: widget.validator,
            ),
          ),
        ),
      ],
    );
  }
}
