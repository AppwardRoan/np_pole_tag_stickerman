import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

void main() {
  DraftTag sample() => DraftTag(
        tagId: 41,
        tagCode: 'M006R',
        step: 2,
        // Half a form: he reached the photos and has not typed a height or a
        // remark yet. The nulls are the point.
        record: const {
          'tag_id': 41,
          'latitude': 10.123456,
          'longitude': 123.654321,
          'gps_accuracy': 3.4,
          'pole_type_id': 2,
          'pole_condition_id': null,
          'telco_option_id': 1,
          'streetlight_option_id': 2,
          'height_ft': null,
          'height_m': null,
          'remarks': null,
        },
        photos: [
          QueuedPhoto(
            path: '/data/1_tag_closeup.jpg',
            photoType: 'tag_closeup',
            takenAt: DateTime.utc(2026, 9, 9, 6, 30),
          ),
        ],
        savedAt: DateTime.utc(2026, 9, 9, 6, 32),
      );

  test('survives the trip to storage and back', () {
    final restored = DraftTag.fromJson(sample().toJson());

    expect(restored.tagId, 41);
    expect(restored.tagCode, 'M006R');
    expect(restored.record['latitude'], 10.123456);
    expect(restored.record['pole_type_id'], 2);
  });

  // What he has not filled in has to come back missing, not as a zero or an
  // empty string - the server treats those as answers.
  test('the blanks come back blank', () {
    final restored = DraftTag.fromJson(sample().toJson());

    expect(restored.record['height_ft'], isNull);
    expect(restored.record['pole_condition_id'], isNull);
    expect(restored.record['remarks'], isNull);
  });

  test('remembers which step he stopped on', () {
    expect(DraftTag.fromJson(sample().toJson()).step, 2);
  });

  test('keeps his photos, with their types', () {
    final restored = DraftTag.fromJson(sample().toJson());

    expect(restored.photos.length, 1);
    expect(restored.photos.first.photoType, 'tag_closeup');
    expect(restored.photos.first.path, '/data/1_tag_closeup.jpg');
  });

  // parseServerDate hands back local time, so the moment is what matters
  // rather than which zone the DateTime is flagged as.
  test('the times come back as the same moment', () {
    final restored = DraftTag.fromJson(sample().toJson());

    expect(restored.savedAt.toUtc(), DateTime.utc(2026, 9, 9, 6, 32));
    expect(
      restored.photos.first.takenAt.toUtc(),
      DateTime.utc(2026, 9, 9, 6, 30),
    );
  });

  test('a draft with no photos yet is fine', () {
    final early = DraftTag(
      tagId: 42,
      tagCode: 'M006T',
      step: 0,
      record: const {'tag_id': 42},
      photos: const [],
      savedAt: DateTime.utc(2026, 9, 9, 7),
    );

    final restored = DraftTag.fromJson(early.toJson());

    expect(restored.photos, isEmpty);
    expect(restored.step, 0);
  });

  // The whole point of sharing the record's shape with QueuedTag: submitting
  // is a handover, not a translation.
  test('hands its answers and photos straight to a queued tag', () {
    final draft = sample();

    final queued = QueuedTag(
      tagId: draft.tagId,
      tagCode: draft.tagCode,
      record: draft.record,
      photos: draft.photos,
      queuedAt: DateTime.utc(2026, 9, 9, 6, 40),
    );

    expect(queued.record['latitude'], 10.123456);
    expect(queued.photos.first.photoType, 'tag_closeup');
    expect(queued.pending.length, 1);
  });
}
