import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/screens/shots_screen.dart';

/// What he picked from the sheet on a shot he has already taken.
enum ShotAction { retake, remove }

/// The choices for one taken shot.
///
/// Remove is offered on the spares only. A required shot removed is one he has
/// to take again anyway, and dropping it would shuffle the shot below it up
/// into a slot the office reads as a different kind of photo - a close-up
/// filed as a full pole shot, with nobody to catch it.
class ShotActions extends StatelessWidget {
  const ShotActions({required this.slot, super.key});

  final int slot;

  /// Opens the sheet and hands back what he chose, or null if he kept it.
  static Future<ShotAction?> ask(BuildContext context, int slot) {
    return showModalBottomSheet<ShotAction>(
      context: context,
      builder: (_) => ShotActions(slot: slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spare = slot >= ShotsScreen.required;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              ShotsScreen.labels[slot],
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Retake this shot'),
            subtitle: const Text('The next photo replaces this one.'),
            onTap: () => Navigator.of(context).pop(ShotAction.retake),
          ),
          if (spare)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove this shot'),
              subtitle: const Text('It is one of the two spares.'),
              onTap: () => Navigator.of(context).pop(ShotAction.remove),
            ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Keep it as it is'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
