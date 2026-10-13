import 'package:flutter/material.dart';

/// The location match below which the reading is shown in red.
///
/// A warning only - he can still go on. Below it the phone keeps reading - the
/// GPS stream stays open for as long as the form does, and the best fix wins.
/// 85% is ±10 m, which is where a reading stops being able to tell this pole
/// from the next one along: poles sit about 20 m apart.
const int kLocationMatchNeeded = 85;

/// How far the reading can be trusted, as a percentage he can read at a
/// glance rather than a ± in metres.
///
/// The mockup's formula with its distance-from-the-expected-pole term taken
/// out, since nothing on the server says where a pole is expected to be: 1.5
/// points off for every metre of error, capped at 99 because no fix is
/// perfect.
int locationMatch(double accuracyMetres) =>
    (100 - accuracyMetres * 1.5).round().clamp(0, 99);

/// How far out the reading might be, and whether that is good enough.
///
/// One line rather than a bare number: `± 14 m` means nothing to him on its
/// own, and what he needs is whether to wait for a better fix.
class AccuracyLine extends StatelessWidget {
  const AccuracyLine({required this.metres, super.key});

  final double metres;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final match = locationMatch(metres);
    final low = match < kLocationMatchNeeded;
    final shown = metres >= 10
        ? metres.round().toString()
        : metres.toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          low ? Icons.warning_amber_rounded : Icons.check_circle,
          size: 18,
          color: low ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            low
                ? '± $shown m · location match $match% · '
                      'Improving GPS accuracy…'
                : 'Recorded automatically · ± $shown m · '
                      'location match $match%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: low ? scheme.error : scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
