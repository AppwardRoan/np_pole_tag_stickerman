import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// One figure in the row of three under the header.
///
/// A white card on the page rather than a panel inside the green. The three
/// used to sit in the header, which made the green block deep enough to push
/// the first batch off the bottom of a short screen.
///
/// The number first and large, the word under it small: he reads these at
/// arm's length in daylight, and the number is the part he is after.
///
/// The figure is set in the mono face. It is a count, and a count sits beside
/// two others - in a proportional face the three columns wander as the day
/// changes, and a row that moves reads as a row that is unsure.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    this.accent,
    super.key,
  });

  final String value;
  final String label;

  /// Picks this tile out of the row. Only Completed uses it - it is the one
  /// figure that climbs as he works, and the one he looks for.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colour = accent ?? AppColors.ink;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              height: 1.05,
              color: colour,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            // Never wrapped to a second line. "BATCH · ONGOING" is the longest
            // of them and it is the one that would push the row's height about
            // as his day changed.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
