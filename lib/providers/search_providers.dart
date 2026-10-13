import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

/// How a search finished, which is what decides the sentence under the box.
///
/// [missed] and [unreachable] both end with nothing on screen and must not
/// read the same. One says the pole is not his; the other says the phone
/// could not ask. Telling him "no such tag" in a dead spot is the same lie
/// the scanner used to tell.
enum SearchOutcome { idle, onPhone, fromServer, missed, unreachable }

class SearchState {
  /// What he typed, as he typed it. Kept so the empty-state line can quote it.
  final String query;

  final List<Tag> results;

  /// How many the server had before it capped what it sent. Zero for a local
  /// hit, where there is no cap and nothing to disclose.
  final int total;

  final bool isSearching;
  final SearchOutcome outcome;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.total = 0,
    this.isSearching = false,
    this.outcome = SearchOutcome.idle,
  });

  bool get isActive => query.isNotEmpty;

  /// Whether the server had more matches than it sent. The screen says so
  /// rather than letting the cap hide the pole he is after.
  bool get wasCut => total > results.length;

  SearchState copyWith({
    String? query,
    List<Tag>? results,
    int? total,
    bool? isSearching,
    SearchOutcome? outcome,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      total: total ?? this.total,
      isSearching: isSearching ?? this.isSearching,
      outcome: outcome ?? this.outcome,
    );
  }
}

/// The search box: the phone's own list first, the server only behind it.
///
/// The phone answers instantly, in a dead spot, and for the pole he did this
/// morning it is the whole answer. What it cannot do is find anything
/// `GET /tags/my` did not send, and that list is capped - so a pole from three
/// months ago reads as a pole he never tagged. The server is asked exactly
/// then, and not before: a request per keystroke over field signal would be
/// slower than the list he already has.
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._api, this._ref) : super(const SearchState());

  final ApiService _api;
  final Ref _ref;

  Timer? _debounce;

  /// Which search the answer on screen belongs to.
  ///
  /// He keeps typing while a request is in the air, and replies do not have to
  /// come back in the order they went out. Without this, the results for
  /// `M00` can land after `M006R` and overwrite the one row he wanted.
  int _generation = 0;

  static const Duration _pause = Duration(milliseconds: 350);

  /// Long enough to be a search. One or two characters against a year of work
  /// matches most of it, and the answer is always "type more" - which he can
  /// be told without a round trip.
  static const int minimumForServer = 3;

  void search(String typed) {
    _debounce?.cancel();

    final wanted = typed.trim().toUpperCase();
    final generation = ++_generation;

    if (wanted.isEmpty) {
      state = const SearchState();
      return;
    }

    final local = _onPhone(wanted);

    // Shown before the server is even considered. He gets an answer on the
    // keystroke, and the request behind it - if there is one - only ever adds
    // to what is already up.
    state = SearchState(
      query: wanted,
      results: local,
      outcome: local.isEmpty ? SearchOutcome.missed : SearchOutcome.onPhone,
      isSearching: local.isEmpty && wanted.length >= minimumForServer,
    );

    if (local.isNotEmpty || wanted.length < minimumForServer) return;

    _debounce = Timer(_pause, () => _askServer(wanted, generation));
  }

  void clear() {
    _debounce?.cancel();
    _generation++;
    state = const SearchState();
  }

  /// A tag code or a batch code matched anywhere inside it. The same rule the
  /// server uses, so a result does not change shape depending on which of the
  /// two answered.
  List<Tag> _onPhone(String wanted) {
    return [
      for (final tag in _ref.read(tagProvider).tags.all)
        if (tag.tagCode.toUpperCase().contains(wanted) ||
            (tag.batchCode ?? '').toUpperCase().contains(wanted))
          tag,
    ];
  }

  Future<void> _askServer(String wanted, int generation) async {
    try {
      final found = await _api.searchMyTags(wanted);

      // `mounted` as well as the generation: he can leave the screen while a
      // request is in the air, and a reply landing on a disposed notifier
      // throws where nobody is left to see it.
      if (!mounted || generation != _generation) return;

      state = state.copyWith(
        results: found.tags,
        total: found.total,
        isSearching: false,
        outcome: found.isEmpty
            ? SearchOutcome.missed
            : SearchOutcome.fromServer,
      );
    } on ApiException catch (error) {
      // `mounted` as well as the generation: he can leave the screen while a
      // request is in the air, and a reply landing on a disposed notifier
      // throws where nobody is left to see it.
      if (!mounted || generation != _generation) return;

      // Status 0 is the app's own code for "never reached the server". That is
      // the one failure he can do something about - walk twenty metres - and
      // the only one worth a different sentence. Anything else is the server
      // answering badly, which for a search is the same as no match.
      state = state.copyWith(
        isSearching: false,
        outcome: error.statusCode == 0
            ? SearchOutcome.unreachable
            : SearchOutcome.missed,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref.read(apiProvider), ref);
});
