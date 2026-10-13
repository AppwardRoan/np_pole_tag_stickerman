import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/providers/sign_out.dart';
import 'package:np_pole_tag_stickerman/widgets/login/brand_mark.dart';
import 'package:np_pole_tag_stickerman/widgets/login/login_backdrop.dart';

/// Shown to a signed-in man who carries no paper: either he is on no crew, or
/// he is on one that somebody else leads.
///
/// A batch is dealt to the crew leader alone, so for anybody else every screen
/// in this app is empty - no tags, no envelope to accept, no pole to file. That
/// emptiness used to be the only explanation he got, and it reads as a broken
/// app rather than as a fact about his crew. This says the fact out loud.
///
/// Not a refusal at sign-in, deliberately. His account is real and his password
/// was right; being bounced at the login box reads as a typing mistake, and
/// five of those lock the account for five minutes on top of everything else.
/// He gets in, and gets told.
///
/// It is not a security boundary either. The server hands out nothing that is
/// not his whatever this screen does - it refuses a tag that names somebody
/// else on every route that touches one. This is the explanation, not the lock.
class NoCrewScreen extends ConsumerStatefulWidget {
  const NoCrewScreen({super.key});

  @override
  ConsumerState<NoCrewScreen> createState() => _NoCrewScreenState();
}

class _NoCrewScreenState extends ConsumerState<NoCrewScreen> {
  /// True while the server is being asked again. Only to stop a second tap and
  /// to put a spinner in the button - the answer arrives as a new user, and the
  /// router is what acts on it.
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);

    await ref.read(authProvider.notifier).recheck();

    // The reply may have moved him off this screen entirely, in which case this
    // State is gone before the await returns.
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Stack(
        children: [
          const LoginBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _recheck,
              color: AppColors.deepGreen,
              backgroundColor: AppColors.onGreen,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    // Always scrollable, though the content fits: the pull is
                    // the gesture he will try first, and a view that cannot
                    // scroll cannot be pulled.
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: _Body(
                              user: user,
                              checking: _checking,
                              onRecheck: _recheck,
                              onSignOut: () => signOut(ref),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.user,
    required this.checking,
    required this.onRecheck,
    required this.onSignOut,
  });

  final User? user;
  final bool checking;
  final Future<void> Function() onRecheck;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final crew = user?.crew;
    final leader = crew?.leaderName;

    // Three states, and each names a different thing the office has to do
    // about it. The heading says which one he is in; the sentence under it says
    // who resolves it.
    //
    // The crew's own label is deliberately never printed beside the leader's
    // name. A crew is labelled after the man who leads it, so the two are the
    // same words in the ordinary case, and a heading carrying both read
    // "P. Santos leads P. Santos".
    final String heading;
    final String detail;
    if (crew == null) {
      heading = 'Crew assignment required';
      detail =
          'This account is not currently assigned to a crew. Batches are '
          'issued to a crew and managed by its designated leader. Please '
          'contact your dispatcher to request an assignment.';
    } else if (leader == null) {
      // `crews.leader_id` is cleared when the account it named is deleted, so
      // a crew can outlive its leader. Naming nobody is the honest answer.
      heading = 'Crew leader not designated';
      detail =
          'Your crew does not currently have a designated leader. Batches are '
          'issued to the crew leader. Please contact your dispatcher to have '
          'one designated.';
    } else {
      heading = 'Crew led by $leader';
      detail =
          'Batches are issued to the designated crew leader. The tags for your '
          'crew are recorded under $leader. Please contact your dispatcher if '
          'this assignment requires review.';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandMark()),
        const SizedBox(height: 22),

        Text(
          heading,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppColors.onGreen,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.mutedGreen,
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: checking ? null : onRecheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionGreen,
              foregroundColor: AppColors.deepGreen,
              disabledBackgroundColor: AppColors.greenSurface,
              disabledForegroundColor: AppColors.mutedGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: checking
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.paleGreen,
                    ),
                  )
                : const Text(
                    'REFRESH STATUS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'Assignments may be updated during your shift. Select Refresh '
          'Status once yours has been updated. Signing in again is not '
          'required.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.mutedGreen,
          ),
        ),

        const SizedBox(height: 26),

        // Signed in as, and the way out. He is the second man on a shared
        // handset often enough that the name matters: the screen he is looking
        // at may be about somebody else's account.
        if (user != null)
          Text(
            'Signed in as ${user!.fullName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.paleGreen),
          ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onSignOut,
          style: TextButton.styleFrom(foregroundColor: AppColors.paleGreen),
          child: const Text(
            'Sign out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
