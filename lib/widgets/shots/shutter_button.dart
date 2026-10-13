import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  const ShutterButton({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 5,
          ),
        ),
      ),
    );
  }
}
