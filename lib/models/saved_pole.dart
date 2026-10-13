/// What the Saved screen shows, handed straight over by the form.
///
/// Carried rather than re-read. The record has just been written to the phone
/// and may not have reached the office at all, so asking the server what was
/// saved would show him nothing in the one place he most wants to see it - a
/// dead spot is exactly when a man wants proof his work was kept.
class SavedPole {
  const SavedPole({
    required this.tagCode,
    required this.record,
    required this.photos,
    required this.queued,
    this.batchCode,
    this.sentBackFor,
  });

  final String tagCode;

  /// The body that went to the queue: the same map `POST /pole-records` takes,
  /// so nothing here is a second copy of the answers that could disagree.
  final Map<String, dynamic> record;

  /// How many shots went with it.
  final int photos;

  /// Still on the phone, waiting for signal. The difference matters to him:
  /// one means the office has it, the other means his handset is holding it and
  /// he should not wipe the app.
  final bool queued;

  final String? batchCode;

  /// Which trip this was - Redo, Re-capture, Re-pin - or null for an ordinary
  /// first capture.
  ///
  /// The screen needs it because [record] cannot say so on its own. On a
  /// partial trip the answers he was not asked for are null in it, and a
  /// screen reading the record straight printed a column of dashes under the
  /// word RECORDED - which says the pole was filed empty to a man who has just
  /// been told his work was saved. The office has those values; they were
  /// carried forward from the visit this one replaces.
  ///
  /// So the rows he was not asked about come out rather than being drawn
  /// blank. A confirmation screen reports what he did.
  final String? sentBackFor;
}
