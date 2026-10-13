import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';

/// How wide the card hangs. Fixed rather than sized to the name: a card that
/// grew with "Roan Tanduyan" and shrank with "R. Cruz" would move under his
/// thumb between one man and the next.
const double _menuWidth = 206;

/// Drops the account card down from the circle it was tapped on.
///
/// Anchored to the circle's bottom-right, so the card hangs below it and runs
/// back towards the middle of the screen - the corner is where the circle is,
/// and a card that opened from the bottom of the screen instead read as a
/// different thing entirely.
Future<void> showAccountMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required User? user,
  required VoidCallback onProfile,
  required VoidCallback onSignOut,
}) async {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return;

  final anchor = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox;

  // The circle's bottom-right corner, in the overlay's own coordinates.
  final corner = anchor.localToGlobal(
    anchor.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );

  await showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      corner.dx - _menuWidth,
      corner.dy + 8,
      overlay.size.width - corner.dx,
      0,
    ),
    constraints: const BoxConstraints(
      minWidth: _menuWidth,
      maxWidth: _menuWidth,
    ),
    color: AppColors.card,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    items: [
      PopupMenuItem<void>(
        enabled: false,
        padding: EdgeInsets.zero,
        // The card draws its own rows and handles its own taps; this item is
        // only the sheet of paper they sit on.
        child: AccountMenu(
          user: user,
          onProfile: onProfile,
          onSignOut: onSignOut,
        ),
      ),
    ],
  );
}

/// What the circle opens: who he is, then the two things he can do about it.
///
/// Sign out used to be the tap itself. One mis-tap on the chip at a pole signed
/// him out, and signing back in needs the signal he does not have - so it sits
/// behind a menu now, at the bottom, in the colour that says think first.
///
/// Reads the cached user rather than asking the server. He opens this where
/// there is no signal, and his own name is not worth a spinner.
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    required this.user,
    required this.onProfile,
    required this.onSignOut,
    super.key,
  });

  final User? user;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  String get _name {
    final user = this.user;
    if (user == null) return '';

    return '${user.firstName} ${user.lastName}'.trim();
  }

  /// The first role the server gave him. He holds one in practice, and a list
  /// of them under his name would be admin detail on a field screen.
  String get _role {
    final roles = user?.roles ?? const [];

    return roles.isEmpty ? '' : roles.first.roleName;
  }

  String get _initials {
    final user = this.user;
    if (user == null) return '';

    final a = user.firstName.trim();
    final b = user.lastName.trim();

    return '${a.isEmpty ? '' : a[0]}${b.isEmpty ? '' : b[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (_role.isNotEmpty)
                      Text(
                        _role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.line),
        _MenuRow(
          icon: Icons.person_outline,
          label: 'My Profile',
          onTap: onProfile,
        ),
        // Inset, so it reads as a line between two choices rather than another
        // edge of the card.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 1, color: AppColors.line),
        ),
        _MenuRow(
          icon: Icons.logout,
          label: 'Sign Out',
          colour: AppColors.danger,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

/// One line of the card: an icon, a word, and the whole width to tap.
///
/// Closes the card itself before running the action. Signing out from under an
/// open card leaves it sitting over the login screen.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.colour,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Left null for an ordinary row. It cannot default to [AppColors.ink] in
  /// the constructor any more: the palette can change while the app is
  /// running, so the fallback has to be read at build time.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final colour = this.colour ?? AppColors.ink;

    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colour),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
