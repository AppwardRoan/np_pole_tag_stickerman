// test/record/asset_type_card_test.dart
//
// Asset type is "select all that apply", and Others opens a box for what it
// is.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/asset_type_card.dart';

const _menu = [
  FormOption(id: 7, label: '69 kb'),
  FormOption(id: 8, label: '13.2 kb'),
  FormOption(id: 9, label: 'DT'),
  FormOption(id: 10, label: '230V'),
  FormOption(id: 11, label: 'AVR'),
  FormOption(id: 12, label: 'Others'),
];

Future<void> _pump(
  WidgetTester t,
  Set<int> selected, {
  ValueChanged<int>? onToggle,
}) {
  return t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetTypeCard(
            options: _menu,
            selectedIds: selected,
            onToggle: onToggle ?? (_) {},
            otherText: TextEditingController(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows every choice as a tick box', (t) async {
    await _pump(t, {8, 10});

    for (final option in _menu) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.text('Select all that apply'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(4));
  });

  testWidgets('tapping a choice reports it', (t) async {
    int? tapped;
    await _pump(t, {}, onToggle: (id) => tapped = id);

    await t.tap(find.text('DT'));

    expect(tapped, 9);
  });

  testWidgets('the Others box shows only while Others is ticked', (t) async {
    await _pump(t, {8});
    expect(find.text('Specify other asset type'), findsNothing);

    await _pump(t, {8, 12});
    expect(find.text('Specify other asset type'), findsOneWidget);
  });

  test('the saved line names every tick, typed text for Others', () {
    expect(
      describeAssetTypes([
        {'asset_type_id': 8},
        {'asset_type_id': 12, 'other_text': 'fuse box'},
      ], _menu),
      '13.2 kb, fuse box',
    );
  });

  test('the label from the server is used when the phone has no menu', () {
    expect(
      describeAssetTypes([
        {'asset_type_id': 9, 'label': 'DT'},
      ], null),
      'DT',
    );
  });

  test('nothing ticked, or an old record, reads as a dash', () {
    expect(describeAssetTypes(const [], _menu), '—');
    expect(describeAssetTypes(null, _menu), '—');
  });
}
