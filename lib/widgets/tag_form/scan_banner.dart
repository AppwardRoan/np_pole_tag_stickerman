import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The sticker he just scanned, named at the top of the form.
///
/// The form asks eight questions and never says which pole they are about. The
/// header carries the code, but it is small print beside a step counter, and a
/// man filling in a height does not check a title bar. This is the answer to
/// "am I filling this in for the right pole" - the one mistake on this screen
/// that cannot be found later, because every answer would be plausible for the
/// pole he meant and wrong for the one he typed it into.
///
/// Step one only. By the time he is on the photos he has seen it, and a banner
/// repeating itself four times is furniture.
///
/// [heading] is given because a re-pin reaches this step without a scan - the
/// office sent that pole back for a reading, and the sticker was read when it
/// was first filed. "Scan complete" over a form nobody scanned into would be
/// the one sentence on this screen that is simply untrue, and it is the
/// sentence a man checks when he wants to know he is at the right pole.
///
/// The mockup's version of this said `Dispatched -> Used - status updated
/// automatically, or discard to undo`. It is not written that way because it is
/// not true here: scanning a sticker sends nothing and changes nothing. The
/// status moves when he saves. A banner claiming otherwise would teach him that
/// scanning commits him, which is the opposite of what Discard is for.
class ScanBanner extends StatelessWidget {
  const ScanBanner({
    required this.tagCode,
    this.heading = 'Scan complete',
    this.scanned = true,
    super.key,
  });

  final String tagCode;

  /// What happened to get him here.
  final String heading;

  /// Whether a sticker was actually read. The tick means "done"; a re-pin has
  /// done nothing yet, so it gets the pin instead.
  final bool scanned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.chipGreenWash,
        border: Border.all(color: AppColors.chipGreenLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  scanned ? Icons.check : Icons.place_outlined,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                heading,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'TAG ID',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.midGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tagCode,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing reaches the office until you save. Add the pole details '
            'below, or discard this form.',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: AppColors.midGreen,
            ),
          ),
        ],
      ),
    );
  }
}
