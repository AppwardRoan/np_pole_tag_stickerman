import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_chip.dart';

/// Says the form is half done, in the place the status normally sits.
///
/// A separate chip rather than another [TagStatus] value: the server still
/// calls this tag Dispatched, and it is right to - nothing has been filed. The
/// draft is a fact about this phone, not about the pole.
///
/// Amber, the colour this app already uses for his own work.
class DraftChip extends StatelessWidget {
  const DraftChip({super.key});

  @override
  Widget build(BuildContext context) {
    return TagChip(
      label: 'Draft',
      icon: Icons.edit_outlined,
      wash: AppColors.chipAmberWash,
      line: AppColors.chipAmberLine,
      ink: AppColors.chipAmberInk,
    );
  }
}
