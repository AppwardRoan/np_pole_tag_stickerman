import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// Assigned, To fix and Completed, as three positions of one switch.
///
/// A `TabBar` underneath, so the tabs still drive the `TabBarView` the screen
/// already had - only the indicator is a white pill on a grey track instead of
/// a line under a word. It reads as a thing with positions, which is what it
/// is, rather than as a heading that happens to be underlined.
///
/// To fix sits in the middle rather than at the end. It is work outstanding
/// like Assigned is, and putting it after Completed would file it behind the
/// tab that means "nothing left to do here".
///
/// Three labels at this size is close to the width of the phone, so they are
/// kept short. "To fix" rather than "Sent back" is Roan's: the crew reads the
/// tab as a job of his own rather than as something the office did to him.
class TagTabs extends StatelessWidget {
  const TagTabs({
    required this.assigned,
    required this.rework,
    required this.completed,
    super.key,
  });

  final int assigned;
  final int rework;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(9),
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.muted,
        // As large as three labels and their counts will go before the
        // longest of them - "Completed · 22" - starts to ellipsise on a
        // narrow phone. Read at arm's length by men who are mostly past
        // forty, so the height goes up with the type: the pill is a thumb
        // target, not a word with a line under it.
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(height: 46, text: 'Assigned · $assigned'),
          Tab(height: 46, text: 'To fix · $rework'),
          Tab(height: 46, text: 'Completed · $completed'),
        ],
      ),
    );
  }
}
