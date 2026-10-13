import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';

/// Who the handset thinks is holding the paper.
///
/// A batch is dealt to the crew leader alone, so this one answer decides
/// whether the app shows a man his work or shows him the wall explaining why
/// there is none. It arrives from `/auth/login` and `/me`, and it is cached, so
/// there are three ways to get it wrong: misreading the reply, losing it on the
/// way to the phone, and meeting a reply that predates it.

const _crewReply = '''
{
  "user_id": 2,
  "first_name": "juan",
  "last_name": "dela cruz",
  "email": "jdelacruz@x.com",
  "username": "jdelacruz",
  "is_active": true,
  "roles": [],
  "can_use_mobile": true,
  "is_crew_leader": false,
  "crew": {
    "crew_id": 3,
    "crew_label": "P. Santos",
    "leader_id": 1,
    "leader_name": "P. Santos"
  }
}
''';

void main() {
  test('a member who does not lead his crew is read as not leading it', () {
    final user = User.fromJson(jsonDecode(_crewReply));

    expect(user.isCrewLeader, isFalse);
  });

  test('and is told who does, so the screen can name him', () {
    final user = User.fromJson(jsonDecode(_crewReply));

    expect(user.crew!.leaderId, 1);
    expect(user.crew!.leaderName, 'P. Santos');
  });

  test('the leader is read as leading it', () {
    final json = jsonDecode(_crewReply) as Map<String, dynamic>;
    json['user_id'] = 1;
    json['is_crew_leader'] = true;

    expect(User.fromJson(json).isCrewLeader, isTrue);
  });

  test('a crew nobody leads names nobody', () {
    final json = jsonDecode(_crewReply) as Map<String, dynamic>;
    (json['crew'] as Map<String, dynamic>)
      ..['leader_id'] = null
      ..['leader_name'] = null;

    final user = User.fromJson(json);

    expect(user.isCrewLeader, isFalse);
    expect(user.crew!.leaderName, isNull);
  });

  test('the answer survives the trip to the phone and back', () {
    // The cache is written with toJson and read with fromJson. A field missing
    // from the first is a man who leads a crew until he restarts his handset.
    final user = User.fromJson(jsonDecode(_crewReply));

    final cached = User.fromJson(jsonDecode(jsonEncode(user.toJson())));

    expect(cached.isCrewLeader, isFalse);
    expect(cached.crew!.leaderName, 'P. Santos');
  });

  test('a reply without the field is treated as leading, not as blocked', () {
    // What a user cached by the previous version of this app looks like, and
    // what an older backend would send. Defaulting the other way would put the
    // wall in front of a leader who restarts his phone out of signal, with his
    // own batch in the van - and out there he cannot sign in again to clear it.
    final json = jsonDecode(_crewReply) as Map<String, dynamic>;
    json.remove('is_crew_leader');

    expect(User.fromJson(json).isCrewLeader, isTrue);
  });

  test('a man on no crew at all is not leading one', () {
    final json = jsonDecode(_crewReply) as Map<String, dynamic>;
    json['crew'] = null;

    final user = User.fromJson(json);

    expect(user.crew, isNull);
    expect(user.isCrewLeader, isFalse);
  });
}
