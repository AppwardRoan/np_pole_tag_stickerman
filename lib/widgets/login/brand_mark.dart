import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The app's mark: two letters in a rounded green tile.
///
/// A monogram rather than a drawing of a pole. It survives being shrunk to a
/// launcher icon, it cannot be misread at arm's length in the sun, and there
/// is no existing logo to be faithful to.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.actionGreen,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'PI',
        style: TextStyle(
          fontSize: size * 0.375,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.deepGreen,
        ),
      ),
    );
  }
}
