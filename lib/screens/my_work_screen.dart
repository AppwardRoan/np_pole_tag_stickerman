import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/my_stats.dart';
import 'package:np_pole_tag_stickerman/providers/batch_tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/export_providers.dart';
import 'package:np_pole_tag_stickerman/providers/my_batch_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/empty_message.dart';
import 'package:np_pole_tag_stickerman/widgets/home/stat_tile.dart';
import 'package:np_pole_tag_stickerman/widgets/work/batch_row.dart';
import 'package:np_pole_tag_stickerman/widgets/work/download_button.dart';

/// His work over the whole job, rather than the day the header's bar counts.
///
/// Nothing here is cached. The home screen's lists have to survive a dead spot
/// because he reads them at a pole; this one he opens at the end of a run or
/// back at the office, so it fetches live and says so when it cannot. That is
/// also what lets it page rather than cap - his history outgrows any figure
/// worth holding on a phone.
///
/// Still to come, from the design: tapping a batch open to the tags inside it,
/// and the CSV of the lot.
class MyWorkScreen extends ConsumerStatefulWidget {
  const MyWorkScreen({super.key});

  @override
  ConsumerState<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends ConsumerState<MyWorkScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(myBatchProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Asks for the next page while there is still a screen's worth below him,
  /// rather than at the very bottom. Fetched at the bottom he watches a
  /// spinner; fetched early the rows are usually there before he arrives.
  void _onScroll() {
    if (!_scroll.hasClients) return;

    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) {
      ref.read(myBatchProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(tagProvider).stats;

    // The same adjustment the home header makes: a pole waiting to upload is
    // done from where he stands, and a figure here that disagreed with the bar
    // he just tapped would read as one of the two being wrong.
    final waiting = ref.watch(uploadProvider).waitingTagIds.length;

    final hasBatches = ref.watch(myBatchProvider).batches.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.page,
      // No SafeArea: the header paints its own way past the status bar, the
      // same as the home screen's does.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          _Stats(done: stats.completed + waiting, stats: stats),
          if (hasBatches) _downloadAll(),
          if (hasBatches) const _SectionLabel('COMPLETED BY BATCH'),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// One RefreshIndicator over one scrollable, always, whatever the state.
  ///
  /// The three states used to be three different widgets, and the empty one
  /// could not be pulled: `load()` raises `isLoading`, the build swapped the
  /// scrollable for a bare spinner, and the gesture lost the thing it had hold
  /// of half a pull in. The state he most wants to retry from was the one state
  /// that ignored him. The spinner is content inside the list now rather than a
  /// replacement for it, so nothing is ever torn out from under his thumb.
  /// The whole-history file, across the top.
  ///
  /// Hidden when he has no batches at all: a download button over an empty
  /// screen offers a file with nothing in it.
  Widget _downloadAll() {
    final exporting = ref.watch(exportProvider);

    // On the page itself. It used to sit on a white strip with a rule under
    // it, which read as a second header rather than as the offer it is.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: DownloadButton(
        label: 'Download all as CSV',
        filled: true,
        isRunning: exporting.isRunning(null),
        onPressed: exporting.isBusy
            ? null
            : (origin) => _download(origin: origin),
      ),
    );
  }

  /// Fetches a file and hands it to the share sheet.
  ///
  /// The failure comes back as a sentence rather than being held in the
  /// provider: a download that did not work is something to say once, not a
  /// state the screen sits in, and only a screen can raise a snack bar.
  Future<void> _download({int? batchId, required Rect origin}) async {
    final failed = await ref
        .read(exportProvider.notifier)
        .download(batchId: batchId, origin: origin);

    if (failed == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed)));
  }

  Widget _body() {
    final batches = ref.watch(myBatchProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Both, and the contents second: the list settles what each row claims,
        // and the open row is then refetched to match the claim above it.
        await ref.read(myBatchProvider.notifier).refresh();
        await ref.read(batchTagProvider.notifier).refreshOpen();
      },
      child: batches.batches.isEmpty ? _message(batches) : _list(batches),
    );
  }

  /// The screen with no rows on it: loading, failed, or genuinely empty.
  ///
  /// Scrollable despite having nothing to scroll - that is what the pull needs
  /// to catch. `minHeight` fills the screen so the message sits centred rather
  /// than clinging to the top.
  Widget _message(MyBatchState batches) {
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: batches.isLoading
              // Only on the very first open. A pull has the indicator's own
              // spinner at the top of the screen, and a second one in the
              // middle reads as two things loading.
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              // The failure and the genuine empty are different messages. One
              // is the phone's problem and worth pulling to retry; the other is
              // a true answer about a man who has not finished anything.
              : batches.error != null
              ? EmptyMessage(
                  icon: Icons.cloud_off,
                  title: 'Could not load your batches',
                  detail: batches.error,
                )
              : const EmptyMessage(
                  icon: Icons.checklist_rtl,
                  title: 'Nothing completed yet',
                  detail:
                      'Batches appear here once you finish a pole in '
                      'one of them.',
                ),
        ),
      ),
    );
  }

  Widget _list(MyBatchState batches) {
    final opened = ref.watch(batchTagProvider);
    final exporting = ref.watch(exportProvider);

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      // One past the rows, for the line underneath saying whether more is
      // coming.
      itemCount: batches.batches.length + 1,
      itemBuilder: (_, index) {
        if (index >= batches.batches.length) return _footer(batches);

        final batch = batches.batches[index];

        return BatchRow(
          batch: batch,
          isOpen: opened.openBatchId == batch.batchId,
          // Held even while the row is shut, so re-opening a batch he looked at
          // a minute ago costs nothing.
          contents: opened.byBatch[batch.batchId],
          onTap: () =>
              ref.read(batchTagProvider.notifier).toggle(batch.batchId),
          onRetry: () =>
              ref.read(batchTagProvider.notifier).retry(batch.batchId),
          isDownloading: exporting.isRunning(batch.batchId),
          // Null while any download runs, including this one: the button greys
          // rather than stacking a second file into the share sheet.
          onDownload: exporting.isBusy
              ? null
              : (origin) => _download(batchId: batch.batchId, origin: origin),
        );
      },
    );
  }

  /// What sits under the last row: a spinner while the next page is coming, the
  /// reason if it failed, and a full stop once he has seen everything.
  Widget _footer(MyBatchState batches) {
    if (batches.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // A failure part-way down, with the rows he already has still above it.
    // Retried in place rather than by pulling from the top, which would throw
    // away every page he has scrolled through.
    if (batches.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              batches.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => ref.read(myBatchProvider.notifier).loadMore(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (batches.hasMore) return const SizedBox(height: 24);

    // The end of his history, said out loud. Without it a list that simply
    // stops reads as one that failed to load the rest.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'End of list',
          style: TextStyle(fontSize: 15, color: AppColors.muted),
        ),
      ),
    );
  }
}

/// The green block at the top: where he is, and the way back out.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // The status bar's height is added on rather than kept clear above, so
      // the green carries on to the top edge of the screen.
      padding: EdgeInsets.fromLTRB(
        16,
        12 + MediaQuery.paddingOf(context).top,
        12,
        14,
      ),
      color: AppColors.deepGreen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MY WORK',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.paleGreen,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Completed tags',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
              ],
            ),
          ),
          // "Done", not an arrow. He came here to read his figures, and the
          // word says he has finished reading them; a back arrow says he took
          // a wrong turn.
          _DoneButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// The way off this screen, as a word in a pill.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.greenLine),
          ),
          child: Text(
            'Done',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// The three figures, on the page under the green.
class _Stats extends StatelessWidget {
  const _Stats({required this.done, required this.stats});

  /// Poles on file, the phone's queue included.
  final int done;

  final MyStats stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              value: '$done',
              label: 'TAGS DONE',
              accent: AppColors.amber,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: StatTile(value: '${stats.batchesTotal}', label: 'BATCHES'),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: StatTile(value: '${stats.batchesDone}', label: 'FINISHED'),
          ),
        ],
      ),
    );
  }
}

/// A line of capitals naming the block under it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
