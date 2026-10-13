import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:np_pole_tag_stickerman/models/my_batch.dart';

/// The first page of the My work screen, kept on the phone.
///
/// Only the first page, and only ever overwritten - never appended to. What is
/// worth holding is enough to draw the screen when he opens it in a dead spot;
/// the pages he scrolls to are his history, and history he cannot reach without
/// signal is not worth the room.
///
/// It exists because the screen contradicted itself offline. The three figures
/// across its header come from the tag cache and drew fine, while the list
/// underneath them said it could not load anything - one screen giving two
/// answers, which reads as broken rather than as offline.
///
/// Stored as the plain map [MyBatchesPage.toJson] already produces, the same
/// way [TagCache] stores its lists: the model turns itself into data and back,
/// so there is no generated adapter to keep in step.
class BatchCache {
  const BatchCache();

  static const String _boxName = 'my_batches';
  static const String _pageKey = 'first_page';
  static const String _syncedAtKey = 'synced_at';

  Future<Box> _open() async {
    return Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  /// Keeps the first page and the moment it arrived.
  ///
  /// `total` is saved with the rows. Without it the screen would come up
  /// believing it holds everything there is, and the scroll would never ask
  /// for page two once the signal came back.
  Future<void> save(MyBatchesPage page) async {
    final box = await _open();

    await box.put(_pageKey, page.toJson());
    await box.put(_syncedAtKey, DateTime.now().toIso8601String());
  }

  /// What was saved, or an empty page if nothing ever was.
  Future<MyBatchesPage> read() async {
    final box = await _open();
    final saved = box.get(_pageKey);

    if (saved is! Map) return MyBatchesPage.empty;

    return MyBatchesPage.fromJson(Map<String, dynamic>.from(saved));
  }

  /// When the saved page was fetched, or null if there is none.
  Future<DateTime?> syncedAt() async {
    final box = await _open();
    final saved = box.get(_syncedAtKey);

    return saved is String ? DateTime.tryParse(saved) : null;
  }

  /// Dropped when he signs out. The batches belong to one man on a handset the
  /// next one may also use.
  Future<void> clear() async {
    final box = await _open();
    await box.clear();
  }
}
