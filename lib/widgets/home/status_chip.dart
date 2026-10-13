import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_chip.dart';

/// What the office says about this tag, as the server last reported it.
///
/// It translated one of them for a day: the server called an accepted tag
/// `Received` and this drew it as "Dispatched", because that is how the crew
/// talk about paper they are carrying. The server says Dispatched itself now —
/// see `TagStatus` — so the translation came out. A word rendered differently
/// from the value behind it is two vocabularies for one fact, and the rename
/// is what made one of them unnecessary.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (wash, line, ink) = switch (status) {
      TagStatus.used => (
        AppColors.chipGreenWash,
        AppColors.chipGreenLine,
        AppColors.chipGreenInk,
      ),
      // Both halves of the hand-over in the one blue. They are different
      // facts - nobody has claimed it, against a named man is holding it - but
      // on his own phone every row under Assigned is the second, so the colour
      // is not what he would tell them apart by.
      TagStatus.dispatched || TagStatus.received => (
        AppColors.chipBlueWash,
        AppColors.chipBlueLine,
        AppColors.chipBlueInk,
      ),
      // The three send-backs. Red rather than the amber the office's own
      // screen gives them, because amber here is the draft chip - and both
      // can sit in the To fix tab at once. One colour for "I have not finished
      // this" and "the office found this wrong" would hide the difference on
      // the one screen where it decides what he does next.
      TagStatus.redo || TagStatus.reCapture || TagStatus.rePin => (
        AppColors.chipRedWash,
        AppColors.chipRedLine,
        AppColors.chipRedInk,
      ),
      // Everything else is a state he cannot act on from this screen, so it
      // reads as a fact rather than as a colour meaning something.
      _ => (
        AppColors.chipSlateWash,
        AppColors.chipSlateLine,
        AppColors.chipSlateInk,
      ),
    };

    return TagChip(label: status, wash: wash, line: line, ink: ink);
  }
}
