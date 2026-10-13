import 'package:flutter/material.dart';

/// Rule-of-thirds lines, so a pole comes out straight rather than leaning
/// across the frame.
class ThirdsGrid extends StatelessWidget {
  const ThirdsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Colors.white.withValues(alpha: 0.32);

    return LayoutBuilder(
      builder: (context, size) => Stack(
        children: [
          for (final fraction in [1 / 3, 2 / 3]) ...[
            Positioned(
              top: size.maxHeight * fraction,
              left: 0,
              right: 0,
              child: Container(height: 1, color: line),
            ),
            Positioned(
              left: size.maxWidth * fraction,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: line),
            ),
          ],
        ],
      ),
    );
  }
}
