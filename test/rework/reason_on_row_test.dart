import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_row.dart';

/// The reason the office sent a pole back, on the row he reads it from.
///
/// The status says which trip he is making - photographs, a pin, the whole
/// form. Only the reason says what was wrong with the pole, and without it a
/// man reads "Re-capture", retakes all three shots and hopes one of them was
/// the bad one.
///
/// On the row rather than behind a tap because he is choosing which of three
/// poles to drive to, and this is what he chooses on.

Tag _tag({required String status, String? remarks}) => Tag(
  tagId: 2098036,
  duId: 6,
  tagCode: 'M00TK',
  poleNo: '883',
  batchCode: 'BT-M-2026-0002',
  status: status,
  remarks: remarks,
);

Future<void> _show(WidgetTester tester, Tag tag) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TagRow(tag: tag, draft: false, waiting: false, done: false),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a sent-back pole shows what was wrong with it', (tester) async {
    await _show(
      tester,
      _tag(status: TagStatus.reCapture, remarks: 'Photos are blurry'),
    );

    expect(find.text('Photos are blurry'), findsOneWidget);
  });

  testWidgets('every mode carries one', (tester) async {
    await _show(
      tester,
      _tag(status: TagStatus.rePin, remarks: 'pinned across the road'),
    );

    expect(find.text('pinned across the road'), findsOneWidget);
  });

  testWidgets('a long one is cut rather than growing the row', (tester) async {
    // One line. A thousand-character remark would otherwise make one row four
    // times the height of its neighbours; the whole of it is on the screen he
    // opens to do the work.
    await _show(
      tester,
      _tag(status: TagStatus.redo, remarks: 'x' * 400),
    );

    final text = tester.widget<Text>(find.text('x' * 400));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an ordinary pole shows no reason', (tester) async {
    // Every other status writes to `remarks` too - a reprint's reason, a note
    // from the admin screen - and those are the sticker's history rather than
    // an instruction to the man holding it.
    await _show(
      tester,
      _tag(status: TagStatus.received, remarks: 'Reprinted after a jam'),
    );

    expect(find.text('Reprinted after a jam'), findsNothing);
  });

  testWidgets('a sent-back pole with no reason shows no empty line', (
    tester,
  ) async {
    await _show(tester, _tag(status: TagStatus.rePin, remarks: '   '));

    expect(find.text('   '), findsNothing);
  });
}
