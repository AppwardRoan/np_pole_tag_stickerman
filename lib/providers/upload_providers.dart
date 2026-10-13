import 'dart:async';
import 'dart:io' show Directory;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
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

  /// Finished, and still on its way up. This is the set the Completed tab
  /// adds to the server's own Used tags.
  ///
  /// Refused ones are left out on purpose: a tag the server turned down is not
  /// finished, it is waiting for somebody to look at it, and filing it under
  /// Completed would bury the one row on the screen that needs him.
  Set<int> get waitingTagIds => tags
      .where((tag) => tag.state != QueuedState.failed)
      .map((tag) => tag.tagId)
      .toSet();

  /// Still waiting, but the office already has the record - only photos are
  /// left. Replace is closed on these: a second record for the tag is answered
  /// with the first one, so the correction would never land.
  Set<int> get sentTagIds => tags
      .where((tag) => tag.state != QueuedState.failed && tag.recordId != null)
      .map((tag) => tag.tagId)
      .toSet();

  UploadState copyWith({List<QueuedTag>? tags, bool? draining}) {
    return UploadState(
      tags: tags ?? this.tags,
      draining: draining ?? this.draining,
    );
  }
}

/// Owns the queue's state and decides when the uploader runs.
class UploadController extends StateNotifier<UploadState> {
  UploadController(
    this._queue,
    this._uploader,
    this._photos, {
    int? Function()? userId,
  }) : _userId = userId ?? (() => null),
       super(const UploadState());

  final UploadQueue _queue;
  final Uploader _uploader;
  final PhotoStore _photos;

  /// Who is signed in right now, read at each pass.
  final int? Function() _userId;

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
  ///
  /// The send is not waited on. It used to be, and it works through every pole
  /// in the pile at up to 30 seconds a call - so with a backlog and one bar,
  /// Save froze for minutes and he closed the app on a half-saved pole.
  Future<void> submit(QueuedTag tag) async {
    await _queue.add(tag);
    await load();

    unawaited(drain());
  }

  /// Throws away a finished tag that has not gone up yet, for Replace.
  ///
  /// Without this, Replace only opened the form again: the old record stayed
  /// in the pile and went up the moment signal returned, and because the
  /// office refuses a second record for the same tag, the replacement he was
  /// standing there making could never land. The row said Draft while the
  /// server already had the record he was replacing.
  ///
  /// Its photos go too. Nothing points at them once the record is gone, and
  /// they are full-size pole shots.
  Future<void> discard(int tagId) async {
    final dropping = [
      for (final tag in state.tags)
        if (tag.tagId == tagId) tag,
    ];

    await _queue.remove(tagId);

    for (final tag in dropping) {
      await _photos.discard([for (final photo in tag.photos) photo.path]);
    }

    await load();
  }

  Future<void>? _running;
  bool _again = false;

  /// One pass over the queue.
  ///
  /// Never two passes at once: the triggers overlap - resuming the app while
  /// the network comes back fires both - and two passes would upload the same
  /// tag twice. A call that lands mid-pass is not dropped, though. It used to
  /// be, so a pole saved while an earlier pass was running sat on the phone
  /// until the next trigger; now it books one more pass for when this one ends.
  Future<void> drain() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }

    return _running = _passes().whenComplete(() => _running = null);
  }

  Future<void> _passes() async {
    state = state.copyWith(draining: true);

    try {
      do {
        _again = false;

        try {
          final result = await _uploader.drain(userId: _userId());

          if (result.uploaded > 0 && !_uploads.isClosed) {
            _uploads.add(result.uploaded);
          }
        } catch (_) {
          // A drain that blows up must not take the app with it. The tags are
          // untouched on the phone, and the next trigger will try again.
        }

        state = state.copyWith(tags: await _queue.read());
      } while (_again);
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
      final connected = results.any(
        (result) => result != ConnectivityResult.none,
      );
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
final photoStoreProvider = FutureProvider<PhotoStore>(
  (ref) => PhotoStore.open(),
);

final uploadProvider = StateNotifierProvider<UploadController, UploadState>((
  ref,
) {
  final queue = ref.read(uploadQueueProvider);

  // Until the folder is ready there is nothing queued to clean up anyway; the
  // app shell awaits it before the first real drain.
  final photos =
      ref.read(photoStoreProvider).valueOrNull ??
      PhotoStore(Directory.systemTemp);

  return UploadController(
    queue,
    Uploader(ref.read(apiProvider), queue, photos),
    photos,
    userId: () => ref.read(authProvider).user?.userId,
  );
});
