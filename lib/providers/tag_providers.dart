import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/my_stats.dart';
import 'package:np_pole_tag_stickerman/models/my_tags.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';
import 'package:np_pole_tag_stickerman/services/tag_cache.dart';

/// The tags on screen, and what is happening to them.
class TagState {
  /// The two lists, in the order the server put them in. Kept apart rather
  /// than merged and re-split: each one is ordered for its own tab, and one
  /// combined list can only hold one of those orders.
  final MyTags tags;

  /// The three tiles across the top, counted by the server rather than by
  /// totalling [tags]. The lists are capped, so counting them reported the cap
  /// once he passed it - and neither list says whether a bundle is finished.
  final MyStats stats;

  final bool isLoading;
  final String? error;

  /// When the list on screen came back from the server. The crew works out of
  /// signal, so a list can be hours old without looking it.
  final DateTime? syncedAt;

  const TagState({
    this.tags = const MyTags(),
    this.stats = MyStats.empty,
    this.isLoading = false,
    this.error,
    this.syncedAt,
  });

  TagState copyWith({
    MyTags? tags,
    MyStats? stats,
    bool? isLoading,
    String? error,
    DateTime? syncedAt,
    bool clearError = false,
  }) {
    return TagState(
      tags: tags ?? this.tags,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

class TagNotifier extends StateNotifier<TagState> {
  TagNotifier(this._api, this._cache) : super(const TagState());

  final ApiService _api;
  final TagCache _cache;

  /// Shows what is on the phone, then refreshes it from the server.
  ///
  /// The phone first, always: the crew opens this app at a pole where there is
  /// no signal, and a screen that waits for the server is a blank screen. The
  /// saved list is shown even when it is hours old - [TagState.syncedAt] is
  /// what tells him that, rather than an empty list he cannot read.
  Future<void> loadMyTags() async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Only when there is nothing on screen yet. A refresh already has the list
    // up, and reading the phone again would only replace it with itself.
    if (state.tags.isEmpty) {
      final cached = await _cache.read();

      if (!cached.isEmpty) {
        state = state.copyWith(
          tags: cached,
          stats: await _cache.readStats(),
          syncedAt: await _cache.syncedAt(),
        );
      }
    }

    try {
      final tags = await _api.getMyTags();
      await _cache.save(tags);

      state = state.copyWith(
        tags: tags,
        isLoading: false,
        syncedAt: await _cache.syncedAt(),
      );
    } catch (e) {
      // The saved list stays on screen. Only the message is new.
      state = state.copyWith(isLoading: false, error: e.toString());
    }

    // After the lists, and never in their place. The two are separate calls,
    // so the header failing must not cost him the list he came here for -
    // which is also why this is not awaited inside the try above.
    await loadMyStats();
  }

  /// The header's figures, from the server.
  ///
  /// Silent on failure, deliberately. The list has its own message and that is
  /// the one worth his attention; a second banner about three numbers would
  /// bury it. What he sees instead is the last figures the phone kept, which
  /// is what [TagState.syncedAt] is already telling him the age of.
  ///
  /// A 403 lands here too - the Crew role missing from his account. Nothing he
  /// can do about it at a pole, and the office fixes it by assigning the role.
  Future<void> loadMyStats() async {
    try {
      final stats = await _api.getMyStats();
      await _cache.saveStats(stats);

      state = state.copyWith(stats: stats);
    } catch (_) {
      // Whatever is on screen stays on screen.
    }
  }

  /// The tag with this code, from the phone first.
  ///
  /// A miss is worth one short refresh: the office can assign a tag after his
  /// last sync, and it would read as missing until he thought to pull down.
  /// Five seconds, not the app's usual thirty - he is standing at the pole
  /// waiting on this one, and would tap the shutter again long before then.
  Future<Tag?> findByCode(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return null;

    Tag? onPhone() {
      // Both lists: a code he scans may well be one he has already filed,
      // and finding it is what lets the scan say so rather than "not one of
      // yours".
      for (final tag in state.tags.all) {
        if (tag.tagCode.toUpperCase() == wanted) return tag;
      }
      return null;
    }

    final local = onPhone();
    if (local != null) return local;

    try {
      await loadMyTags().timeout(const Duration(seconds: 5));
    } catch (_) {
      // No signal, or too slow. The phone's list is the answer either way.
    }

    return onPhone();
  }

  /// Wipes the phone's copy, so the next person to sign in on this handset
  /// does not find the last one's tags waiting.
  Future<void> clear() async {
    await _cache.clear();
    state = const TagState();
  }
}

final tagCacheProvider = Provider<TagCache>((ref) => const TagCache());

final tagProvider = StateNotifierProvider<TagNotifier, TagState>((ref) {
  return TagNotifier(ref.read(apiProvider), ref.read(tagCacheProvider));
});
