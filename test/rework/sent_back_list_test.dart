import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/my_tags.dart';

/// The third list on the home screen: poles the office has sent back.
///
/// What these hold down is that it arrives as its own list and stays that way.
/// An earlier version of this screen worked out which poles were sent back by
/// looking at whether the tag carried a remark, which is the version that was
/// wrong - a remark can mean a reprint, a lost sticker or nothing in
/// particular. The server now says outright, and the phone must read what it
/// says rather than guess again.

const _body = '''
{
  "received": [
    {"tag_id": 1, "du_id": 6, "tag_code": "M00TL", "pole_no": "884",
     "status": "Received"}
  ],
  "received_total": 1,
  "rework": [
    {"tag_id": 2, "du_id": 6, "tag_code": "M00TK", "pole_no": "883",
     "status": "Re-capture", "remarks": "blurry"},
    {"tag_id": 3, "du_id": 6, "tag_code": "MVKF6", "pole_no": "970214",
     "status": "Re-pin", "remarks": "pinned across the road"}
  ],
  "rework_total": 2,
  "completed": [
    {"tag_id": 4, "du_id": 6, "tag_code": "M1874", "pole_no": "41188",
     "status": "Used"}
  ],
  "completed_total": 1
}
''';

MyTags _parse(String body) =>
    MyTags.fromJson(jsonDecode(body) as Map<String, dynamic>);

void main() {
  group('reading the response', () {
    test('the sent-back poles land in their own list', () {
      final tags = _parse(_body);

      expect(tags.rework.map((t) => t.tagCode), ['M00TK', 'MVKF6']);
    });

    test('and nowhere else', () {
      // Mixed into Assigned they would be rows that look like every other and
      // behave differently when tapped.
      final tags = _parse(_body);

      expect(tags.received.map((t) => t.tagCode), ['M00TL']);
      expect(tags.completed.map((t) => t.tagCode), ['M1874']);
    });

    test('each one says which of the three trips it is', () {
      // The status is what decides the screen he opens: a pin, photographs,
      // or the whole form again.
      final tags = _parse(_body);

      expect(tags.rework[0].status, 'Re-capture');
      expect(tags.rework[1].status, 'Re-pin');
    });

    test('and carries the reason the office wrote', () {
      // The sentence he reads before setting out. The status says which trip;
      // only this says what was wrong with the pole.
      final tags = _parse(_body);

      expect(tags.rework[0].remarks, 'blurry');
      expect(tags.rework[1].remarks, 'pinned across the road');
    });
  });

  group('a server that has not been deployed yet', () {
    const old = '{"received": [], "completed": []}';

    test('sends no such list, and that is not an error', () {
      // The same answer as a crew with nothing sent back, and the right one
      // for both.
      final tags = _parse(old);

      expect(tags.rework, isEmpty);
    });

    test('and the phone still works', () {
      final tags = _parse(old);

      expect(tags.isEmpty, isTrue);
    });
  });

  group('the cached copy', () {
    test('keeps the sent-back poles through a round trip', () {
      // `TagCache` writes this back out and reads it in on the next launch. A
      // list dropped on the way to disk is a pole that vanishes the moment he
      // opens the app in a dead spot.
      final tags = _parse(_body);

      final again = MyTags.fromJson(
        jsonDecode(jsonEncode(tags.toJson())) as Map<String, dynamic>,
      );

      expect(again.rework.map((t) => t.tagCode), ['M00TK', 'MVKF6']);
      expect(again.rework[0].remarks, 'blurry');
    });
  });

  test('the scan lookup reaches a sent-back pole', () {
    // `all` is what finds the tag behind a code he has just scanned. A pole
    // sent back is exactly one he might scan again — he is standing at it.
    final tags = _parse(_body);

    expect(tags.all.map((t) => t.tagCode), contains('M00TK'));
  });
}
