import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';
import 'package:np_pole_tag_stickerman/services/uploader.dart';

/// A server that answers however the test tells it to, and writes down what
/// it was asked.
class FakeApi implements PoleUploadApi {
  FakeApi({this.onRecord, this.onPhoto});

  final int Function(Map<String, dynamic> record)? onRecord;
  final void Function(int recordId, String photoType)? onPhoto;

  final List<Map<String, dynamic>> records = [];
  final List<String> photos = [];

  @override
  Future<int> createPoleRecord(Map<String, dynamic> record) async {
    records.add(record);
    return onRecord?.call(record) ?? 907;
  }

  @override
  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  }) async {
    onPhoto?.call(recordId, photoType);
    photos.add(photoType);
  }
}

void main() {
  late Directory home;
  late Directory photoFolder;
  late PhotoStore store;

  setUp(() {
    home = Directory.systemTemp.createTempSync('uploader_hive');
    photoFolder = Directory.systemTemp.createTempSync('uploader_photos');
    Hive.init(home.path);
    store = PhotoStore(photoFolder);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
    if (photoFolder.existsSync()) photoFolder.deleteSync(recursive: true);
  });

  /// A queued tag whose photo files actually exist, because the uploader
  /// deletes them on success.
  QueuedTag queued(int id, String code, {int shots = 2}) {
    final photos = <QueuedPhoto>[];

    for (var index = 0; index < shots; index++) {
      final type = ['tag_closeup', 'full_pole', 'surroundings'][index % 3];
      final file = File('${photoFolder.path}/${id}_$index.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      photos.add(QueuedPhoto(
        path: file.path,
        photoType: type,
        takenAt: DateTime.utc(2026, 9, 9, 6, index),
      ));
    }

    return QueuedTag(
      tagId: id,
      tagCode: code,
      record: {'tag_id': id},
      photos: photos,
      queuedAt: DateTime.utc(2026, 9, 9, 6),
    );
  }

  test('a waiting tag uploads and leaves the queue', () async {
    const queue = UploadQueue();
    await queue.add(queued(41, 'M2GG0'));
    final api = FakeApi();

    final result = await Uploader(api, queue, store).drain();

    expect(result.uploaded, 1);
    expect(api.records.length, 1);
    expect(api.photos, ['tag_closeup', 'full_pole']);
    expect(await queue.read(), isEmpty);
  });

  test('the photo files are deleted once the tag is up', () async {
    const queue = UploadQueue();
    final tag = queued(41, 'M2GG0');
    await queue.add(tag);

    await Uploader(FakeApi(), queue, store).drain();

    for (final photo in tag.photos) {
      expect(File(photo.path).existsSync(), isFalse);
    }
  });

  test('tags go oldest first', () async {
    const queue = UploadQueue();
    await queue.add(QueuedTag(
      tagId: 2,
      tagCode: 'LATER',
      record: {'tag_id': 2},
      photos: const [],
      queuedAt: DateTime.utc(2026, 9, 9, 15),
    ));
    await queue.add(QueuedTag(
      tagId: 1,
      tagCode: 'EARLIER',
      record: {'tag_id': 1},
      photos: const [],
      queuedAt: DateTime.utc(2026, 9, 9, 9),
    ));

    final api = FakeApi();
    await Uploader(api, queue, store).drain();

    expect(api.records.map((record) => record['tag_id']), [1, 2]);
  });

  group('no signal', () {
    test('the tag stays waiting and nothing is lost', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));

      final api = FakeApi(onRecord: (_) => throw ApiException(0, 'unreachable'));
      final result = await Uploader(api, queue, store).drain();

      expect(result.uploaded, 0);
      expect(result.stopped, isTrue);

      final still = await queue.read();
      expect(still.length, 1);
      expect(still.first.state, QueuedState.waiting);
      expect(still.first.failure, isNull);
    });

    test('the whole drain stops rather than failing every tag in turn', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));
      await queue.add(queued(42, 'M2GG1'));

      final api = FakeApi(onRecord: (_) => throw ApiException(0, 'unreachable'));
      await Uploader(api, queue, store).drain();

      expect(api.records.length, 1);
      expect((await queue.read()).length, 2);
    });

    // Half-uploaded is the case that matters: the record is filed, some
    // photos are up, and the signal goes. None of that may be repeated.
    test('a retry resumes at the photo that failed', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0', shots: 3));

      var sent = 0;
      final failing = FakeApi(onPhoto: (_, _) {
        sent++;
        if (sent == 3) throw ApiException(0, 'unreachable');
      });

      await Uploader(failing, queue, store).drain();

      final half = (await queue.read()).first;
      expect(half.recordId, 907);
      expect(half.pending.map((photo) => photo.photoType), ['surroundings']);

      final second = FakeApi();
      final result = await Uploader(second, queue, store).drain();

      expect(result.uploaded, 1);
      // The record is not posted again, and the first two photos do not go up
      // a second time.
      expect(second.records, isEmpty);
      expect(second.photos, ['surroundings']);
      expect(await queue.read(), isEmpty);
    });
  });

  group('the server says no', () {
    test('a 403 turns the tag red and keeps the reason', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));

      final api = FakeApi(
        onRecord: (_) => throw ApiException(403, 'That tag is not assigned to you'),
      );
      final result = await Uploader(api, queue, store).drain();

      expect(result.refused, 1);
      expect(result.stopped, isFalse);

      final red = (await queue.read()).first;
      expect(red.state, QueuedState.failed);
      expect(red.failure, 'That tag is not assigned to you');
    });

    test('a refused tag does not block the ones behind it', () async {
      const queue = UploadQueue();
      await queue.add(QueuedTag(
        tagId: 1,
        tagCode: 'BAD',
        record: {'tag_id': 1},
        photos: const [],
        queuedAt: DateTime.utc(2026, 9, 9, 9),
      ));
      await queue.add(QueuedTag(
        tagId: 2,
        tagCode: 'GOOD',
        record: {'tag_id': 2},
        photos: const [],
        queuedAt: DateTime.utc(2026, 9, 9, 10),
      ));

      final api = FakeApi(onRecord: (record) {
        if (record['tag_id'] == 1) throw ApiException(403, 'not yours');
        return 907;
      });

      final result = await Uploader(api, queue, store).drain();

      expect(result.uploaded, 1);
      expect(result.refused, 1);
      expect((await queue.read()).map((tag) => tag.tagCode), ['BAD']);
    });

    test('a red tag is not tried again on the next drain', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));

      await Uploader(
        FakeApi(onRecord: (_) => throw ApiException(403, 'not yours')),
        queue,
        store,
      ).drain();

      final api = FakeApi();
      final result = await Uploader(api, queue, store).drain();

      expect(api.records, isEmpty);
      expect(result.uploaded, 0);
    });

    // 409 on a photo means the server already has that shot. That is the
    // state the upload was trying to reach, so it counts as done.
    test('a 409 on a photo is treated as already uploaded', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));

      final api = FakeApi(onPhoto: (_, type) {
        if (type == 'tag_closeup') {
          throw ApiException(409, 'This pole already has a tag closeup photo');
        }
      });

      final result = await Uploader(api, queue, store).drain();

      expect(result.uploaded, 1);
      expect(await queue.read(), isEmpty);
    });

    test('a 413 on a photo turns the tag red', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));

      final api = FakeApi(
        onPhoto: (_, _) => throw ApiException(413, 'That photo is larger than 10MB'),
      );
      final result = await Uploader(api, queue, store).drain();

      expect(result.refused, 1);
      expect((await queue.read()).first.state, QueuedState.failed);
    });
  });

  group('the login expired', () {
    // A 401 is neither kind. Retrying will work once he logs in, so the tag
    // must not go red - but there is no point trying the rest right now.
    test('the drain stops and the tag stays waiting', () async {
      const queue = UploadQueue();
      await queue.add(queued(41, 'M2GG0'));
      await queue.add(queued(42, 'M2GG1'));

      final api = FakeApi(onRecord: (_) => throw ApiException(401, 'Not authenticated'));
      final result = await Uploader(api, queue, store).drain();

      expect(result.stopped, isTrue);
      expect(result.refused, 0);
      expect(api.records.length, 1);

      final still = await queue.read();
      expect(still.length, 2);
      expect(still.every((tag) => tag.state == QueuedState.waiting), isTrue);
    });
  });

  test('a 503 is temporary - the tag stays waiting', () async {
    const queue = UploadQueue();
    await queue.add(queued(41, 'M2GG0'));

    final api = FakeApi(onRecord: (_) => throw ApiException(503, 'unavailable'));
    final result = await Uploader(api, queue, store).drain();

    expect(result.stopped, isTrue);
    expect((await queue.read()).first.state, QueuedState.waiting);
  });

  test('draining an empty queue does nothing and says so', () async {
    final result = await Uploader(FakeApi(), const UploadQueue(), store).drain();

    expect(result.uploaded, 0);
    expect(result.refused, 0);
    expect(result.stopped, isFalse);
  });

  group('a photo file is gone from the phone', () {
    test('only that pole turns red, the rest still go up', () async {
      const queue = UploadQueue();
      final broken = queued(1, 'FIRST');
      File(broken.photos.first.path).deleteSync();
      await queue.add(broken);
      for (var id = 2; id <= 5; id++) {
        await queue.add(queued(id, 'T$id'));
      }
      final api = FakeApi();

      final result = await Uploader(api, queue, store).drain();

      expect(result.uploaded, 4);
      expect(result.refused, 1);
      expect(result.stopped, isFalse);

      final left = (await queue.read()).single;
      expect(left.tagId, 1);
      expect(left.state, QueuedState.failed);
      expect(left.failure, missingPhoto);
    });

    test('nothing is sent for that pole, not even the form', () async {
      const queue = UploadQueue();
      final broken = queued(1, 'FIRST');
      File(broken.photos.last.path).deleteSync();
      await queue.add(broken);
      final api = FakeApi();

      await Uploader(api, queue, store).drain();

      expect(api.records, isEmpty);
      expect(api.photos, isEmpty);
    });
  });

  group('two men on one phone', () {
    const juan = 1;
    const pedro = 2;

    QueuedTag filedBy(int? userId, int id) => QueuedTag(
          tagId: id,
          tagCode: 'T$id',
          record: {'tag_id': id},
          photos: const [],
          queuedAt: DateTime.utc(2026, 9, 9, 6, id),
          userId: userId,
        );

    test("Juan's poles are not sent while Pedro is signed in", () async {
      const queue = UploadQueue();
      await queue.add(filedBy(juan, 1));
      await queue.add(filedBy(juan, 2));
      final api = FakeApi();

      final result = await Uploader(api, queue, store).drain(userId: pedro);

      expect(result.uploaded, 0);
      expect(result.refused, 0);
      expect(api.records, isEmpty);

      final left = await queue.read();
      expect(left.length, 2);
      expect(left.every((tag) => tag.state == QueuedState.waiting), isTrue);
    });

    test('they go up once Juan signs back in', () async {
      const queue = UploadQueue();
      await queue.add(filedBy(juan, 1));
      await queue.add(filedBy(juan, 2));
      final api = FakeApi();

      await Uploader(api, queue, store).drain(userId: pedro);
      final result = await Uploader(api, queue, store).drain(userId: juan);

      expect(result.uploaded, 2);
      expect(api.records.length, 2);
      expect(await queue.read(), isEmpty);
    });

    test("Pedro's own poles still go while Juan's wait", () async {
      const queue = UploadQueue();
      await queue.add(filedBy(juan, 1));
      await queue.add(filedBy(pedro, 2));
      final api = FakeApi();

      final result = await Uploader(api, queue, store).drain(userId: pedro);

      expect(result.uploaded, 1);
      expect(api.records.single['tag_id'], 2);
      expect((await queue.read()).single.tagId, 1);
    });

    test('a pole queued before this was kept goes up under anyone', () async {
      const queue = UploadQueue();
      await queue.add(filedBy(null, 1));
      final api = FakeApi();

      final result = await Uploader(api, queue, store).drain(userId: pedro);

      expect(result.uploaded, 1);
    });

    test('who filed it survives the app closing', () async {
      const queue = UploadQueue();
      await queue.add(filedBy(juan, 1));
      await Hive.close();

      expect((await queue.read()).single.userId, juan);
    });
  });
}
