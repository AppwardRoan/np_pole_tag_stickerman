import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_card.dart';

/// What shape the pole is in. Required, and still clearable - a mistap he
/// cannot undo would be worse than one more tap.
class ConditionCard extends StatelessWidget {
  const ConditionCard({
    required this.options,
    required this.selectedId,
    required this.onPick,
    this.missing = false,
    super.key,
  });

  final List<FormOption> options;
  final int? selectedId;
  final ValueChanged<int> onPick;

  /// Passed straight to [FormCard]: draws the panel red once he has tried to
  /// leave the step without answering this.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      label: 'Pole condition',
      required: true,
      missing: missing,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option.label),
              selected: option.id == selectedId,
              onSelected: (_) => onPick(option.id),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
