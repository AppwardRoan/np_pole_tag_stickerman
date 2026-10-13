import 'package:np_pole_tag_stickerman/models/tag.dart';

/// The three lists behind the home screen, as `GET /tags/my` reports them.
///
/// The server sends them apart rather than sending one list to be filtered,
/// because the two are ordered differently and only one order can survive a
/// single list: [received] runs newest batch first and then by code, the way
/// the printed sheets sit in his hand, while [completed] runs most recently
/// filed first.
///
/// So the order of each list is the server's answer, not an accident of how it
/// arrived. Nothing here re-sorts them, and neither should anything downstream
/// - see `TagCache`, which keeps them in this order on the phone too.
///
/// Tags he has not accepted are in none of them, and are not sent at all. One of
/// those cannot be scanned and cannot carry a pole record, and accepting is a
/// batch action with a screen of its own - so a row here would be one no tab
/// draws and no tap reaches.
class MyTags {
  /// His to work: he has tapped Accept, and these are the only tags a pole
  /// record can be filed against.
  final List<Tag> received;

  /// Poles the office has sent back: Redo, Re-capture or Re-pin.
  ///
  /// A second trip to a pole he has already done, and not the same job as one
  /// he has never been to - each carries the reviewer's reason in `remarks`,
  /// and which of the three it is decides what he actually has to do there.
  ///
  /// Sent as its own list rather than mixed into [received] so the phone can
  /// draw it either way. An earlier version of this screen guessed at the
  /// same thing from whether a tag carried a remark, and that guess is what
  /// was wrong with it - a remark can mean anything. The status says it
  /// outright now.
  final List<Tag> rework;

  /// Filed. What he has finished, as far as the server knows - a pole he
  /// submitted with no signal is still under [received] here, because the
  /// server has not heard about it. The home screen is what moves it across.
  final List<Tag> completed;

  const MyTags({
    this.received = const [],
    this.rework = const [],
    this.completed = const [],
  });

  bool get isEmpty => received.isEmpty && rework.isEmpty && completed.isEmpty;

  /// Both lists end to end, for the one job that does not care which is which:
  /// finding the tag behind a code he has just scanned.
  List<Tag> get all => [...received, ...rework, ...completed];

  factory MyTags.fromJson(Map<String, dynamic> json) {
    List<Tag> read(String key) {
      final rows = json[key];
      if (rows is! List) return const [];

      return rows
          .whereType<Map>()
          .map((row) => Tag.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }

    return MyTags(
      received: read('received'),
      // Absent from a server that has not been deployed yet, which `read`
      // answers as an empty list - the same as a crew with nothing sent back,
      // and the right answer for both.
      rework: read('rework'),
      completed: read('completed'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'received': [for (final tag in received) tag.toJson()],
      'rework': [for (final tag in rework) tag.toJson()],
      'completed': [for (final tag in completed) tag.toJson()],
    };
  }
}
