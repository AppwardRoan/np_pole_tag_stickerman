import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// "Download BT-N-2026-0041", and the spinner while it is being built.
///
/// One button in two places - under an opened batch and across the top of the
/// screen - because the two downloads differ only in what they cover, and a
/// second button styled to match would be the same widget written twice.
///
/// [filled] is what the two places disagree on. The whole-history one is the
/// screen's main offer and reads as a bar across it; the per-batch one sits
/// inside a card, where a bar of the same weight would shout over the batch
/// it belongs to.
class DownloadButton extends StatelessWidget {
  const DownloadButton({
    required this.label,
    required this.isRunning,
    required this.onPressed,
    this.code,
    this.filled = false,
    super.key,
  });

  final String label;

  /// A batch code to set after [label], in the mono face.
  ///
  /// Kept apart from the label rather than written into it. It is a printed
  /// code, and the app's rule is that a code is never set in the face used for
  /// words - run together as one string it came out in Barlow like the
  /// sentence around it.
  final String? code;

  /// Draws it as a full-width bar rather than a small text button.
  final bool filled;

  /// This button's own download, not any download. Two buttons are on screen
  /// at once and only the tapped one should show a spinner.
  final bool isRunning;

  /// Null while another download is running, which is what greys it out.
  final void Function(Rect origin)? onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final onTap = onPressed == null
            ? null
            : () => onPressed!(_origin(context));

        final code = this.code;

        final words = isRunning
            ? const Text('Preparing…')
            : code == null
            ? Text(label)
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$label  '),
                    TextSpan(
                      text: code,
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              );

        if (filled) {
          return FilledButton.icon(
            onPressed: onTap,
            icon: isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 20),
            label: words,
            style: FilledButton.styleFrom(
              // Amber, matching the Scan bar on the home screen: on both
              // screens this is the one thing across the width he is being
              // offered.
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.deepGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return TextButton.icon(
          onPressed: onTap,
          icon: isRunning
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 18),
          label: words,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.midGreen,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  /// Where on screen this button is, which iPad needs to anchor the share
  /// popover to. Android ignores it, and a zero rect would put the popover in
  /// the corner rather than beside the thumb that asked for it.
  Rect _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;

    return box.localToGlobal(Offset.zero) & box.size;
  }
}
