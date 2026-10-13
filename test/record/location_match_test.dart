// test/record/location_match_test.dart
//
// The location match score, from GPS accuracy alone, and the 85% bar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/accuracy_line.dart';

void main() {
  test('1.5 points off per metre, capped at 99', () {
    expect(locationMatch(0), 99);
    expect(locationMatch(1.3), 98);
    expect(locationMatch(10), 85);
    expect(locationMatch(14), 79);
    expect(locationMatch(200), 0);
  });

  test('85% is exactly ±10 m', () {
    expect(locationMatch(10) >= kLocationMatchNeeded, isTrue);
    expect(locationMatch(10.5) >= kLocationMatchNeeded, isFalse);
  });

  Future<void> pump(WidgetTester t, double metres) => t.pumpWidget(
    MaterialApp(home: Scaffold(body: AccuracyLine(metres: metres))),
  );

  testWidgets('a good fix shows its match', (t) async {
    await pump(t, 1.3);

    expect(
      find.text('Recorded automatically · ± 1.3 m · location match 98%'),
      findsOneWidget,
    );
  });

  testWidgets('a weak fix says it is re-fixing', (t) async {
    await pump(t, 14);

    expect(find.textContaining('location match 79%'), findsOneWidget);
    expect(find.textContaining('Improving GPS accuracy'), findsOneWidget);
  });
}
