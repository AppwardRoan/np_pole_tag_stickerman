import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('upload_queue_test');
    Hive.init(home.path);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  QueuedTag tag(int id, String code, {DateTime? at}) => QueuedTag(
        tagId: id,
        tagCode: code,
        record: {'tag_id': id},
        photos: [
          QueuedPhoto(
            path: '/data/$id.jpg',
            photoType: 'tag_closeup',
            takenAt: DateTime.utc(2026, 9, 9, 6),
          ),
        ],
        queuedAt: at ?? DateTime.utc(2026, 9, 9, 6),
      );

  test('an added tag can be read back', () async {
    const queue = UploadQueue();

    await queue.add(tag(41, 'M2GG0'));
    final waiting = await queue.read();

    expect(waiting.length, 1);
    expect(waiting.first.tagCode, 'M2GG0');
    expect(waiting.first.record['tag_id'], 41);
  });

  // The point of the whole feature: the battery dies and the work is still
  // there in the morning.
  test('a tag survives the box being closed and reopened', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    await Hive.close();
    Hive.init(home.path);

    expect((await queue.read()).first.tagCode, 'M2GG0');
  });

  test('read hands them back oldest first', () async {
    const queue = UploadQueue();

    await queue.add(tag(2, 'SECOND', at: DateTime.utc(2026, 9, 9, 14)));
    await queue.add(tag(1, 'FIRST', at: DateTime.utc(2026, 9, 9, 9)));
    await queue.add(tag(3, 'THIRD', at: DateTime.utc(2026, 9, 9, 16)));

    expect(
      (await queue.read()).map((tag) => tag.tagCode),
      ['FIRST', 'SECOND', 'THIRD'],
    );
  });

  test('update replaces the entry rather than adding a second one', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    final found = await queue.find(41);
    await queue.update(found!.copyWith(recordId: 907));

    final all = await queue.read();
    expect(all.length, 1);
    expect(all.first.recordId, 907);
  });

  test('remove takes it out', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));
    await queue.add(tag(42, 'M2GG1'));

    await queue.remove(41);

    expect((await queue.read()).map((tag) => tag.tagId), [42]);
  });

  test('find returns null for a tag that was never queued', () async {
    expect(await const UploadQueue().find(999), isNull);
  });

  // Submit is final, so one tag can only ever have one entry. Adding twice is
  // a bug upstream, and it must not produce two records for one pole.
  test('adding the same tag twice keeps one entry', () async {
    const queue = UploadQueue();

    await queue.add(tag(41, 'M2GG0'));
    await queue.add(tag(41, 'M2GG0'));

    expect((await queue.read()).length, 1);
  });
}
