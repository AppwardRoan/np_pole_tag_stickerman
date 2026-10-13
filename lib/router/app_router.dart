import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:np_pole_tag_stickerman/models/saved_pole.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/screens/accept_screen.dart';
import 'package:np_pole_tag_stickerman/screens/home_screen.dart';
import 'package:np_pole_tag_stickerman/screens/login_screen.dart';
import 'package:np_pole_tag_stickerman/screens/my_work_screen.dart';
import 'package:np_pole_tag_stickerman/screens/no_crew_screen.dart';
import 'package:np_pole_tag_stickerman/screens/saved_screen.dart';
import 'package:np_pole_tag_stickerman/screens/scan_screen.dart';
import 'package:np_pole_tag_stickerman/screens/startup_screen.dart';
import 'package:np_pole_tag_stickerman/screens/tag_form_screen.dart';

// import 'package:np_pole_tag_stickerman/screens/tag_screen.dart';

/// Every screen's name in one place, so a typo is a compile error rather than a
/// blank screen in the field.
abstract final class Routes {
  static const startup = '/';
  static const login = '/login';
  static const tags = '/tags';
  static const scan = '/scan';
  static const tag = '/tag';
  static const tagForm = '/tag-form';
  static const work = '/work';

  /// The envelopes waiting for him to say he is holding them. Pushed from the
  /// strip under the home header, so backing out of it lands where he was.
  static const accept = '/accept';

  /// The receipt for a pole just filed. Replaces the form rather than sitting
  /// on top of it, so the back gesture cannot reopen a record already sent.
  static const saved = '/saved';

  /// Signed in, but carrying nothing: on no crew, or on one somebody else
  /// leads. Not pushed by any screen - the redirect below is what sends him
  /// here, and what takes him off again.
  static const noCrew = '/no-crew';
}

/// The app's routes, and the two rules that decide which of them is allowed.
///
/// There is no role guard here, unlike the web app's router: `AuthNotifier`
/// refuses to sign in anyone who is not a sticker man, so a signed-in user is
/// already known to belong. A guard would be a second copy of a check that has
/// only one place it can be answered - the login reply.
///
/// Leading a crew is guarded here rather than there, and the difference is the
/// point. The role is about whether the app is his at all, so it is settled at
/// the door and nothing is kept for an account that fails it. Leading is about
/// whether there is work in it today, which can change while he is standing in
/// the yard - so he signs in, keeps his token, and waits on a screen that can
/// ask again.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    // Starts on the spinner, not on Login: the token saved on the phone has
    // not been read yet, and showing Login for that half second reads to Juan
    // as having been signed out overnight.
    initialLocation: Routes.startup,

    // Re-runs the redirect below whenever the sign-in changes. This is what
    // replaces the old `_AuthGate` rebuild: logging in, logging out, and the
    // background token check finding a dead token all arrive here, and none of
    // them is a screen calling `go()`.
    refreshListenable: refresh,

    redirect: (context, state) {
      final here = state.matchedLocation;

      // Still reading the phone. Deciding anything now would read an empty
      // account and bounce a signed-in man to Login.
      if (ref.read(authRestoreProvider).isLoading) {
        return here == Routes.startup ? null : Routes.startup;
      }

      final user = ref.read(authProvider).user;
      final isSignedIn = user != null;

      // Where a signed-in man belongs. Every screen in this app is about the
      // tags dealt to him, and only the crew leader is dealt any, so for
      // anybody else there is nothing behind the door but empty lists.
      final home = user != null && user.isCrewLeader
          ? Routes.tags
          : Routes.noCrew;

      // The read is done, so nobody has a reason to sit on the spinner.
      if (here == Routes.startup) {
        return isSignedIn ? home : Routes.login;
      }

      if (!isSignedIn) return here == Routes.login ? null : Routes.login;
      if (here == Routes.login) return home;

      // Held on the one screen that explains it, and let straight back out the
      // moment the office names him leader - `recheck()` is what brings that
      // answer in, and this line is what acts on it.
      if (home == Routes.noCrew) return here == Routes.noCrew ? null : home;
      if (here == Routes.noCrew) return home;

      return null;
    },

    routes: [
      GoRoute(path: Routes.startup, builder: (_, _) => const StartupScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.tags, builder: (_, _) => const HomeScreen()),
      // Catches the tag the list sent and hands it to the camera. Nullable
      // because the Scan button sends none - that absence is what tells the
      // camera to find the tag rather than confirm one.
      //
      // Checked with `is` rather than cast: a restart while this screen is
      // open cannot carry the Tag through, and what comes back in its place is
      // a raw map. Casting that red-screened him. Anything that is not a Tag
      // now means "nothing was named", which is the harmless mode.
      GoRoute(
        path: Routes.scan,
        builder: (_, state) => ScanScreen(
          expected: state.extra is Tag ? state.extra as Tag : null,
        ),
      ),

      // Off the path since the scan started opening the form directly, the way
      // the mockup does. Left here rather than deleted - the screen still
      // exists and this is the one line that puts it back.
      // GoRoute(path: Routes.tag, builder: (_, state) => TagScreen(tag: state.extra! as Tag)),
      GoRoute(
        path: Routes.tagForm,
        builder: (_, state) =>
            TagFormScreen(tag: state.extra is Tag ? state.extra as Tag : null),
      ),

      GoRoute(path: Routes.work, builder: (_, _) => const MyWorkScreen()),
      GoRoute(path: Routes.accept, builder: (_, _) => const AcceptScreen()),
      GoRoute(path: Routes.noCrew, builder: (_, _) => const NoCrewScreen()),

      // Checked with `is`, like the scan route above: a restart cannot carry
      // the summary across, and what comes back in its place is a raw map.
      // Without the tag there is nothing to show, so it goes to the list.
      GoRoute(
        path: Routes.saved,
        builder: (_, state) => state.extra is SavedPole
            ? SavedScreen(pole: state.extra as SavedPole)
            : const HomeScreen(),
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(
      authRestoreProvider,
      (_, _) => notifyListeners(),
      fireImmediately: true,
    );
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}
