import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/saved_pole.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/screens/saved_screen.dart';

/// What the confirmation screen reports after a re-capture.
///
/// It reads the record the phone sent, and on a re-capture the phone sends
/// photographs and a note - the six other answers go up null, because he was
/// never asked them and the office keeps the ones from the visit this one
/// replaces.
///
/// Drawn straight, that record printed six dashes under the word RECORDED: a
/// man who has just been told his work was saved, looking at a pole that reads
/// as filed empty.

const _options = FormOptions(
  poleTypes: [FormOption(id: 1, label: 'Wood')],
  poleConditions: [FormOption(id: 3, label: 'Cracked')],
  telcoOptions: [FormOption(id: 4, label: 'No')],
  streetlightOptions: [FormOption(id: 6, label: 'Yes')],
);

Future<void> _show(WidgetTester tester, SavedPole pole) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [formOptionsProvider.overrideWith((ref) async => _options)],
      child: MaterialApp(home: SavedScreen(pole: pole)),
    ),
  );
  await tester.pumpAndSettle();
}

SavedPole _recapture() => const SavedPole(
  tagCode: 'M00TK',
  record: {'tag_id': 2098036, 'remarks': 'M00TK round 2'},
  photos: 3,
  queued: false,
  batchCode: 'BT-M-2026-0002',
  sentBackFor: TagStatus.reCapture,
);

SavedPole _repin() => const SavedPole(
  tagCode: 'MVKF6',
  record: {
    'tag_id': 3067367,
    'latitude': 10.693241,
    'longitude': 122.958117,
    'gps_accuracy': 3.5,
  },
  photos: 0,
  queued: false,
  sentBackFor: TagStatus.rePin,
);

SavedPole _ordinary() => const SavedPole(
  tagCode: 'M00TL',
  record: {
    'tag_id': 2098037,
    'latitude': 10.673902,
    'longitude': 122.951884,
    'gps_accuracy': 0.8,
    'pole_type_id': 1,
    'pole_condition_id': 3,
    'telco_option_id': 4,
    'streetlight_option_id': 6,
    'height_ft': 30.0,
    'height_m': 9.14,
  },
  photos: 3,
  queued: false,
);

void main() {
  testWidgets('a re-capture reports the two things he did', (tester) async {
    await _show(tester, _recapture());

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('3 captured'), findsOneWidget);
    expect(find.text('M00TK round 2'), findsOneWidget);
  });

  testWidgets('and says nothing about the six he was not asked', (
    tester,
  ) async {
    // Not "—" against each of them. A dash is an answer he failed to give,
    // and he gave every answer he was asked for.
    await _show(tester, _recapture());

    for (final row in const [
      'Location',
      'GPS accuracy',
      'Telco attachment',
      'Streetlight attachment',
      'Pole',
      'Condition',
    ]) {
      expect(find.text(row), findsNothing, reason: row);
    }
  });

  testWidgets('a re-pin reports the position and not the photographs', (
    tester,
  ) async {
    // He pointed no camera. "0 captured" under a pole photographed weeks ago
    // reads as work he failed to do - the office carries the shots across to
    // the new record.
    await _show(tester, _repin());

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('GPS accuracy'), findsOneWidget);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Pole'), findsNothing);
    expect(find.text('Condition'), findsNothing);
  });

  testWidgets('an ordinary pole still reports all of them', (tester) async {
    await _show(tester, _ordinary());

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Cracked'), findsOneWidget);
  });
}
