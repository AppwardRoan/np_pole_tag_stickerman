import 'dart:io';

import 'package:flutter/material.dart';

class ShotThumb extends StatelessWidget {
  const ShotThumb({
    required this.path,
    required this.label,
    this.onTap,
    this.active = false,
    super.key,
  });

  final String? path;
  final String label;

  /// Opens the retake or remove choice. Null on a slot he has not shot yet -
  /// there is nothing to retake, and the shutter is how an empty slot fills.
  final VoidCallback? onTap;

  /// This is the shot the next press of the shutter replaces. Ringed so he can
  /// see which one he is about to overwrite before he presses it.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final scheme = Theme.of(context).colorScheme;

    final thumb = Container(
      width: 52,
      height: 68,
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101A13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active
              ? scheme.error
              : path == null
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.7),
          width: active ? 2.5 : 1.5,
        ),
        image: path == null
            ? null
            : DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
      ),
      child: path != null
          ? null
          : Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
    );

    final onTap = this.onTap;
    if (onTap == null) return thumb;

    return GestureDetector(onTap: onTap, child: thumb);
  }
}
