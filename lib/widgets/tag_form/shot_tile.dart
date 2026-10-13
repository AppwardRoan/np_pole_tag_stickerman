import 'dart:io';

import 'package:flutter/material.dart';

class ShotTile extends StatelessWidget {
  const ShotTile({
    required this.title,
    required this.path,
    required this.required,
    required this.onTap,
    this.onRemove,
    this.missing = false,
    super.key,
  });

  final String title;
  final String? path;
  final bool required;
  final VoidCallback onTap;

  /// Drops this shot, from the X in the corner.
  ///
  /// Null on the three the office names by position - removing one of those
  /// would slide the shot below it up into a slot that means something else,
  /// and the surroundings would arrive filed as the full pole. Those tiles get
  /// a retake corner instead, which swaps the picture and moves nothing.
  final VoidCallback? onRemove;

  /// Draws an empty slot red. Only the required ones are ever set, and only
  /// after he has tried to leave the step short.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = this.path;
    final taken = path != null;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: taken
                  ? scheme.primary
                  : missing
                  ? scheme.error
                  : scheme.outlineVariant,
              width: taken || missing ? 2 : 1,
            ),
            image: taken
                ? DecorationImage(
                    image: FileImage(File(path)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!taken)
                Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 30,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              // A shot of a dark pole against a bright sky needs something
              // behind the label, or the label is the part that disappears.
              if (taken)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD10A140E), Color(0x0D0A140E)],
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: taken
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    taken ? 'CAPTURED' : (required ? 'REQUIRED' : 'OPTIONAL'),
                    style: TextStyle(
                      fontSize: 13.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: taken ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              // Same corner on every captured tile, so his thumb learns one
              // place. The icon is what differs: an X drops a spare, and the
              // camera swaps a named shot without moving anything.
              if (taken)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: const Color(0xB3000000),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onRemove ?? onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          onRemove == null
                              ? Icons.photo_camera_outlined
                              : Icons.close,
                          size: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: taken ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
