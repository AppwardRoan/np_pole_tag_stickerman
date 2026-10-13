import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

enum QueuedState { waiting, sending, failed }

/// One shot, and whether the server has it yet.
class QueuedPhoto {
  final String path;
  final String photoType;

  /// When he pressed the shutter, not when it uploaded. Sent as `taken_at`.
  final DateTime takenAt;

  final bool uploaded;

  const QueuedPhoto({
    required this.path,
    required this.photoType,
    required this.takenAt,
    this.uploaded = false,
  });

  QueuedPhoto copyWith({bool? uploaded}) {
    return QueuedPhoto(
      path: path,
      photoType: photoType,
      takenAt: takenAt,
      uploaded: uploaded ?? this.uploaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'photo_type': photoType,
      'taken_at': takenAt.toUtc().toIso8601String(),
      'uploaded': uploaded,
    };
  }

  factory QueuedPhoto.fromJson(Map<String, dynamic> json) {
    return QueuedPhoto(
      path: json['path'] as String,
      photoType: json['photo_type'] as String,
      takenAt: parseServerDate(json['taken_at']) ?? DateTime.now(),
      uploaded: json['uploaded'] == true,
    );
  }
}

class QueuedTag {
  final int tagId;
  final String tagCode;
  final Map<String, dynamic> record;
  final List<QueuedPhoto> photos;
  final int? recordId;
  final QueuedState state;
  final String? failure;

  final DateTime queuedAt;

  /// Who filed it. Only sent while he is the one signed in: under anyone
  /// else's login the server answers "not assigned to you" and the pole turns
  /// red for good. Null on poles queued before this was kept.
  final int? userId;

  const QueuedTag({
    required this.tagId,
    required this.tagCode,
    required this.record,
    required this.photos,
    required this.queuedAt,
    this.userId,
    this.recordId,
    this.state = QueuedState.waiting,
    this.failure,
  });

  List<QueuedPhoto> get pending =>
      photos.where((photo) => !photo.uploaded).toList();

  QueuedTag copyWith({
    List<QueuedPhoto>? photos,
    int? recordId,
    QueuedState? state,
    String? failure,
    bool clearFailure = false,
  }) {
    return QueuedTag(
      tagId: tagId,
      tagCode: tagCode,
      record: record,
      photos: photos ?? this.photos,
      queuedAt: queuedAt,
      userId: userId,
      recordId: recordId ?? this.recordId,
      state: state ?? this.state,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag_id': tagId,
      'tag_code': tagCode,
      'record': record,
      'photos': photos.map((photo) => photo.toJson()).toList(),
      'record_id': recordId,
      'state': state.name,
      'failure': failure,
      'queued_at': queuedAt.toUtc().toIso8601String(),
      'user_id': userId,
    };
  }

  factory QueuedTag.fromJson(Map<String, dynamic> json) {
    final saved = QueuedState.values.firstWhere(
      (state) => state.name == json['state'],
      orElse: () => QueuedState.waiting,
    );

    return QueuedTag(
      tagId: json['tag_id'] as int,
      tagCode: (json['tag_code'] as String?) ?? '',
      record: Map<String, dynamic>.from(json['record'] as Map),
      photos: ((json['photos'] as List?) ?? [])
          .whereType<Map>()
          .map((row) => QueuedPhoto.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      recordId: json['record_id'] as int?,
      // Interrupted mid-send is the same situation as never started.
      state: saved == QueuedState.sending ? QueuedState.waiting : saved,
      failure: json['failure'] as String?,
      queuedAt: parseServerDate(json['queued_at']) ?? DateTime.now(),
      userId: json['user_id'] as int?,
    );
  }
}
