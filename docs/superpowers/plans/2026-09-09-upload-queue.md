# Upload Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Submit writes a finished tag to the phone and it uploads by itself whenever the app has signal, so a day in the field with no bars loses nothing.

**Architecture:** Submit stops being a network call. It copies the photos somewhere permanent, writes one entry to a Hive box, and returns. A separate uploader walks that box oldest-first — posting the record, then each photo — and is kicked off by three triggers: app resume, network return, and Submit itself. Failures split two ways: the server never answered (retry later) or the server said no (stop, show red).

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), Hive CE, `http`, `connectivity_plus`, `flutter_image_compress`, `path_provider`

**Spec:** `docs/superpowers/specs/2026-09-09-upload-queue-design.md`

## Global Constraints

- **This is not a git repository.** There are no commits and nothing to revert to. Before rewriting any existing file, copy it to `<name>.bak-0909` first. Consider proposing `git init` to Roan before starting — it is not assumed here.
- **Working agreement:** do not write code until Roan says to. Explain the change first and wait for a go-ahead on *that* change.
- **Import style:** absolute package imports throughout — `package:np_pole_tag_stickerman/...`. No relative imports anywhere in `lib/`.
- **Wording is fixed by the spec.** Use these strings verbatim:
  - uploaded on submit → `Tag uploaded.`
  - queued on submit → `Tag saved. Will upload later.`
  - home counter, singular → `1 tag waiting to upload`
  - home counter, plural → `{n} tags waiting to upload`
  - drain bar, singular → `1 tag uploaded.`
  - drain bar, plural → `{n} tags uploaded.`
  - red row → `{tagCode} — could not upload. {server detail}`
- **"tag", never "pole"** in anything Juan sees. **"upload", never "send"**.
- **Photo types** are exactly `tag_closeup`, `full_pole`, `surroundings`, `extra`. Shot index 0→`tag_closeup`, 1→`full_pole`, 2→`surroundings`, 3 and 4→`extra`.
- **The backend is not modified by this plan.** Not one file under `../np-pole-tag-api`.
- **Logout must never clear the upload queue.** `home_screen.dart:44-48` clears the tag cache and form options; do not add the queue to it.
- Run `flutter analyze` and `flutter test` at the end of every task. Both must be clean before moving on.

---

## File Structure

**Create:**

| File | Responsibility |
|---|---|
| `lib/models/queued_tag.dart` | One waiting tag as data: the record body, its photos, how far it got. Knows how to become a map and back. |
| `lib/services/photo_store.dart` | Photo files on disk only. Copy out of the camera's temp folder, shrink, delete. Never touches the network or Hive. |
| `lib/services/upload_queue.dart` | The Hive box. Add, read, update, remove. Never touches the network. |
| `lib/services/pole_upload_api.dart` | The two-method interface the uploader talks to, so a fake can stand in. |
| `lib/services/uploader.dart` | The sender. Walks the queue, calls the API, decides retry-later vs permanent. No Flutter imports. |
| `lib/providers/upload_providers.dart` | Wires the above to the screens and owns the three triggers. |
| `test/upload/*_test.dart` | One test file per unit above. |

**Modify:**

| File | Change |
|---|---|
| `lib/services/api_services.dart` | Accept an injectable `http.Client`; add `createPoleRecord` and `uploadPhoto`; declare `implements PoleUploadApi`. |
| `lib/screens/tag_form_screen.dart:228-236` | Replace the "not built yet" placeholder with a real submit. |
| `lib/screens/home_screen.dart` | Counter line, grey rows for queued tags, red rows for refused ones. |
| `lib/main.dart` | A `scaffoldMessengerKey`, so the drain bar can appear from anywhere. |
| `pubspec.yaml` | Three packages. |

**Why the uploader has no Flutter imports:** it is the piece with all the branching, and it is the piece that must be tested. Keeping `package:flutter/*` out of it means its tests run as plain Dart, fast, with no widget harness.

---

## Task 1: Packages and the photo store

Photos come out of the camera in a temp folder Android clears whenever it wants space. A tag that waits overnight would come back with its photos gone. This task gives the queue somewhere permanent to put them.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/photo_store.dart`
- Test: `test/upload/photo_store_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class PhotoStore` with `PhotoStore(this._folder, {Compressor? compressor})`
  - `Future<String> keep(String tempPath, String name)` → the permanent path
  - `Future<void> discard(Iterable<String> paths)`
  - `typedef Compressor = Future<void> Function(File source, File target)`

- [ ] **Step 1: Add the packages**

In `pubspec.yaml`, under `dependencies:`, after `latlong2: ^0.10.1`:

```yaml
  connectivity_plus: ^6.1.0     # to notice the network coming back
  path_provider: ^2.1.5         # the app's own permanent folder
  flutter_image_compress: ^2.3.0  # 8MB phone photo -> ~1MB upload
```

Run: `flutter pub get`
Expected: resolves with no version conflicts. If one appears, relax the constraint rather than upgrading unrelated packages.

- [ ] **Step 2: Write the failing test**

Create `test/upload/photo_store_test.dart`:

```dart
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
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/upload/photo_store_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:np_pole_tag_stickerman/services/photo_store.dart'`

- [ ] **Step 4: Write the implementation**

Create `lib/services/photo_store.dart`:

```dart
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Shrinks [source] into [target]. Injectable because the real one is a
/// platform plugin, and a unit test has no platform to call.
typedef Compressor = Future<void> Function(File source, File target);

/// The photos of tags that have not uploaded yet.
///
/// The camera writes to a cache folder Android empties whenever it wants the
/// space, so a tag that waits overnight would come back in the morning with
/// nothing attached. Everything here exists to move the file out of there and
/// into somewhere the system will leave alone.
///
/// Files only. It never calls the server and never touches Hive.
class PhotoStore {
  PhotoStore(this._folder, {Compressor? compressor})
      : _compress = compressor ?? _shrink;

  final Directory _folder;
  final Compressor _compress;

  static const String folderName = 'pending_photos';

  /// A high-res phone shot is 4-8MB and there are up to five per tag. This is
  /// still far more than enough to read a tag code off, and it keeps a day's
  /// queue inside what a field connection can actually push.
  static const int _maxEdge = 1600;
  static const int _quality = 70;

  /// The real store, rooted in the app's documents folder. Not called in
  /// tests - they construct [PhotoStore] with a temp directory directly.
  static Future<PhotoStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/$folderName');

    if (!await folder.exists()) await folder.create(recursive: true);

    return PhotoStore(folder);
  }

  /// Copies the shot at [tempPath] somewhere permanent, shrinking it on the
  /// way, and returns where it went.
  ///
  /// [name] is only for the filename, so a folder full of waiting photos can
  /// be read by a human. The clock makes it unique: he can shoot two 'extra'
  /// photos of the same pole, and the second must not overwrite the first.
  Future<String> keep(String tempPath, String name) async {
    if (!await _folder.exists()) await _folder.create(recursive: true);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = File('${_folder.path}/${stamp}_$name.jpg');

    await _compress(File(tempPath), target);

    return target.path;
  }

  /// Deletes photos whose tag has uploaded. A missing file is not a problem
  /// worth reporting - it is already in the state this is trying to reach.
  Future<void> discard(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A photo that will not delete is wasted space, not a failed upload.
        // Losing the tag over it would be the worse outcome.
      }
    }
  }

  static Future<void> _shrink(File source, File target) async {
    final shrunk = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      target.absolute.path,
      minWidth: _maxEdge,
      minHeight: _maxEdge,
      quality: _quality,
    );

    // Some phones refuse a format the plugin cannot re-encode. A full-size
    // photo that uploads beats no photo at all.
    if (shrunk == null) {
      await target.writeAsBytes(await source.readAsBytes());
    }
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/upload/photo_store_test.dart`
Expected: PASS, 4 tests

- [ ] **Step 6: Checkpoint**

Run: `flutter analyze`
Expected: `No issues found!`

---

## Task 2: The QueuedTag model

One waiting tag as plain data. It has to survive being written to Hive and read back, because that round trip is the whole point — it is what makes a submitted tag outlive the battery dying.

**Files:**
- Create: `lib/models/queued_tag.dart`
- Test: `test/upload/queued_tag_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum QueuedState { waiting, sending, failed }`
  - `class QueuedPhoto` — `path`, `photoType`, `takenAt`, `uploaded`; `toJson()`, `QueuedPhoto.fromJson(Map)`, `copyWith({bool? uploaded})`
  - `class QueuedTag` — `tagId`, `tagCode`, `record`, `photos`, `recordId`, `state`, `failure`, `queuedAt`; `toJson()`, `QueuedTag.fromJson(Map)`, `copyWith(...)`

- [ ] **Step 1: Write the failing test**

Create `test/upload/queued_tag_test.dart`:

```dart
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
    expect(restored.photos[1].takenAt, DateTime.utc(2026, 9, 9, 6, 31));
    expect(restored.queuedAt, DateTime.utc(2026, 9, 9, 6, 32));
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/upload/queued_tag_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/models/queued_tag.dart`:

```dart
import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// Where a waiting tag is in its journey to the server.
///
/// [sending] is a runtime state only. It is written to disk the way anything
/// else is, but [QueuedTag.fromJson] reads it back as [waiting]: a tag found
/// mid-send was interrupted by the app closing, and interrupted means it still
/// has to go.
enum QueuedState { waiting, sending, failed }

/// One shot, and whether the server has it yet.
class QueuedPhoto {
  final String path;

  /// `tag_closeup`, `full_pole`, `surroundings` or `extra` - the four the
  /// backend's CHECK constraint accepts.
  final String photoType;

  /// When he pressed the shutter, not when it uploaded. Sent as `taken_at`.
  final DateTime takenAt;

  final bool uploaded;

  const QueuedPhoto({
    required this.path,
    required this.photoType,
    required this.takenAt,
    this.uploaded = false,
  });

  QueuedPhoto copyWith({bool? uploaded}) {
    return QueuedPhoto(
      path: path,
      photoType: photoType,
      takenAt: takenAt,
      uploaded: uploaded ?? this.uploaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'photo_type': photoType,
      'taken_at': takenAt.toUtc().toIso8601String(),
      'uploaded': uploaded,
    };
  }

  factory QueuedPhoto.fromJson(Map<String, dynamic> json) {
    return QueuedPhoto(
      path: json['path'] as String,
      photoType: json['photo_type'] as String,
      takenAt: parseServerDate(json['taken_at']) ?? DateTime.now(),
      uploaded: json['uploaded'] == true,
    );
  }
}

/// A finished tag sitting on the phone, waiting for signal.
///
/// [record] is the `POST /pole-records` body already built, rather than the
/// fields spread out here. The form knows how to fill that in and the server
/// knows how to read it; repeating every column in this class would give two
/// places to keep in step for no gain.
class QueuedTag {
  final int tagId;

  /// Only so the home screen can name it in a red row without loading the tag.
  final String tagCode;

  final Map<String, dynamic> record;
  final List<QueuedPhoto> photos;

  /// Set once the record has been accepted. Its presence is what stops a retry
  /// posting the record a second time.
  final int? recordId;

  final QueuedState state;

  /// The server's own `detail` text, for a red row. Null unless [state] is
  /// [QueuedState.failed].
  final String? failure;

  final DateTime queuedAt;

  const QueuedTag({
    required this.tagId,
    required this.tagCode,
    required this.record,
    required this.photos,
    required this.queuedAt,
    this.recordId,
    this.state = QueuedState.waiting,
    this.failure,
  });

  /// The photos the server does not have yet, in the order he shot them.
  List<QueuedPhoto> get pending =>
      photos.where((photo) => !photo.uploaded).toList();

  QueuedTag copyWith({
    List<QueuedPhoto>? photos,
    int? recordId,
    QueuedState? state,
    String? failure,
    bool clearFailure = false,
  }) {
    return QueuedTag(
      tagId: tagId,
      tagCode: tagCode,
      record: record,
      photos: photos ?? this.photos,
      queuedAt: queuedAt,
      recordId: recordId ?? this.recordId,
      state: state ?? this.state,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag_id': tagId,
      'tag_code': tagCode,
      'record': record,
      'photos': photos.map((photo) => photo.toJson()).toList(),
      'record_id': recordId,
      'state': state.name,
      'failure': failure,
      'queued_at': queuedAt.toUtc().toIso8601String(),
    };
  }

  factory QueuedTag.fromJson(Map<String, dynamic> json) {
    final saved = QueuedState.values.firstWhere(
      (state) => state.name == json['state'],
      orElse: () => QueuedState.waiting,
    );

    return QueuedTag(
      tagId: json['tag_id'] as int,
      tagCode: (json['tag_code'] as String?) ?? '',
      record: Map<String, dynamic>.from(json['record'] as Map),
      photos: ((json['photos'] as List?) ?? [])
          .whereType<Map>()
          .map((row) => QueuedPhoto.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      recordId: json['record_id'] as int?,
      // Interrupted mid-send is the same situation as never started.
      state: saved == QueuedState.sending ? QueuedState.waiting : saved,
      failure: json['failure'] as String?,
      queuedAt: parseServerDate(json['queued_at']) ?? DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/upload/queued_tag_test.dart`
Expected: PASS, 7 tests

If `parseServerDate` does not return `DateTime?`, open `lib/helpers/parsing.dart` and match its actual signature rather than changing it — `tag.dart` depends on it.

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

---

## Task 3: The upload queue

The Hive box. Add, read, update, remove — and nothing else. It never calls the server, exactly as `TagCache` never does.

**Files:**
- Create: `lib/services/upload_queue.dart`
- Test: `test/upload/upload_queue_test.dart`

**Interfaces:**
- Consumes: `QueuedTag` (Task 2)
- Produces:
  - `class UploadQueue` — `const UploadQueue()`
  - `Future<void> add(QueuedTag tag)`
  - `Future<List<QueuedTag>> read()` — oldest first
  - `Future<QueuedTag?> find(int tagId)`
  - `Future<void> update(QueuedTag tag)`
  - `Future<void> remove(int tagId)`
  - `static const String boxName = 'upload_queue'`

- [ ] **Step 1: Write the failing test**

Create `test/upload/upload_queue_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/upload/upload_queue_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/services/upload_queue.dart`:

```dart
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';

/// The tags that have been submitted but not uploaded.
///
/// Stores each one as the plain map [QueuedTag.toJson] already produces, keyed
/// by tag id, the way [TagCache] stores tags. No generated adapter: the model
/// turns itself into data and back.
///
/// Keyed by tag id on purpose. Submit is final and the backend allows one
/// record per pole, so a second entry for the same tag is never correct - and
/// keying it this way makes that impossible rather than merely unlikely.
///
/// Only touches the phone. It never calls the server, and it is never cleared
/// on logout: a signed-out Juan still has a day's work sitting here.
class UploadQueue {
  const UploadQueue();

  static const String boxName = 'upload_queue';

  Future<Box> _open() async {
    return Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);
  }

  Future<void> add(QueuedTag tag) async {
    final box = await _open();
    await box.put(tag.tagId, tag.toJson());
  }

  /// Everything waiting, oldest first - which is the order the uploader sends
  /// them in, so the tag he has been carrying longest goes first.
  Future<List<QueuedTag>> read() async {
    final box = await _open();

    final tags = box.values
        .whereType<Map>()
        .map((row) => QueuedTag.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    tags.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return tags;
  }

  Future<QueuedTag?> find(int tagId) async {
    final box = await _open();
    final row = box.get(tagId);

    return row is Map ? QueuedTag.fromJson(Map<String, dynamic>.from(row)) : null;
  }

  /// Same key, so this overwrites rather than appends.
  Future<void> update(QueuedTag tag) async {
    final box = await _open();
    await box.put(tag.tagId, tag.toJson());
  }

  Future<void> remove(int tagId) async {
    final box = await _open();
    await box.delete(tagId);
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/upload/upload_queue_test.dart`
Expected: PASS, 7 tests

If `package:hive_ce/hive.dart` is not the right import for `Hive.init` outside Flutter, check what `hive_ce_flutter` re-exports and use that — `tag_cache.dart` imports `package:hive_ce_flutter/hive_flutter.dart`, but `initFlutter` needs a Flutter binding that a plain unit test does not have, which is why the test uses `Hive.init` with a temp path.

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

---

## Task 4: The two API calls

`ApiService` currently calls `http.post` as a top-level function, which nothing can stand in for. This task makes the client injectable and adds the two endpoints.

**Files:**
- Create: `lib/services/pole_upload_api.dart`
- Modify: `lib/services/api_services.dart` (back it up first)
- Test: `test/upload/api_services_upload_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `abstract interface class PoleUploadApi` with:
    - `Future<int> createPoleRecord(Map<String, dynamic> record)` → the `record_id`
    - `Future<void> uploadPhoto({required int recordId, required String path, required String photoType, required DateTime takenAt})`
  - `ApiService implements PoleUploadApi`
  - `ApiService({http.Client? client})`

- [ ] **Step 1: Back up the file**

Run: `cp lib/services/api_services.dart lib/services/api_services.dart.bak-0909`
Expected: the copy exists. This repo has no git; that backup is the only way back.

- [ ] **Step 2: Write the failing test**

Create `test/upload/api_services_upload_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

void main() {
  late File photo;

  setUp(() {
    photo = File('${Directory.systemTemp.path}/upload_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    if (photo.existsSync()) photo.deleteSync();
  });

  group('createPoleRecord', () {
    test('posts the record and returns the new record id', () async {
      late http.Request seen;

      final api = ApiService(client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'record_id': 907, 'tag_id': 41}),
          201,
        );
      }))
        ..setToken('token-abc');

      final id = await api.createPoleRecord({'tag_id': 41, 'remarks': 'leaning'});

      expect(id, 907);
      expect(seen.method, 'POST');
      expect(seen.url.path, endsWith('/pole-records'));
      expect(seen.headers['Authorization'], 'Bearer token-abc');
      expect(jsonDecode(seen.body)['remarks'], 'leaning');
    });

    // The backend answers 200 with the record that already exists rather than
    // erroring, so a reply lost on a flaky connection cannot make a duplicate.
    test('accepts the 200 that means the record was already filed', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(jsonEncode({'record_id': 907}), 200);
      }));

      expect(await api.createPoleRecord({'tag_id': 41}), 907);
    });

    test('a refusal comes back as ApiException carrying the server wording', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(
          jsonEncode({'detail': 'That tag is not assigned to you'}),
          403,
        );
      }));

      expect(
        () => api.createPoleRecord({'tag_id': 41}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message',
                'That tag is not assigned to you')),
      );
    });

    test('an unreachable server comes back as status 0', () async {
      final api = ApiService(client: MockClient((_) async {
        throw const SocketException('no route to host');
      }));

      expect(
        () => api.createPoleRecord({'tag_id': 41}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
      );
    });
  });

  group('uploadPhoto', () {
    test('sends the file as multipart with its type and time', () async {
      late http.BaseRequest seen;
      late String body;

      final api = ApiService(client: MockClient((request) async {
        seen = request;
        body = request.body;
        return http.Response(jsonEncode({'photo_id': 3}), 201);
      }))
        ..setToken('token-abc');

      await api.uploadPhoto(
        recordId: 907,
        path: photo.path,
        photoType: 'tag_closeup',
        takenAt: DateTime.utc(2026, 9, 9, 6, 30),
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, endsWith('/pole-records/907/photos'));
      expect(seen.headers['Authorization'], 'Bearer token-abc');
      // Multipart, not JSON: sending application/json here makes FastAPI
      // reject the form fields with a 422.
      expect(seen.headers['Content-Type'], contains('multipart/form-data'));
      expect(body, contains('tag_closeup'));
      expect(body, contains('2026-09-09T06:30:00'));
    });

    test('a refusal comes back as ApiException', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(
          jsonEncode({'detail': 'This pole already has a tag closeup photo'}),
          409,
        );
      }));

      expect(
        () => api.uploadPhoto(
          recordId: 907,
          path: photo.path,
          photoType: 'tag_closeup',
          takenAt: DateTime.utc(2026, 9, 9, 6, 30),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/upload/api_services_upload_test.dart`
Expected: FAIL — `ApiService` has no named parameter `client`, and no `createPoleRecord`

- [ ] **Step 4: Add the interface**

Create `lib/services/pole_upload_api.dart`:

```dart
/// The two calls the uploader needs, and nothing else.
///
/// It exists so [Uploader] can be handed a fake in a test. Depending on the
/// whole of `ApiService` would mean a fake that implements login, `/me`, the
/// tag list and the form options as well - four methods of noise for a class
/// that only ever files records and pushes photos.
abstract interface class PoleUploadApi {
  /// `POST /pole-records`. Returns the new `record_id`.
  ///
  /// A 200 rather than a 201 means the record was already filed; the id comes
  /// back either way, so the caller does not need to tell them apart.
  Future<int> createPoleRecord(Map<String, dynamic> record);

  /// `POST /pole-records/{recordId}/photos`, one photo per call.
  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  });
}
```

- [ ] **Step 5: Make the client injectable**

In `lib/services/api_services.dart`:

Add to the imports:

```dart
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';
```

Change the class declaration and add a constructor. Replace:

```dart
class ApiService {
```

with:

```dart
class ApiService implements PoleUploadApi {
  /// The client is injectable for one reason: a test can hand in a fake and
  /// assert on what went out. Every caller in the app uses the default.
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
```

Then replace every top-level `http.post(` and `http.get(` inside the existing methods with `_client.post(` and `_client.get(`. There are four: in `login`, `getMe`, `getMyTags`, `getFormOptions`.

- [ ] **Step 6: Add the two methods**

Append inside `ApiService`, before the closing brace:

```dart
  // Part 8 — createPoleRecord
  //
  // - POST /pole-records. The body is the map the form already built.
  // - 201 is a new record. 200 means one was already filed for this pole -
  //   the server hands back the existing one rather than erroring, which is
  //   what makes retrying an upload whose reply was lost safe.
  // - Returns the record id, because every photo has to be posted under it.
  @override
  Future<int> createPoleRecord(Map<String, dynamic> record) async {
    final response = await _send(() => _client.post(
      Uri.parse('$baseUrl/pole-records'),
      headers: _authHeaders,
      body: jsonEncode(record),
    ));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final id = decoded['record_id'];

      if (id is! int) {
        throw ApiException(
          response.statusCode,
          'The server saved the tag but did not say which record it is.',
        );
      }

      return id;
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not upload the tag: ${response.statusCode}',
    );
  }

  // Part 9 — uploadPhoto
  //
  // - POST /pole-records/{id}/photos, one photo per call.
  // - Multipart, not JSON: the endpoint takes an UploadFile and two Form
  //   fields. _authHeaders cannot be used whole here - it sets
  //   Content-Type: application/json, and that makes FastAPI reject the form
  //   with a 422. Only the Authorization header carries over.
  // - taken_at is when he pressed the shutter, which with no signal is hours
  //   before this call happens.
  @override
  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  }) async {
    final response = await _send(() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/pole-records/$recordId/photos'),
      );

      final token = _token;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['photo_type'] = photoType;
      request.fields['taken_at'] = takenAt.toUtc().toIso8601String();
      request.files.add(await http.MultipartFile.fromPath('file', path));

      return http.Response.fromStream(await _client.send(request));
    });

    if (response.statusCode == 201) return;

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not upload a photo: ${response.statusCode}',
    );
  }
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/upload/api_services_upload_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 8: Check nothing else broke**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass. The four existing call sites now use `_client` and must still compile.

---

## Task 5: The uploader

All the branching lives here: which failures retry and which are final, and where a half-finished tag picks up. It imports no Flutter, so its tests are plain and fast.

**Files:**
- Create: `lib/services/uploader.dart`
- Test: `test/upload/uploader_test.dart`

**Interfaces:**
- Consumes: `QueuedTag`, `QueuedState`, `QueuedPhoto` (Task 2); `UploadQueue` (Task 3); `PoleUploadApi` (Task 4); `PhotoStore` (Task 1)
- Produces:
  - `class UploadResult` — `final int uploaded; final int refused; final bool stopped;`
  - `class Uploader` — `Uploader(this._api, this._queue, this._photos)`
  - `Future<UploadResult> drain()`

- [ ] **Step 1: Write the failing test**

Create `test/upload/uploader_test.dart`:

```dart
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
  /// deletes them on success and http would read them for real.
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

  test('a 500 is temporary - the tag stays waiting', () async {
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
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/upload/uploader_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../uploader.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/services/uploader.dart`:

```dart
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';

/// What one pass over the queue managed.
///
/// [stopped] means it gave up part-way rather than reaching the end - no
/// signal, or the login expired. Nothing is wrong with the tags; there is just
/// no point trying the rest this second.
class UploadResult {
  final int uploaded;
  final int refused;
  final bool stopped;

  const UploadResult({
    this.uploaded = 0,
    this.refused = 0,
    this.stopped = false,
  });
}

/// Pushes waiting tags to the server.
///
/// Deliberately free of Flutter imports: this is where every decision about
/// failure lives, so it is the part that has to be easy to test.
class Uploader {
  Uploader(this._api, this._queue, this._photos);

  final PoleUploadApi _api;
  final UploadQueue _queue;
  final PhotoStore _photos;

  /// Sends what is waiting, oldest first, one tag at a time.
  ///
  /// One at a time rather than all at once: it is gentler on the weak
  /// connection this is most likely to run over, and it means a failure has
  /// exactly one tag to attribute itself to.
  Future<UploadResult> drain() async {
    var uploaded = 0;
    var refused = 0;

    for (final tag in await _queue.read()) {
      // Red tags are done being tried. Retrying gets the same answer.
      if (tag.state == QueuedState.failed) continue;

      final outcome = await _upload(tag);

      switch (outcome) {
        case _Outcome.uploaded:
          uploaded++;
        case _Outcome.refused:
          refused++;
        case _Outcome.tryLater:
          // The server was never reached, or the login is dead. Both mean the
          // rest of the queue would fail the same way, so stop rather than
          // walking the whole list to learn it once per tag.
          return UploadResult(uploaded: uploaded, refused: refused, stopped: true);
      }
    }

    return UploadResult(uploaded: uploaded, refused: refused);
  }

  Future<_Outcome> _upload(QueuedTag tag) async {
    var current = tag;

    // The record first: photos are posted under its id, so there is nowhere to
    // put them until it exists. Skipped when a previous pass already filed it.
    if (current.recordId == null) {
      try {
        final recordId = await _api.createPoleRecord(current.record);
        current = current.copyWith(recordId: recordId);
        await _queue.update(current);
      } on ApiException catch (error) {
        return _handle(current, error);
      }
    }

    // Each photo separately, marking them off as they land. A tag that dies
    // after photo 3 of 5 resumes at photo 3 on the next pass.
    for (final photo in current.pending) {
      try {
        await _api.uploadPhoto(
          recordId: current.recordId!,
          path: photo.path,
          photoType: photo.photoType,
          takenAt: photo.takenAt,
        );
      } on ApiException catch (error) {
        // 409 means the server already has this shot - which is the state
        // this call was trying to produce. Nothing is wrong.
        if (error.statusCode != 409) return _handle(current, error);
      }

      current = current.copyWith(
        photos: [
          for (final each in current.photos)
            each.path == photo.path ? each.copyWith(uploaded: true) : each,
        ],
      );

      await _queue.update(current);
    }

    // Everything is on the server. The copies on the phone are now just
    // occupying space he needs for tomorrow.
    await _photos.discard(current.photos.map((photo) => photo.path));
    await _queue.remove(current.tagId);

    return _Outcome.uploaded;
  }

  /// Which kind of failure this was, and leave the tag in the matching state.
  Future<_Outcome> _handle(QueuedTag tag, ApiException error) async {
    if (_isPermanent(error.statusCode)) {
      await _queue.update(tag.copyWith(
        state: QueuedState.failed,
        failure: error.message,
      ));

      return _Outcome.refused;
    }

    // Left exactly as it was: waiting, with whatever progress it made.
    await _queue.update(tag.copyWith(state: QueuedState.waiting));

    return _Outcome.tryLater;
  }

  /// Whether trying this again could ever produce a different answer.
  ///
  /// 401 is deliberately absent. The login expired, which a fresh login fixes -
  /// turning the tag red over it would throw away a day's work because a token
  /// aged out. [drain] stops on it instead.
  ///
  /// 0 is the app's own code for "never reached the server" (see `_send` in
  /// ApiService), and 5xx is the server having a bad minute. Both retry.
  static bool _isPermanent(int status) {
    const refusals = {400, 403, 404, 409, 413, 422};

    return refusals.contains(status);
  }
}

enum _Outcome { uploaded, refused, tryLater }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/upload/uploader_test.dart`
Expected: PASS, 14 tests

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

---

## Task 6: Providers and the three triggers

Wires the uploader to the app and decides when it runs: on resume, when the network returns, and after a Submit.

**Files:**
- Create: `lib/providers/upload_providers.dart`
- Test: `test/upload/upload_controller_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-5
- Produces:
  - `class UploadState` — `final List<QueuedTag> tags; final bool draining;` plus `int get waiting`, `List<QueuedTag> get failed`, `Set<int> get queuedTagIds`
  - `class UploadController extends StateNotifier<UploadState>` — `Future<void> submit(QueuedTag tag)`, `Future<void> drain()`, `Stream<int> get uploads`
  - `final uploadQueueProvider`, `photoStoreProvider`, `uploadProvider`

- [ ] **Step 1: Write the failing test**

Create `test/upload/upload_controller_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';
import 'package:np_pole_tag_stickerman/services/uploader.dart';

class FakeApi implements PoleUploadApi {
  FakeApi({this.fail});

  final Object? Function()? fail;
  int records = 0;

  @override
  Future<int> createPoleRecord(Map<String, dynamic> record) async {
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
    return UploadController(
      queue,
      Uploader(api, queue, PhotoStore(photos)),
    );
  }

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

    expect(api.records, 1);
    expect(subject.state.waiting, 0);
  });

  test('submit with no signal leaves it waiting', () async {
    final subject = controller(FakeApi(fail: () => ApiExceptionStub()));

    await subject.submit(tag(41, 'M2GG0'));

    expect(subject.state.waiting, 1);
    expect(subject.state.queuedTagIds, {41});
  });

  test('the count is what the home screen shows', () async {
    final subject = controller(FakeApi(fail: () => ApiExceptionStub()));

    await subject.submit(tag(41, 'M2GG0'));
    await subject.submit(tag(42, 'M2GG1'));

    expect(subject.state.waiting, 2);
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

  test('a drain that uploads nothing announces nothing', () async {
    final subject = controller(FakeApi());
    final announced = <int>[];
    subject.uploads.listen(announced.add);

    await subject.drain();
    await Future<void>.delayed(Duration.zero);

    expect(announced, isEmpty);
  });

  test('two drains at once do not both run', () async {
    const queue = UploadQueue();
    await queue.add(tag(41, 'M2GG0'));

    final api = FakeApi();
    final subject = controller(api);

    await Future.wait([subject.drain(), subject.drain()]);

    expect(api.records, 1);
  });
}

/// Stands in for a no-signal failure without importing the real exception,
/// which needs a status code the fake has no opinion about.
class ApiExceptionStub implements Exception {}
```

Note: `ApiExceptionStub` will surface as a non-`ApiException` throw. The controller must not let that crash a submit — see Step 3's `catch (_)`.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/upload/upload_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../upload_providers.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/providers/upload_providers.dart`:

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/photo_store.dart';
import 'package:np_pole_tag_stickerman/services/upload_queue.dart';
import 'package:np_pole_tag_stickerman/services/uploader.dart';

/// What is waiting, and whether a pass is running right now.
class UploadState {
  final List<QueuedTag> tags;
  final bool draining;

  const UploadState({this.tags = const [], this.draining = false});

  /// The number on the home screen. Red ones are not waiting for anything -
  /// they are waiting for a person.
  int get waiting =>
      tags.where((tag) => tag.state != QueuedState.failed).length;

  List<QueuedTag> get failed =>
      tags.where((tag) => tag.state == QueuedState.failed).toList();

  /// What the tag list greys out. A tag in here is one he has finished, even
  /// though the server has not heard about it yet.
  Set<int> get queuedTagIds => tags.map((tag) => tag.tagId).toSet();

  UploadState copyWith({List<QueuedTag>? tags, bool? draining}) {
    return UploadState(
      tags: tags ?? this.tags,
      draining: draining ?? this.draining,
    );
  }
}

/// Owns the queue's state and decides when the uploader runs.
class UploadController extends StateNotifier<UploadState> {
  UploadController(this._queue, this._uploader) : super(const UploadState());

  final UploadQueue _queue;
  final Uploader _uploader;

  final _uploads = StreamController<int>.broadcast();

  /// How many just went up. The app shell listens and shows the bar, so he is
  /// told wherever he happens to be standing in the app.
  Stream<int> get uploads => _uploads.stream;

  Future<void> load() async {
    state = state.copyWith(tags: await _queue.read());
  }

  /// Submit. Writes the tag to the phone, then tries immediately.
  ///
  /// The write comes first and is not conditional on anything: with signal the
  /// tag is gone a second later, and without it, it is still here tomorrow.
  Future<void> submit(QueuedTag tag) async {
    await _queue.add(tag);
    await load();

    await drain();
  }

  /// One pass over the queue.
  ///
  /// Re-entrant calls are dropped rather than queued: the triggers overlap -
  /// resuming the app while the network comes back fires both - and two
  /// passes at once would upload the same tag twice.
  Future<void> drain() async {
    if (state.draining) return;

    state = state.copyWith(draining: true);

    try {
      final result = await _uploader.drain();

      if (result.uploaded > 0 && !_uploads.isClosed) {
        _uploads.add(result.uploaded);
      }
    } catch (_) {
      // A drain that blows up must not take the app with it. The tags are
      // untouched on the phone, and the next trigger will try again.
    } finally {
      state = state.copyWith(tags: await _queue.read(), draining: false);
    }
  }

  @override
  void dispose() {
    _uploads.close();
    super.dispose();
  }
}

/// Watches for the app coming back and for the network returning, and drains
/// on either. Created once, by the app shell.
class UploadTriggers with WidgetsBindingObserver {
  UploadTriggers(this._controller);

  final UploadController _controller;
  StreamSubscription<List<ConnectivityResult>>? _network;

  void start() {
    WidgetsBinding.instance.addObserver(this);

    _network = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((result) => result != ConnectivityResult.none);
      if (connected) _controller.drain();
    });

    // The app opening is itself a trigger.
    _controller.load().then((_) => _controller.drain());
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _network?.cancel();
    _network = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.drain();
  }
}

final uploadQueueProvider = Provider<UploadQueue>((ref) => const UploadQueue());

/// Async because the documents folder has to be asked for. Everything that
/// needs it is already behind a `Future`.
final photoStoreProvider = FutureProvider<PhotoStore>((ref) => PhotoStore.open());

final uploadProvider =
    StateNotifierProvider<UploadController, UploadState>((ref) {
  final queue = ref.read(uploadQueueProvider);
  final photos = ref.read(photoStoreProvider).valueOrNull;

  return UploadController(
    queue,
    Uploader(
      ref.read(apiProvider),
      queue,
      // Until the folder is ready there is nothing queued to clean up anyway;
      // the first real drain happens after the app shell has awaited it.
      photos ?? PhotoStore(Directory.systemTemp),
    ),
  );
});
```

Add at the top of the file, with the other imports:

```dart
import 'dart:io' show Directory;
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/upload/upload_controller_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

---

## Task 7: Wire Submit

Replaces the placeholder. This is the task that makes the feature real for Juan.

**Files:**
- Modify: `lib/screens/tag_form_screen.dart` (back it up first) — lines 228-236, plus a helper
- Modify: `lib/main.dart` (back it up first) — the messenger key and the triggers
- Test: manual, in the app

**Interfaces:**
- Consumes: `UploadController.submit`, `PhotoStore.keep`, `QueuedTag`, `QueuedPhoto`
- Produces: nothing further tasks depend on

- [ ] **Step 1: Back up both files**

Run:

```bash
cp lib/screens/tag_form_screen.dart lib/screens/tag_form_screen.dart.bak-0909
cp lib/main.dart lib/main.dart.bak-0909
```

- [ ] **Step 2: Add the shot-to-type mapping**

In `lib/screens/shots_screen.dart`, inside `ShotsScreen`, below `static const int required = 3;`:

```dart
  /// What each slot is called on the server. Both spares are `extra`: the type
  /// says what the shot is *of*, and the two spares are the same shot twice.
  /// Same order as [labels], because the index is the only thing linking them.
  static const List<String> photoTypes = [
    'tag_closeup',
    'full_pole',
    'surroundings',
    'extra',
    'extra',
  ];
```

- [ ] **Step 3: Replace the placeholder**

In `lib/screens/tag_form_screen.dart`, change `_next`'s signature to async and swap the final block. Replace:

```dart
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Everything is filled in. Sending is not built yet.')),
    );
  }
```

with:

```dart
    await _submit();
  }

  /// Hands the finished tag to the queue and leaves.
  ///
  /// Deliberately does not wait on the server. The photos are copied somewhere
  /// permanent, the tag is written to the phone, and he is back on the list -
  /// with signal that all happens in about a second, and without it, it happens
  /// anyway.
  Future<void> _submit() async {
    final tag = widget.tag;
    if (tag == null || _submitting) return;

    setState(() => _submitting = true);

    final store = await ref.read(photoStoreProvider.future);
    final shotAt = DateTime.now();

    final photos = <QueuedPhoto>[];

    for (final (index, path) in _shots.indexed) {
      // More shots than named slots should be impossible - ShotsScreen stops
      // at five - but a crash at the pole is not the place to find out.
      final type = index < ShotsScreen.photoTypes.length
          ? ShotsScreen.photoTypes[index]
          : 'extra';

      photos.add(QueuedPhoto(
        path: await store.keep(path, type),
        photoType: type,
        takenAt: shotAt,
      ));
    }

    final feet = double.tryParse(_feet.text.trim());
    final metres = double.tryParse(_metres.text.trim());
    final remarks = _remarks.text.trim();

    await ref.read(uploadProvider.notifier).submit(QueuedTag(
          tagId: tag.tagId,
          tagCode: tag.tagCode,
          record: {
            'tag_id': tag.tagId,
            'latitude': _best?.latitude,
            'longitude': _best?.longitude,
            'gps_accuracy': _best?.accuracy,
            'pole_type_id': _poleTypeId,
            'pole_condition_id': _poleConditionId,
            'telco_option_id': _telcoOptionId,
            'streetlight_option_id': _streetlightOptionId,
            'height_ft': feet,
            'height_m': metres,
            'remarks': remarks.isEmpty ? null : remarks,
          },
          photos: photos,
          queuedAt: DateTime.now(),
        ));

    if (!mounted) return;

    // Whether it actually went up is the queue's answer, not this screen's.
    final stillWaiting =
        ref.read(uploadProvider).queuedTagIds.contains(tag.tagId);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        stillWaiting ? 'Tag saved. Will upload later.' : 'Tag uploaded.',
      ),
    ));

    // The list is where he goes next either way. It refreshes itself, and the
    // tag he just did is now greyed out on it.
    Navigator.of(context).pop();
  }
```

- [ ] **Step 4: Add the guard flag and the imports**

In `_TagFormScreenState`, beside `bool _cameraOffered = false;`:

```dart
  /// Stops a double-tap on the last step queueing the same tag twice while the
  /// photos are still being copied.
  bool _submitting = false;
```

At the top of the file:

```dart
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
```

Then find the button that calls `_next` (around line 333, `onPressed: _next`) and disable it while submitting:

```dart
                onPressed: _submitting ? null : _next,
```

- [ ] **Step 5: Start the triggers and add the messenger key**

In `lib/main.dart`, replace the `StickermanApp` build method and add the state class. The app becomes stateful so the observer has somewhere to live:

```dart
/// Lets the drain bar be shown from outside any particular screen: the upload
/// finishes while he is on the camera or the form, not necessarily on Home.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class StickermanApp extends ConsumerStatefulWidget {
  const StickermanApp({super.key});

  @override
  ConsumerState<StickermanApp> createState() => _StickermanAppState();
}

class _StickermanAppState extends ConsumerState<StickermanApp> {
  UploadTriggers? _triggers;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for the photo folder before the first pass: a drain started
      // without it would have nowhere to delete the uploaded copies from.
      await ref.read(photoStoreProvider.future);

      if (!mounted) return;

      _triggers = UploadTriggers(ref.read(uploadProvider.notifier))..start();
    });
  }

  @override
  void dispose() {
    _triggers?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(uploadProvider, (previous, next) {
      final was = previous?.waiting ?? 0;
      final now = next.waiting;

      if (now < was) {
        final uploaded = was - now;

        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(
            uploaded == 1 ? '1 tag uploaded.' : '$uploaded tags uploaded.',
          ),
        ));
      }
    });

    return MaterialApp.router(
      title: 'Poletagging Stickerman',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
```

Add the import:

```dart
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
```

- [ ] **Step 6: Check it compiles**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

- [ ] **Step 7: Try it on a phone**

Run: `flutter run`

Walk it through, in this order:

1. **With wifi.** Scan a tag, fill the form, take 3 photos, Submit → *Tag uploaded.* Check the backend: the record exists and the tag's status is Installed.
2. **Turn wifi and mobile data off.** Do another tag → *Tag saved. Will upload later.*
3. **Kill the app from the recents list. Reopen it, still offline.** The tag must still be waiting.
4. **Turn wifi back on with the app open.** It uploads, and the bar says *1 tag uploaded.*

Stop and report if any of the four does not behave. Do not move on to Task 8.

---

## Task 8: The home screen

The three visible pieces: the counter, greyed-out submitted tags, and red refused ones.

**Files:**
- Modify: `lib/screens/home_screen.dart` (back it up first)
- Test: manual, plus the existing suite must stay green

**Interfaces:**
- Consumes: `uploadProvider`, `UploadState.waiting`, `UploadState.failed`, `UploadState.queuedTagIds`
- Produces: nothing

- [ ] **Step 1: Back it up**

Run: `cp lib/screens/home_screen.dart lib/screens/home_screen.dart.bak-0909`

- [ ] **Step 2: Add the import and watch the provider**

At the top:

```dart
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
```

In `_HomeScreenState.build`, below `final tags = ref.watch(tagProvider);`:

```dart
    final uploads = ref.watch(uploadProvider);
```

- [ ] **Step 3: Add the counter and the red rows**

In the same `build`, replace the `Column`'s children with:

```dart
          children: [
            _Header(
              user: user,
              count: tags.tags.length,
              syncedAt: tags.syncedAt,
              isLoading: tags.isLoading,
              isOffline: tags.error != null,
            ),
            if (uploads.waiting > 0) _WaitingLine(count: uploads.waiting),
            for (final tag in uploads.failed) _RefusedLine(tag: tag),
            if (tags.error != null && tags.tags.isNotEmpty)
              _ErrorBanner(message: tags.error!),
            Expanded(
              child: _Body(state: tags, queued: uploads.queuedTagIds),
            ),
          ],
```

- [ ] **Step 4: Add the two new widgets**

At the bottom of the file:

```dart
/// How many tags he has finished that the office has not got yet.
///
/// Only here when there is something waiting - on a day with coverage he never
/// sees it, because nothing ever waits.
class _WaitingLine extends StatelessWidget {
  const _WaitingLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Text(
            count == 1
                ? '1 tag waiting to upload'
                : '$count tags waiting to upload',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tag the server refused. It carries the server's own wording, because
/// "could not upload" on its own gives a supervisor nothing to act on.
class _RefusedLine extends StatelessWidget {
  const _RefusedLine({required this.tag});

  final QueuedTag tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tag.tagCode} — could not upload. '
              '${tag.failure ?? 'The server refused it.'}',
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Grey the submitted tags**

Replace `_Body` and `_TagRow`:

```dart
class _Body extends StatelessWidget {
  const _Body({required this.state, required this.queued});

  final TagState state;

  /// Tag ids he has already submitted. The server still calls them Dispatched
  /// because it has not heard yet, so this is the only thing that knows.
  final Set<int> queued;

  @override
  Widget build(BuildContext context) {
    if (state.tags.isNotEmpty) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.tags.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => _TagRow(
          tag: state.tags[index],
          done: queued.contains(state.tags[index].tagId),
        ),
      );
    }

    if (state.error != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Could not load your tags',
        detail: state.error,
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return const _Message(
      icon: Icons.inbox,
      title: 'No tags assigned to you yet',
      detail: 'Ask your dispatcher to assign you a batch.',
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, this.done = false});

  final Tag tag;

  /// Submitted, whether or not it has reached the server. Greyed out so he can
  /// see at a glance what is left - without it, a pole he did at 2pm still
  /// looks like work, and he can walk back and tag it twice.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(context).colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: done ? 0.45 : 1,
      child: ListTile(
        title: Text(
          tag.tagCode,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: done ? faded : null,
          ),
        ),
        subtitle: tag.batchCode == null ? null : Text(tag.batchCode!),
        trailing: _StatusChip(status: tag.status),
        titleAlignment: ListTileTitleAlignment.titleHeight,
        // Still tappable when done: a tag whose upload was refused may have to
        // be looked at, and blocking the tap would only puzzle him.
        onTap: () => context.push(Routes.scan, extra: tag),
      ),
    );
  }
}
```

- [ ] **Step 6: Confirm logout still leaves the queue alone**

Read `home_screen.dart:44-48`. It must still clear only the tag cache, the form options and the auth session. If `uploadProvider` or `UploadQueue` appears anywhere in that callback, remove it — a logout that wipes the queue throws away a day of tagging.

- [ ] **Step 7: Checkpoint**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests pass

- [ ] **Step 8: Try it on a phone**

Run: `flutter run`

1. **Offline.** Submit a tag → home shows *1 tag waiting to upload*, and that tag is greyed out in the list.
2. Submit two more → *3 tags waiting to upload*, three greyed rows.
3. **Kill and reopen the app, still offline.** Counter still 3, still three greyed rows.
4. **Back online.** Counter clears, the bar says *3 tags uploaded.*, and after the list refreshes the tags drop off it.
5. **The red case.** Submit a tag offline, then have someone reassign that tag to another crew in the admin app, then go online. A red line appears carrying the server's own wording, and the other tags upload past it.

Report what happens at each step.

---

## Self-Review

**Spec coverage:**

| Spec point | Task |
|---|---|
| 1. Submit saves the tag on the phone | 1, 2, 3, 7 |
| Photos copied out of the camera temp folder | 1 |
| 2. Signal → uploads right away | 6 (`submit` calls `drain`), 7 |
| 3. No signal → uploads later, by itself | 5, 6 (the three triggers) |
| Record first, then photos, resume where it stopped | 5 |
| One tag at a time, oldest first | 5 |
| 4. Home screen counts what's waiting | 6 (`waiting`), 8 (`_WaitingLine`) |
| 5. Refused tags go red | 5 (`_isPermanent`), 8 (`_RefusedLine`) |
| 6. Submitted tags go grey | 6 (`queuedTagIds`), 8 (`_TagRow.done`) |
| 7. Logging out doesn't delete the queue | 8 step 6; `UploadQueue` has no `clear` |
| Shrink photos before upload | 1 |
| Delete local photos once uploaded | 1 (`discard`), 5 |
| A waiting tag cannot be edited | No task adds an edit path; `UploadQueue` is keyed by tag id |
| Drain bar wherever he is in the app | 7 (`scaffoldMessengerKey`) |
| Exact wording | Global Constraints; 7, 8 |
| 401 pauses rather than reddens | 5 |
| Backend unchanged | No task touches `../np-pole-tag-api` |

No gaps.

**Type consistency:** `QueuedTag`, `QueuedPhoto`, `QueuedState`, `UploadQueue`, `PhotoStore`, `PoleUploadApi`, `Uploader`, `UploadResult`, `UploadController`, `UploadState`, `UploadTriggers` are each defined once and used with the same names and signatures throughout. `PhotoStore.keep(String, String)` and `discard(Iterable<String>)` match their call sites in Tasks 5 and 7. `createPoleRecord(Map<String, dynamic>) → Future<int>` matches Tasks 5 and 6.

**One known rough edge, deliberately left:** `uploadProvider` builds its `PhotoStore` from `photoStoreProvider.valueOrNull`, which is null on the very first read and falls back to a temp directory. Task 7 awaits the real folder before starting the triggers, so no real drain runs against the fallback. If this proves fragile on a device, the fix is to make `uploadProvider` a `FutureProvider` — a change worth making only if the symptom actually appears.

---

## Deliberately not in this plan

- Background upload with the app closed
- Refresh tokens or a longer login (`ACCESS_TOKEN_EXPIRE_MINUTES` is global and shared with the admin app)
- Editing or deleting a waiting tag
- A retry button on a red tag
- Listing or deleting photos already on the server — `router/photos.py` has upload only
