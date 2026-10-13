/// The values `tag_photos.photo_type` can hold, spelled exactly as the API
/// expects them.
///
/// Constants rather than a Dart enum, matching [TagStatus]: the API speaks
/// these strings, so there is nothing to convert. A mistyped one is not silent
/// here - the endpoint has a pattern on the field and answers 422 - but it is
/// found at the pole rather than at the desk, which is worse.
///
/// Mirrors `PhotoType` in the backend's `models/enums.py`, and the CHECK
/// constraint on the column.
class PhotoType {
  const PhotoType._();

  /// The sticker itself, close enough to read the code off.
  static const String tagCloseup = 'tag_closeup';

  /// The whole pole, so its condition and attachments are visible.
  static const String fullPole = 'full_pole';

  /// What is around it - the road, the buildings - so it can be found again.
  static const String surroundings = 'surroundings';

  /// Either spare slot. The type says what the shot is *of*, and the two
  /// spares are the same shot twice, so they share one value.
  static const String extra = 'extra';

  /// What each camera slot is called on the server, in the order he shoots
  /// them. Index-aligned with `ShotsScreen.labels` - the position is the only
  /// thing tying a photo to its type, so the two lists must stay in step.
  ///
  /// Mirrors `REQUIRED_PHOTO_TYPES` in the backend for the first three; the
  /// two spares are absent there, because optional is optional.
  static const List<String> bySlot = [
    tagCloseup,
    fullPole,
    surroundings,
    extra,
    extra,
  ];
}
