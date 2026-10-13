import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    required this.icon,
    required this.title,
    this.detail,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    // A Column, not a ListView. This used to scroll itself so a pull-to-refresh
    // had something to grab, but every place it is used already sits inside a
    // scrollable - and a viewport inside a viewport has no height to work with,
    // so it threw and drew nothing. Scrolling is the caller's job now.
    // No fixed spacer above or below. There used to be 80 at each end, which
    // on a short tab stopped the centring working and left the message sitting
    // low - the padding is the caller's space to give, not this widget's to
    // take.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.fieldLine),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
