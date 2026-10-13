import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/services/draft_store.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('draft_store_test');
    Hive.init(home.path);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  DraftTag draft(
    int id,
    String code, {
    int step = 1,
    DateTime? at,
    List<QueuedPhoto> photos = const [],
  }) =>
      DraftTag(
        tagId: id,
        tagCode: code,
        step: step,
        record: {'tag_id': id, 'pole_type_id': 2},
        photos: photos,
        savedAt: at ?? DateTime.utc(2026, 9, 9, 6),
      );

  test('a saved draft can be read back', () async {
    const store = DraftStore();

    await store.save(draft(41, 'M006R'));
    final found = await store.find(41);

    expect(found, isNotNull);
    expect(found!.tagCode, 'M006R');
    expect(found.record['pole_type_id'], 2);
  });

  // The point of the feature: he walks away, the battery dies, and the form
  // is still there in the morning.
  test('a draft survives the box being closed and reopened', () async {
    const store = DraftStore();
    await store.save(draft(41, 'M006R', step: 2));

    await Hive.close();
    Hive.init(home.path);

    final found = await store.find(41);
    expect(found!.step, 2);
  });

  // He carries on filling it in, so the same tag is saved over and over. That
  // has to replace, not pile up.
  test('saving the same tag again replaces it', () async {
    const store = DraftStore();

    await store.save(draft(41, 'M006R', step: 1));
    await store.save(draft(41, 'M006R', step: 3));

    final all = await store.read();
    expect(all.length, 1);
    expect(all.first.step, 3);
  });

  test('read hands back every draft, newest first', () async {
    const store = DraftStore();

    await store.save(draft(1, 'FIRST', at: DateTime.utc(2026, 9, 9, 9)));
    await store.save(draft(3, 'NEWEST', at: DateTime.utc(2026, 9, 9, 16)));
    await store.save(draft(2, 'MIDDLE', at: DateTime.utc(2026, 9, 9, 14)));

    expect(
      (await store.read()).map((draft) => draft.tagCode),
      ['NEWEST', 'MIDDLE', 'FIRST'],
    );
  });

  test('remove takes it out', () async {
    const store = DraftStore();
    await store.save(draft(41, 'M006R'));
    await store.save(draft(42, 'M006T'));

    await store.remove(41);

    expect((await store.read()).map((draft) => draft.tagId), [42]);
  });

  test('find returns null for a tag with no draft', () async {
    expect(await const DraftStore().find(999), isNull);
  });

  test('photos taken before he walked away are kept', () async {
    const store = DraftStore();

    await store.save(draft(41, 'M006R', photos: [
      QueuedPhoto(
        path: '/data/1_tag_closeup.jpg',
        photoType: 'tag_closeup',
        takenAt: DateTime.utc(2026, 9, 9, 6, 30),
      ),
    ]));

    final found = await store.find(41);
    expect(found!.photos.single.photoType, 'tag_closeup');
  });
}
