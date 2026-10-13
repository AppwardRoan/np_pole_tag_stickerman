import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/providers/awaiting_receipt_providers.dart';
import 'package:np_pole_tag_stickerman/providers/my_batch_providers.dart';
import 'package:np_pole_tag_stickerman/providers/palette_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';

// ProviderScope has to wrap the app, or nothing inside can reach a provider.
//
// Hive is opened before runApp so the tag cache is ready by the time the first
// screen asks for it - the crew opens this app where there is no signal, and
// the saved list is the only thing it has to show.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only the icons. The colours that used to sit here - `statusBarColor` and
  // `systemNavigationBarColor` - are ignored from Android 15 onward, and
  // asking for them bought a dark band above the green header instead. The
  // strips are made transparent in `MainActivity.kt`; what shows through them
  // is whatever the screen paints, so all that is left to say is which way
  // round the icons go.
  //
  // Light at the top, over the green header. Dark at the foot, over the page.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Upright only.
  //
  // Sideways, a handset gives the body about 330 logical pixels of height and
  // this app's furniture - the green header, the finder, the tabs and the
  // scan button - comes to nearer 390. The tag list, which is the whole point
  // of the page, is squeezed out of existence, and every screen behind it has
  // the same arithmetic against it.
  //
  // Locked rather than laid out again because sideways buys him nothing. He
  // works one-handed at the foot of a pole with the phone upright, and a pole
  // is a tall thing to photograph. One line here, rather than a second layout
  // on eleven screens that nobody would ever see.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Hive.initFlutter();

  runApp(const ProviderScope(child: StickermanApp()));
}

/// Lets the upload bar be shown from outside any particular screen: a queue
/// drains while he is on the camera or the form, not necessarily on Home.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The app shell: theme, the router that decides what is on screen, and the
/// watchers that push waiting tags whenever the phone can.
///
/// Which screen shows is not decided here. That lives in
/// `router/app_router.dart`, so a new screen is one entry in one list instead
/// of another branch in this file.
class StickermanApp extends ConsumerStatefulWidget {
  const StickermanApp({super.key});

  @override
  ConsumerState<StickermanApp> createState() => _StickermanAppState();
}

class _StickermanAppState extends ConsumerState<StickermanApp> {
  UploadTriggers? _triggers;
  StreamSubscription<int>? _uploaded;
  StreamSubscription<List<ConnectivityResult>>? _network;

  /// Whether the last word from the phone was "no signal". Starts false, so
  /// the first report - which only says what the phone already had when the
  /// app opened - does not count as the signal coming back.
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();

    // Signal coming back refreshes what he is looking at. Without this the
    // screens kept what they had from the dead spot until he thought to pull
    // down, and a batch the office sent him meanwhile sat there unseen.
    _network = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      final cameBack = online && _wasOffline;
      _wasOffline = !online;

      if (cameBack) _refreshAll();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for the photo folder before the first pass: a drain started
      // without it would have nowhere to delete the uploaded copies from.
      await ref.read(photoStoreProvider.future);

      if (!mounted) return;

      final uploads = ref.read(uploadProvider.notifier);

      // Told only what the server actually took. This used to be read off the
      // waiting count falling - but a pole refused (turned red) or thrown away
      // by Replace drops that count too, and the bar said "1 tag uploaded" for
      // a pole that never went up.
      _uploaded = uploads.uploads.listen(_announce);
      _triggers = UploadTriggers(uploads)..start();
    });
  }

  @override
  void dispose() {
    _triggers?.stop();
    _uploaded?.cancel();
    _network?.cancel();
    super.dispose();
  }

  /// The same as pulling down on each screen. Quiet: no spinner, and a failure
  /// leaves what is on screen alone, as a failed pull-down does.
  ///
  /// Only when someone is signed in - on the login screen there is nothing to
  /// refresh, and every call would come back refused.
  void _refreshAll() {
    if (ref.read(authProvider).user == null) return;

    ref.read(tagProvider.notifier).loadMyTags();
    ref.read(awaitingReceiptProvider.notifier).refresh();
    ref.read(myBatchProvider.notifier).refresh();
  }

  void _announce(int uploaded) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          uploaded == 1 ? '1 tag uploaded.' : '$uploaded tags uploaded.',
        ),
      ),
    );

    // Those tags are Used on the server now, so they belong under Completed
    // rather than Assigned. Nothing else would move them: they left the queue
    // when they uploaded, so the greying that stood in for "done" while they
    // waited has gone with it.
    ref.read(tagProvider.notifier).loadMyTags();
  }

  @override
  Widget build(BuildContext context) {
    // Set before the theme is built, because the screens read their colours
    // off `AppColors` rather than off the theme: the static has to be right
    // by the time any of them builds.
    final palette = ref.watch(palettePickedProvider);
    AppColors.active = palette;

    // Keyed on the palette so the whole tree is thrown away and rebuilt when
    // he taps the sun. Widgets that are `const` would otherwise be skipped
    // and keep yesterday's colours, and hunting every one of them down is a
    // worse trade than rebuilding once, on a tap he makes twice a week.
    //
    // Nothing is lost by it: the router lives in a provider, so the screen he
    // is on and the stack behind it both survive.
    return MaterialApp.router(
      key: ValueKey(palette),
      title: 'Poletagging Stickerman',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.of(palette),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
