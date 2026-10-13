import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';

/// What one opened batch holds, on the My work screen.
class BatchTags {
  /// His tags in that batch, in code order.
  final List<Tag> tags;

  final bool isLoading;
  final String? error;

  const BatchTags({this.tags = const [], this.isLoading = false, this.error});

  /// Fetched and came back with nothing. Told apart from "not fetched yet",
  /// which is the absence of an entry altogether - one is an answer, the other
  /// is a question nobody has asked.
  bool get isEmpty => !isLoading && error == null && tags.isEmpty;
}

/// Which batch is open, and what is inside the ones he has opened.
///
/// One open at a time. Two expanded rows push the second off the bottom of the
/// screen, and he is comparing a batch against the list rather than against
/// another batch.
class BatchTagState {
  /// The batch currently expanded, or null with everything closed.
  final int? openBatchId;

  /// Keyed by batch id, and kept after the row is collapsed. Re-opening a batch
  /// he looked at a moment ago is a tap, not a second request - the rows cannot
  /// have changed, since he is the only person who files against his own tags.
  final Map<int, BatchTags> byBatch;

  const BatchTagState({this.openBatchId, this.byBatch = const {}});

  BatchTags? get open => openBatchId == null ? null : byBatch[openBatchId];

  BatchTagState copyWith({
    int? openBatchId,
    Map<int, BatchTags>? byBatch,
    bool closed = false,
  }) {
    return BatchTagState(
      openBatchId: closed ? null : (openBatchId ?? this.openBatchId),
      byBatch: byBatch ?? this.byBatch,
    );
  }
}

class BatchTagNotifier extends StateNotifier<BatchTagState> {
  BatchTagNotifier(this._ref) : super(const BatchTagState());

  final Ref _ref;

  /// Tapping a batch row: opens it, closes it, or swaps which one is open.
  Future<void> toggle(int batchId) async {
    if (state.openBatchId == batchId) {
      state = state.copyWith(closed: true);
      return;
    }

    state = state.copyWith(openBatchId: batchId);

    // Already fetched, whether it came back with rows or with nothing. Asking
    // again on every tap would make an empty batch fetch forever.
    final held = state.byBatch[batchId];
    if (held != null && !held.isLoading && held.error == null) return;

    await _fetch(batchId);
  }

  /// Fetches a batch's contents without opening a row for it.
  ///
  /// For the accept screen, which shows them in a dialog rather than by
  /// expanding a row - there is nothing on that screen for `openBatchId` to
  /// mean, and setting it would leave a row on My work standing open because
  /// somebody looked at a different batch somewhere else.
  ///
  /// Same holding rule as [toggle]: already fetched is already answered, and a
  /// batch that came back empty must not be asked again on every look.
  Future<void> open(int batchId) async {
    final held = state.byBatch[batchId];
    if (held != null && !held.isLoading && held.error == null) return;

    await _fetch(batchId);
  }

  /// Forgets every batch's contents, keeping whichever row is open.
  ///
  /// What a pull-to-refresh means here. The summary above each row is refetched
  /// by the list, so without this the row could read "19 of 30" over a held
  /// list of eighteen tags - the screen disagreeing with itself, which is the
  /// thing the refresh was pulled to settle.
  ///
  /// Only the open row is fetched again, and only if one is open. Refetching
  /// all ten would be ten requests to redraw one visible list; the rest are
  /// dropped and asked for if and when he opens them.
  Future<void> refreshOpen() async {
    final open = state.openBatchId;

    state = BatchTagState(openBatchId: open);

    if (open != null) await _fetch(open);
  }

  /// Emptied when he signs out.
  ///
  /// These rows live in memory rather than in Hive, but the notifier outlives a
  /// sign-out - so without this the next man on the handset could open a batch
  /// carrying the same id and be shown the last man's tags off the held map,
  /// with no request made to correct it.
  void clear() {
    state = const BatchTagState();
  }

  /// Another go after a failure, from the line inside the open row.
  Future<void> retry(int batchId) => _fetch(batchId);

  Future<void> _fetch(int batchId) async {
    state = state.copyWith(
      byBatch: {...state.byBatch, batchId: const BatchTags(isLoading: true)},
    );

    try {
      final tags = await _ref.read(apiProvider).getMyTagsInBatch(batchId);

      state = state.copyWith(
        byBatch: {
          ...state.byBatch,
          batchId: BatchTags(tags: tags),
        },
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        byBatch: {
          ...state.byBatch,
          batchId: BatchTags(error: e.message),
        },
      );
    }
  }
}

final batchTagProvider = StateNotifierProvider<BatchTagNotifier, BatchTagState>(
  (ref) => BatchTagNotifier(ref),
);
