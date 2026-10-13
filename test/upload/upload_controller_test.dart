import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';
import 'package:np_pole_tag_stickerman/services/uploader.dart';

class FakeApi implements PoleUploadApi {
  FakeApi({this.fail, this.hold});

  /// Thrown instead of answering, when the test wants a failure.
  final Object Function()? fail;

  /// Not answered until the test completes it: one bar of signal.
  final Completer<void>? hold;

  int records = 0;

  @override
  Future<int> createPoleRecord(Map<String, dynamic> record) async {
    await hold?.future;

    final error = fail?.call();
    if (error != null) throw error;

    records++;
    return 907;
  }

  @override
  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  }) async {}
}

void main() {
  late Directory home;
  late Directory photos;

  setUp(() {
    home = Directory.systemTemp.createTempSync('upload_controller_hive');
    photos = Directory.systemTemp.createTempSync('upload_controller_photos');
    Hive.init(home.path);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
    if (photos.existsSync()) photos.deleteSync(recursive: true);
  });

  UploadController controller(PoleUploadApi api) {
    const queue = UploadQueue();
    // The same store the uploader writes through, not a second one pointed at
    // the same folder: `discard` deletes a queued tag's photos through the
    // controller's copy, and a test holding two would be checking that one of
    // them cleaned up after the other.
    final store = PhotoStore(photos);
    return UploadController(
      queue,
      Uploader(api, queue, store),
      store,
    );
  }

  /// What a phone with no bars produces: the server was never reached.
  Object noSignal() => ApiException(0, 'Could not reach the server.');

  QueuedTag tag(int id, String code) => QueuedTag(
        tagId: id,
        tagCode: code,
        record: {'tag_id': id},
        photos: const [],
        queuedAt: DateTime.utc(2026, 9, 9, 6),
      );

  test('submit with signal uploads it and leaves nothing waiting', () async {
    final api = FakeApi();
    final subject = controller(api);

    await subject.submit(tag(41, 'M2GG0'));
    await subject.drain();

    expect(api.records, 1);
    expect(subject.state.waiting, 0);
  });

  test('submit with no signal leaves it waiting', () async {
    final subject = controller(FakeApi(fail: noSignal));

    await subject.submit(tag(41, 'M2GG0'));
    await subject.drain();

    expect(subject.state.waiting, 1);
    expect(subject.state.queuedTagIds, {41});
  });

  test('the count is what the home screen shows', () async {
    final subject = controller(FakeApi(fail: noSignal));

    await subject.submit(tag(41, 'M2GG0'));
    await subject.submit(tag(42, 'M2GG1'));
    await subject.drain();

    expect(subject.state.waiting, 2);
  });

  test('Save does not wait for the server', () async {
    final hold = Completer<void>();
    final api = FakeApi(hold: hold);
    final subject = controller(api);

    // Would never return if submit still waited on the upload.
    await subject.submit(tag(41, 'M2GG0'));

    expect(subject.state.queuedTagIds, {41});
    expect(api.records, 0);

    hold.complete();
    await subject.drain();
    expect(api.records, 1);
  });

  test('a pole saved mid-pass still goes up in that run', () async {
    final hold = Completer<void>();
    final api = FakeApi(hold: hold);
    final subject = controller(api);

    await subject.submit(tag(41, 'M2GG0'));
    await subject.submit(tag(42, 'M2GG1'));

    hold.complete();
    await subject.drain();

    expect(api.records, 2);
    expect(subject.state.waiting, 0);
  });

  test('a later drain with signal clears them', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));
    await queue.add(tag(42, 'M2GG1'));

    final subject = controller(FakeApi());
    await subject.drain();

    expect(subject.state.waiting, 0);
  });

  test('the number uploaded is announced once, for the bar', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));
    await queue.add(tag(42, 'M2GG1'));

    final subject = controller(FakeApi());
    final announced = <int>[];
    subject.uploads.listen(announced.add);

    await subject.drain();
    await Future<void>.delayed(Duration.zero);

    expect(announced, [2]);
  });

  test('a refused pole is not announced as uploaded', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    final subject = controller(
      FakeApi(fail: () => ApiException(403, 'That tag is not assigned to you')),
    );
    final announced = <int>[];
    subject.uploads.listen(announced.add);

    await subject.drain();
    await Future<void>.delayed(Duration.zero);

    expect(announced, isEmpty);
  });

  test('a drain that uploads nothing announces nothing', () async {
    final subject = controller(FakeApi());
    final announced = <int>[];
    subject.uploads.listen(announced.add);

    await subject.drain();
    await Future<void>.delayed(Duration.zero);

    expect(announced, isEmpty);
  });

  // The triggers overlap - resuming the app while the network comes back
  // fires both - and two passes at once would send the same tag twice.
  test('two drains at once do not both run', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    final api = FakeApi();
    final subject = controller(api);

    await Future.wait([subject.drain(), subject.drain()]);

    expect(api.records, 1);
  });

  test('a refused tag is counted as red, not as waiting', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    final subject = controller(
      FakeApi(fail: () => ApiException(403, 'That tag is not assigned to you')),
    );
    await subject.drain();

    expect(subject.state.waiting, 0);
    expect(subject.state.failed.length, 1);
    expect(subject.state.failed.first.failure, 'That tag is not assigned to you');
    // Still greyed out on the list: he did the work, whatever the server says.
    expect(subject.state.queuedTagIds, {41});
  });
}
