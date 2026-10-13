import 'package:np_pole_tag_stickerman/models/tag.dart';

/// What `GET /tags/my/search` sends back.
///
/// One flat list, unlike [MyTags]. The box is not the home screen: he is
/// looking for one pole he already has in mind, and splitting four results
/// across two headings only makes him read both.
///
/// [total] is why this is a shape rather than a bare list. [tags] is capped by
/// the server, and a search of two characters against a year of work is cut
/// far more often than not. With only the surviving rows, the screen would say
/// "no such pole" about a pole sitting at number 900 - the same lie the old
/// "not one of your tags" message told. With the total beside them it can say
/// it is showing 25 of 2,800 and ask for another character, which is something
/// he can act on.
class TagSearch {
  /// The matches he can see.
  final List<Tag> tags;

  /// The matches there were before the server capped them. Equal to
  /// `tags.length` when nothing was cut, which is how [wasCut] knows.
  final int total;

  const TagSearch({this.tags = const [], this.total = 0});

  static const TagSearch empty = TagSearch();

  bool get isEmpty => tags.isEmpty;

  /// Whether the server had more than it sent.
  bool get wasCut => total > tags.length;

  factory TagSearch.fromJson(Map<String, dynamic> json) {
    final rows = json['tags'];

    final tags = rows is List
        ? rows
              .whereType<Map>()
              .map((row) => Tag.fromJson(Map<String, dynamic>.from(row)))
              .toList()
        : <Tag>[];

    // Falls back to the row count rather than to zero. A reply missing its
    // total is a reply that cannot say anything was cut, and "0 of 4" reads
    // as a bug where "4 of 4" is merely the truth as far as anyone knows.
    final total = json['total'];

    return TagSearch(tags: tags, total: total is int ? total : tags.length);
  }
}
