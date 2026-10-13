import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The way into the camera, across the bottom of the tag list.
///
/// A bar rather than the floating button it replaces: he is holding the phone
/// one-handed at a pole, and a full-width target is one his thumb finds without
/// looking. 58 high to match the login controls, which were sized for gloves.
///
/// Corner brackets, not a QR icon - the scan reads the printed code as text and
/// nothing in this system prints a barcode. A QR mark would promise something
/// the sticker does not carry.
class ScanButton extends StatelessWidget {
  const ScanButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 22 at the bottom, not 12. On a handset with the three Android buttons
      // the system bar is its own strip below the app, so the gap here is the
      // only thing between this bar and Home - and he reaches for this one
      // without looking, one-handed, at a pole. `minimum` rather than a fixed
      // pad so a gesture-nav phone keeps its own larger inset.
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.crop_free, size: 22),
        label: const Text('Scan tag ID'),
        style: FilledButton.styleFrom(
          // Amber, not green. It is the one thing on this screen he is meant
          // to reach for, and the green button sat in a green screen.
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
