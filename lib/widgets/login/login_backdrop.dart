import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The two soft shapes behind the sign-in screen.
///
/// Deliberately almost invisible - a couple of percent off the background,
/// with no edge line. They give the screen a shape without competing with the
/// one thing on it that matters, which is the button.
///
/// Drawn rather than shipped as an image: it is a handful of curves, it scales
/// to any handset, and it costs nothing to bundle.
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _Shapes())),
    );
  }
}

class _Shapes extends CustomPainter {
  const _Shapes();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Down the right edge, from a little below the top to a little above the
    // bottom. Proportions, not pixels: the same shape on a small phone.
    final right = Path()
      ..moveTo(w, h * 0.114)
      ..cubicTo(
        w * 0.769,
        h * 0.178,
        w * 0.641,
        h * 0.355,
        w * 0.672,
        h * 0.557,
      )
      ..cubicTo(w * 0.697, h * 0.732, w * 0.846, h * 0.843, w, h * 0.905)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();

    // A low rise in the bottom-left corner, to stop the foot of the screen
    // reading as a flat band.
    final foot = Path()
      ..moveTo(0, h * 0.734)
      ..cubicTo(
        w * 0.246,
        h * 0.706,
        w * 0.431,
        h * 0.782,
        w * 0.549,
        h * 0.886,
      )
      ..cubicTo(w * 0.610, h * 0.940, w * 0.651, h * 0.974, w * 0.672, h)
      ..lineTo(0, h)
      ..close();

    canvas
      ..drawPath(right, Paint()..color = AppColors.deeperGreen)
      ..drawPath(foot, Paint()..color = const Color(0xFF0C3721));
  }

  @override
  bool shouldRepaint(_Shapes oldDelegate) => false;
}
