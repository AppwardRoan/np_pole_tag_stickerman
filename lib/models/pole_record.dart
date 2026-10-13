import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// A record the office holds against one pole, as `GET /pole-records/tag/{id}`
/// sends it back.
///
/// The form builds its own map on the way up; this is the way down, and it is
/// the only place the app reads a record it did not just write. Nothing here is
/// cached: he reads it to check work already filed, which is a question worth
/// asking the server rather than answering from a copy that may be a week old.
class PoleRecord {
  final int recordId;
  final int tagId;
  final String? tagCode;

  /// The pole's live record, or one of its earlier attempts. A pole filed once
  /// - which is nearly all of them - has a single record and this is true.
  final bool isCurrent;

  /// The four choices, as ids. The labels live in `/form-options`, whose ids
  /// differ per utility, so they are resolved against the cached options rather
  /// than spelled here.
  final int? poleTypeId;
  final int? poleConditionId;
  final int? telcoOptionId;
  final int? streetlightOptionId;
  final int? duOwnedOptionId;

  /// Every asset type ticked, as the server sends them: `asset_type_id`,
  /// `label`, and `other_text` on the Others tick. See `describeAssetTypes`.
  final List<Map<String, dynamic>> assetTypes;

  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;

  final double? heightFt;
  final double? heightM;

  final String? remarks;
  final DateTime? createdAt;

  /// The shots filed against this record. Three are required - the tag, the
  /// whole pole, the surroundings - and any number of extras may follow, so
  /// this is a list to lay out rather than three slots to fill.
  final List<RecordPhoto> photos;

  const PoleRecord({
    required this.recordId,
    required this.tagId,
    this.tagCode,
    this.isCurrent = true,
    this.poleTypeId,
    this.poleConditionId,
    this.telcoOptionId,
    this.streetlightOptionId,
    this.duOwnedOptionId,
    this.assetTypes = const [],
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.heightFt,
    this.heightM,
    this.remarks,
    this.createdAt,
    this.photos = const [],
  });

  factory PoleRecord.fromJson(Map<String, dynamic> json) {
    return PoleRecord(
      recordId: json['record_id'],
      tagId: json['tag_id'],
      tagCode: json['tag_code'],
      isCurrent: json['is_current'] ?? true,
      poleTypeId: json['pole_type_id'],
      poleConditionId: json['pole_condition_id'],
      telcoOptionId: json['telco_option_id'],
      streetlightOptionId: json['streetlight_option_id'],
      duOwnedOptionId: json['du_owned_option_id'],
      assetTypes: json['asset_types'] is List
          ? (json['asset_types'] as List)
                .whereType<Map>()
                .map((t) => Map<String, dynamic>.from(t))
                .toList()
          : const [],
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      gpsAccuracy: _number(json['gps_accuracy']),
      heightFt: _number(json['height_ft']),
      heightM: _number(json['height_m']),
      remarks: json['remarks'],
      createdAt: parseServerDate(json['created_at']),
      photos: json['photos'] is List
          ? (json['photos'] as List)
                .whereType<Map>()
                .map((p) => RecordPhoto.fromJson(Map<String, dynamic>.from(p)))
                .toList()
          : const [],
    );
  }

  /// The columns are `Numeric` on the server, so a whole number can arrive as
  /// an int and a fraction as a double. Casting to double directly threw on the
  /// first pole somebody recorded as exactly 35 feet.
  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

}

/// One photograph on a record.
class RecordPhoto {
  final int photoId;

  /// Which shot this is: `tag_closeup`, `full_pole`, `surroundings`, or
  /// `extra`. The first three are required and appear once each; `extra` may
  /// appear any number of times.
  final String photoType;

  final String viewUrl;
  final DateTime? takenAt;

  const RecordPhoto({
    required this.photoId,
    required this.photoType,
    required this.viewUrl,
    this.takenAt,
  });

  factory RecordPhoto.fromJson(Map<String, dynamic> json) {
    return RecordPhoto(
      photoId: json['photo_id'],
      photoType: json['photo_type'] ?? 'extra',
      viewUrl: json['view_url'] ?? '',
      takenAt: parseServerDate(json['taken_at']),
    );
  }

  /// What the strip writes under the thumbnail.
  String get label => switch (photoType) {
    'tag_closeup' => 'TAG',
    'full_pole' => 'POLE',
    'surroundings' => 'AROUND',
    _ => 'EXTRA',
  };
}
