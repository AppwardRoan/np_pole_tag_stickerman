import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';

/// The forms he started and did not finish.
///
/// Same shape as [UploadQueue] - a Hive box of plain maps, keyed by tag id -
/// and deliberately a *different* box. The uploader sends everything it finds
/// in the queue; a half-filled form in there would file an incomplete record
/// and mark the pole Used before he had finished it.
///
/// Keyed by tag id because he fills one form in stages, saving over the same
/// draft each time. One tag, one draft, always.
///
/// Only touches the phone, and has no `clear`: signing out must not throw away
/// half a day's work. Another user signing in on the same handset never sees
/// these - drafts are matched to rows by tag id, and his tag list holds his
/// own tags, so there is no row for someone else's draft to appear on.
class DraftStore {
  const DraftStore();

  static const String boxName = 'drafts';

  Future<Box> _open() async {
    return Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);
  }

  /// Writes the draft, replacing whatever was there for this tag.
  Future<void> save(DraftTag draft) async {
    final box = await _open();
    await box.put(draft.tagId, draft.toJson());
  }

  Future<DraftTag?> find(int tagId) async {
    final box = await _open();
    final row = box.get(tagId);

    return row is Map
        ? DraftTag.fromJson(Map<String, dynamic>.from(row))
        : null;
  }

  /// Every draft, newest first - the one he was working on last is the one he
  /// is most likely to come back to.
  Future<List<DraftTag>> read() async {
    final box = await _open();

    final drafts = box.values
        .whereType<Map>()
        .map((row) => DraftTag.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  /// Called when he submits: the tag becomes a queued tag instead, and a tag
  /// is never in both places at once.
  Future<void> remove(int tagId) async {
    final box = await _open();
    await box.delete(tagId);
  }
}
