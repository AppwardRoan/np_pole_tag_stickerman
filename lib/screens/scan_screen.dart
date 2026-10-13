import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';
import 'package:np_pole_tag_stickerman/services/stacked_code.dart';
import 'package:np_pole_tag_stickerman/widgets/scan/camera_message.dart';
import 'package:np_pole_tag_stickerman/widgets/scan/read_out.dart';
import 'package:np_pole_tag_stickerman/widgets/scan/shutter_button.dart';
import 'package:np_pole_tag_stickerman/widgets/scan/viewfinder.dart';
import 'package:np_pole_tag_stickerman/widgets/shared/already_sent_dialog.dart';
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.expected});

  /// The tag he tapped in the list, when he came that way.
  ///
  /// Null from the Scan button, where the read has to find the tag. Set from
  /// the list, where he has already named it and the sticker only has to agree.
  final Tag? expected;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  final _recognizer = TextRecognizer();

  CameraController? _camera;
  String? _cameraError;
  bool _isReading = false;
  String _readText = '';
  Tag? _found;
  bool _missed = false;
  bool _wrongTag = false;

  /// Nothing matched, and the top or bottom letter ran off the edge of the
  /// photo. Said instead of [_missed] or [_wrongTag]: the read was of half a
  /// code, so it says nothing about whether the sticker is the right one.
  bool _cutOff = false;

  /// The sticker he read is his, and the office already has its pole record.
  ///
  /// Its own state rather than a kind of [_missed]: the tag *was* found, and
  /// telling him it was not would send him hunting for a sticker he is holding.
  Tag? _alreadyDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  /// Android takes the camera away when the app leaves the screen - a call, a
  /// message, the home button - and never hands it back. Without this he
  /// returned to a dead preview and every press failed until he left the
  /// screen and came back. Let go of it on the way out, open it again on the
  /// way back.
  bool _released = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;

    if (state == AppLifecycleState.inactive && camera != null) {
      setState(() => _camera = null);
      _released = true;
      camera.dispose();
    } else if (state == AppLifecycleState.resumed && _released) {
      _released = false;
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'This phone has no camera.');
        return;
      }

      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final camera = CameraController(back, ResolutionPreset.medium);
      await camera.initialize();

      if (!mounted) {
        await camera.dispose();
        return;
      }

      setState(() => _camera = camera);
    } catch (e) {
      const denials = {
        'CameraAccessDenied',
        'CameraAccessDeniedWithoutPrompt',
        'CameraAccessRestricted',
      };
      final denied = e is CameraException && denials.contains(e.code);

      if (mounted) {
        setState(
          () => _cameraError = denied
              ? 'Camera access is off. Turn it on for this app in Settings.'
              : 'Could not open the camera.',
        );
      }
    }
  }

  Future<void> _read() async {
    final camera = _camera;
    if (camera == null || _isReading) return;

    setState(() {
      _isReading = true;
      _found = null;
      _missed = false;
      _wrongTag = false;
      _cutOff = false;
      _alreadyDone = null;
    });

    try {
      final shot = await camera.takePicture();
      final result = await _recognizer.processImage(
        InputImage.fromFilePath(shot.path),
      );

      var text = result.text.trim();
      var candidates = _candidates(text).toList();

      // Second look: the photo rebuilt with a stacked code stood in a row, and
      // read again. See `rebuildStackedCode`.
      //
      // Every scan, not only the ones the first pass came back empty on. Doing
      // it only on an empty read looked right and was not: anything else with
      // writing on it in the frame - a sign, a van, a screen with a toolbar
      // along the top - fills the first pass with words, and the stacked code
      // he is actually pointing at is then never looked for. What it costs when
      // there is no stacked code in the photo is one glance at the pixels,
      // which comes back empty.
      //
      // The rebuilt readings go in front, in the order they came back. They are
      // the deliberate ones: letters arranged in a column for a person to read
      // down.
      var cutOff = false;
      try {
        final rebuild = await rebuildStackedCode(shot.path);
        cutOff = rebuild.cutOff;

        final rebuiltCandidates = <String>[];
        String? rebuiltText;

        for (final row in rebuild.paths) {
          final rebuilt = await _recognizer.processImage(
            InputImage.fromFilePath(row),
          );
          // The row was built as one code, so any gap the reader sees in it
          // is not a word break. The W is wider than the other letters and
          // N9M5W came back as "N9M5 W" - split there, the W was thrown away
          // as too short to be a code and the sticker read as the wrong tag.
          final more = _candidates(
            rebuilt.text.replaceAll(RegExp(r'\s+'), ''),
          ).toList();

          if (more.isNotEmpty) {
            rebuiltCandidates.addAll(more);
            rebuiltText ??= rebuilt.text.trim();
          }
        }

        if (rebuiltText != null) {
          candidates = [...rebuiltCandidates, ...candidates];
          text = rebuiltText;
        }
      } catch (_) {
        // A photo that cannot be rebuilt is not a failed scan. What the
        // ordinary read found still stands.
      }

      if (!mounted) return;
      setState(() => _readText = text);

      final expected = widget.expected;

      Tag? found;
      if (expected != null) {
        // He has already named the tag by tapping its row, so the read only
        // has to agree with that one code. Nothing is looked up: the tag came
        // across with him, and a wrong read must not be allowed to find some
        // other tag of his and open that instead.
        found = candidates.contains(expected.tagCode) ? expected : null;
      } else {
        for (final candidate in candidates) {
          found = await ref.read(tagProvider.notifier).findByCode(candidate);
          if (found != null) break;
        }
      }

      if (!mounted) return;

      // The list carries finished tags now, so a code can resolve to a pole
      // that is already on file. Opening the form on one would have him fill
      // in a pole he tagged this morning and file it twice, and the server
      // would take it - so it is stopped here, where he still has the sticker
      // in front of him and can check he has the right one.
      //
      // The two finished states part company at this point. A record the
      // office holds is closed: nothing he does at the pole can replace it.
      // One still queued on the phone is not, and a wrong reading is worth
      // catching before it goes rather than after.
      //
      // A tap on a row settles both before the camera ever opens - see
      // `_TagRow._open`. This is the other way in, where the sticker has to be
      // read before anyone knows which tag it is, so the same two answers are
      // given here instead.
      final done = found != null && found.status == TagStatus.used;
      final queued =
          found != null &&
          !done &&
          ref.read(uploadProvider).waitingTagIds.contains(found.tagId);

      setState(() {
        _found = done ? null : found;
        _alreadyDone = done ? found : null;
        // Two different failures, and he needs them told apart: a tag that is
        // not his at all, and the wrong one of his own tags.
        _cutOff = found == null && cutOff;
        _missed =
            !_cutOff && expected == null && found == null && text.isNotEmpty;
        _wrongTag =
            !_cutOff && expected != null && found == null && text.isNotEmpty;
      });

      if (found == null || done) return;

      // Half-sent: same answer as the tag row gives.
      if (queued && ref.read(uploadProvider).sentTagIds.contains(found.tagId)) {
        await showAlreadySent(context, found.tagCode);
        return;
      }

      if (queued && !await _confirmRedo(found)) return;
      if (!mounted) return;

      // Replaced, not pushed. Pushing left this screen alive underneath and the
      // camera streaming 30 frames a second into nothing - battery and heat all
      // day at every pole. Going back from the form to the tag list is also the
      // right way out: the tag is confirmed, so a camera is nothing to return to.
      context.pushReplacement(Routes.tagForm, extra: found);
    } catch (_) {
      if (mounted) setState(() => _readText = '');
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  /// Asks before reopening a pole that is saved but not sent.
  ///
  /// Worded the same as the one on the tag list on purpose: he meets this at
  /// two different doors and it has to be the same fact both times.
  Future<bool> _confirmRedo(Tag tag) async {
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending upload'),
        content: Text(
          'Tag ${tag.tagCode} is saved on this device and has not been '
          'uploaded. Replace the saved record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    return again == true;
  }

  Iterable<String> _candidates(String text) {
    final words = text
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .split(RegExp(r'[^0-9A-Z]+'))
        .where((word) => word.length >= 4 && word.length <= 20)
        .toSet()
        .toList();

    words.sort((a, b) => b.length.compareTo(a.length));
    return words;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expected = widget.expected;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // The form's header, so the camera reads as part of the same job rather
        // than a stock screen dropped in between: the green, the chevron, a
        // caption over a title.
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.onGreen,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.chevron_left, size: 30),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The code he is checking against, from the list - the one thing
            // worth reading before the camera. Nothing over the plain scan.
            if (expected != null) ...[
              Text(
                expected.tagCode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontFamily: AppFonts.mono,
                  color: AppColors.paleGreen,
                ),
              ),
              const SizedBox(height: 1),
            ],
            Text(
              expected == null ? 'Scan tag' : 'Check the sticker',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AppColors.onGreen,
              ),
            ),
          ],
        ),
      ),
      body: _cameraError != null
          ? ColoredBox(
              color: AppColors.page,
              child: CameraMessage(message: _cameraError!),
            )
          : _camera == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_camera!),
                      const IgnorePointer(child: Center(child: Viewfinder())),
                    ],
                  ),
                ),
                ReadOut(
                  text: _readText,
                  isReading: _isReading,
                  found: _found,
                  alreadyDone: _alreadyDone,
                  missed: _missed,
                  wrongTag: _wrongTag,
                  cutOff: _cutOff,
                  expected: expected,
                  // Centred under the message, not in a corner. In the corner
                  // it sat on top of the message and squeezed it into a narrow
                  // column; here the message gets the full width and either
                  // thumb reaches the button.
                  action: ShutterButton(onPressed: _read, busy: _isReading),
                ),
              ],
            ),
    );
  }
}
