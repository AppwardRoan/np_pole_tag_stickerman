import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/batch_awaiting_receipt.dart';
import 'package:np_pole_tag_stickerman/providers/awaiting_receipt_providers.dart';
import 'package:np_pole_tag_stickerman/providers/batch_tag_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/empty_message.dart';

/// The envelopes the office has sent out that he has not claimed.
///
/// One screen, one act: saying he has the paper. Everything else about a batch
/// - what is in it, how far through it he is - lives on the home screen and on
/// My work, and is none of this screen's business until he has accepted.
///
/// Reached from the strip under the home header rather than from a tab. On
/// most mornings there is nothing here, and a permanent tab would stand empty
/// to say so.
///
/// The list is cached, and it is the button that goes grey rather than the
/// screen that goes blank. Accepting is a claim the office has to hear, so it
/// cannot be done offline - but the strip that sends him here counts from
/// cached figures and draws in a dead spot, so refusing to show the list would
/// have the phone promising something the phone then would not explain. He can
/// read what is waiting; he is told plainly that taking it needs a signal.
class AcceptScreen extends ConsumerStatefulWidget {
  const AcceptScreen({super.key});

  @override
  ConsumerState<AcceptScreen> createState() => _AcceptScreenState();
}

class _AcceptScreenState extends ConsumerState<AcceptScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(awaitingReceiptProvider.notifier).load(),
    );
  }

  /// Asks before it accepts, because there is no undo.
  ///
  /// The count is in the question rather than left to the card behind the
  /// dialog: what he is agreeing to is the size of the share, and a bare "Are
  /// you sure?" makes him dismiss it to go and look.
  Future<bool> _confirmed(BatchAwaitingReceipt batch) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this batch?'),
        content: Text(
          '${batch.myTags} ${batch.myTags == 1 ? 'tag' : 'tags'} in '
          '${batch.batchCode} become yours to tag. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    return answer ?? false;
  }

  Future<void> _accept(BatchAwaitingReceipt batch) async {
    if (!await _confirmed(batch)) return;

    final accepted = await ref
        .read(awaitingReceiptProvider.notifier)
        .accept(batch.batchId);

    // The widget can be gone by now - he may have backed out while the request
    // was in flight - and using its context after that throws.
    if (!mounted) return;

    final message = accepted
        ? '${batch.myTags} tags from ${batch.batchCode} are yours'
        : ref.read(awaitingReceiptProvider).error ?? 'Could not accept';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    // Back to the list he came from once the last envelope is gone. Staying
    // would leave him reading an empty screen he has to find his own way out
    // of, on the one tap that finished the job.
    if (accepted && ref.read(awaitingReceiptProvider).isEmpty) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(awaitingReceiptProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.onGreen,
        elevation: 0,
        // A chevron, not Material's arrow with a tail - the same mark the form
        // carries. It reads as "back a step" rather than "leave this screen",
        // and this screen is a step off the home list rather than a place of
        // its own.
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 30),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: const Text('Waiting for you'),
      ),
      // One RefreshIndicator over one scrollable whatever the state, the same
      // as My work: a screen that swaps the list for a bare spinner loses the
      // gesture half a pull in, and the empty state is exactly the one he most
      // wants to retry from.
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(awaitingReceiptProvider.notifier).refresh();
          // What the eye has already fetched is dropped with it. The counts
          // above have just been refetched, so a held list of one under a
          // fresh "2 tags" would have the screen disagreeing with itself -
          // which is the thing the pull was meant to settle.
          ref.read(batchTagProvider.notifier).clear();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            // Only over rows. With nothing on screen the empty state below
            // says it better - a red box above "Nothing waiting" reads as two
            // problems where there is one.
            if (state.error != null && !state.isEmpty)
              _Offline(message: state.error!, syncedAt: state.syncedAt),
            if (state.isLoading && state.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.isEmpty && state.isOffline)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyMessage(
                  icon: Icons.wifi_off_outlined,
                  title: 'No signal',
                  detail:
                      'Pull down to try again once you have a connection.',
                ),
              )
            else if (state.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyMessage(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing waiting',
                  detail:
                      'When the office sends a batch out to your crew, it '
                      'appears here for you to accept.',
                ),
              )
            else
              for (final batch in state.batches)
                _BatchCard(
                  batch: batch,
                  // Only the card he pressed shows a spinner. A flag shared
                  // across the screen would grey out the others as though they
                  // were being accepted too.
                  isAccepting: state.accepting == batch.batchId,
                  // Greyed with a reason rather than left pressable. The tap
                  // would only fail, and a button that fails teaches him
                  // nothing about why.
                  isOffline: state.isOffline,
                  // Locked while any one of them is in flight, so a second tap
                  // cannot start a second claim before the first has answered.
                  onAccept: state.accepting == null && !state.isOffline
                      ? () => _accept(batch)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

/// Why the rows under this are the phone's copy rather than the office's.
///
/// Amber, not red. Nothing has gone wrong - the envelopes are still out with
/// him and the list is still true as far as anyone knows. What he is being
/// told is how old it is and why the buttons are grey, which is a caution
/// rather than a failure.
class _Offline extends StatelessWidget {
  const _Offline({required this.message, this.syncedAt});

  final String message;
  final DateTime? syncedAt;

  /// The age of what he is reading, said as a clock rather than a date - the
  /// question is whether this is from this morning or from yesterday.
  String get _asOf {
    final at = syncedAt?.toLocal();
    if (at == null) return '';

    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');

    return ' Showing the list as of '
        '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.chipAmberWash,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.chipAmberLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 16,
            color: AppColors.chipAmberInk,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$message$_asOf',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.chipAmberInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One envelope: what it is, how much of it is his, and the one button.
///
/// Opens to the codes inside. He is agreeing to carry this paper, and
/// "2 tags" is a number - which two is a thing he can check against what
/// is in his hand before he says he has it.
class _BatchCard extends ConsumerWidget {
  const _BatchCard({
    required this.batch,
    required this.isAccepting,
    required this.isOffline,
    required this.onAccept,
  });

  final BatchAwaitingReceipt batch;
  final bool isAccepting;

  /// The office cannot be reached, so the claim cannot be made. The button
  /// says so instead of going grey without a word.
  final bool isOffline;

  final VoidCallback? onAccept;

  /// "out since 7:40 AM" - the clock, not a date.
  ///
  /// How long the paper has been out is the only urgent thing about a row, and
  /// on a batch that went out this morning a full date reads as archive. An
  /// older one says the day as well, because "out since 7:40 AM" on a
  /// Wednesday about a Monday envelope is the wrong kind of reassuring.
  String get _out {
    final at = batch.dispatchedAt?.toLocal();
    if (at == null) return '';

    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final clock = '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';

    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;

    return sameDay
        ? 'out since $clock'
        : 'out since ${at.day}/${at.month} $clock';
  }

  /// Opens the codes over the card rather than under it.
  ///
  /// A share runs to tens of tags, and inline that is five rows of chips
  /// pushing the button he came for off the bottom of the screen. A dialog is
  /// the same size whatever the count and scrolls on its own.
  void _showCodes(BuildContext context, WidgetRef ref) {
    // Asked for before the dialog is up, so it opens on the codes rather than
    // on a spinner when he has looked at this batch already.
    ref.read(batchTagProvider.notifier).open(batch.batchId);

    showDialog<void>(
      context: context,
      builder: (context) => _CodesDialog(batch: batch),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.batchCode,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              // Opposite the code, because what it opens is that batch's
              // contents - the two belong on one line the way a label belongs
              // beside the thing it names.
              IconButton(
                onPressed: () => _showCodes(context, ref),
                icon: const Icon(Icons.visibility_outlined),
                iconSize: 20,
                color: AppColors.muted,
                tooltip: 'See the codes',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
              ),
            ],
          ),
          if (batch.workOrderName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              batch.workOrderName,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                // His share, not the batch's quantity: the rest of the
                // envelope is three other men's paper.
                '${batch.myTags} ${batch.myTags == 1 ? 'tag' : 'tags'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                _out,
                style: TextStyle(fontSize: 14.5, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: AppColors.onGreen,
                disabledBackgroundColor: AppColors.line,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isAccepting ? null : onAccept,
              child: isAccepting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.mutedGreen,
                      ),
                    )
                  // The reason is on the button itself, not beside it. This is
                  // the thing he came to press, and a greyed ACCEPT with an
                  // explanation somewhere above reads as broken.
                  : Text(
                      isOffline ? 'NEEDS SIGNAL TO ACCEPT' : 'ACCEPT',
                      style: TextStyle(
                        fontSize: isOffline ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isOffline ? AppColors.muted : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


/// The codes inside an envelope, over the card rather than under it.
///
/// Codes only - no pole numbers, no status. Every one of them is his and every
/// one is unaccepted, so a column repeating that on each row would say nothing.
/// What he is doing is reading the list against the paper in his hand.
///
/// Fetched through the same provider the My work screen uses. It already holds
/// what it has fetched and empties itself on a sign-out, and a second copy of
/// that is how two screens start disagreeing about what a batch holds.
class _CodesDialog extends ConsumerWidget {
  const _CodesDialog({required this.batch});

  final BatchAwaitingReceipt batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(batchTagProvider).byBatch[batch.batchId];

    return AlertDialog(
      title: Text(
        batch.batchCode,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      // Bounded rather than left to grow: a share of thirty would otherwise
      // make a dialog taller than the phone. Inside that box the table
      // scrolls, so the Close button stays where he can reach it.
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _body(context, ref, rows),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, BatchTags? rows) {
    final batchId = batch.batchId;

    if (rows == null || rows.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (rows.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rows.error!,
            style: TextStyle(fontSize: 15, color: AppColors.danger),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  ref.read(batchTagProvider.notifier).retry(batchId),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (rows.tags.isEmpty) {
      return Text(
        'Nothing of yours left in this batch.',
        style: TextStyle(fontSize: 15, color: AppColors.muted),
      );
    }

    // Codes and nothing else in the second column. Every tag here is his,
    // every one is unaccepted, and every one is from the batch named in the
    // title - so a status or batch column would be the same word thirty times
    // over. `pole_no` is the code decoded, which says nothing the code has not
    // already said.
    //
    // A table rather than a row of chips, and the number down the left is the
    // whole reason. He is reading this against a stack of paper in his hand,
    // and what a stack of paper has is a position - "I am on the eleventh".
    // Chips have no position, so checking them means starting over every time
    // he looks up.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 7),
          child: Row(
            children: [
              SizedBox(width: 30, child: Text('#', style: _headStyle)),
              Text('TAG CODE', style: _headStyle),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.line),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: rows.tags.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Text(
                    rows.tags[index].tagCode,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      // The codes read down the column as a list of the same
                      // shape, which is what lets a wrong one stand out.
                      letterSpacing: 0.6,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// A getter rather than a const, because the colour it reads changes with the
// palette and a const would keep whichever one the app started in.
TextStyle get _headStyle => TextStyle(
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  letterSpacing: 1,
  color: AppColors.muted,
);
