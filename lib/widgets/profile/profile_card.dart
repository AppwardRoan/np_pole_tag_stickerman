import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';

/// Opens the profile card over whatever he was looking at.
Future<void> showProfileCard(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ProfileCard(),
  );
}

/// Who he is, in the words the server uses for him.
///
/// Opens on the copy of him already on the phone, then asks `GET /me` and swaps
/// in whatever comes back. A failed call is left alone on purpose: he opens
/// this in dead spots, the cached answer is still true, and a red box over his
/// own name would say something is wrong when nothing is.
class ProfileCard extends ConsumerStatefulWidget {
  const ProfileCard({super.key});

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  /// The server's answer, once it arrives. Null means the cached user is still
  /// what is on screen.
  User? _fresh;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final user = await ref.read(apiProvider).getMe();
      if (mounted) setState(() => _fresh = user);
    } catch (_) {
      // No signal, or the server is down. Keep the cached user.
    }
  }

  String _name(User? user) => user == null ? '' : user.fullName.trim();

  String? _role(User? user) {
    final roles = user?.roles ?? const [];

    return roles.isEmpty ? null : roles.first.roleName;
  }

  String _initials(User? user) {
    if (user == null) return '';

    final a = user.firstName.trim();
    final b = user.lastName.trim();
    final first = a.isEmpty ? '' : a[0];
    final last = b.isEmpty ? '' : b[0];

    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = _fresh ?? ref.watch(authProvider).user;
    final role = _role(user);

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Crown(initials: _initials(user)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _name(user),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (role != null) ...[
              const SizedBox(height: 9),
              _RolePill(role: role),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email,
                    label: 'Username',
                    value: user?.username ?? '—',
                    // A username is typed, not read - mono for the same reason
                    // a tag code is mono.
                    mono: true,
                  ),
                  const _RowLine(),
                  _InfoRow(
                    icon: Icons.apartment_outlined,
                    label: 'Organization',
                    value: user?.orgCode ?? '—',
                  ),
                  const _RowLine(),
                  _InfoRow(
                    icon: Icons.groups_outlined,
                    label: 'Crew',
                    value: user?.crew?.crewLabel ?? 'Not on a crew',
                    // Where that crew belongs. It comes nested inside the crew,
                    // so it is the crew's city rather than his own assignment.
                    sub: user?.crew?.city?.cityName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.midGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The green band, and the circle sitting half on it.
class _Crown extends StatelessWidget {
  const _Crown({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: Stack(
        children: [
          Container(
            height: 92,
            width: double.infinity,
            color: AppColors.deepGreen,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
          Positioned(
            top: 46,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenSurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, size: 18, color: AppColors.onGreen),
        ),
      ),
    );
  }
}

/// What the server calls him, as a badge under his name.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: AppColors.midGreen),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.midGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact about him: what it is called, and what it says.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// A second, quieter line under the value. Null on a row with nothing more
  /// to add.
  final String? sub;

  final bool mono;

  @override
  Widget build(BuildContext context) {
    final sub = this.sub;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.midGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFamily: mono ? AppFonts.mono : null,
                  ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
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
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.line);
  }
}
