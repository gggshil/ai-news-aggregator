import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CollapsibleSettings extends StatefulWidget {
  final TextEditingController serverController;

  const CollapsibleSettings({
    super.key,
    required this.serverController,
  });

  @override
  State<CollapsibleSettings> createState() => _CollapsibleSettingsState();
}

class _CollapsibleSettingsState extends State<CollapsibleSettings> {
  bool _isExpanded = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Subtle divider above settings
        const Divider(color: Color(0xFF161822), height: 1),
        const SizedBox(height: 14),

        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 13,
                    color: _isHovered ? AppColors.textSecondary : const Color(0xFF5B6069),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Backend Server Settings',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _isHovered ? AppColors.textSecondary : const Color(0xFF5B6069),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: _isHovered ? AppColors.textSecondary : const Color(0xFF5B6069),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090A0E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1C1E26), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API ENDPOINT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: widget.serverController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'http://localhost:8000',
                    hintStyle: const TextStyle(color: Color(0xFF424652), fontSize: 12.5),
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF1C1E26)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.brandPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
