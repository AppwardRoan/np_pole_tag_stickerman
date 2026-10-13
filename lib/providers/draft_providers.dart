import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/services/draft_store.dart';

/// The unfinished forms on this phone.
class DraftState {
  final List<DraftTag> drafts;

  const DraftState({this.drafts = const []});

  /// What the tag list marks as Draft. A set rather than the list, because the
  /// list asks this question once per row.
  Set<int> get draftTagIds => drafts.map((draft) => draft.tagId).toSet();

  DraftState copyWith({List<DraftTag>? drafts}) {
    return DraftState(drafts: drafts ?? this.drafts);
  }
}

/// Keeps the screens and the phone in step.
///
/// Thinner than [UploadController]: drafts never go anywhere, so there is no
/// sending, no retrying and no failure to report. Save, read, drop.
class DraftController extends StateNotifier<DraftState> {
  DraftController(this._store) : super(const DraftState());

  final DraftStore _store;

  Future<void> load() async {
    state = state.copyWith(drafts: await _store.read());
  }

  /// Called every time he finishes a step, backs out, or comes off the camera.
  Future<void> save(DraftTag draft) async {
    await _store.save(draft);
    await load();
  }

  /// What the form reads when he taps a tag he has already started.
  Future<DraftTag?> find(int tagId) => _store.find(tagId);

  /// On submit. The tag becomes a queued tag instead, and it must not be in
  /// both places - the row cannot say Draft and greyed-out at once.
  Future<void> discard(int tagId) async {
    await _store.remove(tagId);
    await load();
  }
}

final draftStoreProvider = Provider<DraftStore>((ref) => const DraftStore());

final draftProvider = StateNotifierProvider<DraftController, DraftState>((ref) {
  return DraftController(ref.read(draftStoreProvider));
});
