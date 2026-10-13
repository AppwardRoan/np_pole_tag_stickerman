import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The round button that takes the photo, shaped like the one in the phone's
/// own camera so nobody has to be told what it does.
///
/// Amber, because amber is the scan colour already - the scan bar on the home
/// screen is amber - and on the green panel it is the one thing that stands
/// out. It sits in that panel rather than over the picture: floating over the
/// picture it crowded the bottom of the frame and covered the last letter of
/// the sticker he was lining up.
///
/// While a photo is being read the disc turns into a spinner, so a second tap
/// has nothing to land on and he can see it is working.
class ShutterButton extends StatelessWidget {
  const ShutterButton({required this.onPressed, required this.busy, super.key});

  final VoidCallback? onPressed;
  final bool busy;

  static const double _size = 80;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: Container(
          width: _size,
          height: _size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amber, width: 4),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: busy ? Colors.transparent : AppColors.amber,
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: AppColors.amber,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt_rounded,
                      size: 32,
                      color: AppColors.deepGreen,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
