import 'dart:io';

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
  ///
  /// Only [userId]'s poles: another man's wait for him to sign back in.
  Future<UploadResult> drain({int? userId}) async {
    var uploaded = 0;
    var refused = 0;

    for (final tag in await _queue.read()) {
      // Red tags are done being tried. Retrying gets the same answer.
      if (tag.state == QueuedState.failed) continue;
      if (tag.userId != null && tag.userId != userId) continue;

      final outcome = await _upload(tag);

      switch (outcome) {
        case _Outcome.uploaded:
          uploaded++;
        case _Outcome.refused:
          refused++;
        case _Outcome.tryLater:
          return UploadResult(
            uploaded: uploaded,
            refused: refused,
            stopped: true,
          );
      }
    }

    return UploadResult(uploaded: uploaded, refused: refused);
  }

  Future<_Outcome> _upload(QueuedTag tag) async {
    var current = tag;

    // A photo file gone from the phone used to fail inside the send and read
    // as "no signal" - and since the pile stops at the first try-later, this
    // pole, always first, held every pole behind it forever. Trying again
    // cannot bring the file back, so it turns red and the rest carry on.
    if (current.pending.any((photo) => !File(photo.path).existsSync())) {
      await _queue.update(
        current.copyWith(state: QueuedState.failed, failure: missingPhoto),
      );

      return _Outcome.refused;
    }

    if (current.recordId == null) {
      try {
        final recordId = await _api.createPoleRecord(current.record);
        current = current.copyWith(recordId: recordId);
        await _queue.update(current);
      } on ApiException catch (error) {
        return _handle(current, error);
      }
    }

    for (final photo in current.pending) {
      try {
        await _api.uploadPhoto(
          recordId: current.recordId!,
          path: photo.path,
          photoType: photo.photoType,
          takenAt: photo.takenAt,
        );
      } on ApiException catch (error) {
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
      await _queue.update(
        tag.copyWith(state: QueuedState.failed, failure: error.message),
      );

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

/// Shown on the red line under a pole whose photo file is gone.
const String missingPhoto =
    'A photo is missing from this phone. Tag the pole again to retake it.';
