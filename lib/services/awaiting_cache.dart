import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:np_pole_tag_stickerman/models/batch_awaiting_receipt.dart';

/// The envelopes waiting to be accepted, kept on the phone.
///
/// This was deliberately not cached at first, on the argument that accepting
/// needs signal - so a saved list would only draw buttons that cannot be
/// pressed. What that missed is that the strip under the home header already
/// draws offline: it counts from the cached figures, so in a dead spot he is
/// told "1 batch waiting for you", taps it, and gets an error. The promise
/// came from the phone and the answer had to come from the office.
///
/// So the list is saved, and it is the button that goes grey rather than the
/// screen that goes blank. He can read what is waiting - which envelope, how
/// much of it is his, how long it has been out - and is told plainly that
/// taking it needs a signal. The same choice [BatchCache] made for My work,
/// for the same reason: one screen must not give two answers.
///
/// Stored as the plain maps the model already produces, like every other cache
/// here - no generated adapter to keep in step.
class AwaitingCache {
  const AwaitingCache();

  static const String _boxName = 'awaiting_receipt';
  static const String _listKey = 'batches';
  static const String _syncedAtKey = 'synced_at';

  Future<Box> _open() async {
    return Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  /// Keeps the list and the moment it arrived.
  ///
  /// Cleared first rather than written over: an empty list is a real answer -
  /// he has accepted everything - and putting `[]` under the key has to leave
  /// nothing behind it, or the next cold open would show him envelopes he
  /// picked up yesterday.
  Future<void> save(List<BatchAwaitingReceipt> batches) async {
    final box = await _open();

    await box.put(_listKey, [for (final batch in batches) batch.toJson()]);
    await box.put(_syncedAtKey, DateTime.now().toIso8601String());
  }

  /// What was saved, or an empty list if nothing ever was.
  Future<List<BatchAwaitingReceipt>> read() async {
    final box = await _open();
    final saved = box.get(_listKey);

    if (saved is! List) return const [];

    return saved
        .whereType<Map>()
        .map(
          (row) => BatchAwaitingReceipt.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  /// When the saved list was fetched, or null if there is none.
  ///
  /// Read by the screen to say how old what he is looking at is. An envelope
  /// accepted by somebody else - a dispatcher correcting a mis-deal - is gone
  /// from the office and still on his phone, and the time is the only thing
  /// that says so.
  Future<DateTime?> syncedAt() async {
    final box = await _open();
    final saved = box.get(_syncedAtKey);

    return saved is String ? DateTime.tryParse(saved) : null;
  }

  /// Dropped when he signs out. These are one man's envelopes on a handset the
  /// next one may also use.
  Future<void> clear() async {
    final box = await _open();
    await box.clear();
  }
}
