import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/saved_pole.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/screens/saved_screen.dart';

/// The receipt for a pole just filed.
///
/// It is the only place his work is shown back to him at the moment he finishes
/// it, and it is read in the field - so it has to be right about two things
/// above all: what he recorded, and whether the office actually has it.

const _options = FormOptions(
  poleTypes: [FormOption(id: 4, label: 'Lattice')],
  poleConditions: [FormOption(id: 7, label: 'Rusted')],
  telcoOptions: [FormOption(id: 2, label: 'No')],
  streetlightOptions: [FormOption(id: 5, label: 'No')],
);

SavedPole _pole({bool queued = false, Map<String, dynamic>? record}) {
  return SavedPole(
    tagCode: 'M31NH',
    photos: 4,
    queued: queued,
    batchCode: 'BT-B-2026-0001',
    record:
        record ??
        {
          'latitude': 10.671336,
          'longitude': 122.951150,
          'gps_accuracy': 1.1,
          'telco_option_id': 2,
          'streetlight_option_id': 5,
          'pole_type_id': 4,
          'pole_condition_id': 7,
          'height_ft': 40,
          'height_m': 12.19,
          'remarks': 'leaning slightly',
        },
  );
}

Future<void> _show(WidgetTester tester, SavedPole pole) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [formOptionsProvider.overrideWith((ref) async => _options)],
      child: MaterialApp(home: SavedScreen(pole: pole)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows what was recorded, in words rather than ids',
      (tester) async {
    await _show(tester, _pole());

    expect(find.text('M31NH'), findsOneWidget);
    expect(find.text('10.671336, 122.951150'), findsOneWidget);
    expect(find.text('± 1.1 m'), findsOneWidget);
    expect(find.text('Lattice · 40 ft (12.19 m)'), findsOneWidget);
    expect(find.text('Rusted'), findsOneWidget);
    expect(find.text('4 captured'), findsOneWidget);
    expect(find.text('leaning slightly'), findsOneWidget);
  });

  testWidgets('says the office has it when it went up', (tester) async {
    await _show(tester, _pole());

    expect(
      find.textContaining('the office has it'),
      findsOneWidget,
    );
  });

  testWidgets('and says it is still on the phone when it did not',
      (tester) async {
    // The distinction he has to be able to see. A man who believes the office
    // has a pole that is still in his pocket is a man who wipes the app.
    await _show(tester, _pole(queued: true));

    expect(find.textContaining('will upload when there is signal'),
        findsOneWidget);
    expect(find.textContaining('the office has it'), findsNothing);
  });

  testWidgets('an answer with nothing behind it prints a dash, not a number',
      (tester) async {
    await _show(
      tester,
      _pole(record: {'pole_type_id': 999, 'remarks': '   '}),
    );

    // 999 is an id with no option behind it - a handset that has never been
    // online has no list to resolve it against. "Pole type 999" would mean
    // nothing to him.
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('offers the next pole and the way back', (tester) async {
    await _show(tester, _pole());

    expect(find.text('Scan next pole'), findsOneWidget);
    expect(find.text('Back to list'), findsOneWidget);

    // No back arrow: the form behind this has been submitted, and returning to
    // it would offer a second go at a finished pole.
    expect(find.byType(BackButton), findsNothing);
  });
}
