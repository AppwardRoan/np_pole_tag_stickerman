import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/my_batch.dart';
import 'package:np_pole_tag_stickerman/providers/batch_tag_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_chip.dart';
import 'package:np_pole_tag_stickerman/widgets/work/batch_tag_row.dart';
import 'package:np_pole_tag_stickerman/widgets/work/download_button.dart';

/// One batch on the My work screen, and its tags when he opens it.
///
/// The summary reads as a sentence about his own share: the code, how far
/// through it he is, and when he last touched it. The batch's own status is not
/// here - his fifty can be finished while the run has a hundred left in it, and
/// printing "Ongoing" over "50 of 50" reads as a contradiction.
class BatchRow extends StatelessWidget {
  const BatchRow({
    required this.batch,
    required this.isOpen,
    required this.onTap,
    required this.onRetry,
    required this.isDownloading,
    required this.onDownload,
    this.contents,
    super.key,
  });

  final MyBatch batch;

  final bool isOpen;

  /// What is inside, once it has been asked for. Null until he opens it the
  /// first time, which is what stops ten rows fetching five hundred tags to
  /// show whichever one he taps.
  final BatchTags? contents;

  final VoidCallback onTap;
  final VoidCallback onRetry;

  /// This batch's own download. Null while another one is running, which greys
  /// the button rather than letting two files race into the share sheet.
  final bool isDownloading;
  final void Function(Rect origin)? onDownload;

  /// How long the card takes to open and shut.
  static const Duration _opening = Duration(milliseconds: 190);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        // The same hairline open or shut. It used to turn green when open,
        // which put a heavy outline round the one card he was reading.
        border: Border.all(color: AppColors.line),
      ),
      // Clipped so the ink of a tap cannot square off the rounded corners -
      // and so the tags are cut off by the card's edge while they slide out
      // rather than hanging past it.
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _summary(),
          // The tags drop out of the card rather than appearing under it. A
          // row that changed height between one frame and the next shifted
          // every batch below it in a jump, and he could not tell whether the
          // list had moved or he had opened the wrong one.
          AnimatedSize(
            duration: _opening,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isOpen
                ? _contents()
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final finished = batch.isFinished;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.batchCode,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${batch.myDone} of ${batch.myTags} tags done',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // His share of the batch, not the batch's own state - his fifty can
            // be finished while the run has a hundred left in it.
            finished
                ? TagChip(
                    label: 'Completed',
                    wash: AppColors.chipGreenWash,
                    line: AppColors.chipGreenLine,
                    ink: AppColors.chipGreenInk,
                  )
                : TagChip(
                    label: 'Ongoing',
                    wash: AppColors.chipAmberWash,
                    line: AppColors.chipAmberLine,
                    ink: AppColors.chipAmberInk,
                  ),
            // Turns over as the card opens rather than swapping for a second
            // icon. The turn is the thing that says the two states are one row
            // in two positions.
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: _opening,
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.expand_more,
                size: 22,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What sits under the summary once it is open: the tags, or the reason there
  /// are none to show.
  Widget _contents() {
    final held = contents;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.page,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      // No padding of its own. The rule above the download has to run the
      // whole width of the card, so each part inside sets its own inset.
      child: _inside(held),
    );
  }

  Widget _inside(BatchTags? held) {
    if (held == null || held.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Only this row failed. The rest of the screen is still readable, so the
    // retry belongs inside the row rather than over the screen.
    if (held.error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            Text(
              held.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }

    // Fetched, and there was nothing. Not the same as the spinner above, which
    // is a question still being asked.
    if (held.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Text(
          'Nothing of yours in this batch.',
          style: TextStyle(fontSize: 15, color: AppColors.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final tag in held.tags) BatchTagRow(tag: tag)],
          ),
        ),
        // Under the tags rather than beside the batch code: it is what he does
        // after reading them, and a download button on a row he has not opened
        // offers a file whose contents he has not seen.
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          // Room of its own. Sat straight on the rule it read as a line of
          // text that had fallen out of the list above it.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: DownloadButton(
              label: 'Download',
              code: batch.batchCode,
              isRunning: isDownloading,
              onPressed: onDownload,
            ),
          ),
        ),
      ],
    );
  }
}
