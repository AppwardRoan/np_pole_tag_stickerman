import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';

void main() {
  late Directory folder;
  late Directory temp;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('photo_store_kept');
    temp = Directory.systemTemp.createTempSync('photo_store_camera');
  });

  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  // The compressor is a plugin and cannot run in a unit test, so the store
  // takes one. Here it is a plain copy, which is what it has to behave like.
  Future<void> justCopy(File source, File target) async {
    await target.writeAsBytes(await source.readAsBytes());
  }

  File shot(String name, String contents) {
    final file = File('${temp.path}/$name')..createSync();
    file.writeAsStringSync(contents);
    return file;
  }

  test('keep puts the photo in its own folder, not the camera temp one', () async {
    final store = PhotoStore(folder, compressor: justCopy);
    final source = shot('CAP123.jpg', 'pixels');

    final kept = await store.keep(source.path, 'tag_closeup');

    expect(kept, startsWith(folder.path));
    expect(File(kept).existsSync(), isTrue);
    expect(File(kept).readAsStringSync(), 'pixels');
  });

  test('the kept copy survives the camera temp folder being wiped', () async {
    final store = PhotoStore(folder, compressor: justCopy);
    final source = shot('CAP124.jpg', 'pixels');

    final kept = await store.keep(source.path, 'full_pole');
    temp.deleteSync(recursive: true);

    expect(File(kept).existsSync(), isTrue);
  });

  test('two photos of the same type never collide', () async {
    final store = PhotoStore(folder, compressor: justCopy);

    final first = await store.keep(shot('a.jpg', 'one').path, 'extra');
    final second = await store.keep(shot('b.jpg', 'two').path, 'extra');

    expect(first, isNot(second));
    expect(File(first).readAsStringSync(), 'one');
    expect(File(second).readAsStringSync(), 'two');
  });

  test('discard removes the files and tolerates ones already gone', () async {
    final store = PhotoStore(folder, compressor: justCopy);
    final kept = await store.keep(shot('c.jpg', 'three').path, 'surroundings');

    await store.discard([kept, '${folder.path}/never_existed.jpg']);

    expect(File(kept).existsSync(), isFalse);
  });
}
