import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/answer_option.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_card.dart';

/// Which kind of pole it is. One choice, and the record needs it.
///
/// Two across rather than a row: "Concrete" and "Lattice" do not fit side by
/// side four-wide on a phone, and a squeezed label is a misread label.
class PoleTypeCard extends StatelessWidget {
  const PoleTypeCard({
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
      label: 'Pole type',
      required: true,
      missing: missing,
      child: options.isEmpty
          ? const Text('No choices saved.')
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 2.7,
              children: [
                for (final option in options)
                  AnswerOption(
                    label: option.label,
                    selected: option.id == selectedId,
                    onTap: () => onPick(option.id),
                  ),
              ],
            ),
    );
  }
}
