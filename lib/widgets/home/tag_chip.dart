import 'package:flutter/material.dart';

/// The shape every chip on a tag row takes.
///
/// One widget rather than three near-copies, so the four families cannot drift
/// apart in padding or weight - which is how two of them ended up identical
/// before, both borrowing Material's tertiary container.
class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    required this.wash,
    required this.line,
    required this.ink,
    this.icon,
    super.key,
  });

  final String label;
  final Color wash;
  final Color line;
  final Color ink;

  /// Only on the chips that say something the status alone cannot. Dispatched
  /// and Used carry no icon: they are the ordinary case, and an icon on every
  /// row would make the two that matter harder to pick out.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 11 : 9, 5, 11, 5),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: ink),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
