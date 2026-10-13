import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';

/// Which waiting poles still offer Replace: only those the office has not
/// heard of yet.
void main() {
  QueuedTag tag(int id, {int? recordId, QueuedState? state}) => QueuedTag(
    tagId: id,
    tagCode: 'T$id',
    record: {'tag_id': id},
    photos: const [],
    queuedAt: DateTime.utc(2026, 10, 2),
    recordId: recordId,
    state: state ?? QueuedState.waiting,
  );

  test('nothing sent yet - Replace stays open', () {
    final state = UploadState(tags: [tag(1)]);

    expect(state.sentTagIds, isEmpty);
    expect(state.waitingTagIds, {1});
  });

  test('form with the office, photos still going - Replace closes', () {
    final state = UploadState(tags: [tag(1, recordId: 907)]);

    expect(state.sentTagIds, {1});
  });

  test('a refused pole is not counted as sent', () {
    final state = UploadState(
      tags: [tag(1, recordId: 907, state: QueuedState.failed)],
    );

    expect(state.sentTagIds, isEmpty);
  });
}
