import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/camera_view.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/shot_actions.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/shots_footer.dart';

/// The asset photos, shot one after another without leaving the camera.
///
/// Opens over the form the moment he reaches the photos step, the way the
/// mockup does it: he is at the pole with the phone already up, and making him
/// tap a tile before each shot is three extra taps per pole.
///
/// Hands back the paths of what he shot. Nothing is uploaded - there is no
/// column for a photo yet, so these live only as long as the form does.
class ShotsScreen extends StatefulWidget {
  const ShotsScreen({super.key, this.taken = const [], this.replacing});

  /// What he has already shot, so re-opening the camera continues rather than
  /// starting over.
  final List<String> taken;

  /// Opens straight into retaking this slot, for when he tapped a bad shot on
  /// the form rather than in here.
  final int? replacing;

  /// The three the office will not accept a pole without, then two spares.
  static const List<String> labels = [
    'Tag close-up',
    'Full pole',
    'Surroundings',
    'Extra shot',
    'Extra shot',
  ];

  static const int required = 3;

  @override
  State<ShotsScreen> createState() => _ShotsScreenState();
}

class _ShotsScreenState extends State<ShotsScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraError;
  bool _shooting = false;

  late final List<String> _shots = [...widget.taken];

  /// The slot the next shot overwrites. Null means the next shot is a new one.
  late int? _replacing = (widget.replacing ?? _shots.length) < _shots.length
      ? widget.replacing
      : null;

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

      final camera = CameraController(back, ResolutionPreset.high);
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

  Future<void> _shoot() async {
    final camera = _camera;
    final replacing = _replacing;

    if (camera == null || _shooting) return;

    // Full only blocks a new shot. Replacing one is what he does once all five
    // slots are taken and one of them is blurry.
    if (replacing == null && _shots.length >= ShotsScreen.labels.length) return;

    setState(() => _shooting = true);

    try {
      final shot = await camera.takePicture();
      if (!mounted) return;

      setState(() {
        if (replacing != null && replacing < _shots.length) {
          _shots[replacing] = shot.path;
          _replacing = null;
        } else {
          _shots.add(shot.path);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That shot did not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _shooting = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  /// What to do with a shot he has already taken.
  ///
  /// Remove is offered on the spares only. A required shot removed is one he
  /// has to take again anyway, and dropping it would shuffle the shot below it
  /// up into a slot the office reads as a different kind of photo - a
  /// close-up filed as a full pole shot, with nobody to catch it.
  /// What to do with a shot he has already taken. The choices themselves are
  /// in [ShotActions], including why remove is missing on the required three.
  Future<void> _offer(int index) async {
    if (index >= _shots.length) return;

    // Tapping the one he is already retaking calls it off. He changed his
    // mind, and the alternative is a shutter he cannot press safely.
    if (_replacing == index) {
      setState(() => _replacing = null);
      return;
    }

    final choice = await ShotActions.ask(context, index);

    if (!mounted) return;

    switch (choice) {
      case ShotAction.retake:
        setState(() => _replacing = index);
      // Guarded as well as hidden. [ShotActions] only offers remove on a
      // spare, and this is the line that would shuffle a named shot into the
      // wrong slot if that ever stopped being true.
      case ShotAction.remove when index >= ShotsScreen.required:
        setState(() {
          _shots.removeAt(index);
          _replacing = null;
        });
      case ShotAction.remove:
        break;
      case null:
        break;
    }
  }

  /// Which shot he is lining up, named the way the office asks for it.
  String get _label {
    final replacing = _replacing;
    if (replacing != null) {
      return 'Retaking ${ShotsScreen.labels[replacing].toLowerCase()}';
    }

    final next = _shots.length;

    if (next >= ShotsScreen.labels.length) return 'All shots taken';
    if (next < ShotsScreen.required) {
      return 'Shot ${next + 1} of ${ShotsScreen.required} required';
    }
    return '${ShotsScreen.labels[next]} - optional';
  }

  @override
  Widget build(BuildContext context) {
    final full =
        _shots.length >= ShotsScreen.labels.length && _replacing == null;

    return PopScope(
      // Back does the same as Cancel: what he has shot is kept either way.
      // Losing three photos to a stray back-swipe at a pole is not recoverable.
      //
      // `canPop: false` and the hand-written pop are what make that true. With
      // the default the route popped itself with no result, the form read that
      // as nothing to keep, and every shot of that session went in the bin -
      // the comment above described what was meant, not what happened.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_shots);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08150D),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Asset photos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CameraView(
                  camera: _camera,
                  error: _cameraError,
                  label: _label,
                ),
              ),
              ShotsFooter(
                shots: _shots,
                replacing: _replacing,
                shooting: _shooting,
                full: full,
                onShoot: _shoot,
                onThumbTap: _offer,
                onLeave: () => Navigator.of(context).pop(_shots),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
