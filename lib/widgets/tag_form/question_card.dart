import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/answer_option.dart';

/// One question and its answers, drawn from whatever the server sent.
///
/// Not hardcoded to Yes and No: an admin can edit those rows, and the ids are
/// per utility. Whatever comes back is what he gets to tap.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    required this.title,
    required this.options,
    required this.onPick,
    this.selectedId,
    this.required = false,
    this.missing = false,
    super.key,
  });

  final String title;
  final List<FormOption> options;
  final int? selectedId;
  final ValueChanged<int> onPick;

  /// Puts a red asterisk after the label. Marks the ones he cannot leave
  /// blank, so the form says so before he taps Next rather than after.
  final bool required;

  /// Draws the card red once he has tried to leave the step without picking.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: missing ? scheme.error : scheme.outlineVariant,
          width: missing ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: title,
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Select one',
            style: TextStyle(
              fontSize: 16,
              color: missing ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (options.isEmpty)
            Text('No choices saved.', style: TextStyle(color: scheme.error))
          else
            // A row of equal buttons rather than a wrap: he is tapping this in
            // sunlight with one hand, so each answer takes half the width and
            // the full 52 of height.
            Row(
              children: [
                for (final option in options) ...[
                  Expanded(
                    child: AnswerOption(
                      label: option.label,
                      selected: option.id == selectedId,
                      onTap: () => onPick(option.id),
                    ),
                  ),
                  if (option != options.last) const SizedBox(width: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
