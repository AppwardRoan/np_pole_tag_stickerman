import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/my_batch.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/batch_cache.dart';

/// How many batches one request fetches. Enough to fill a screen and a little
/// more, so the next page is already being asked for before he reaches the
/// bottom of this one.
const int _pageSize = 10;

/// What the My work screen knows about his finished batches.
class MyBatchState {
  /// Everything fetched so far, in the order the server sent it - newest work
  /// first. Pages are appended, never re-sorted: the server owns the order and
  /// re-deciding it here is how page 2 ends up holding a row from page 1.
  final List<MyBatch> batches;

  /// How many there are in total, which is what tells the scroll when to stop.
  final int total;

  /// The first load, where the screen has nothing to show yet.
  final bool isLoading;

  /// A further page, where the screen keeps its rows and puts a spinner under
  /// them. Separate from [isLoading] because the two draw differently - one
  /// replaces the screen, the other adds a line to it.
  final bool isLoadingMore;

  final String? error;

  const MyBatchState({
    this.batches = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  /// Whether there is another page to ask for.
  bool get hasMore => batches.length < total;

  MyBatchState copyWith({
    List<MyBatch>? batches,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return MyBatchState(
      batches: batches ?? this.batches,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MyBatchNotifier extends StateNotifier<MyBatchState> {
  MyBatchNotifier(this._ref) : super(const MyBatchState());

  final Ref _ref;

  final _cache = const BatchCache();

  /// The first open.
  ///
  /// Draws whatever is on the phone first, then goes and asks. With signal the
  /// saved page is replaced a moment later and he sees nothing of the swap;
  /// without it he keeps a screen that agrees with its own header instead of
  /// one that says it could not load while three figures sit above it.
  Future<void> load() async {
    final saved = await _cache.read();
    if (saved.batches.isNotEmpty) {
      state = MyBatchState(batches: saved.batches, total: saved.total);
      // No spinner over rows that are already on the screen. The refresh goes
      // out underneath and only shows itself if it fails.
      await _first(showSpinner: false);
      return;
    }

    await _first(showSpinner: true);
  }

  /// A pull-to-refresh.
  ///
  /// The same request as [load] without raising `isLoading`, and that is the
  /// whole difference: the gesture already puts a spinner at the top of the
  /// screen, so raising the flag too would draw a second one in the middle and
  /// read as two things loading at once.
  Future<void> refresh() => _first(showSpinner: false);

  /// Page one. Replaces whatever is held rather than appending, so a batch he
  /// finished since the last look lands in its place instead of twice.
  Future<void> _first({required bool showSpinner}) async {
    state = state.copyWith(isLoading: showSpinner, clearError: true);

    try {
      final page = await _ref
          .read(apiProvider)
          .getMyCompletedBatches(skip: 0, limit: _pageSize);

      state = MyBatchState(batches: page.batches, total: page.total);

      // Saved after the state, not before: what is kept is what he is looking
      // at. Awaited so a screen closed the instant it loads cannot leave the
      // write half done.
      await _cache.save(page);
    } on ApiException catch (e) {
      // The rows already on screen are left alone. A refresh that fails has
      // not made what he was reading untrue.
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// The next page, asked for when he nears the bottom.
  ///
  /// Guarded three ways: nothing already in flight, something left to fetch,
  /// and no first load running. Without the first guard a fast scroll fires
  /// this several times and the same page is appended twice.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _ref
          .read(apiProvider)
          .getMyCompletedBatches(skip: state.batches.length, limit: _pageSize);

      state = state.copyWith(
        batches: [...state.batches, ...page.batches],
        // Taken from the newest reply rather than kept: he may have finished a
        // pole in a new batch while he was scrolling, and a stale total would
        // stop the scroll one page early or send it asking for a page that is
        // not there.
        total: page.total,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    }
  }

  /// Drops what is on screen. Emptying the cache is not enough on its own -
  /// these batches are already loaded, and the next man opening My Work would
  /// read them before his own reply landed.
  void clear() => state = const MyBatchState();
}

/// The cache on its own, for the one caller that wants it without the
/// notifier: signing out, which has to empty it before the next man on this
/// handset opens the screen.
final batchCacheProvider = Provider<BatchCache>((ref) => const BatchCache());

final myBatchProvider = StateNotifierProvider<MyBatchNotifier, MyBatchState>(
  (ref) => MyBatchNotifier(ref),
);
