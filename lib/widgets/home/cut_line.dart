import 'package:flutter/material.dart';

class CutLine extends StatelessWidget {
  const CutLine({required this.showing, required this.total, super.key});

  final int showing;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.surfaceContainerHighest,
      child: Text(
        'Showing $showing of $total. Type more characters.',
        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
