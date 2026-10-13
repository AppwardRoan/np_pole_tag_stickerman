import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_card.dart';

/// The most he can type after ticking Others. The server refuses longer.
const int _otherTextLimit = 200;

/// Whether [option] is the one that opens the text box.
///
/// Found by its name, because its id differs per organization.
bool isOtherAssetType(FormOption option) => option.label == 'Others';

/// What is on the pole: "select all that apply", so tick boxes rather than
/// the single answer the other questions take.
///
/// Two columns, like the mockup — every label is short enough to sit side by
/// side. Ticking Others opens a box under the grid for what it is, since
/// "Others" alone tells the office nothing.
class AssetTypeCard extends StatelessWidget {
  const AssetTypeCard({
    required this.options,
    required this.selectedIds,
    required this.onToggle,
    required this.otherText,
    this.missing = false,
    super.key,
  });

  final List<FormOption> options;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  /// The Others box. Held by the form, so the text survives unticking and
  /// ticking again, and goes into the draft with everything else.
  final TextEditingController otherText;

  /// Passed straight to [FormCard]: draws the panel red once he has tried to
  /// leave the step without answering this.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final otherOn = options.any(
      (option) => isOtherAssetType(option) && selectedIds.contains(option.id),
    );

    return FormCard(
      label: 'Asset type',
      required: true,
      missing: missing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select all that apply',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (var row = 0; row < options.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var i = row; i < row + 2; i++) ...[
                  if (i > row) const SizedBox(width: 10),
                  Expanded(
                    child: i < options.length
                        ? _TickOption(
                            label: options[i].label,
                            ticked: selectedIds.contains(options[i].id),
                            onTap: () => onToggle(options[i].id),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
          if (otherOn) ...[
            const SizedBox(height: 10),
            TextField(
              controller: otherText,
              maxLength: _otherTextLimit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Specify other asset type',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tick box. [AnswerOption]'s look, with a square box for the round dot —
/// the shape that says "more than one" before he has tried.
class _TickOption extends StatelessWidget {
  const _TickOption({
    required this.label,
    required this.ticked,
    required this.onTap,
  });

  final String label;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = ticked ? scheme.onPrimaryContainer : scheme.onSurface;

    return Semantics(
      checked: ticked,
      child: Material(
        color: ticked ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ticked ? scheme.primaryContainer : scheme.outlineVariant,
                width: ticked ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ticked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 22,
                  color: ticked ? ink : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
