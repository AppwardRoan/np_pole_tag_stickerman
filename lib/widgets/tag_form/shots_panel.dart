import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/screens/shots_screen.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/shot_tile.dart';

/// What he has shot so far, behind the camera.
///
/// The camera is the way photos are taken; this is the record of them, and the
/// way back in when he wants to add the optional two or replace a bad shot.
class ShotsPanel extends StatelessWidget {
  const ShotsPanel({
    required this.shots,
    required this.onOpenCamera,
    required this.onRetake,
    required this.onRemove,
    this.missing = false,
    super.key,
  });

  final List<String> shots;
  final VoidCallback onOpenCamera;

  /// Opens the camera on a shot he already has, rather than on the next empty
  /// slot. Tapping a blurry photo should lead to fixing that photo.
  final ValueChanged<int> onRetake;

  /// Drops a spare. Offered on the last two slots only - see [ShotTile] for
  /// why the three named shots cannot be dropped without mislabelling one.
  final ValueChanged<int> onRemove;

  /// Reddens the required slots he has not filled. The panel itself has no
  /// border to colour, and the empty slots are the thing he has to act on.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = ShotsScreen.required - shots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                left <= 0
                    ? 'All required shots captured'
                    : '$left required shot${left == 1 ? '' : 's'} left',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: missing ? scheme.error : null,
                ),
              ),
            ),
            Text(
              '${shots.length} of ${ShotsScreen.labels.length} captured',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3 / 4,
          children: [
            for (final (index, label) in ShotsScreen.labels.indexed)
              ShotTile(
                title: label,
                path: index < shots.length ? shots[index] : null,
                required: index < ShotsScreen.required,
                missing:
                    missing &&
                    index < ShotsScreen.required &&
                    index >= shots.length,
                // A filled slot goes to that shot; an empty one goes to the
                // camera, which is already pointed at the next empty slot.
                onTap: index < shots.length
                    ? () => onRetake(index)
                    : onOpenCamera,
                onRemove: index >= ShotsScreen.required && index < shots.length
                    ? () => onRemove(index)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onOpenCamera,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(shots.isEmpty ? 'Open camera' : 'Take more'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Photos stay on the phone for now - nothing is sent to the office yet.',
          style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
