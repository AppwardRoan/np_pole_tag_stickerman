import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_chip.dart';
import 'package:np_pole_tag_stickerman/widgets/record/record_sheet.dart';

/// One of his tags inside an opened batch.
///
/// Three facts, and a tap that opens what was filed - the same sheet the home
/// screen's Completed tab opens, because it is the same question asked from the
/// other end: there he is checking today's work, here he is checking a batch he
/// finished weeks ago.
///
/// Every row taps, not only the finished ones, and the unfinished ones are the
/// reason. A tag reading Received has usually never been touched - but a pole
/// the office sent back to be re-done reads Received too, and it is carrying
/// the record of the first attempt. The two are indistinguishable from here, so
/// the row asks rather than guessing: the sheet shows the earlier record where
/// there is one and says there is none where there is not.
///
/// Nothing here opens a camera. Redoing a pole is the home screen's job, and
/// this screen is the history.
class BatchTagRow extends StatelessWidget {
  const BatchTagRow({required this.tag, super.key});

  final Tag tag;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Sep 14, 2026 · 3:55pm", or nothing when the tag has never been touched.
  ///
  /// The year is spelled out because this list is his history: a batch he
  /// finished last January reads as last week without it.
  String? get _when {
    final when = tag.updatedAt;
    if (when == null) return null;

    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    final ampm = when.hour < 12 ? 'am' : 'pm';
    final day = '${_months[when.month - 1]} ${when.day}, ${when.year}';

    return '$day · $hour:$minute$ampm';
  }

  @override
  Widget build(BuildContext context) {
    final when = _when;
    final done = tag.status == TagStatus.used;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.tagCode,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.ink,
                  ),
                ),
                if (when != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The same chip as everywhere else, rather than a coloured word.
          // This row is the one place a status used to be set in plain text,
          // and it read as a different kind of fact from the identical one on
          // the home screen.
          done
              ? TagChip(
                  label: 'Completed',
                  wash: AppColors.chipGreenWash,
                  line: AppColors.chipGreenLine,
                  ink: AppColors.chipGreenInk,
                )
              : TagChip(
                  label: tag.status,
                  wash: AppColors.chipSlateWash,
                  line: AppColors.chipSlateLine,
                  ink: AppColors.chipSlateInk,
                ),
        ],
      ),
    );

    return InkWell(
      onTap: () =>
          showRecordSheet(context, tagId: tag.tagId, tagCode: tag.tagCode),
      child: row,
    );
  }
}
