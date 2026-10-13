import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';

/// One tag, read-only.
///
/// Off the path for now - its route is commented out in the router. A
/// confirmed scan opens `TagFormScreen` instead, the way the mockup goes
/// straight from the tag to step 1 with nothing in between.
class TagScreen extends StatelessWidget {
  const TagScreen({super.key, required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tag.tagCode)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAG ID',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tag.tagCode,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Row(label: 'Status', value: tag.status),
          _Row(label: 'Batch', value: tag.batchCode),
          _Row(label: 'Remarks', value: tag.remarks),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = (value == null || value!.isEmpty) ? '—' : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
