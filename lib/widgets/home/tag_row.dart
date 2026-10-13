import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';
import 'package:np_pole_tag_stickerman/widgets/home/draft_chip.dart';
import 'package:np_pole_tag_stickerman/widgets/record/record_sheet.dart';
import 'package:np_pole_tag_stickerman/widgets/shared/already_sent_dialog.dart';
import 'package:np_pole_tag_stickerman/widgets/home/status_chip.dart';
import 'package:np_pole_tag_stickerman/widgets/home/waiting_chip.dart';

class TagRow extends ConsumerWidget {
  const TagRow({
    required this.tag,
    this.done = false,
    this.waiting = false,
    this.draft = false,
    super.key,
  });

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

  /// "Approved Sep 17, 2026", or null on a pole nobody has accepted.
  ///
  /// The year is spelled out for the reason `BatchTagRow` spells it out: this
  /// tab is his history, and a pole accepted last January reads as last week
  /// without it.
  String? get _approved {
    final at = tag.approvedAt;
    if (at == null) return null;

    return 'Approved ${_months[at.month - 1]} ${at.day}, ${at.year}';
  }

  /// He started this form and walked away. The row says so and carries on
  /// where he left off, rather than sending him back to step one.
  final bool draft;

  /// Submitted, whether or not it has reached the server. Greyed out so he can
  /// see at a glance what is left - without it, a pole he did at 2pm still
  /// looks like work, and he can walk back and tag it twice.
  final bool done;

  /// Submitted and still on its way up. The one finished state he is allowed
  /// back into: nothing has been filed yet, so a second go replaces the first
  /// rather than arguing with it.
  final bool waiting;

  /// What tapping the row does, before any camera opens.
  ///
  /// The old rule was one tap, one camera, every row. That stopped being
  /// honest once Completed held finished work: a row the office has on file
  /// opened a camera whose only possible outcome was a refusal, and he had to
  /// read a viewfinder to be told no. The answer is known at the tap, so it is
  /// given at the tap.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (tag.status == TagStatus.used) {
      // Opens what the office holds against this pole, rather than the notice
      // that used to stand here saying no further action is required. That was
      // true and useless: he taps a finished row to check what he filed - the
      // height he read, the photograph he took - and a dialog telling him it is
      // done answers a question he did not ask.
      await showRecordSheet(context, tagId: tag.tagId, tagCode: tag.tagCode);
      return;
    }

    // Half-sent: the record is with the office and only photos are left, so
    // Replace would look like it worked and change nothing.
    if (waiting && ref.read(uploadProvider).sentTagIds.contains(tag.tagId)) {
      await showAlreadySent(context, tag.tagCode);
      return;
    }

    if (waiting) {
      final again = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pending upload'),
          content: Text(
            'Tag ${tag.tagCode} is saved on this device and has not been '
            'uploaded. Replace the saved record?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            // What he came back for: a wrong reading or a bad photo can still
            // be replaced while the record is on the phone. Once it is sent,
            // this way in closes.
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (again != true) return;

      // Thrown away here, not when the replacement is saved. Left in the pile
      // it would go up the moment signal returned - and the office refuses a
      // second record for the same tag, so the one he is about to make could
      // never land. He confirmed the dialog; Replace has to mean it.
      await ref.read(uploadProvider.notifier).discard(tag.tagId);
    }

    if (!context.mounted) return;

    // A draft goes straight back to its form. He scanned this sticker once
    // already - that is how the draft exists - and the draft carries its own
    // tag and its own fix from that pole, so carrying on binds nothing new.
    // Making him read a wet sticker again to reach work he has already done
    // is the row promising "tap to carry on" and handing him a camera.
    if (draft) {
      context.push(Routes.tagForm, extra: tag);
      return;
    }

    // A pole sent back for part of itself goes straight to the form.
    //
    // Roan's call, and the argument for it is that the sticker has already
    // done its job on these: the pole was identified when it was first filed,
    // and what the office is asking for now is a photograph or a reading, not
    // an identification. A re-pin is often needed *because* the fix was poor,
    // so making him read a wet sticker again buys nothing the record does not
    // already know.
    //
    // What it costs, written down because nothing else will say it: the scan
    // is what stopped him working the wrong pole. Three good photographs of
    // the pole next door would arrive looking correct - the tag close-up is
    // what would eventually show it - and a re-pin at the wrong pole would
    // move the pin there with nothing to catch it at all.
    //
    // A redo keeps the camera. That one files the pole from scratch, which is
    // the same claim a first capture makes, and it is the claim the sticker
    // is there to back.
    if (tag.status == TagStatus.rePin ||
        tag.status == TagStatus.reCapture) {
      context.push(Routes.tagForm, extra: tag);
      return;
    }

    // Everything else opens the camera and carries this tag with it, so the
    // sticker can confirm the row he tapped rather than the tap being taken
    // on trust. A replaced record counts: it is going up again, and the
    // sticker is what says it is going up against the right pole.
    context.push(Routes.scan, extra: tag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faded = AppColors.muted;

    // The chip answers the one question a finished row raises: has the office
    // got this, or is it still sitting in my pocket? The status cannot answer
    // it - the server still calls a queued tag Dispatched.
    final chip = draft
        ? const DraftChip()
        : waiting
        ? const WaitingChip()
        : StatusChip(status: tag.status);

    // Why the office sent this one back.
    //
    // Only on a pole it sent back. Every other status writes to `remarks` too
    // - a reprint's reason, a note from the admin screen - and those are the
    // sticker's history rather than an instruction to the man holding it.
    final reason = TagStatus.rework.contains(tag.status)
        ? tag.remarks?.trim()
        : null;

    // What the office decided about a pole he has already filed.
    //
    // Only where there is something to say. A finished row with no line is one
    // QC has not reached yet, and saying so on each of them would put a line
    // about nothing having happened on nearly every row of the tab - noise
    // over the few that have.
    final approved = _approved;

    return Opacity(
      opacity: done ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag.tagCode,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: done ? faded : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        draft
                            ? 'Unfinished - tap to carry on'
                            : (tag.batchCode ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // The batch is a printed code; the draft line is a
                          // sentence. Each in the face it belongs to.
                          fontFamily: draft ? null : AppFonts.mono,
                          fontSize: 16,
                          color: AppColors.muted,
                        ),
                      ),
                      // The status says which trip he is making - photographs,
                      // a pin, the whole form. Only this says what was wrong
                      // with the pole, and without it he reads "Re-capture",
                      // retakes all three shots and hopes one of them was the
                      // bad one.
                      //
                      // On the row rather than behind a tap, because he is
                      // choosing which of three poles to drive to and the
                      // reason is what he chooses on. Cut to one line so a
                      // long remark cannot make one row four times the height
                      // of its neighbours; the whole of it is on the screen he
                      // opens to do the work.
                      if (reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.chipAmberInk,
                          ),
                        ),
                      ],
                      if (approved != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 13,
                              color: AppColors.midGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              approved,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.midGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                chip,
                const SizedBox(width: 10),
                // What the tap does, said in the corner of every row - the
                // same brackets the button at the bottom carries.
                Icon(Icons.crop_free, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
