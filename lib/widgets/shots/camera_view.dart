import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/thirds_grid.dart';

/// The live camera, or the reason there is no live camera.
class CameraView extends StatelessWidget {
  const CameraView({
    required this.camera,
    required this.error,
    required this.label,
    super.key,
  });

  final CameraController? camera;

  /// Shown instead of the preview. Wins over everything: with no camera there
  /// is nothing to frame, and a spinner over a permission problem would have
  /// him standing at a pole waiting for something that is never coming.
  final String? error;

  /// Which shot he is lining up, repeated over the preview because his eyes
  /// are on the pole through the screen, not on the bar above it.
  final String label;

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ),
      );
    }

    final camera = this.camera;
    if (camera == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: CameraPreview(camera)),
        const IgnorePointer(child: ThirdsGrid()),
        Positioned(
          top: 14,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F0C).withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
