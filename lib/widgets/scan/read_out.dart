import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';

/// The green panel under the camera: what just happened, what to do next, and
/// the scan button.
///
/// Green like the header above the camera, so the screen reads as one frame
/// round the picture rather than a camera with two strips stuck to it. Every
/// message is a short bold line he can take in at a glance, then one plain
/// sentence; nothing in small grey capitals that has to be squinted at in sun.
class ReadOut extends StatelessWidget {
  const ReadOut({
    required this.text,
    required this.isReading,
    this.found,
    this.alreadyDone,
    this.missed = false,
    this.wrongTag = false,
    this.cutOff = false,
    this.expected,
    this.action,
    super.key,
  });

  final String text;
  final bool isReading;
  final Tag? found;

  /// Read, recognised, and already filed. Set instead of [found] - nothing
  /// opens, and the message says why rather than leaving him tapping again.
  final Tag? alreadyDone;
  final bool missed;
  final bool wrongTag;

  /// Part of the code was outside the photo. Not an error: nothing is wrong
  /// with the sticker, he only has to step back.
  final bool cutOff;
  final Tag? expected;

  /// The scan button, centred under the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tag = found;

    final (
      IconData icon,
      Color mark,
      String title,
      String detail,
    ) = switch (true) {
      _ when isReading => (
        Icons.hourglass_top_rounded,
        AppColors.paleGreen,
        'Reading the sticker',
        'Hold the phone still.',
      ),
      _ when tag != null => (
        Icons.check_circle_rounded,
        AppColors.paleGreen,
        'Found ${tag.tagCode}',
        'Opening the form.',
      ),
      // Above the two failures below: this one is not a bad read, and
      // calling it one would have him wipe the sticker and try again all
      // afternoon.
      _ when alreadyDone != null => (
        Icons.error_rounded,
        AppColors.dangerWash,
        'Already submitted',
        'Tag ${alreadyDone!.tagCode} has already been recorded. Check the '
            'sticker.',
      ),
      // None of these repeats what the camera read. Pointed at a page or a
      // screen it printed every word in the frame: three hundred
      // characters where the answer he needed was the first sentence.
      _ when cutOff => (
        Icons.zoom_out_map_rounded,
        AppColors.amber,
        'Step back',
        'Part of the code is outside the photo. Fit the whole code in the '
            'frame.',
      ),
      _ when wrongTag => (
        Icons.error_rounded,
        AppColors.dangerWash,
        'Wrong tag',
        'This sticker does not match ${expected!.tagCode}. Check the tag '
            'and try again.',
      ),
      _ when missed => (
        Icons.error_rounded,
        AppColors.dangerWash,
        'Tag not recognized',
        'This tag is not assigned to you. Check the sticker and try again.',
      ),
      _ when text.isNotEmpty => (
        Icons.text_fields_rounded,
        AppColors.paleGreen,
        'Read',
        text,
      ),
      _ => (
        Icons.crop_free_rounded,
        AppColors.paleGreen,
        'Line up the sticker',
        'Fit the whole code inside the frame, then tap the button.',
      ),
    };

    // The phone's own back and home buttons sit over the bottom of the screen
    // now that the app draws edge to edge. Without this the second line of a
    // message - "tag and try again." - ran in behind them.
    final under = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 14 + under),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: mark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Room for two lines whatever the message, so the button under it
          // stays put instead of jumping each time the message changes length.
          SizedBox(
            height: 46,
            child: Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AppColors.paleGreen,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            Center(child: action),
          ],
        ],
      ),
    );
  }
}
