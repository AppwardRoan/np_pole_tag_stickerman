/// The values `tags.status` can hold, spelled exactly as the API sends them.
///
/// Constants rather than a Dart enum: the API speaks these strings in both
/// directions, so there is nothing to convert. They exist because a mistyped
/// status is silent - the server matches nothing and answers with an empty
/// list rather than an error.
///
/// Mirrors `TagStatus` in the backend's `models/enums.py`.
class TagStatus {
  const TagStatus._();

  /// Never printed. Still in the pool.
  static const String available = 'Available';

  /// Printed, but still on the shelf at the office.
  static const String printed = 'Printed';

  /// The two halves of the hand-over. Neither name matches its value, and
  /// that is deliberate: the words swapped on 2026-09-17 and the names were
  /// left alone, the same as the server's own enum members. See `TagStatus` in
  /// the backend's `models/enums.py`, and `docs/status-rename.md`.
  ///
  /// The office does not read them the way the application spelled them. Paper
  /// out of the building that nobody has claimed is waiting to be received;
  /// paper a named man has admitted holding is dispatched, because it is out
  /// with him.

  /// Out of the office, and nobody has claimed his share of it.
  static const String dispatched = 'To receive';

  /// A named crew member has said he is holding his share of the envelope.
  ///
  /// Set by his own tap on the accept screen, and the only status a pole
  /// record can be filed against. [dispatched] is the dispatcher's word that
  /// the paper went out; this is the half that says somebody has what is in
  /// it.
  ///
  /// The constant was missing while the accept screen was being built, which
  /// is why a tag he had accepted drew in the unknown-status grey: nothing in
  /// the app could name the status it was in.
  static const String received = 'Dispatched';

  /// On a pole. Done.
  ///
  /// "Used", not "Installed". The server renamed it and this constant did not
  /// follow, so for a while every comparison against it was false and a
  /// finished tag read as unfinished on every screen. The name is spelled the
  /// same as the value now so the two cannot drift apart again unnoticed.
  static const String used = 'Used';

  /// Filed, and sent back. The office found something wrong with the record
  /// and the pole is going out a second time.
  ///
  /// Three words rather than one because they are three different trips, and
  /// the word decides what he is actually asked for at the pole: the whole
  /// form again, the photographs only, or the location only. The reason sits
  /// on the tag's `remarks` - what the office typed when it sent it back, and
  /// the sentence he reads before setting out.
  ///
  /// All three are reached from [used] and all three return to it. Nothing
  /// here sets them; only the office can send a pole back.

  /// The whole capture again, steps 1 to 4.
  static const String redo = 'Redo';

  /// The photographs only. He is shown the photo step and the remarks, and
  /// answers nothing else - the server keeps the rest of the record as it was.
  static const String reCapture = 'Re-capture';

  /// The location only. The map and the calibration, nothing else.
  static const String rePin = 'Re-pin';

  /// The three above, for the one question worth asking as a set: is this pole
  /// out for a second trip?
  static const List<String> rework = [rePin, reCapture, redo];

  /// Printed but never reached a pole. The code gets reprinted.
  static const String lostPrinted = 'Lost Printed';

  /// The code reads as something that cannot go on a pole in public.
  /// Withdrawn for good.
  static const String doNotUse = 'Do Not Use';
}
