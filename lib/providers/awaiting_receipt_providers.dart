import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/batch_awaiting_receipt.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/awaiting_cache.dart';

/// What the accept screen knows: envelopes out with him that he has not
/// claimed.
class AwaitingReceiptState {
  /// In the order the server sent it - longest wait first. Not re-sorted here:
  /// what makes a row urgent is how long the paper has been out, and that is a
  /// question the server has already answered.
  final List<BatchAwaitingReceipt> batches;

  final bool isLoading;

  /// The batch whose Accept he has pressed, or null. One id rather than a
  /// flag, because the screen has a button per card and only the one he
  /// pressed should show a spinner - a flag would grey out all of them.
  final int? accepting;

  /// The last fetch could not reach the office.
  ///
  /// Separate from [error], which is the sentence. This is the fact the
  /// buttons read: accepting is a claim the office has to hear, so with no
  /// signal the card can say so up front rather than let him press a button
  /// that will fail.
  final bool isOffline;

  /// When what he is looking at was fetched. Null until the first load lands.
  ///
  /// The screen shows it whenever the rows came off the phone rather than the
  /// wire: an envelope somebody else has since dealt away is gone from the
  /// office and still on his handset, and the time is the only thing that says
  /// how much to trust it.
  final DateTime? syncedAt;

  final String? error;

  const AwaitingReceiptState({
    this.batches = const [],
    this.isLoading = false,
    this.accepting,
    this.isOffline = false,
    this.syncedAt,
    this.error,
  });

  bool get isEmpty => batches.isEmpty;

  /// What the home screen's strip counts. Batches, not tags: the strip says
  /// "1 batch waiting", and one envelope is one thing to go and accept
  /// whatever it holds.
  int get waitingBatches => batches.length;

  AwaitingReceiptState copyWith({
    List<BatchAwaitingReceipt>? batches,
    bool? isLoading,
    int? accepting,
    bool clearAccepting = false,
    bool? isOffline,
    DateTime? syncedAt,
    String? error,
    bool clearError = false,
  }) {
    return AwaitingReceiptState(
      batches: batches ?? this.batches,
      isLoading: isLoading ?? this.isLoading,
      accepting: clearAccepting ? null : (accepting ?? this.accepting),
      isOffline: isOffline ?? this.isOffline,
      syncedAt: syncedAt ?? this.syncedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AwaitingReceiptNotifier extends StateNotifier<AwaitingReceiptState> {
  AwaitingReceiptNotifier(this._ref) : super(const AwaitingReceiptState());

  final Ref _ref;

  final _cache = const AwaitingCache();

  /// The phone first, then the office.
  ///
  /// Both, and the order matters. The strip that sent him here counts from the
  /// cached figures, so it draws in a dead spot - and a screen that then said
  /// only "could not reach the server" would have the phone promising
  /// something the phone itself refused to show. What he gets instead is the
  /// list as it last stood, with the buttons greyed and a line saying why.
  Future<void> load({bool showSpinner = true}) async {
    if (state.isEmpty) {
      final saved = await _cache.read();

      if (saved.isNotEmpty) {
        state = AwaitingReceiptState(
          batches: saved,
          syncedAt: await _cache.syncedAt(),
        );
        // No spinner over rows that are already on the screen. The refresh
        // goes out underneath and only shows itself if it fails.
        showSpinner = false;
      }
    }

    state = state.copyWith(isLoading: showSpinner, clearError: true);

    try {
      final batches = await _ref.read(apiProvider).getBatchesAwaitingReceipt();

      // Saved before the state is published, so what the screen shows and what
      // the phone holds cannot disagree - including when the answer is none,
      // which is why an empty list is written rather than skipped.
      await _cache.save(batches);

      state = AwaitingReceiptState(
        batches: batches,
        syncedAt: await _cache.syncedAt(),
      );
    } on ApiException catch (e) {
      // The rows on screen are left alone. A refresh that failed has not made
      // what he was reading untrue - the paper is still out with him.
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        error: e.message,
      );
    }
  }

  /// A pull-to-refresh: the same request without the middle-of-screen spinner,
  /// which the gesture is already drawing at the top.
  Future<void> refresh() => load(showSpinner: false);

  /// His word that he has this envelope's share in his hand.
  ///
  /// Returns true when the office heard it, which is what tells the screen
  /// whether to say so and step back.
  ///
  /// Reloads his tags on the way out, and that is the point of the tap rather
  /// than a detail of it: the tags this batch holds were locked a moment ago
  /// and are his to work now, so the home screen has to be told or he returns
  /// to the empty list he left.
  Future<bool> accept(int batchId) async {
    if (state.accepting != null) return false;

    state = state.copyWith(accepting: batchId, clearError: true);

    try {
      await _ref.read(apiProvider).receiveBatch(batchId);
    } on ApiException catch (e) {
      state = state.copyWith(
        clearAccepting: true,
        // A refusal the office gave is not being offline. Only a request that
        // never arrived is, and `ApiException` marks that with status 0.
        isOffline: e.statusCode == 0,
        error: e.message,
      );
      return false;
    }

    // Dropped from the list here rather than by re-asking the server: the
    // refusal above is the only way the tap fails, so a batch that got past it
    // has nothing of his left waiting. Re-asking would be a second request on
    // the signal he has, to be told what this already knows.
    final left = [
      for (final batch in state.batches)
        if (batch.batchId != batchId) batch,
    ];

    // Written through, so a cold open in a dead spot does not offer him an
    // envelope he is already carrying.
    await _cache.save(left);

    state = AwaitingReceiptState(
      batches: left,
      syncedAt: await _cache.syncedAt(),
    );

    await _ref.read(tagProvider.notifier).loadMyTags();

    return true;
  }

  /// Drops what is on screen and what is on the phone, for the man signing
  /// out. These are one person's envelopes, and the next one on this handset
  /// must not find them waiting.
  Future<void> clear() async {
    await _cache.clear();
    state = const AwaitingReceiptState();
  }
}

/// The cache on its own, for the one caller that wants it without the
/// notifier: signing out.
final awaitingCacheProvider = Provider<AwaitingCache>(
  (ref) => const AwaitingCache(),
);

final awaitingReceiptProvider =
    StateNotifierProvider<AwaitingReceiptNotifier, AwaitingReceiptState>(
      (ref) => AwaitingReceiptNotifier(ref),
    );
