import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';

/// The form's choices kept on the phone, so a pole with no signal still has
/// something to tap.
///
/// One key, not a row each: the four lists are a dozen items that change when
/// an admin edits them and not otherwise, so they are saved and read as a
/// single blob. That is the difference from [TagCache], which keys hundreds of
/// tags by id because they change one at a time.
///
/// Only touches the phone. When to save and when to read is the provider's
/// decision.
class FormOptionsCache {
  const FormOptionsCache();

  static const String _boxName = 'form_options';
  static const String _key = 'options';

  Future<Box> _open() async {
    return Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  Future<void> save(FormOptions options) async {
    final box = await _open();
    await box.put(_key, options.toJson());
  }

  /// Null when nothing has been saved yet - a phone that has never had signal.
  /// The screen has to say so rather than show an empty form.
  Future<FormOptions?> read() async {
    final box = await _open();
    final saved = box.get(_key);

    if (saved is! Map) return null;
    return FormOptions.fromJson(Map<String, dynamic>.from(saved));
  }

  /// Wiped on logout with the tags: the ids belong to one utility, and the next
  /// man on this phone may not be in it.
  Future<void> clear() async {
    await (await _open()).clear();
  }
}
