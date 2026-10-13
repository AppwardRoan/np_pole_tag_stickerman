import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/screens/shots_screen.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/shot_thumb.dart';
import 'package:np_pole_tag_stickerman/widgets/shots/shutter_button.dart';

/// The strip of shots and the three controls under the viewfinder.
class ShotsFooter extends StatelessWidget {
  const ShotsFooter({
    required this.shots,
    required this.replacing,
    required this.shooting,
    required this.full,
    required this.onShoot,
    required this.onThumbTap,
    required this.onLeave,
    super.key,
  });

  final List<String> shots;

  /// The slot the next shot overwrites, ringed in the strip.
  final int? replacing;

  final bool shooting;

  /// No room for a new shot. Not the same as having all five: replacing one
  /// stays possible when every slot is taken.
  final bool full;

  final VoidCallback onShoot;

  /// Opens the retake or remove choice for a slot he has already shot.
  final ValueChanged<int> onThumbTap;

  /// Cancel and Done both do this - leaving with what he has. The two read
  /// differently to him and identically to the form, which is the point: a
  /// stray tap on Cancel must not cost him three photos.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final done = shots.length >= ShotsScreen.required;
    final remaining = ShotsScreen.required - shots.length;

    return Container(
      color: const Color(0xFF08150D),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
      child: Column(
        children: [
          SizedBox(
            height: 68,
            child: Row(
              children: [
                for (final (index, _) in ShotsScreen.labels.indexed) ...[
                  ShotThumb(
                    path: index < shots.length ? shots[index] : null,
                    label: index < ShotsScreen.required
                        ? 'REQ'
                        : '${index + 1}',
                    active: replacing == index,
                    onTap: index < shots.length
                        ? () => onThumbTap(index)
                        : null,
                  ),
                  if (index != ShotsScreen.labels.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLeave,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              ShutterButton(onTap: shooting || full ? null : onShoot),
              const SizedBox(width: 12),
              Expanded(
                child: done
                    ? FilledButton(
                        onPressed: onLeave,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontSize: 19),
                        ),
                      )
                    // Not a button until the three are in: it says how many are
                    // left rather than offering a way out that would fail.
                    : Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '$remaining more',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
