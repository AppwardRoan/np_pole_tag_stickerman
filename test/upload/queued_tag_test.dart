import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

void main() {
  QueuedTag sample() => QueuedTag(
        tagId: 41,
        tagCode: 'M2GG0',
        record: const {
          'tag_id': 41,
          'latitude': 10.123456,
          'longitude': 123.654321,
          'gps_accuracy': 3.4,
          'pole_type_id': 2,
          'pole_condition_id': 1,
          'telco_option_id': 1,
          'streetlight_option_id': 2,
          'height_ft': 30.0,
          'height_m': 9.14,
          'remarks': 'leaning',
        },
        photos: [
          QueuedPhoto(
            path: '/data/1_tag_closeup.jpg',
            photoType: 'tag_closeup',
            takenAt: DateTime.utc(2026, 9, 9, 6, 30),
          ),
          QueuedPhoto(
            path: '/data/2_full_pole.jpg',
            photoType: 'full_pole',
            takenAt: DateTime.utc(2026, 9, 9, 6, 31),
            uploaded: true,
          ),
        ],
        queuedAt: DateTime.utc(2026, 9, 9, 6, 32),
      );

  test('survives the trip to storage and back', () {
    final original = sample();

    final restored = QueuedTag.fromJson(original.toJson());

    expect(restored.tagId, 41);
    expect(restored.tagCode, 'M2GG0');
    expect(restored.record['remarks'], 'leaning');
    expect(restored.record['latitude'], 10.123456);
    expect(restored.photos.length, 2);
    expect(restored.photos[0].photoType, 'tag_closeup');
    expect(restored.photos[0].uploaded, isFalse);
    expect(restored.photos[1].uploaded, isTrue);
  });

  // parseServerDate hands back local time, so the moment is what matters here
  // rather than which zone the DateTime is flagged as. Comparing the two
  // directly would fail on a machine that is not on UTC.
  test('the times come back as the same moment', () {
    final restored = QueuedTag.fromJson(sample().toJson());

    expect(restored.photos[0].takenAt.toUtc(), DateTime.utc(2026, 9, 9, 6, 30));
    expect(restored.photos[1].takenAt.toUtc(), DateTime.utc(2026, 9, 9, 6, 31));
    expect(restored.queuedAt.toUtc(), DateTime.utc(2026, 9, 9, 6, 32));
  });

  test('a new tag starts waiting, with no record id and no failure', () {
    final tag = sample();

    expect(tag.state, QueuedState.waiting);
    expect(tag.recordId, isNull);
    expect(tag.failure, isNull);
  });

  // The app can be killed mid-upload. 'sending' is a runtime state, so
  // anything found in it on disk was interrupted and has to go again.
  test('a tag saved mid-upload comes back as waiting', () {
    final interrupted = sample().copyWith(state: QueuedState.sending);

    final restored = QueuedTag.fromJson(interrupted.toJson());

    expect(restored.state, QueuedState.waiting);
  });

  test('a refused tag keeps its reason across a restart', () {
    final refused = sample().copyWith(
      state: QueuedState.failed,
      failure: 'That tag is not assigned to you',
    );

    final restored = QueuedTag.fromJson(refused.toJson());

    expect(restored.state, QueuedState.failed);
    expect(restored.failure, 'That tag is not assigned to you');
  });

  test('copyWith can clear the failure without touching anything else', () {
    final refused = sample().copyWith(
      state: QueuedState.failed,
      failure: 'nope',
    );

    final retried = refused.copyWith(
      state: QueuedState.waiting,
      clearFailure: true,
    );

    expect(retried.failure, isNull);
    expect(retried.tagCode, 'M2GG0');
    expect(retried.photos.length, 2);
  });

  test('remembers the record id once the record has been posted', () {
    final posted = sample().copyWith(recordId: 907);

    expect(QueuedTag.fromJson(posted.toJson()).recordId, 907);
  });

  test('pending lists only the photos still to go, in order', () {
    expect(
      sample().pending.map((photo) => photo.photoType),
      ['tag_closeup'],
    );
  });
}
