import 'package:flutter/material.dart';

class ErrorAlert extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const ErrorAlert({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF180A0C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B1418), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.0),
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF87171),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFFE57373),
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
