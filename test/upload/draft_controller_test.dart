import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/draft_providers.dart';
import 'package:np_pole_tag_stickerman/services/draft_store.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('draft_controller_test');
    Hive.init(home.path);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  DraftTag draft(int id, String code, {int step = 1}) => DraftTag(
        tagId: id,
        tagCode: code,
        step: step,
        record: {'tag_id': id},
        photos: const [],
        savedAt: DateTime.utc(2026, 9, 9, 6),
      );

  test('starts with nothing until it loads', () {
    final subject = DraftController(const DraftStore());

    expect(subject.state.drafts, isEmpty);
    expect(subject.state.draftTagIds, isEmpty);
  });

  test('load brings back what is on the phone', () async {
    const store = DraftStore();
    await store.save(draft(41, 'M006R'));
    await store.save(draft(42, 'M006T'));

    final subject = DraftController(store);
    await subject.load();

    expect(subject.state.drafts.length, 2);
  });

  // What the tag list needs: which rows say Draft.
  test('draftTagIds is what the list marks', () async {
    const store = DraftStore();
    await store.save(draft(41, 'M006R'));

    final subject = DraftController(store);
    await subject.load();

    expect(subject.state.draftTagIds, {41});
  });

  test('saving a draft shows up straight away', () async {
    final subject = DraftController(const DraftStore());

    await subject.save(draft(41, 'M006R', step: 2));

    expect(subject.state.draftTagIds, {41});
    expect(subject.state.drafts.single.step, 2);
  });

  test('saving the same tag again replaces it rather than adding', () async {
    final subject = DraftController(const DraftStore());

    await subject.save(draft(41, 'M006R', step: 1));
    await subject.save(draft(41, 'M006R', step: 3));

    expect(subject.state.drafts.length, 1);
    expect(subject.state.drafts.single.step, 3);
  });

  test('discard removes it', () async {
    final subject = DraftController(const DraftStore());
    await subject.save(draft(41, 'M006R'));
    await subject.save(draft(42, 'M006T'));

    await subject.discard(41);

    expect(subject.state.draftTagIds, {42});
  });

  test('stepFor tells the form where to reopen', () async {
    final subject = DraftController(const DraftStore());
    await subject.save(draft(41, 'M006R', step: 2));

    expect(await subject.find(41), isNotNull);
    expect((await subject.find(41))!.step, 2);
    expect(await subject.find(999), isNull);
  });

  // Submitting hands the draft to the queue, so the draft has to go - or the
  // row would say Draft and grey-out at the same time.
  test('a submitted tag is no longer a draft', () async {
    final subject = DraftController(const DraftStore());
    final started = draft(41, 'M006R', step: 3);
    await subject.save(started);

    // What the form does on submit: build the queued tag from the draft, then
    // drop the draft.
    final queued = QueuedTag(
      tagId: started.tagId,
      tagCode: started.tagCode,
      record: started.record,
      photos: started.photos,
      queuedAt: DateTime.utc(2026, 9, 9, 7),
    );
    await subject.discard(queued.tagId);

    expect(subject.state.draftTagIds, isEmpty);
  });
}
