import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:np_pole_tag_stickerman/models/my_stats.dart';
import 'package:np_pole_tag_stickerman/models/my_tags.dart';

/// The tags kept on the phone, so the list is there with no signal.
///
/// Stores each tag as the plain map [Tag.toJson] already produces. That skips
/// Hive's code-generation step: the model can turn itself into data and back,
/// so there is nothing for a generated adapter to add.
///
/// The two lists are stored whole, in their order, under one key each - not a
/// row per tag keyed by id. A box keyed by id has no order to give back, and
/// what came off it had to be re-sorted by code on the way out, which threw
/// away the ordering the server had just worked out. Offline is exactly when
/// he cannot afford a list in a different order from the one he saw with
/// signal.
///
/// Only touches the phone - it never calls the server. When to save and when
/// to read is the provider's decision.
class TagCache {
  const TagCache();

  static const String _boxName = 'tags'; // where the tags go
  static const String _metaBoxName = 'tags_meta'; // where the time goes
  static const String _syncedAtKey =
      'synced_at'; // the label on the time itself
  static const String _listsKey =
      'lists'; // both lists, in order, under one key
  static const String _statsKey = 'stats'; // the header's three tiles

  // - Before you can use a box, it has to be open
  // - This checks: is it already open?
  // - Already open → use it
  // - Not open → open it first
  Future<Box> _open(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
  }

  // function save
  // Monday 7:00 AM — Juan has 4 tags
  // - Server sends 4 tags
  // - save() runs
  // - Phone is empty → nothing to wipe
  // - Writes the 4 on
  // - Notes: 7:00 AM

  // Monday 2:00 PM — dispatcher gave him 20 more

  // - Server sends 24 tags
  // - save() runs
  // - Wipes the 4 that were there
  // - Writes all 24 on
  // - Notes: 2:00 PM

  // Tuesday 8:00 AM — one tag was taken off him

  // - Server sends 23 tags
  // - save() runs
  // - Wipes the 24
  // - Writes the 23 on
  // - The one taken away is gone from his phone
  // - Notes: 8:00 AM
  Future<void> save(MyTags tags) async {
    final box = await _open(_boxName);
    final meta = await _open(_metaBoxName);

    // Cleared first, and it matters: the old shape wrote a row per tag id, so
    // a phone updating from that version would otherwise keep every one of
    // them alongside the new key forever.
    await box.clear();
    await box.put(_listsKey, tags.toJson());

    await meta.put(_syncedAtKey, DateTime.now().toIso8601String());
  }

  // - Gets both lists off the phone
  // - Turns them back into tags the app can use
  // - Hands them back in the order they were saved

  // Scenario

  // - Monday 9:00 AM, no signal
  // - Juan opens the app
  // - read() runs
  // - The 24 tags come off the phone
  // - Same order as yesterday afternoon, newest batch on top
  // - Screen shows them
  Future<MyTags> read() async {
    final box = await _open(_boxName);
    final saved = box.get(_listsKey);

    if (saved is! Map) return const MyTags();

    // Handed back in the order it went in. Nothing sorts here - the order is
    // the server's answer, and re-deciding it on the way out is how the two
    // would drift apart.
    return MyTags.fromJson(Map<String, dynamic>.from(saved));
  }

  // saveStats / readStats — the header's figures, kept for the next cold open.
  //
  // In the meta box rather than beside the lists, and that is deliberate:
  // save() above clears its box before writing, so anything sharing it would
  // be wiped on every tag refresh. These two write and read independently of
  // the lists, because the two calls behind them can fail independently - a
  // phone that got its tags and not its totals should keep yesterday's
  // totals, not blank them.

  // Scenario

  // - Monday 5:00 PM — 0 assigned, 40 completed, saved
  // - Tuesday 6:30 AM, no signal — Juan opens the app
  // - readStats() hands back Monday's figures
  // - Header draws straight away, alongside "Updated 5:00 PM"
  Future<void> saveStats(MyStats stats) async {
    final meta = await _open(_metaBoxName);
    await meta.put(_statsKey, stats.toJson());
  }

  Future<MyStats> readStats() async {
    final meta = await _open(_metaBoxName);
    final saved = meta.get(_statsKey);

    if (saved is! Map) return MyStats.empty;

    return MyStats.fromJson(Map<String, dynamic>.from(saved));
  }

  // syncedAt() — what it does
  // - Looks in the small drawer for the time
  // - Hands it back
  // - Never saved anything yet → hands back nothing

  // Scenario

  // - Monday 9:00 AM, no signal
  // - Juan opens the app
  // - syncedAt() returns 7:00 AM
  // - Header shows "Updated 7:00 AM"
  // - He knows the list is from this morning, not from now
  Future<DateTime?> syncedAt() async {
    final meta = await _open(_metaBoxName);
    final saved = meta.get(_syncedAtKey);

    return saved is String ? DateTime.tryParse(saved) : null;
  }

  // clear() — what it does
  // - Empties both drawers
  // - The tags, and the time

  // Scenario

  // - Juan taps logout
  // - clear() runs
  // - His 24 tags come off the phone
  // - Pedro logs in on the same phone
  // - Sees nothing until the server answers — not Juan's tags
  Future<void> clear() async {
    await (await _open(_boxName)).clear();
    await (await _open(_metaBoxName)).clear();
  }

  // Monday 7:00 AM — office, wifi

  // - Juan logs in
  // - Server sends 4 tags
  // - save() — the 4 go onto the phone, time noted as 7:00 AM
  // - Screen shows 4 tags

  // Monday 9:00 AM — field, no signal

  // - Juan opens the app
  // - read() — the 4 come off the phone
  // - syncedAt() — returns 7:00 AM
  // - Screen: 4 tags, "Updated 7:00 AM"
  // - App tries the server, gets nothing, stays quiet

  // Monday 2:00 PM — signal comes back

  // - Juan opens the app
  // - read() — the 4 show instantly
  // - Server answers with 24 tags
  // - save() — wipes the 4, writes the 24, time noted as 2:00 PM
  // - Screen: 24 tags, "Updated 2:00 PM"

  // Monday 5:00 PM — end of shift

  // - Juan taps logout
  // - clear() — the 24 tags and the time both wiped
  // - Login screen

  // Monday 5:02 PM — Pedro borrows the phone

  // - Logs in
  // - read() — nothing there
  // - Server sends Pedro's tags
  // - save() — Pedro's tags go on
}
