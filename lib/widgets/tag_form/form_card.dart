import 'package:flutter/material.dart';

/// The panel every part of the form sits in, so one does not drift from the
/// next as the steps get built.
class FormCard extends StatelessWidget {
  const FormCard({
    required this.label,
    required this.child,
    this.trailing,
    this.required = false,
    this.missing = false,
    this.outlined = true,
    super.key,
  });

  final String label;
  final Widget child;
  final String? trailing;

  /// Puts a red asterisk after the label. Marks the ones he cannot leave
  /// blank, so the form says so before he taps Next rather than after.
  final bool required;

  /// Draws the panel red. Set only after he has tried to leave the step with
  /// this one unanswered - see `_flagged` in `tag_form_screen.dart`.
  final bool missing;

  /// Draws the line around the panel. Off for a card whose child already has
  /// its own outline, so the two do not box it in twice.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = this.trailing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: outlined || missing
            ? Border.all(
                color: missing ? scheme.error : scheme.outlineVariant,
                width: missing ? 2 : 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label.toUpperCase(),
                    children: [
                      if (required)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: scheme.error, fontSize: 16),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: missing ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
