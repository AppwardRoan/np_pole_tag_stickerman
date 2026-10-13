import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/answer_option.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/unit_field.dart';

/// How tall the pole is, in feet or in metres.
///
/// Both boxes, both live: the crew talks in feet, the record and the office
/// take metres, and making him convert 35 ft in his head at a pole is how a
/// wrong number gets written down.
class HeightCard extends StatelessWidget {
  const HeightCard({
    required this.feet,
    required this.metres,
    required this.onFeet,
    required this.onMetres,
    required this.onPreset,
    this.missing = false,
    super.key,
  });

  /// The heights nearly every pole turns out to be. Straight from the mockup.
  static const List<int> _common = [30, 35, 40, 45, 50];

  final TextEditingController feet;
  final TextEditingController metres;
  final ValueChanged<String> onFeet;
  final ValueChanged<String> onMetres;
  final ValueChanged<int> onPreset;

  /// Passed straight to [FormCard]: draws the panel red once he has tried to
  /// leave the step without answering this.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FormCard(
      label: 'Pole height',
      required: true,
      missing: missing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: UnitField(
                  controller: feet,
                  unit: 'ft',
                  onChanged: onFeet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: UnitField(
                  controller: metres,
                  unit: 'm',
                  onChanged: onMetres,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Or tap a common height',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final height in _common) ...[
                Expanded(
                  child: AnswerOption(
                    label: '$height',
                    selected: feet.text == '$height',
                    onTap: () => onPreset(height),
                  ),
                ),
                if (height != _common.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
