import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

/// The tags that have been submitted but not uploaded.
///
/// Stores each one as the plain map [QueuedTag.toJson] already produces, keyed
/// by tag id, the way `TagCache` stores tags. No generated adapter: the model
/// turns itself into data and back.
///
/// Keyed by tag id on purpose. Submit is final and the backend allows one
/// record per pole, so a second entry for the same tag is never correct - and
/// keying it this way makes that impossible rather than merely unlikely.
///
/// Only touches the phone. It never calls the server, and it has no `clear`:
/// logging out must not throw away a day's tagging.
class UploadQueue {
  const UploadQueue();

  static const String boxName = 'upload_queue';

  Future<Box> _open() async {
    return Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);
  }

  Future<void> add(QueuedTag tag) async {
    final box = await _open();
    await box.put(tag.tagId, tag.toJson());
  }

  /// Everything waiting, oldest first - which is the order the uploader sends
  /// them in, so the tag he has been carrying longest goes first.
  Future<List<QueuedTag>> read() async {
    final box = await _open();

    final tags = box.values
        .whereType<Map>()
        .map((row) => QueuedTag.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    tags.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return tags;
  }

  Future<QueuedTag?> find(int tagId) async {
    final box = await _open();
    final row = box.get(tagId);

    return row is Map
        ? QueuedTag.fromJson(Map<String, dynamic>.from(row))
        : null;
  }

  /// Same key, so this overwrites rather than appends.
  Future<void> update(QueuedTag tag) async {
    final box = await _open();
    await box.put(tag.tagId, tag.toJson());
  }

  Future<void> remove(int tagId) async {
    final box = await _open();
    await box.delete(tagId);
  }
}
