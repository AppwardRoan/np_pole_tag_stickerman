// Replaces the generated counter test, which referenced the starter template's
// MyApp and no longer compiles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:np_pole_tag_stickerman/main.dart';

void main() {
  // The app opens on a spinner while it reads the saved login off the phone,
  // and only then decides between Login and the tag list. Two things are
  // needed to get past it in a test:
  //
  //   * SharedPreferences has no plugin here, so `getInstance()` never answers
  //     and the router sits on the spinner forever. An empty mock store stands
  //     in for a phone nobody has signed in on.
  //   * The redirect happens after that read completes, which is a later frame
  //     than `pumpWidget` produces. Hence the pumps rather than one.
  //
  // `pumpAndSettle` is deliberately not used: the startup spinner animates
  // forever, so settling never happens and the test times out instead.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('the app opens on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StickermanApp()));

    await tester.pump();
    await tester.pump();

    expect(find.text('Pole Identification'), findsOneWidget);
    expect(find.text('FIELD CREW SIGN-IN'), findsOneWidget);
    // Upper case because `LoginField` upper-cases the label it is given, not
    // because the screen is passed one - so this is the rendered text rather
    // than the argument.
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'SIGN IN'), findsOneWidget);
  });
}
