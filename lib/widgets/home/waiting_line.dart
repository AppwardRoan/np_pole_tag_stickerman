import 'package:flutter/material.dart';

/// How many tags he has finished that the office has not got yet.
///
/// Only here when there is something waiting - on a day with coverage he never
/// sees it, because nothing ever waits.
class WaitingLine extends StatelessWidget {
  const WaitingLine({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 16,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            count == 1
                ? '1 tag waiting to upload'
                : '$count tags waiting to upload',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
