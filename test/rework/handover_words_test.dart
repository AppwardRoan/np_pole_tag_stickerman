import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/widgets/home/status_chip.dart';

/// The two halves of the hand-over, drawn as the server sends them.
///
/// This app translated one of them for a day: the server called an accepted
/// tag `Received` and the chip said "Dispatched", because that is how the crew
/// talk about paper they are carrying. The server says Dispatched itself now,
/// so the translation came out — and what these hold down is that it stays
/// out. A word rendered differently from the value behind it is two
/// vocabularies for one fact.

Future<void> _show(WidgetTester tester, String status) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: StatusChip(status: status))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tag a crew is holding reads Dispatched', (tester) async {
    await _show(tester, TagStatus.received);

    expect(find.text('Dispatched'), findsOneWidget);
  });

  testWidgets('a tag nobody has claimed reads To receive', (tester) async {
    await _show(tester, TagStatus.dispatched);

    expect(find.text('To receive'), findsOneWidget);
  });

  testWidgets('neither is translated on the way to the chip', (tester) async {
    // The chip prints the status it was given. Nothing between the server and
    // the screen changes a word.
    for (final status in const [
      TagStatus.dispatched,
      TagStatus.received,
      TagStatus.used,
      TagStatus.rePin,
      TagStatus.lostPrinted,
    ]) {
      await _show(tester, status);

      expect(find.text(status), findsOneWidget, reason: status);
    }
  });
}
