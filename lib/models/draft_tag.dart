import 'package:np_pole_tag_stickerman/helpers/parsing.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

/// A form he started and did not finish.
///
/// Kept apart from [QueuedTag] on purpose, even though the two overlap. A
/// queued tag means "finished, waiting to go up", and the uploader sends
/// everything it finds in that box - so a half-filled form living there would
/// file an incomplete record and mark the pole Used before he had done
/// it. Two boxes, two meanings: drafts never send, the queue always does.
///
/// [record] deliberately has the same shape as [QueuedTag.record] - the body
/// `POST /pole-records` wants, with whatever he has not answered still absent.
/// Submitting is then a handover rather than a translation.
///
/// [QueuedPhoto] is reused rather than copied: a photo is the same thing in
/// both places. Its `uploaded` flag simply stays false until the tag is
/// submitted, since a draft never uploads anything.
class DraftTag {
  final int tagId;
  final String tagCode;

  /// Which form step he stopped on, so reopening lands him there rather than
  /// at the beginning. The one field a finished tag has no use for.
  final int step;

  /// What he has answered so far. Anything untouched is absent or null - never
  /// zero or an empty string, which the server would read as an answer.
  final Map<String, dynamic> record;

  /// Already copied out of the camera's temp folder. That copy happens when
  /// the draft is saved rather than at submit, or a draft left overnight comes
  /// back with its photos gone.
  final List<QueuedPhoto> photos;

  final DateTime savedAt;

  const DraftTag({
    required this.tagId,
    required this.tagCode,
    required this.step,
    required this.record,
    required this.photos,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'tag_id': tagId,
      'tag_code': tagCode,
      'step': step,
      'record': record,
      'photos': photos.map((photo) => photo.toJson()).toList(),
      'saved_at': savedAt.toUtc().toIso8601String(),
    };
  }

  factory DraftTag.fromJson(Map<String, dynamic> json) {
    return DraftTag(
      tagId: json['tag_id'] as int,
      tagCode: (json['tag_code'] as String?) ?? '',
      step: (json['step'] as int?) ?? 0,
      record: Map<String, dynamic>.from(json['record'] as Map),
      photos: ((json['photos'] as List?) ?? [])
          .whereType<Map>()
          .map((row) => QueuedPhoto.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      savedAt: parseServerDate(json['saved_at']) ?? DateTime.now(),
    );
  }
}
