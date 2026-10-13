import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/draft_providers.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/screens/tag_form_screen.dart';
import 'package:np_pole_tag_stickerman/services/draft_store.dart';

/// What a pole sent back for its photographs asks of the crew.
///
/// The office rejected the shots and nothing else. So the form puts the photo
/// step and the remarks in front of him and stops there - the pin, the height,
/// the type and the condition were right when he filed them, and asking again
/// is asking him to copy his own answers back in while standing at a pole he
/// came to photograph.
///
/// What he is not asked, he does not send. Those fields go up null and the
/// server fills them from the record this one replaces, reading the row as it
/// stands rather than trusting a copy the phone took days earlier.

class _NoDrafts implements DraftStore {
  @override
  Future<List<DraftTag>> read() async => const [];

  @override
  Future<DraftTag?> find(int tagId) async => null;

  @override
  Future<void> save(DraftTag draft) async {}

  @override
  Future<void> remove(int tagId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Tag _tag(String status) => Tag(
  tagId: 2098036,
  duId: 6,
  tagCode: 'M00TK',
  poleNo: '883',
  status: status,
  remarks: 'blurry',
);

Future<void> _open(WidgetTester tester, String status) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        draftStoreProvider.overrideWithValue(_NoDrafts()),
        formOptionsProvider.overrideWith(
          (ref) async => const FormOptions(
            poleTypes: [FormOption(id: 1, label: 'Wood')],
            poleConditions: [FormOption(id: 3, label: 'Cracked')],
            telcoOptions: [FormOption(id: 4, label: 'No')],
            streetlightOptions: [FormOption(id: 6, label: 'Yes')],
          ),
        ),
      ],
      child: MaterialApp(home: TagFormScreen(tag: _tag(status))),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a re-capture walks two steps, not four', (tester) async {
    await _open(tester, TagStatus.reCapture);

    expect(find.textContaining('STEP 1 OF 2'), findsOneWidget);
  });

  testWidgets('and opens on the photographs', (tester) async {
    // Not on the map. He is standing at the pole with a camera; the first
    // thing in front of him should be the thing he came to do.
    await _open(tester, TagStatus.reCapture);

    expect(find.text('Asset photos'), findsOneWidget);
  });

  testWidgets('a re-pin walks two steps as well', (tester) async {
    await _open(tester, TagStatus.rePin);

    expect(find.textContaining('STEP 1 OF 2'), findsOneWidget);
  });

  testWidgets('and opens on the map', (tester) async {
    await _open(tester, TagStatus.rePin);

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Asset photos'), findsNothing);
  });

  testWidgets('a re-pin is not asked about telco or streetlight', (
    tester,
  ) async {
    // They belong to a first capture and are already on file. Demanding an
    // answer about a telco cable would stop a man who came to move a pin, over
    // a box he was not shown.
    await _open(tester, TagStatus.rePin);

    expect(find.textContaining('telco attachment'), findsNothing);
    expect(find.textContaining('streetlight attachment'), findsNothing);
  });

  testWidgets('a redo still walks all four', (tester) async {
    // A fresh capture. Everything is being filed again, so he is asked
    // everything again.
    await _open(tester, TagStatus.redo);

    expect(find.textContaining('STEP 1 OF 4'), findsOneWidget);
  });

  testWidgets('a re-pin does not claim a scan that never happened', (
    tester,
  ) async {
    // It reaches this step without the camera now. "Scan complete" over a form
    // nobody scanned into is the one sentence on this screen that would be
    // simply untrue - and it is the sentence a man checks when he wants to
    // know he is at the right pole.
    await _open(tester, TagStatus.rePin);

    expect(find.text('Scan complete'), findsNothing);
    expect(find.text('Sent back · Re-pin'), findsOneWidget);
    expect(find.text('M00TK'), findsOneWidget);
  });

  testWidgets('a redo still comes off the camera and says so', (tester) async {
    await _open(tester, TagStatus.redo);

    expect(find.text('Scan complete'), findsOneWidget);
  });

  testWidgets('the location step is not one of them', (tester) async {
    // The pin is not being changed. A step offering to move it is an invitation
    // to move it by accident.
    await _open(tester, TagStatus.reCapture);

    expect(find.text('Location'), findsNothing);
    expect(find.text('Pole details'), findsNothing);
  });
}
