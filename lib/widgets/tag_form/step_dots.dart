import 'package:flutter/material.dart';

/// How far along he is, one bar per step.
class StepDots extends StatelessWidget implements PreferredSizeWidget {
  const StepDots({required this.at, required this.count, super.key});

  final int at;
  final int count;

  @override
  Size get preferredSize => const Size.fromHeight(10);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  // Filled up to and including where he is, so it reads as
                  // progress rather than as a set of separate lamps.
                  color: i <= at
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
