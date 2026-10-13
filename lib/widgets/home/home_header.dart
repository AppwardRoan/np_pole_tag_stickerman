import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/providers/palette_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/account_menu.dart';
import 'package:np_pole_tag_stickerman/models/my_stats.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';
import 'package:np_pole_tag_stickerman/widgets/profile/profile_card.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.user,
    required this.stats,
    required this.waiting,
    required this.isLoading,
    required this.isOffline,
    required this.onLogout,
    required this.onOpenWork,
    this.syncedAt,
    super.key,
  });

  final User? user;

  /// The figures as the server last counted them.
  final MyStats stats;

  /// Poles he has filed that the server has not been told about yet.
  final int waiting;

  final bool isLoading;
  final bool isOffline;

  /// Signing out clears the tags and the pick-lists with him: the ids belong
  /// to one utility, and the next man on this handset may not be from it.
  final Future<void> Function() onLogout;

  /// Opens the screen holding everything the bar no longer has room for - his
  /// year's total and how his bundles stand.
  final VoidCallback onOpenWork;
  final DateTime? syncedAt;

  /// Still to place, as this screen counts it.
  ///
  /// The server's figure as it stands, queue included. It used to take the
  /// queue off, back when a pole waiting to upload moved to Completed; now
  /// that those stay under Assigned, subtracting here put "2 left" directly
  /// above a tab reading "Assigned · 3" - one screen, two counts of the same
  /// three poles.
  int get _assigned => stats.assigned;

  /// Today's, counting the ones still on the phone.
  ///
  /// Without the queue this reads zero all morning wherever there is no
  /// signal, then jumps by six at lunch - and a man who has tagged six poles
  /// looking at a bar that says none has been told his morning did not happen.
  /// Adding the queue means the figure never moves when the upload finally
  /// goes: the poles cross from the phone's count to the server's.
  int get _completedToday => stats.completedToday + waiting;

  static String _clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  String _status() {
    if (isLoading) return 'Checking…';
    if (syncedAt == null) return isOffline ? 'No signal' : 'Not updated yet';

    final updated = 'Updated ${_clock(syncedAt!)}';
    return isOffline ? '$updated · offline' : updated;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // The status bar's height is added to the top rather than kept clear by
      // a SafeArea above this block. The bar is transparent now, so something
      // has to be painted under it - and the green carrying on to the very top
      // edge is what stops a strip of another colour sitting over the header.
      padding: EdgeInsets.fromLTRB(
        16,
        12 + MediaQuery.paddingOf(context).top,
        12,
        14,
      ),
      color: AppColors.deepGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIELD CAPTURE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.paleGreen,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tag a pole',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onGreen,
                      ),
                    ),
                  ],
                ),
              ),
              // Who is signed in. Tapping it opens the account menu - it used
              // to sign him out on the tap itself, which one thumb at a pole
              // could do by accident, with no signal to sign back in with.
              const _SunSwitch(),
              _Who(user: user, onLogout: onLogout),
            ],
          ),
          const SizedBox(height: 14),
          // One line where there were three tiles. The bundle figures came off
          // it rather than being shrunk to fit: they answer a question he asks
          // at the end of a run, not one he asks between poles, and they are a
          // tap away behind the chevron. What is left of him here is the two
          // numbers that change while he works.
          _DayBar(
            left: _assigned,
            doneToday: _completedToday,
            onOpen: onOpenWork,
          ),
          const SizedBox(height: 11),
          // Inside the green rather than under it. It is a fact about the
          // figures above, and a line of its own below the block read as a
          // fact about the list instead.
          Row(
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.paleGreen,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                _status(),
                style: TextStyle(
                  fontSize: 15.5,
                  color: AppColors.mutedGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The day in one line: what is left, what is done since midnight, and a way
/// through to the rest.
///
/// Two numbers rather than three tiles. Both move while he works and both are
/// about today, so they read as one sentence about the shift rather than three
/// separate facts he has to assemble.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.left,
    required this.doneToday,
    required this.onOpen,
  });

  /// Stickers he is still carrying.
  final int left;

  /// Poles he has filed today, the phone's queue included.
  final int doneToday;

  final VoidCallback onOpen;

  /// The number, then its word, as one run of text.
  ///
  /// A Row of two Texts would let the pair break across the bar on a narrow
  /// handset with the word landing under its own figure. Spans cannot be split
  /// from each other, so "9 done today" stays together or wraps whole.
  TextSpan _figure(int value, String word, Color colour) {
    return TextSpan(
      children: [
        TextSpan(
          text: '$value ',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: colour,
          ),
        ),
        TextSpan(
          text: word,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.paleGreen,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deeperGreen,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      _figure(left, 'left', AppColors.onGreen),
                      TextSpan(
                        text: '   │   ',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.mutedGreen,
                        ),
                      ),
                      // Amber for the half he has finished, the one colour the
                      // rest of this app already uses to mean his own work.
                      _figure(doneToday, 'done today', AppColors.amber),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.paleGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signed-in man, as a circle: his initials, in a ring, and nothing else.
///
/// His name used to sit beside it. It went because the name is already on the
/// card the circle opens, and saying it twice cost the width the title wants
/// on a 360-wide handset.
///
/// Tapping it opens the account card - it used to sign him out on the tap
/// itself, which one thumb at a pole could do by accident, with no signal to
/// sign back in with.
/// The sun switch: the design as drawn, or the same design for a screen with
/// the sun on it.
///
/// Here, beside his initials, rather than buried in the account menu. It is
/// not a setting he picks once at install - it is the light changing on him,
/// and when the list goes flat at noon the switch has to be under his thumb
/// on the screen he is already looking at.
///
/// The sun is filled when sunlight is on and drawn in outline when it is off,
/// so the state reads without colour. Colour is the one thing that cannot be
/// trusted to carry a message here: half the point of the switch is that he
/// is somewhere the colours have stopped working.
class _SunSwitch extends ConsumerWidget {
  const _SunSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(paletteProvider).isSunlight;

    return Semantics(
      toggled: on,
      button: true,
      label: 'Sunlight mode',
      child: Tooltip(
        message: on ? 'Sunlight mode on' : 'Sunlight mode off',
        child: InkResponse(
          onTap: () => ref.read(paletteProvider.notifier).toggle(),
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? AppColors.greenSurface : Colors.transparent,
                border: Border.all(color: AppColors.greenLine, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                on ? Icons.wb_sunny : Icons.wb_sunny_outlined,
                size: 19,
                color: AppColors.onGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Who extends StatefulWidget {
  const _Who({required this.user, required this.onLogout});

  final User? user;
  final Future<void> Function() onLogout;

  @override
  State<_Who> createState() => _WhoState();
}

class _WhoState extends State<_Who> {
  /// What the card hangs from. Held here rather than made in `build` so the
  /// anchor survives the rebuilds the figures above cause every sync.
  final GlobalKey _anchor = GlobalKey();

  String get _initials {
    final user = widget.user;
    if (user == null) return '';

    final first = user.firstName.trim();
    final last = user.lastName.trim();

    final a = first.isEmpty ? '' : first[0];
    final b = last.isEmpty ? '' : last[0];

    return '$a$b'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () => showAccountMenu(
        context: context,
        anchorKey: _anchor,
        user: widget.user,
        onProfile: () => showProfileCard(context),
        onSignOut: widget.onLogout,
      ),
      radius: 26,
      child: Padding(
        // The circle is small; the padding is what his thumb actually hits.
        padding: const EdgeInsets.all(5),
        child: Container(
          key: _anchor,
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.greenLine, width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.amber,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
