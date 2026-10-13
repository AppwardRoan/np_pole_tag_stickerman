import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

/// A tag the server refused. It carries the server's own wording, because
/// "could not upload" on its own gives a supervisor nothing to act on.
class RefusedLine extends StatelessWidget {
  const RefusedLine({required this.tag, super.key});

  final QueuedTag tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tag.tagCode} — could not upload. '
              '${tag.failure ?? 'The server refused it.'}',
              style: TextStyle(fontSize: 14, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
