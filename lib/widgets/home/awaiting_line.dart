import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// Envelopes out with him that he has not said he is holding.
///
/// Only here when something is waiting. Most mornings nothing is, and on those
/// the home screen looks exactly as it did before the hand-over was split in
/// two - which is the point of a strip rather than a third tab standing empty.
///
/// Sits where [WaitingLine] and [RefusedLine] sit, under the green and above
/// the list, because it is the same kind of sentence: a fact about his work
/// that he can act on, rather than part of the list itself.
///
/// Counts batches, not stickers. One tap claims a whole share, so the number
/// he needs is how many taps are waiting - "30 tags" would be the size of a
/// job he has not agreed to yet.
///
/// Sized for a man in his forties holding a phone at arm's length in daylight:
/// type he can read without squinting and a strip tall enough to hit with a
/// thumb without looking. It stays full width for the same reason - the whole
/// band is the target, not a small corner of it.
class AwaitingLine extends StatelessWidget {
  const AwaitingLine({required this.count, required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipAmberWash,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.chipAmberLine),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 22,
                color: AppColors.chipAmberInk,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 batch waiting for you'
                      : '$count batches waiting for you',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.chipAmberInk,
                  ),
                ),
              ),
              // "Tap to accept" rather than a bare chevron. The strip is the
              // only thing on this screen that leads somewhere he has never
              // been, and an arrow alone does not say what is on the far side.
              // Filled rather than plain text so it reads as a button from a
              // glance away, the way the scan bar at the bottom does.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap to accept',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.chipAmberInk,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.chipAmberInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
