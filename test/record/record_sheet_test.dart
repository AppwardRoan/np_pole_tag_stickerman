import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/widgets/record/record_sheet.dart';
import 'package:np_pole_tag_stickerman/widgets/work/batch_tag_row.dart';

/// The sheet a finished tag opens.
///
/// What it has to get right is which record is on show. A pole sent back and
/// re-filed has more than one, they are the same shape, and reading the
/// replaced one as though it were live would have him checking his work
/// against something the office threw away.

const _refiled = '''
[
  {
    "record_id": 940, "tag_id": 4821, "tag_code": "M31M0", "is_current": true,
    "org_id": 1, "created_at": "2026-09-15T01:12:44",
    "pole_type_id": 2, "height_ft": 35, "height_m": 10.67,
    "latitude": 10.657912, "longitude": 122.948103, "photos": []
  },
  {
    "record_id": 912, "tag_id": 4821, "tag_code": "M31M0", "is_current": false,
    "org_id": 1, "created_at": "2026-09-12T06:03:00",
    "pole_type_id": 1, "height_ft": 30, "photos": []
  }
]
''';

const _justOne = '''
[
  {"record_id": 940, "tag_id": 4821, "tag_code": "M31M0", "is_current": true,
   "org_id": 1, "created_at": "2026-09-15T01:12:44", "pole_type_id": 2,
   "photos": []}
]
''';

const _options = FormOptions(
  poleTypes: [
    FormOption(id: 1, label: 'Wood'),
    FormOption(id: 2, label: 'Concrete'),
  ],
  poleConditions: [],
  telcoOptions: [],
  streetlightOptions: [],
);

Future<void> _open(
  WidgetTester tester, {
  required String body,
  int status = 200,
}) async {
  final api = ApiService(
    client: MockClient((_) async => http.Response(body, status)),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(api),
        formOptionsProvider.overrideWith((ref) async => _options),
      ],
      child: const MaterialApp(
        home: Scaffold(body: RecordSheet(tagId: 4821, tagCode: 'M31M0')),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// The history sits under the record, off the bottom of the sheet. A tap only
/// reaches what is on screen, so the list is dragged up first - which is what
/// he does with his thumb.
Future<void> _scrollToHistory(WidgetTester tester) async {
  // Dragged in steps until the heading is built: how far it sits depends on
  // how many rows the record has, and that grows as the form does.
  for (var i = 0; i < 10 && find.text('ALL RECORDS').evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

/// Taps a row in the history, bringing it into view first.
///
/// `ensureVisible` rather than a bare tap: the section lists every record now,
/// not every record but the one on screen, so it is a row taller and the older
/// attempts can sit past the bottom of the sheet. A tap on a built-but-unseen
/// row lands on whatever is at those coordinates instead.
Future<void> _openRecord(WidgetTester tester, String when) async {
  await tester.ensureVisible(find.text(when));
  await tester.pumpAndSettle();
  await tester.tap(find.text(when));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the current record', (tester) async {
    await _open(tester, body: _refiled);

    expect(find.text('M31M0'), findsOneWidget);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('REPLACED'), findsNothing);

    // The live record's own figures, not the one it replaced: 35 ft, concrete.
    expect(find.text('35 ft · 10.67 m'), findsOneWidget);
    expect(find.text('Concrete'), findsOneWidget);
  });

  testWidgets('lists what it replaced, and opens it on a tap', (tester) async {
    await _open(tester, body: _refiled);

    await _scrollToHistory(tester);
    expect(find.text('ALL RECORDS'), findsOneWidget);

    await _openRecord(tester, 'Sep 12, 2026 · 2:03pm');

    // Now reading the older one: its own height and type, and a chip saying so.
    expect(find.text('REPLACED'), findsOneWidget);
    expect(find.text('30 ft'), findsOneWidget);
    expect(find.text('Wood'), findsOneWidget);
  });

  testWidgets('and comes back to the current one', (tester) async {
    await _open(tester, body: _refiled);

    await _scrollToHistory(tester);
    await _openRecord(tester, 'Sep 12, 2026 · 2:03pm');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('35 ft · 10.67 m'), findsOneWidget);
  });

  testWidgets('the record on screen stays in the list, marked', (
    tester,
  ) async {
    // It used to be left out, so tapping an earlier visit made it vanish while
    // the live record appeared in its place. The rows he was choosing between
    // were never the same rows twice.
    await _open(tester, body: _refiled);

    await _scrollToHistory(tester);
    // `findsWidgets` on the live one: the facts above print it as "Filed" as
    // well, so its date is on screen twice.
    expect(find.text('Sep 15, 2026 · 9:12am'), findsWidgets);
    expect(find.text('Sep 12, 2026 · 2:03pm'), findsOneWidget);

    await _openRecord(tester, 'Sep 12, 2026 · 2:03pm');
    await _scrollToHistory(tester);

    expect(find.text('Sep 15, 2026 · 9:12am'), findsOneWidget);
    expect(find.text('Sep 12, 2026 · 2:03pm'), findsWidgets);
  });

  testWidgets('and reading one brings it up rather than changing it below', (
    tester,
  ) async {
    // The list is at the bottom of the sheet and the record it swaps is at the
    // top. Without this he taps a row and everything he asked to see happens
    // above the fold.
    await _open(tester, body: _refiled);

    await _scrollToHistory(tester);
    await _openRecord(tester, 'Sep 12, 2026 · 2:03pm');

    expect(find.text('REPLACED'), findsOneWidget);
    expect(find.text('30 ft'), findsOneWidget);
  });

  testWidgets('a pole filed once shows no history section', (tester) async {
    await _open(tester, body: _justOne);

    expect(find.text('CURRENT'), findsOneWidget);
    // A list of one under a heading is furniture.
    expect(find.text('ALL RECORDS'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('no signal says so, and offers another go', (tester) async {
    await _open(tester, body: '{"detail": "down"}', status: 500);

    expect(find.text('Cannot reach the office'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a pole with nothing filed says that, rather than an empty form',
      (tester) async {
    await _open(tester, body: '[]');

    expect(find.text('No record filed'), findsOneWidget);
  });

  // The rows inside an opened batch, on My Work. Same sheet, asked from the
  // other end of his history.

  testWidgets('a finished tag in a batch opens the sheet', (tester) async {
    final api = ApiService(
      client: MockClient((_) async => http.Response(_justOne, 200)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          formOptionsProvider.overrideWith((ref) async => _options),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BatchTagRow(
              tag: const Tag(
                tagId: 4821,
                duId: 1,
                tagCode: 'M31M0',
                status: 'Used',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('M31M0'));
    await tester.pumpAndSettle();

    expect(find.text('CURRENT'), findsOneWidget);
  });

  testWidgets('a Received tag in a batch asks too, because it may be a redo',
      (tester) async {
    // The point of tapping an unfinished row. A pole the office sent back reads
    // Received and carries the record of the first attempt, and it looks
    // exactly like a pole nobody has been to yet.
    final api = ApiService(
      client: MockClient((_) async => http.Response(_justOne, 200)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          formOptionsProvider.overrideWith((ref) async => _options),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BatchTagRow(
              tag: const Tag(
                tagId: 4821,
                duId: 1,
                tagCode: 'M31M0',
                status: 'Received',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('M31M0'));
    await tester.pumpAndSettle();

    expect(find.text('CURRENT'), findsOneWidget);
  });

  testWidgets('and says so plainly when there is nothing behind it',
      (tester) async {
    final api = ApiService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          formOptionsProvider.overrideWith((ref) async => _options),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BatchTagRow(
              tag: const Tag(
                tagId: 4822,
                duId: 1,
                tagCode: 'M31M1',
                status: 'Received',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('M31M1'));
    await tester.pumpAndSettle();

    expect(find.text('No record filed'), findsOneWidget);
  });
}
