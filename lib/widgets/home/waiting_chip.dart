import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_chip.dart';

/// Finished, and the office has yet to hear about it.
///
/// Sits where the status normally does, and deliberately does not read like
/// one: `Dispatched` is what the server would still call this tag, and showing
/// that under Completed would look like the screen contradicting itself.
///
/// Grey rather than a colour. Nothing is wrong and nothing is owed - the
/// record is simply on its way - and it used to wear the same amber as the
/// draft chip, which made the one row he still had to finish look like the
/// four he had already done.
class WaitingChip extends StatelessWidget {
  const WaitingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return TagChip(
      label: 'Pending upload',
      icon: Icons.cloud_upload_outlined,
      wash: AppColors.chipSlateWash,
      line: AppColors.chipSlateLine,
      ink: AppColors.chipSlateInk,
    );
  }
}
