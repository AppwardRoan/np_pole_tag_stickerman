import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:np_pole_tag_stickerman/services/location_service.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/accuracy_line.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/mini_map.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/reading_value.dart';

/// Where the pole is, as the phone currently has it.
///
/// Shows the reading narrowing rather than one final answer: the first fix is
/// wide enough to cover the poles either side of this one, and watching the
/// number come down is what tells him it is worth trusting.
class LocationCard extends StatelessWidget {
  const LocationCard({
    required this.position,
    required this.blocked,
    required this.onSettings,
    required this.onRefix,
    this.required = false,
    this.missing = false,
    super.key,
  });

  final Position? position;
  final LocationBlock? blocked;
  final VoidCallback onSettings;
  final VoidCallback onRefix;

  /// Puts a red asterisk after the label. Marks the ones he cannot leave
  /// blank, so the form says so before he taps Next rather than after.
  final bool required;

  /// Draws the card red once he has tried to leave with no fix yet. The GPS
  /// is the one field he cannot simply answer, so the red says wait or move,
  /// not that he forgot something.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = this.blocked;
    final position = this.position;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: missing ? scheme.error : scheme.outlineVariant,
          width: missing ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Location',
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (blocked != null) ...[
            Text(
              blocked.message,
              style: TextStyle(fontSize: 17, color: scheme.error),
            ),
            const SizedBox(height: 12),
            // Every one of these messages ends in "try again", so there has to
            // be something to tap. Settings is offered alongside only where
            // Android will not ask him a second time.
            Row(
              children: [
                OutlinedButton(
                  onPressed: onRefix,
                  child: const Text('Try again'),
                ),
                if (blocked == LocationBlock.deniedForever) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onSettings,
                    child: const Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ] else if (position == null)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Finding the pole…',
                  style: TextStyle(
                    fontSize: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else ...[
            MiniMap(latitude: position.latitude, longitude: position.longitude),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ReadingValue(
                    label: 'Latitude',
                    value: position.latitude.toStringAsFixed(6),
                  ),
                ),
                Expanded(
                  child: ReadingValue(
                    label: 'Longitude',
                    value: position.longitude.toStringAsFixed(6),
                  ),
                ),
                OutlinedButton(onPressed: onRefix, child: const Text('Re-fix')),
              ],
            ),
            const SizedBox(height: 12),
            AccuracyLine(metres: position.accuracy),
          ],
        ],
      ),
    );
  }
}
